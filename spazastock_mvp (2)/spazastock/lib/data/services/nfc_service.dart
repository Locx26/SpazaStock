// lib/data/services/nfc_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:logger/logger.dart';

final _log = Logger();

enum NfcState { idle, scanning, writing, success, error, unavailable }

class NfcScanResult {
  final bool success;
  final String? tagUid;
  final String? productId;
  final String? rawPayload;
  final String? error;

  const NfcScanResult({
    required this.success,
    this.tagUid,
    this.productId,
    this.rawPayload,
    this.error,
  });

  factory NfcScanResult.failure(String error) =>
      NfcScanResult(success: false, error: error);
}

class NfcService {
  static const String _spazaUrnPrefix = 'urn:spazastock:product:';

  final _stateController = StreamController<NfcState>.broadcast();
  Stream<NfcState> get stateStream => _stateController.stream;

  bool _isAvailable = false;

  Future<bool> initialize() async {
    try {
      _isAvailable = await NfcManager.instance.isAvailable();
      if (!_isAvailable) {
        _log.w('NFC is not available on this device');
        _stateController.add(NfcState.unavailable);
      }
      return _isAvailable;
    } catch (e) {
      _log.e('NFC initialization error: $e');
      _stateController.add(NfcState.unavailable);
      return false;
    }
  }

  bool get isAvailable => _isAvailable;

  // ── Read tag ──────────────────────────────────────────────────────────────

  /// Starts NFC session and resolves with first tag read.
  /// Works on Android (NfcA, NfcB, NfcF, NfcV, Ndef, MifareClassic, etc.)
  /// and iOS (Iso7816, FeliCa, Iso15693, MiFare, Ndef)
  Future<NfcScanResult> readTag() async {
    if (!_isAvailable) {
      return NfcScanResult.failure('NFC not available');
    }

    final completer = Completer<NfcScanResult>();
    _stateController.add(NfcState.scanning);

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final uid = _extractUid(tag);
            final productId = _readProductIdFromNdef(tag);

            _log.i('Tag discovered: uid=$uid, productId=$productId');
            _stateController.add(NfcState.success);

            await NfcManager.instance.stopSession();
            completer.complete(NfcScanResult(
              success: true,
              tagUid: uid,
              productId: productId,
            ));
          } catch (e) {
            _log.e('Error reading tag: $e');
            _stateController.add(NfcState.error);
            await NfcManager.instance.stopSession(errorMessage: 'Read error');
            completer.complete(NfcScanResult.failure(e.toString()));
          }
        },
        // iOS: required alert messages
        alertMessage: 'Hold your phone near the SpazaStock tag',
      );
    } catch (e) {
      _stateController.add(NfcState.error);
      completer.complete(NfcScanResult.failure(e.toString()));
    }

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        NfcManager.instance.stopSession();
        _stateController.add(NfcState.idle);
        return NfcScanResult.failure('Scan timed out');
      },
    );
  }

  // ── Write tag ─────────────────────────────────────────────────────────────

  /// Writes a product ID to an NFC tag as an NDEF URI record.
  Future<NfcScanResult> writeProductToTag(String productId) async {
    if (!_isAvailable) return NfcScanResult.failure('NFC not available');

    final completer = Completer<NfcScanResult>();
    _stateController.add(NfcState.writing);

    final message = NdefMessage([
      NdefRecord.createUri(Uri.parse('$_spazaUrnPrefix$productId')),
    ]);

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          final uid = _extractUid(tag);
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              throw Exception('Tag does not support NDEF');
            }
            if (!ndef.isWritable) {
              throw Exception('Tag is not writable (read-only)');
            }
            await ndef.write(message);
            _log.i('Wrote productId=$productId to tag uid=$uid');
            _stateController.add(NfcState.success);
            await NfcManager.instance.stopSession(alertMessage: 'Tag written!');
            completer.complete(NfcScanResult(
              success: true,
              tagUid: uid,
              productId: productId,
            ));
          } catch (e) {
            _log.e('Write error: $e');
            _stateController.add(NfcState.error);
            await NfcManager.instance.stopSession(errorMessage: 'Write failed');
            completer.complete(NfcScanResult.failure(e.toString()));
          }
        },
        alertMessage: 'Hold your phone near a blank SpazaStock tag',
      );
    } catch (e) {
      _stateController.add(NfcState.error);
      completer.complete(NfcScanResult.failure(e.toString()));
    }

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        NfcManager.instance.stopSession();
        _stateController.add(NfcState.idle);
        return NfcScanResult.failure('Write timed out');
      },
    );
  }

  Future<void> stopSession() async {
    await NfcManager.instance.stopSession();
    _stateController.add(NfcState.idle);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _extractUid(NfcTag tag) {
    final data = tag.data;

    // Android: nfca, nfcb, nfcf, nfcv all expose 'identifier'
    for (final key in ['nfca', 'nfcb', 'nfcf', 'nfcv', 'mifareclassic', 'mifareultralight']) {
      if (data.containsKey(key)) {
        final identifier = data[key]?['identifier'];
        if (identifier is Uint8List) {
          return identifier.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
        }
      }
    }

    // iOS: iso7816, iso15693, feliCa, miFare
    for (final key in ['iso7816', 'iso15693', 'feliCa', 'miFare']) {
      if (data.containsKey(key)) {
        final identifier = data[key]?['identifier'] ?? data[key]?['currentIDm'];
        if (identifier is Uint8List) {
          return identifier.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
        }
      }
    }

    // NDEF has identifier too
    if (data.containsKey('ndef')) {
      final identifier = data['ndef']?['identifier'];
      if (identifier is Uint8List) {
        return identifier.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
      }
    }

    return 'UNKNOWN-${DateTime.now().millisecondsSinceEpoch}';
  }

  String? _readProductIdFromNdef(NfcTag tag) {
    final ndef = Ndef.from(tag);
    final cachedMessage = ndef?.cachedMessage;
    if (cachedMessage == null) return null;

    for (final record in cachedMessage.records) {
      if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
          String.fromCharCodes(record.type) == 'U') {
        final payload = record.payload;
        if (payload.isEmpty) continue;
        // First byte is the URI identifier code (0x00 = no prepend)
        final uriString = String.fromCharCodes(payload.sublist(1));
        if (uriString.startsWith(_spazaUrnPrefix)) {
          return uriString.substring(_spazaUrnPrefix.length);
        }
      }
    }
    return null;
  }

  void dispose() {
    _stateController.close();
  }
}
