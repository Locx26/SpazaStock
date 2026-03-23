// test/inventory_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spazastock/data/database/database_helper.dart';
import 'package:spazastock/data/models/models.dart';
import 'package:spazastock/data/repositories/inventory_repository.dart';

void main() {
  late InventoryRepository repo;

  setUpAll(() {
    // Use in-memory SQLite for tests
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    repo = InventoryRepository();
  });

  tearDown(() async {
    await DatabaseHelper().clearAll();
    await DatabaseHelper().close();
  });

  group('InventoryRepository - Products', () {
    test('creates and retrieves a product', () async {
      final product = Product(
        name: 'Test Bread',
        nameSetswana: 'Borotho jwa Test',
        category: 'Food',
        price: 12.50,
        quantity: 50,
      );

      final id = await repo.createProduct(product);
      final retrieved = await repo.getProductById(id);

      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Test Bread'));
      expect(retrieved.price, equals(12.50));
      expect(retrieved.quantity, equals(50));
    });

    test('updates a product', () async {
      final product = Product(
        name: 'Old Name',
        category: 'Food',
        price: 10.00,
        quantity: 20,
      );
      await repo.createProduct(product);

      final updated = product.copyWith(name: 'New Name', price: 15.00);
      await repo.updateProduct(updated);

      final retrieved = await repo.getProductById(product.id);
      expect(retrieved!.name, equals('New Name'));
      expect(retrieved.price, equals(15.00));
    });

    test('soft-deletes a product', () async {
      final product = Product(
        name: 'Delete Me',
        category: 'Food',
        price: 5.00,
        quantity: 10,
      );
      await repo.createProduct(product);
      await repo.deleteProduct(product.id);

      final active = await repo.getAllProducts(activeOnly: true);
      expect(active.where((p) => p.id == product.id).isEmpty, isTrue);
    });

    test('returns low-stock products', () async {
      final lowStock = Product(
        name: 'Nearly Gone',
        category: 'Food',
        price: 8.00,
        quantity: 3,
        lowStockThreshold: 5,
      );
      final wellStocked = Product(
        name: 'Plenty Here',
        category: 'Food',
        price: 8.00,
        quantity: 50,
        lowStockThreshold: 5,
      );

      await repo.createProduct(lowStock);
      await repo.createProduct(wellStocked);

      final results = await repo.getLowStockProducts();
      expect(results.any((p) => p.id == lowStock.id), isTrue);
      expect(results.any((p) => p.id == wellStocked.id), isFalse);
    });
  });

  group('InventoryRepository - Sales', () {
    late Product testProduct;

    setUp(() async {
      testProduct = Product(
        name: 'Test Product',
        category: 'Food',
        price: 10.00,
        quantity: 100,
      );
      await repo.createProduct(testProduct);
    });

    test('records a sale and reduces stock', () async {
      final sale = await repo.recordSale(
        productId: testProduct.id,
        quantity: 3,
        unitPrice: 10.00,
      );

      expect(sale.quantitySold, equals(3));
      expect(sale.totalAmount, equals(30.00));

      final updated = await repo.getProductById(testProduct.id);
      expect(updated!.quantity, equals(97));
    });

    test('throws on insufficient stock', () async {
      expect(
        () => repo.recordSale(
          productId: testProduct.id,
          quantity: 200, // More than available
          unitPrice: 10.00,
        ),
        throwsException,
      );
    });

    test('adds sale to sync queue', () async {
      await repo.recordSale(
        productId: testProduct.id,
        quantity: 1,
        unitPrice: 10.00,
      );

      final pending = await repo.getPendingSyncCount();
      expect(pending, greaterThan(0));
    });

    test('records daily summary correctly', () async {
      await repo.recordSale(
          productId: testProduct.id, quantity: 2, unitPrice: 10.00);
      await repo.recordSale(
          productId: testProduct.id, quantity: 1, unitPrice: 10.00);

      final summary = await repo.getDailySummary(DateTime.now());
      expect(summary['transaction_count'], equals(2));
      expect((summary['total_revenue'] as num).toDouble(), equals(30.00));
      expect(summary['items_sold'], equals(3));
    });
  });

  group('InventoryRepository - NFC Tags', () {
    late Product testProduct;

    setUp(() async {
      testProduct = Product(
        name: 'NFC Product',
        category: 'Food',
        price: 15.00,
        quantity: 30,
      );
      await repo.createProduct(testProduct);
    });

    test('links NFC tag to product', () async {
      const tagUid = 'AA:BB:CC:DD:EE:FF';
      await repo.linkNfcTag(productId: testProduct.id, tagUid: tagUid);

      final found = await repo.getProductByTagUid(tagUid);
      expect(found, isNotNull);
      expect(found!.id, equals(testProduct.id));
    });
  });

  group('SyncQueue', () {
    test('marks sync complete', () async {
      final product = Product(
        name: 'Sync Test',
        category: 'Food',
        price: 10.00,
        quantity: 10,
      );
      await repo.createProduct(product);

      final pending = await repo.getPendingSyncItems();
      expect(pending.isNotEmpty, isTrue);

      await repo.markSyncComplete(pending.first.id);

      final count = await repo.getPendingSyncCount();
      expect(count, equals(0));
    });

    test('increments retry count on failure', () async {
      final product = Product(
        name: 'Fail Sync',
        category: 'Food',
        price: 5.00,
        quantity: 5,
      );
      await repo.createProduct(product);

      final pending = await repo.getPendingSyncItems();
      await repo.markSyncFailed(pending.first.id);

      final afterFail = await repo.getPendingSyncItems();
      final item = afterFail.firstWhere((i) => i.id == pending.first.id);
      expect(item.retryCount, equals(1));
    });
  });
}
