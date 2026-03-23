// lib/presentation/screens/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../data/services/sync_service.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _repoProvider = Provider((ref) => InventoryRepository());
final _syncServiceProvider = Provider((ref) => SyncService(repo: ref.watch(_repoProvider)));

final dashboardSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final repo = ref.watch(_repoProvider);
  return repo.getDailySummary(DateTime.now());
});

final lowStockProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(_repoProvider).getLowStockProducts();
});

final recentSalesProvider = FutureProvider<List<Sale>>((ref) {
  return ref.watch(_repoProvider).getSalesHistory(limit: 5);
});

final syncCountProvider = FutureProvider<int>((ref) {
  return ref.watch(_repoProvider).getPendingSyncCount();
});

final isOnlineProvider = FutureProvider<bool>((ref) {
  return ref.watch(_syncServiceProvider).isOnline();
});

// ── Screen ───────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final lowStock = ref.watch(lowStockProvider);
    final recentSales = ref.watch(recentSalesProvider);
    final syncCount = ref.watch(syncCountProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      backgroundColor: SpazaColors.background,
      body: RefreshIndicator(
        color: SpazaColors.primary,
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(lowStockProvider);
          ref.invalidate(recentSalesProvider);
          ref.invalidate(syncCountProvider);
        },
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context, isOnline, syncCount),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting() + ' 👋',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: SpazaColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 24),

                    // Stats row
                    summary.when(
                      data: (data) => _StatsRow(data: data),
                      loading: () => const _StatsRowSkeleton(),
                      error: (_, __) => const _ErrorCard(),
                    ),

                    const SizedBox(height: 24),

                    // Quick actions
                    _QuickActions(),

                    const SizedBox(height: 24),

                    // Low stock alerts
                    lowStock.when(
                      data: (items) => items.isNotEmpty
                          ? _LowStockCard(items: items)
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 24),

                    // Recent sales
                    Text(
                      'Recent sales',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    recentSales.when(
                      data: (sales) => sales.isEmpty
                          ? const _EmptySalesCard()
                          : Column(
                              children: sales
                                  .map((s) => _SaleTile(sale: s))
                                  .toList(),
                            ),
                      loading: () => const _SalesTileSkeleton(),
                      error: (_, __) => const _ErrorCard(),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(
    BuildContext context,
    AsyncValue<bool> isOnline,
    AsyncValue<int> syncCount,
  ) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      snap: true,
      backgroundColor: SpazaColors.primary,
      title: Row(
        children: [
          const Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          const Text('SpazaStock',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
        ],
      ),
      actions: [
        // Connectivity + sync badge
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            children: [
              isOnline.maybeWhen(
                data: (online) => Icon(
                  online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: online ? Colors.white : Colors.white60,
                  size: 20,
                ),
                orElse: () =>
                    const Icon(Icons.wifi_rounded, color: Colors.white60, size: 20),
              ),
              const SizedBox(width: 4),
              syncCount.maybeWhen(
                data: (count) => count > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: SpazaColors.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () {/* settings */},
        ),
      ],
    );
  }
}

// ── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StatsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final revenue = (data['total_revenue'] as num?)?.toDouble() ?? 0;
    final txCount = (data['transaction_count'] as int?) ?? 0;
    final itemsSold = (data['items_sold'] as int?) ?? 0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Revenue',
            value: 'BWP ${revenue.toStringAsFixed(2)}',
            icon: Icons.attach_money_rounded,
            color: SpazaColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Transactions',
            value: '$txCount',
            icon: Icons.receipt_long_outlined,
            color: SpazaColors.info,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Items sold',
            value: '$itemsSold',
            icon: Icons.shopping_bag_outlined,
            color: SpazaColors.accent,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: SpazaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.nfc_rounded,
                label: 'NFC Sale',
                color: SpazaColors.primary,
                onTap: () => context.go('/scan'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.add_box_outlined,
                label: 'Add product',
                color: SpazaColors.accent,
                onTap: () => context.go('/product/add'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.inventory_2_outlined,
                label: 'Inventory',
                color: SpazaColors.info,
                onTap: () => context.go('/inventory'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Low stock alert ───────────────────────────────────────────────────────────

class _LowStockCard extends StatelessWidget {
  final List<Product> items;
  const _LowStockCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpazaColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SpazaColors.warning.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: SpazaColors.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                'Low stock alert — ${items.length} item${items.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: SpazaColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.take(3).map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(p.name,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.isOutOfStock
                            ? SpazaColors.error
                            : SpazaColors.warning,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.isOutOfStock ? 'Out' : '${p.quantity} left',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          if (items.length > 3) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => context.go('/inventory'),
              child: Text(
                'View all ${items.length} items →',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: SpazaColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sale tile ─────────────────────────────────────────────────────────────────

class _SaleTile extends StatelessWidget {
  final Sale sale;
  const _SaleTile({required this.sale});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpazaColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SpazaColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SpazaColors.primaryLight.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_bag_outlined,
                color: SpazaColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.productName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${sale.quantitySold} unit${sale.quantitySold == 1 ? '' : 's'} · ${sale.paymentMethod.name}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: SpazaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'BWP ${sale.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: SpazaColors.primary,
                ),
              ),
              Text(
                DateFormat('HH:mm').format(sale.soldAt),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: SpazaColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Skeleton + error states ──────────────────────────────────────────────────

class _StatsRowSkeleton extends StatelessWidget {
  const _StatsRowSkeleton();
  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(
          3,
          (_) => Expanded(
            child: Container(
              height: 90,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: SpazaColors.divider,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      );
}

class _SalesTileSkeleton extends StatelessWidget {
  const _SalesTileSkeleton();
  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(
          3,
          (_) => Container(
            height: 68,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: SpazaColors.divider,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
}

class _EmptySalesCard extends StatelessWidget {
  const _EmptySalesCard();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 48, color: SpazaColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                'No sales yet today',
                style: TextStyle(
                    fontFamily: 'Poppins', color: SpazaColors.textSecondary),
              ),
            ],
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SpazaColors.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.error_outline, color: SpazaColors.error, size: 18),
            SizedBox(width: 8),
            Text('Failed to load data',
                style: TextStyle(
                    fontFamily: 'Poppins', color: SpazaColors.error)),
          ],
        ),
      );
}
