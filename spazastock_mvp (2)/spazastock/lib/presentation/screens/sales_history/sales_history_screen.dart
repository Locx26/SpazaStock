// lib/presentation/screens/sales_history/sales_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/inventory_repository.dart';

final _repoProvider = Provider((_) => InventoryRepository());

enum _DateFilter { today, week, month, all }

final _dateFilterProvider = StateProvider((_) => _DateFilter.today);

final salesProvider = FutureProvider<List<Sale>>((ref) {
  final repo = ref.watch(_repoProvider);
  final filter = ref.watch(_dateFilterProvider);
  final now = DateTime.now();
  final from = switch (filter) {
    _DateFilter.today => DateTime(now.year, now.month, now.day),
    _DateFilter.week => now.subtract(const Duration(days: 7)),
    _DateFilter.month => now.subtract(const Duration(days: 30)),
    _DateFilter.all => null,
  };
  return repo.getSalesHistory(from: from);
});

class SalesHistoryScreen extends ConsumerWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(salesProvider);
    final filter = ref.watch(_dateFilterProvider);

    return Scaffold(
      backgroundColor: SpazaColors.background,
      appBar: AppBar(
        title: const Text('Sales history'),
        backgroundColor: SpazaColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Date filter tabs
          Container(
            color: SpazaColors.primary,
            child: Row(
              children: _DateFilter.values.map((f) {
                final isSelected = filter == f;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => ref.read(_dateFilterProvider.notifier).state = f,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Text(
                        _filterLabel(f),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? Colors.white : Colors.white60,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Summary banner
          sales.maybeWhen(
            data: (list) {
              final total = list.fold(0.0, (s, e) => s + e.totalAmount);
              return Container(
                padding: const EdgeInsets.all(16),
                color: SpazaColors.surfaceVariant,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${list.length} transaction${list.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Total: BWP ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        color: SpazaColors.primary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // Sales list
          Expanded(
            child: sales.when(
              data: (list) => list.isEmpty
                  ? const _EmptySales()
                  : RefreshIndicator(
                      color: SpazaColors.primary,
                      onRefresh: () async =>
                          ref.invalidate(salesProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _SaleTile(sale: list[i]),
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

  String _filterLabel(_DateFilter f) => switch (f) {
        _DateFilter.today => 'Today',
        _DateFilter.week => 'Week',
        _DateFilter.month => 'Month',
        _DateFilter.all => 'All',
      };
}

class _SaleTile extends StatelessWidget {
  final Sale sale;
  const _SaleTile({required this.sale});

  @override
  Widget build(BuildContext context) => Container(
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _methodColor(sale.paymentMethod).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_methodIcon(sale.paymentMethod),
                  color: _methodColor(sale.paymentMethod), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sale.productName,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          fontSize: 14)),
                  Text(
                    '${sale.quantitySold} unit${sale.quantitySold == 1 ? '' : 's'} · ${_methodLabel(sale.paymentMethod)}',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: SpazaColors.textSecondary),
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
                      fontWeight: FontWeight.w700,
                      color: SpazaColors.primary),
                ),
                Text(
                  DateFormat('dd MMM · HH:mm').format(sale.soldAt),
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: SpazaColors.textSecondary),
                ),
                if (!sale.synced)
                  const Icon(Icons.cloud_off_outlined,
                      size: 13, color: SpazaColors.warning),
              ],
            ),
          ],
        ),
      );

  Color _methodColor(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => SpazaColors.success,
        PaymentMethod.orangeMoney => SpazaColors.accent,
        PaymentMethod.myZaka => SpazaColors.info,
        PaymentMethod.card => SpazaColors.primary,
        _ => SpazaColors.textSecondary,
      };

  IconData _methodIcon(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => Icons.payments_outlined,
        PaymentMethod.orangeMoney => Icons.phone_android_outlined,
        PaymentMethod.myZaka => Icons.mobile_friendly_outlined,
        PaymentMethod.card => Icons.credit_card_outlined,
        _ => Icons.receipt_outlined,
      };

  String _methodLabel(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.orangeMoney => 'Orange Money',
        PaymentMethod.myZaka => 'MyZaka',
        PaymentMethod.card => 'Card',
        _ => 'Other',
      };
}

class _EmptySales extends StatelessWidget {
  const _EmptySales();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 64, color: SpazaColors.textSecondary),
            const SizedBox(height: 16),
            Text('No sales in this period',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Use NFC scan to record a sale',
                style: TextStyle(color: SpazaColors.textSecondary)),
          ],
        ),
      );
}
