// lib/presentation/screens/inventory/inventory_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/inventory_repository.dart';

final _repoProvider = Provider((_) => InventoryRepository());

enum _Filter { all, lowStock, expiring, outOfStock }

final _filterProvider = StateProvider((_) => _Filter.all);
final _searchProvider = StateProvider((_) => '');

final inventoryProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(_repoProvider).getAllProducts();
});

final filteredInventoryProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final all = ref.watch(inventoryProvider);
  final filter = ref.watch(_filterProvider);
  final search = ref.watch(_searchProvider).toLowerCase();

  return all.whenData((products) {
    var filtered = products;
    if (search.isNotEmpty) {
      filtered = filtered
          .where((p) =>
              p.name.toLowerCase().contains(search) ||
              p.nameSetswana.toLowerCase().contains(search) ||
              (p.sku?.toLowerCase().contains(search) ?? false))
          .toList();
    }
    return switch (filter) {
      _Filter.lowStock => filtered.where((p) => p.isLowStock && !p.isOutOfStock).toList(),
      _Filter.outOfStock => filtered.where((p) => p.isOutOfStock).toList(),
      _Filter.expiring => filtered.where((p) => p.isExpiringSoon).toList(),
      _Filter.all => filtered,
    };
  });
});

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredInventoryProvider);
    final filter = ref.watch(_filterProvider);

    return Scaffold(
      backgroundColor: SpazaColors.background,
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: SpazaColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            onPressed: () => context.go('/product/add'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: (v) =>
                  ref.read(_searchProvider.notifier).state = v,
              style: const TextStyle(fontFamily: 'Poppins'),
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                prefixIconColor: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: _Filter.values.map((f) {
                final isSelected = filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filterLabel(f)),
                    selected: isSelected,
                    onSelected: (_) =>
                        ref.read(_filterProvider.notifier).state = f,
                    backgroundColor: SpazaColors.surface,
                    selectedColor: SpazaColors.primary.withOpacity(0.15),
                    checkmarkColor: SpazaColors.primary,
                    labelStyle: TextStyle(
                      fontFamily: 'Poppins',
                      color: isSelected ? SpazaColors.primary : SpazaColors.onBackground,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    side: BorderSide(
                      color: isSelected ? SpazaColors.primary : SpazaColors.divider,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Product list
          Expanded(
            child: filtered.when(
              data: (products) => products.isEmpty
                  ? _EmptyState(filter: filter)
                  : RefreshIndicator(
                      color: SpazaColors.primary,
                      onRefresh: () async => ref.invalidate(inventoryProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: products.length,
                        itemBuilder: (_, i) => _ProductTile(product: products[i]),
                      ),
                    ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: SpazaColors.primary),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/product/add'),
        backgroundColor: SpazaColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add product',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
      ),
    );
  }

  String _filterLabel(_Filter f) => switch (f) {
        _Filter.all => 'All',
        _Filter.lowStock => '⚠ Low stock',
        _Filter.outOfStock => '✗ Out of stock',
        _Filter.expiring => '⏰ Expiring',
      };
}

class _ProductTile extends ConsumerWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color stockColor = SpazaColors.inStock;
    String stockLabel = '${product.quantity} in stock';
    if (product.isOutOfStock) {
      stockColor = SpazaColors.outOfStock;
      stockLabel = 'Out of stock';
    } else if (product.isLowStock) {
      stockColor = SpazaColors.lowStock;
      stockLabel = 'Low: ${product.quantity}';
    }

    return GestureDetector(
      onTap: () => context.go('/product/edit/${product.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SpazaColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: product.isOutOfStock
                ? SpazaColors.outOfStock.withOpacity(0.3)
                : SpazaColors.divider,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _categoryColor(product.category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _categoryEmoji(product.category),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  if (product.nameSetswana.isNotEmpty)
                    Text(product.nameSetswana,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: SpazaColors.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(product.category,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: SpazaColors.textSecondary)),
                      if (product.nfcTagId != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.nfc_rounded,
                            size: 14, color: SpazaColors.primary),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'BWP ${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: SpazaColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stockColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: stockColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    stockLabel,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: stockColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String cat) => switch (cat.toLowerCase()) {
        'food' || 'dijo' => SpazaColors.success,
        'drinks' || 'mamanzi' => SpazaColors.info,
        'snacks' || 'dikaka' => SpazaColors.accent,
        'airtime' => SpazaColors.primary,
        _ => SpazaColors.textSecondary,
      };

  String _categoryEmoji(String cat) => switch (cat.toLowerCase()) {
        'food' || 'dijo' => '🍞',
        'drinks' || 'mamanzi' => '🥤',
        'snacks' || 'dikaka' => '🍟',
        'household' || 'ntlo' => '🧹',
        'personalcare' || 'tlhokomelo ya mmele' => '🧴',
        'airtime' => '📱',
        _ => '📦',
      };
}

class _EmptyState extends StatelessWidget {
  final _Filter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 64, color: SpazaColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                filter == _Filter.all
                    ? 'No products yet'
                    : 'No products match this filter',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                filter == _Filter.all
                    ? 'Tap + to add your first product'
                    : 'Try a different filter',
                style: const TextStyle(color: SpazaColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
