// lib/data/services/sync_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workmanager/workmanager.dart';
import 'package:logger/logger.dart';
import '../repositories/inventory_repository.dart';
import '../models/models.dart';

final _log = Logger();

const _syncTaskName = 'spazastock.sync';
const _syncTaskTag = 'sync';

// Called by WorkManager on Android / BGTaskScheduler on iOS
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    _log.i('Background sync task: $taskName');
    try {
      final repo = InventoryRepository();
      final syncService = SyncService(repo: repo);
      await syncService.runSync();
      return Future.value(true);
    } catch (e) {
      _log.e('Background sync failed: $e');
      return Future.value(false);
    }
  });
}

class SyncService {
  final InventoryRepository _repo;
  final http.Client _client;
  bool _isSyncing = false;

  // Replace with real server URL for production
  static const String _baseUrl = 'http://localhost:3000/api';

  SyncService({
    required InventoryRepository repo,
    http.Client? client,
  })  : _repo = repo,
        _client = client ?? http.Client();

  /// Register background sync task with platform schedulers
  static Future<void> registerBackgroundSync() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      _syncTaskName,
      _syncTaskName,
      tag: _syncTaskTag,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
    _log.i('Background sync task registered');
  }

  /// Listen for connectivity and trigger sync on reconnect
  Stream<bool> get connectivityStream => Connectivity()
      .onConnectivityChanged
      .map((result) => result != ConnectivityResult.none);

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // ── Main sync loop ────────────────────────────────────────────────────────

  Future<SyncResult> runSync() async {
    if (_isSyncing) {
      _log.d('Sync already in progress, skipping');
      return const SyncResult(synced: 0, failed: 0, skipped: true);
    }

    if (!await isOnline()) {
      _log.d('Offline — sync deferred');
      return const SyncResult(synced: 0, failed: 0, skipped: true);
    }

    _isSyncing = true;
    int synced = 0;
    int failed = 0;

    try {
      final pending = await _repo.getPendingSyncItems(limit: 100);
      _log.i('Syncing ${pending.length} items');

      for (final item in pending) {
        final ok = await _syncItem(item);
        if (ok) {
          await _repo.markSyncComplete(item.id);
          synced++;
        } else {
          await _repo.markSyncFailed(item.id);
          failed++;
        }
      }

      _log.i('Sync complete: $synced synced, $failed failed');
    } finally {
      _isSyncing = false;
    }

    return SyncResult(synced: synced, failed: failed);
  }

  Future<bool> _syncItem(SyncQueueItem item) async {
    try {
      final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
      final endpoint = _endpointFor(item.entityType, item.operation);
      final method = _methodFor(item.operation);

      final response = await _sendRequest(
        method: method,
        url: endpoint,
        payload: payload,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }

      // 409 Conflict → apply conflict resolution
      if (response.statusCode == 409) {
        return await _resolveConflict(item, response);
      }

      _log.w('Sync HTTP ${response.statusCode} for ${item.entityType}/${item.entityId}');
      return false;
    } catch (e) {
      _log.e('Sync error for ${item.id}: $e');
      return false;
    }
  }

  // Conflict resolution: local-write-wins for sales (never lose a sale),
  // server-wins for product master data
  Future<bool> _resolveConflict(SyncQueueItem item, http.Response response) async {
    _log.w('Conflict for ${item.entityType}/${item.entityId}');

    if (item.entityType == 'sale') {
      // Always push the local sale — never lose revenue data
      _log.i('Conflict resolution: local-wins for sale ${item.entityId}');
      final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
      payload['_conflict_override'] = true;
      final forceResponse = await _sendRequest(
        method: 'POST',
        url: '$_baseUrl/sales/force',
        payload: payload,
      );
      return forceResponse.statusCode < 300;
    }

    // For products: accept server version (server wins)
    _log.i('Conflict resolution: server-wins for ${item.entityType} ${item.entityId}');
    final serverData = jsonDecode(response.body) as Map<String, dynamic>?;
    if (serverData != null && item.entityType == 'product') {
      final updated = Product.fromMap(serverData);
      await _repo.updateProduct(updated.copyWith(synced: true));
    }
    return true;
  }

  Future<http.Response> _sendRequest({
    required String method,
    required String url,
    required Map<String, dynamic> payload,
  }) {
    final uri = Uri.parse(url);
    final body = jsonEncode(payload);
    final headers = {
      'Content-Type': 'application/json',
      'X-Spaza-Client': 'mobile/1.0.0',
    };
    return switch (method) {
      'POST' => _client.post(uri, headers: headers, body: body),
      'PUT' => _client.put(uri, headers: headers, body: body),
      'DELETE' => _client.delete(uri, headers: headers),
      _ => _client.get(uri, headers: headers),
    };
  }

  String _endpointFor(String entityType, SyncOperation op) {
    final base = '$_baseUrl/${entityType}s';
    return op == SyncOperation.create ? base : '$base/{id}';
  }

  String _methodFor(SyncOperation op) => switch (op) {
        SyncOperation.create => 'POST',
        SyncOperation.update => 'PUT',
        SyncOperation.delete => 'DELETE',
      };

  void dispose() {
    _client.close();
  }
}

class SyncResult {
  final int synced;
  final int failed;
  final bool skipped;

  const SyncResult({
    required this.synced,
    required this.failed,
    this.skipped = false,
  });
}
