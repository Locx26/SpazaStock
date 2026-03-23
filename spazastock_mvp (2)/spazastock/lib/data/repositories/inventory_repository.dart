// lib/data/repositories/inventory_repository.dart
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

final _log = Logger();

class InventoryRepository {
  final DatabaseHelper _db;

  InventoryRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  // ── Products ──────────────────────────────────────────────────────────────

  Future<List<Product>> getAllProducts({bool activeOnly = true}) async {
    final db = await _db.database;
    final where = activeOnly ? 'WHERE is_active = 1' : '';
    final maps = await db.rawQuery(
      'SELECT * FROM products $where ORDER BY name ASC',
    );
    return maps.map(Product.fromMap).toList();
  }

  Future<Product?> getProductById(String id) async {
    final db = await _db.database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : Product.fromMap(maps.first);
  }

  Future<Product?> getProductByTagUid(String tagUid) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT p.* FROM products p
      INNER JOIN nfc_tags t ON t.product_id = p.id
      WHERE t.tag_uid = ? AND t.is_active = 1
    ''', [tagUid]);
    return maps.isEmpty ? null : Product.fromMap(maps.first);
  }

  Future<List<Product>> getLowStockProducts() async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT * FROM products
      WHERE is_active = 1 AND quantity <= low_stock_threshold
      ORDER BY quantity ASC
    ''');
    return maps.map(Product.fromMap).toList();
  }

  Future<List<Product>> getExpiringSoonProducts() async {
    final db = await _db.database;
    final cutoff = DateTime.now().add(const Duration(days: 7)).toIso8601String();
    final maps = await db.rawQuery('''
      SELECT * FROM products
      WHERE is_active = 1 AND expiry_date IS NOT NULL AND expiry_date <= ?
      ORDER BY expiry_date ASC
    ''', [cutoff]);
    return maps.map(Product.fromMap).toList();
  }

  Future<String> createProduct(Product product) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert('products', product.toMap());
      await _enqueueSync(
        txn: txn,
        entityType: 'product',
        entityId: product.id,
        operation: SyncOperation.create,
        payload: product.toMap(),
      );
    });
    _log.i('Created product: ${product.name}');
    return product.id;
  }

  Future<void> updateProduct(Product product) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'products',
        product.copyWith(synced: false).toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );
      await _enqueueSync(
        txn: txn,
        entityType: 'product',
        entityId: product.id,
        operation: SyncOperation.update,
        payload: product.toMap(),
      );
    });
    _log.i('Updated product: ${product.name}');
  }

  Future<void> deleteProduct(String id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'products',
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _enqueueSync(
        txn: txn,
        entityType: 'product',
        entityId: id,
        operation: SyncOperation.delete,
        payload: {'id': id},
      );
    });
  }

  // ── Stock management ──────────────────────────────────────────────────────

  /// Reduce stock for a sale — works fully offline
  Future<Sale> recordSale({
    required String productId,
    required int quantity,
    required double unitPrice,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    String? paymentRef,
  }) async {
    final db = await _db.database;
    late Sale sale;

    final product = await getProductById(productId);
    if (product == null) throw Exception('Product $productId not found');
    if (product.quantity < quantity) {
      throw Exception('Insufficient stock: have ${product.quantity}, need $quantity');
    }

    await db.transaction((txn) async {
      final newQty = product.quantity - quantity;
      await txn.update(
        'products',
        {'quantity': newQty, 'updated_at': DateTime.now().toIso8601String(), 'synced': 0},
        where: 'id = ?',
        whereArgs: [productId],
      );

      sale = Sale(
        productId: productId,
        productName: product.name,
        quantitySold: quantity,
        unitPrice: unitPrice,
        totalAmount: unitPrice * quantity,
        paymentMethod: paymentMethod,
        paymentRef: paymentRef,
      );
      await txn.insert('sales', sale.toMap());

      final movement = StockMovement(
        productId: productId,
        movementType: MovementType.sale,
        quantityDelta: -quantity,
        reason: 'Sale ${sale.id}',
        referenceId: sale.id,
      );
      await txn.insert('stock_movements', movement.toMap());

      await _enqueueSync(
        txn: txn,
        entityType: 'sale',
        entityId: sale.id,
        operation: SyncOperation.create,
        payload: sale.toMap(),
      );
    });

    _log.i('Recorded sale: ${product.name} x$quantity @ BWP ${unitPrice.toStringAsFixed(2)}');
    return sale;
  }

  Future<void> adjustStock({
    required String productId,
    required int newQuantity,
    required String reason,
  }) async {
    final db = await _db.database;
    final product = await getProductById(productId);
    if (product == null) throw Exception('Product $productId not found');

    final delta = newQuantity - product.quantity;
    await db.transaction((txn) async {
      await txn.update(
        'products',
        {'quantity': newQuantity, 'updated_at': DateTime.now().toIso8601String(), 'synced': 0},
        where: 'id = ?',
        whereArgs: [productId],
      );
      final movement = StockMovement(
        productId: productId,
        movementType: MovementType.adjustment,
        quantityDelta: delta,
        reason: reason,
      );
      await txn.insert('stock_movements', movement.toMap());
      await _enqueueSync(
        txn: txn,
        entityType: 'stock_movement',
        entityId: movement.id,
        operation: SyncOperation.create,
        payload: movement.toMap(),
      );
    });
  }

  // ── NFC Tags ──────────────────────────────────────────────────────────────

  Future<void> linkNfcTag({
    required String productId,
    required String tagUid,
  }) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      // Deactivate any existing tag for this product
      await txn.update(
        'nfc_tags',
        {'is_active': 0},
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      final tag = NfcTag(tagUid: tagUid, productId: productId);
      await txn.insert('nfc_tags', tag.toMap());
      await txn.update(
        'products',
        {'nfc_tag_id': tag.id, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [productId],
      );
    });
    _log.i('Linked NFC tag $tagUid to product $productId');
  }

  // ── Sales history ─────────────────────────────────────────────────────────

  Future<List<Sale>> getSalesHistory({
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    final db = await _db.database;
    String where = '1=1';
    final args = <dynamic>[];
    if (from != null) {
      where += ' AND sold_at >= ?';
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where += ' AND sold_at <= ?';
      args.add(to.toIso8601String());
    }
    final maps = await db.rawQuery(
      'SELECT * FROM sales WHERE $where ORDER BY sold_at DESC LIMIT $limit',
      args.isEmpty ? null : args,
    );
    return maps.map(Sale.fromMap).toList();
  }

  Future<Map<String, dynamic>> getDailySummary(DateTime date) async {
    final db = await _db.database;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as transaction_count,
        COALESCE(SUM(total_amount), 0) as total_revenue,
        COALESCE(SUM(quantity_sold), 0) as items_sold
      FROM sales
      WHERE sold_at BETWEEN ? AND ?
    ''', [start, end]);

    final topItems = await db.rawQuery('''
      SELECT product_name, SUM(quantity_sold) as qty, SUM(total_amount) as revenue
      FROM sales
      WHERE sold_at BETWEEN ? AND ?
      GROUP BY product_id
      ORDER BY qty DESC
      LIMIT 5
    ''', [start, end]);

    return {
      'transaction_count': result.first['transaction_count'],
      'total_revenue': result.first['total_revenue'],
      'items_sold': result.first['items_sold'],
      'top_items': topItems,
    };
  }

  // ── Sync queue helpers ────────────────────────────────────────────────────

  Future<void> _enqueueSync({
    required dynamic txn,
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    final item = SyncQueueItem(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payloadJson: jsonEncode(payload),
    );
    await txn.insert('sync_queue', item.toMap());
  }

  Future<List<SyncQueueItem>> getPendingSyncItems({int limit = 50}) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT * FROM sync_queue
      WHERE status IN ('pending', 'failed') AND retry_count < 5
      ORDER BY queued_at ASC
      LIMIT $limit
    ''');
    return maps.map(SyncQueueItem.fromMap).toList();
  }

  Future<void> markSyncComplete(String syncItemId) async {
    final db = await _db.database;
    await db.update(
      'sync_queue',
      {'status': 'completed', 'last_attempt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [syncItemId],
    );
  }

  Future<void> markSyncFailed(String syncItemId) async {
    final db = await _db.database;
    await db.rawUpdate('''
      UPDATE sync_queue
      SET status = 'failed',
          retry_count = retry_count + 1,
          last_attempt = ?
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), syncItemId]);
  }

  Future<int> getPendingSyncCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as c FROM sync_queue WHERE status IN ('pending','failed') AND retry_count < 5",
    );
    return (result.first['c'] as int?) ?? 0;
  }
}
