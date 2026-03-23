// lib/core/utils/seed_data.dart
// Run this in dev mode to populate the database with realistic test data.

import 'package:uuid/uuid.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/models.dart';
import '../../data/repositories/inventory_repository.dart';

class SeedData {
  static Future<void> seedAll() async {
    final repo = InventoryRepository();
    await _seedProducts(repo);
    await _seedSales(repo);
    print('✅ SpazaStock seed data loaded');
  }

  static Future<void> _seedProducts(InventoryRepository repo) async {
    final products = [
      Product(name: 'White Bread 700g', nameSetswana: 'Borotho jo Botshweu', sku: 'BRD001', category: 'Food', price: 12.50, costPrice: 9.00, quantity: 50, lowStockThreshold: 10),
      Product(name: 'Brown Bread 700g', nameSetswana: 'Borotho jo Bosootho', sku: 'BRD002', category: 'Food', price: 13.00, costPrice: 9.50, quantity: 35, lowStockThreshold: 10),
      Product(name: 'Coca-Cola 340ml', nameSetswana: 'Kokokola', sku: 'CCL340', category: 'Drinks', price: 10.00, costPrice: 7.00, quantity: 48, lowStockThreshold: 12),
      Product(name: 'Fanta Orange 340ml', nameSetswana: 'Fanta', sku: 'FNT340', category: 'Drinks', price: 10.00, costPrice: 7.00, quantity: 36, lowStockThreshold: 12),
      Product(name: 'Simba Chips 120g', nameSetswana: 'Dikaka tsa Simba', sku: 'SIM120', category: 'Snacks', price: 12.00, costPrice: 8.50, quantity: 60, lowStockThreshold: 15),
      Product(name: 'Nik Naks 100g', nameSetswana: 'Nik Naks', sku: 'NIK100', category: 'Snacks', price: 10.00, costPrice: 7.00, quantity: 45, lowStockThreshold: 10),
      Product(name: 'Sunlight Dishwash 200ml', nameSetswana: 'Sesepa sa go Tlhapa', sku: 'SUN200', category: 'Household', price: 15.00, costPrice: 11.00, quantity: 20, lowStockThreshold: 5),
      Product(name: 'Doom Insect Spray', nameSetswana: 'Boswe', sku: 'DOM001', category: 'Household', price: 35.00, costPrice: 27.00, quantity: 8, lowStockThreshold: 5),
      Product(name: 'Vaseline 50ml', nameSetswana: 'Vaseline', sku: 'VAS050', category: 'Personal care', price: 18.00, costPrice: 12.00, quantity: 25, lowStockThreshold: 8),
      Product(name: 'Airtime Orange BWP10', nameSetswana: 'Airtime ya BWP10', sku: 'AIR010', category: 'Airtime', price: 10.00, costPrice: 10.00, quantity: 200, lowStockThreshold: 20),
      Product(name: 'Airtime Orange BWP20', nameSetswana: 'Airtime ya BWP20', sku: 'AIR020', category: 'Airtime', price: 20.00, costPrice: 20.00, quantity: 150, lowStockThreshold: 15),
      Product(name: 'Milk 1L Clover', nameSetswana: 'Mashi', sku: 'MLK001', category: 'Food', price: 20.00, costPrice: 15.50, quantity: 20, lowStockThreshold: 8,
        expiryDate: DateTime.now().add(const Duration(days: 5)).toIso8601String().substring(0, 10)),
      Product(name: 'Eggs × 6', nameSetswana: 'Mae a 6', sku: 'EGG006', category: 'Food', price: 22.00, costPrice: 17.00, quantity: 4, lowStockThreshold: 5,
        expiryDate: DateTime.now().add(const Duration(days: 14)).toIso8601String().substring(0, 10)),
      Product(name: 'Magwinya (doughnut)', nameSetswana: 'Magwinya', sku: 'MAG001', category: 'Food', price: 3.00, costPrice: 1.50, quantity: 0, lowStockThreshold: 5),
    ];

    for (final p in products) {
      await repo.createProduct(p);
    }
    print('  Seeded ${products.length} products');
  }

  static Future<void> _seedSales(InventoryRepository repo) async {
    final allProducts = await repo.getAllProducts();
    if (allProducts.isEmpty) return;

    final rand = DateTime.now().millisecondsSinceEpoch;
    final methods = PaymentMethod.values;

    // Generate 30 days of historical sales
    for (int day = 29; day >= 0; day--) {
      final date = DateTime.now().subtract(Duration(days: day));
      final txCount = 5 + (rand % 10).toInt(); // 5–15 sales per day

      for (int t = 0; t < txCount; t++) {
        final product = allProducts[(t + day) % allProducts.length];
        if (product.quantity <= 0) continue;

        final qty = 1 + (t % 3);
        final method = methods[(t + day) % (methods.length - 1)];

        try {
          final sale = Sale(
            productId: product.id,
            productName: product.name,
            quantitySold: qty,
            unitPrice: product.price,
            totalAmount: product.price * qty,
            paymentMethod: method,
            synced: true,
            soldAt: DateTime(date.year, date.month, date.day,
                8 + (t * 2 % 12), t * 7 % 60),
          );

          final db = await DatabaseHelper().database;
          await db.insert('sales', sale.toMap());
        } catch (_) {
          // Skip if product not found
        }
      }
    }
    print('  Seeded historical sales');
  }
}
