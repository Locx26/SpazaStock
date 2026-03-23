// lib/presentation/screens/nfc_scan/nfc_scan_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../data/services/nfc_service.dart';
import '../../../data/services/payment_service.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final nfcServiceProvider = Provider((_) => NfcService());
final _repoProvider = Provider((_) => InventoryRepository());
final _paymentServiceProvider = Provider((_) => PaymentService());

final nfcStateProvider = StreamProvider<NfcState>((ref) {
  return ref.watch(nfcServiceProvider).stateStream;
});

// ── Screen ────────────────────────────────────────────────────────────────────

class NfcScanScreen extends ConsumerStatefulWidget {
  const NfcScanScreen({super.key});

  @override
  ConsumerState<NfcScanScreen> createState() => _NfcScanScreenState();
}

class _NfcScanScreenState extends ConsumerState<NfcScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  NfcScanResult? _lastResult;
  Product? _scannedProduct;
  bool _isAvailable = false;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initNfc();
  }

  Future<void> _initNfc() async {
    final svc = ref.read(nfcServiceProvider);
    final ok = await svc.initialize();
    if (mounted) setState(() => _isAvailable = ok);
  }

  Future<void> _startScan() async {
    if (!_isAvailable) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _lastResult = null;
      _scannedProduct = null;
    });

    final svc = ref.read(nfcServiceProvider);
    final result = await svc.readTag();

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (!result.success) {
      setState(() => _errorMsg = result.error);
      return;
    }

    setState(() => _lastResult = result);
    HapticFeedback.mediumImpact();

    // Look up product
    if (result.productId != null) {
      final repo = ref.read(_repoProvider);
      final product = await repo.getProductById(result.productId!);
      if (mounted) {
        setState(() => _scannedProduct = product);
        if (product != null) {
          _showSaleDialog(product);
        } else {
          setState(() => _errorMsg = 'Product not found in database');
        }
      }
    } else if (result.tagUid != null) {
      // Tag scanned but no product ID written — offer to link
      _showLinkTagDialog(result.tagUid!);
    }
  }

  // ── Sale dialog ──────────────────────────────────────────────────────────

  void _showSaleDialog(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SaleConfirmSheet(
        product: product,
        onConfirm: (qty, method) => _processSale(product, qty, method),
      ),
    );
  }

  Future<void> _processSale(
    Product product,
    int quantity,
    PaymentMethod method,
  ) async {
    Navigator.of(context).pop();
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(_repoProvider);

      // Handle mobile money
      if (method == PaymentMethod.orangeMoney ||
          method == PaymentMethod.myZaka) {
        final paymentSvc = ref.read(_paymentServiceProvider);
        final request = PaymentRequest(
          transactionId: DateTime.now().millisecondsSinceEpoch.toString(),
          amount: product.price * quantity,
          phoneNumber: '267XXXXXXXX', // Collected from user in real flow
          description: 'SpazaStock: ${product.name} x$quantity',
        );
        final payResult = method == PaymentMethod.orangeMoney
            ? await paymentSvc.initiateOrangeMoneyPayment(request)
            : await paymentSvc.initiateMyzakaPayment(request);

        if (payResult.status != PaymentStatus.success) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMsg = payResult.errorMessage ?? 'Payment failed';
            });
          }
          return;
        }
      }

      final sale = await repo.recordSale(
        productId: product.id,
        quantity: quantity,
        unitPrice: product.price,
        paymentMethod: method,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        HapticFeedback.heavyImpact();
        _showSuccessOverlay(sale, product);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = e.toString();
        });
      }
    }
  }

  void _showLinkTagDialog(String tagUid) {
    // In a real flow: show product picker to link this tag
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Tag $tagUid found — no product linked yet'),
      action: SnackBarAction(label: 'Link', onPressed: () {}),
    ));
  }

  void _showSuccessOverlay(Sale sale, Product product) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SaleSuccessDialog(sale: sale, product: product),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    ref.read(nfcServiceProvider).stopSession();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final nfcState = ref.watch(nfcStateProvider);

    return Scaffold(
      backgroundColor: SpazaColors.background,
      appBar: AppBar(
        title: const Text('NFC Scanner'),
        backgroundColor: SpazaColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _isLoading
                    ? _buildLoadingState()
                    : !_isAvailable
                        ? _buildUnavailableState()
                        : _buildReadyState(nfcState),
              ),
            ),
            if (_errorMsg != null) _buildErrorBanner(),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyState(AsyncValue<NfcState> nfcState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _pulseAnim,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SpazaColors.primary.withOpacity(0.08),
              border: Border.all(
                color: SpazaColors.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SpazaColors.primary.withOpacity(0.12),
                ),
                child: const Icon(
                  Icons.nfc_rounded,
                  size: 72,
                  color: SpazaColors.primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Tap to scan NFC tag',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Hold your device near the product tag\nto record a sale instantly',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: SpazaColors.textSecondary),
        ),
        const SizedBox(height: 48),
        FilledButton.icon(
          onPressed: _startScan,
          icon: const Icon(Icons.nfc_rounded),
          label: const Text('Start scanning'),
          style: FilledButton.styleFrom(
            backgroundColor: SpazaColors.primary,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: SpazaColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Scanning...',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Hold device near the NFC tag',
            style: TextStyle(color: SpazaColors.textSecondary),
          ),
        ],
      );

  Widget _buildUnavailableState() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.nfc_rounded,
              size: 80, color: SpazaColors.textSecondary),
          const SizedBox(height: 24),
          const Text(
            'NFC not available',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'This device does not support NFC, or NFC is turned off. '
              'Enable NFC in device settings.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontFamily: 'Poppins', color: SpazaColors.textSecondary),
            ),
          ),
        ],
      );

  Widget _buildErrorBanner() => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SpazaColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SpazaColors.error.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: SpazaColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMsg!,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: SpazaColors.error,
                  fontSize: 13,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _errorMsg = null),
              child: const Icon(Icons.close, size: 18, color: SpazaColors.error),
            ),
          ],
        ),
      );

  Widget _buildBottomBar() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: SpazaColors.surface,
          border: Border(top: BorderSide(color: SpazaColors.divider)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                size: 16, color: SpazaColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Works offline — sales are queued and synced when online',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: SpazaColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Sale confirmation bottom sheet ────────────────────────────────────────────

class _SaleConfirmSheet extends StatefulWidget {
  final Product product;
  final void Function(int quantity, PaymentMethod method) onConfirm;

  const _SaleConfirmSheet({
    required this.product,
    required this.onConfirm,
  });

  @override
  State<_SaleConfirmSheet> createState() => _SaleConfirmSheetState();
}

class _SaleConfirmSheetState extends State<_SaleConfirmSheet> {
  int _quantity = 1;
  PaymentMethod _method = PaymentMethod.cash;

  @override
  Widget build(BuildContext context) {
    final total = widget.product.price * _quantity;
    return Container(
      decoration: const BoxDecoration(
        color: SpazaColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SpazaColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: SpazaColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shopping_bag_outlined,
                    color: SpazaColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.product.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      '${widget.product.quantity} in stock · BWP ${widget.product.price.toStringAsFixed(2)} each',
                      style: TextStyle(
                          fontSize: 13, color: SpazaColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Quantity picker
          Text('Quantity', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              _QtyButton(
                icon: Icons.remove,
                onTap: () {
                  if (_quantity > 1) setState(() => _quantity--);
                },
              ),
              const SizedBox(width: 16),
              Text(
                '$_quantity',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 16),
              _QtyButton(
                icon: Icons.add,
                onTap: () {
                  if (_quantity < widget.product.quantity) {
                    setState(() => _quantity++);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Payment method
          Text('Payment method', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PaymentMethod.values
                .where((m) => m != PaymentMethod.other)
                .map((m) => _PaymentChip(
                      method: m,
                      isSelected: _method == m,
                      onTap: () => setState(() => _method = m),
                    ))
                .toList(),
          ),
          const SizedBox(height: 28),
          // Total + confirm
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total',
                        style: TextStyle(color: SpazaColors.textSecondary)),
                    Text(
                      'BWP ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: SpazaColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => widget.onConfirm(_quantity, _method),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpazaColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                ),
                child: const Text('Confirm sale',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: SpazaColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: SpazaColors.primary),
        ),
      );
}

class _PaymentChip extends StatelessWidget {
  final PaymentMethod method;
  final bool isSelected;
  final VoidCallback onTap;
  const _PaymentChip(
      {required this.method, required this.isSelected, required this.onTap});

  static const _labels = {
    PaymentMethod.cash: 'Cash',
    PaymentMethod.orangeMoney: 'Orange Money',
    PaymentMethod.myZaka: 'MyZaka',
    PaymentMethod.card: 'Card',
    PaymentMethod.other: 'Other',
  };

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? SpazaColors.primary : SpazaColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _labels[method] ?? method.name,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : SpazaColors.onBackground,
            ),
          ),
        ),
      );
}

// ── Sale success overlay ──────────────────────────────────────────────────────

class _SaleSuccessDialog extends StatelessWidget {
  final Sale sale;
  final Product product;
  const _SaleSuccessDialog({required this.sale, required this.product});

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: SpazaColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: SpazaColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sale recorded!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${product.name} × ${sale.quantitySold}',
                style: TextStyle(color: SpazaColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'BWP ${sale.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: SpazaColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
}
