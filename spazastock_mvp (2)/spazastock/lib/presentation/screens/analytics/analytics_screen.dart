// lib/presentation/screens/analytics/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/inventory_repository.dart';

final _repoProvider = Provider((_) => InventoryRepository());

final weeklyAnalyticsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(_repoProvider);
  final results = <Map<String, dynamic>>[];
  for (int i = 6; i >= 0; i--) {
    final date = DateTime.now().subtract(Duration(days: i));
    final summary = await repo.getDailySummary(date);
    results.add({...summary, 'date': date});
  }
  return results;
});

final topProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(_repoProvider);
  final summary = await repo.getDailySummary(DateTime.now());
  return (summary['top_items'] as List<Map<String, dynamic>>?) ?? [];
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: SpazaColors.background,
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: SpazaColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: SpazaColors.primary,
        onRefresh: () async {
          ref.invalidate(weeklyAnalyticsProvider);
          ref.invalidate(topProductsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _WeeklyRevenueChart(),
            const SizedBox(height: 24),
            _TopProductsCard(),
            const SizedBox(height: 24),
            _SummaryStatsCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Weekly revenue bar chart ──────────────────────────────────────────────────

class _WeeklyRevenueChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklyAnalyticsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SpazaColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SpazaColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue — last 7 days',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: weekly.when(
              data: (data) => BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: data.map((d) => (d['total_revenue'] as num).toDouble()).fold(0.0, (a, b) => a > b ? a : b) * 1.2 + 10,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                        'BWP ${rod.toY.toStringAsFixed(2)}',
                        const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) {
                          final i = val.toInt();
                          if (i < 0 || i >= data.length) return const SizedBox();
                          final date = data[i]['date'] as DateTime;
                          return Text(
                            DateFormat('EEE').format(date),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: SpazaColors.textSecondary,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: SpazaColors.divider,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: data.asMap().entries.map((e) {
                    final isToday = e.key == data.length - 1;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: (e.value['total_revenue'] as num).toDouble(),
                          color: isToday
                              ? SpazaColors.primary
                              : SpazaColors.primaryLight.withOpacity(0.4),
                          width: 24,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    );
                  }).toList(),
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
    );
  }
}

// ── Top products ──────────────────────────────────────────────────────────────

class _TopProductsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(topProductsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SpazaColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SpazaColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top selling items today',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          top.when(
            data: (items) => items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No sales data yet',
                          style: TextStyle(
                              color: SpazaColors.textSecondary,
                              fontFamily: 'Poppins')),
                    ),
                  )
                : Column(
                    children: items.asMap().entries.map((e) {
                      final rank = e.key + 1;
                      final item = e.value;
                      final maxQty = (items.first['qty'] as num).toDouble();
                      final qty = (item['qty'] as num).toDouble();
                      return _TopProductRow(
                        rank: rank,
                        name: item['product_name'] as String,
                        qty: qty.toInt(),
                        revenue: (item['revenue'] as num).toDouble(),
                        barFraction: maxQty > 0 ? qty / maxQty : 0,
                      );
                    }).toList(),
                  ),
            loading: () => const Center(
              child: CircularProgressIndicator(color: SpazaColors.primary),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  final int rank;
  final String name;
  final int qty;
  final double revenue;
  final double barFraction;

  const _TopProductRow({
    required this.rank,
    required this.name,
    required this.qty,
    required this.revenue,
    required this.barFraction,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? SpazaColors.accent
                        : SpazaColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: rank == 1 ? Colors.white : SpazaColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          fontSize: 14)),
                ),
                Text(
                  '$qty sold',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: SpazaColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Text(
                  'BWP ${revenue.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: SpazaColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: barFraction,
                backgroundColor: SpazaColors.divider,
                valueColor: const AlwaysStoppedAnimation(SpazaColors.primary),
                minHeight: 6,
              ),
            ),
          ],
        ),
      );
}

// ── Summary stats card ────────────────────────────────────────────────────────

class _SummaryStatsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklyAnalyticsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SpazaColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SpazaColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7-day summary',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          weekly.when(
            data: (data) {
              final totalRevenue = data.fold(
                  0.0, (sum, d) => sum + (d['total_revenue'] as num).toDouble());
              final totalTx = data.fold(
                  0, (sum, d) => sum + ((d['transaction_count'] as int?) ?? 0));
              final totalItems = data.fold(
                  0, (sum, d) => sum + ((d['items_sold'] as int?) ?? 0));

              return Row(
                children: [
                  _SummaryChip(
                    label: 'Revenue',
                    value: 'BWP ${totalRevenue.toStringAsFixed(2)}',
                    color: SpazaColors.primary,
                  ),
                  const SizedBox(width: 10),
                  _SummaryChip(
                    label: 'Transactions',
                    value: '$totalTx',
                    color: SpazaColors.info,
                  ),
                  const SizedBox(width: 10),
                  _SummaryChip(
                    label: 'Items sold',
                    value: '$totalItems',
                    color: SpazaColors.accent,
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: SpazaColors.primary),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: color)),
              Text(label,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: SpazaColors.textSecondary)),
            ],
          ),
        ),
      );
}
