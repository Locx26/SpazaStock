// lib/presentation/screens/add_product/add_product_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/inventory_repository.dart';

final _repoProvider = Provider((_) => InventoryRepository());

final _editProductProvider =
    FutureProvider.family<Product?, String>((ref, id) async {
  return ref.watch(_repoProvider).getProductById(id);
});

class AddProductScreen extends ConsumerStatefulWidget {
  final String? productId;
  const AddProductScreen({super.key, this.productId});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nameTswanaCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '0');
  final _lowStockCtrl = TextEditingController(text: '5');
  final _expiryCtrl = TextEditingController();

  String _category = 'Food';
  bool _isSaving = false;
  bool _isLoading = true;
  Product? _existingProduct;

  bool get _isEdit => widget.productId != null;

  static const _categories = [
    'Food', 'Drinks', 'Snacks', 'Household', 'Personal care', 'Airtime', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadProduct();
    else _isLoading = false;
  }

  Future<void> _loadProduct() async {
    final repo = ref.read(_repoProvider);
    final p = await repo.getProductById(widget.productId!);
    if (p != null && mounted) {
      setState(() {
        _existingProduct = p;
        _nameCtrl.text = p.name;
        _nameTswanaCtrl.text = p.nameSetswana;
        _skuCtrl.text = p.sku ?? '';
        _priceCtrl.text = p.price.toStringAsFixed(2);
        _costCtrl.text = p.costPrice.toStringAsFixed(2);
        _qtyCtrl.text = p.quantity.toString();
        _lowStockCtrl.text = p.lowStockThreshold.toString();
        _expiryCtrl.text = p.expiryDate ?? '';
        _category = p.category;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(_repoProvider);
      final product = Product(
        id: _existingProduct?.id ?? const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        nameSetswana: _nameTswanaCtrl.text.trim(),
        sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
        category: _category,
        price: double.parse(_priceCtrl.text),
        costPrice: double.tryParse(_costCtrl.text) ?? 0,
        quantity: int.parse(_qtyCtrl.text),
        lowStockThreshold: int.parse(_lowStockCtrl.text),
        expiryDate: _expiryCtrl.text.trim().isEmpty ? null : _expiryCtrl.text.trim(),
        nfcTagId: _existingProduct?.nfcTagId,
        isActive: true,
      );

      if (_isEdit) {
        await repo.updateProduct(product);
      } else {
        await repo.createProduct(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Product updated' : 'Product added'),
            backgroundColor: SpazaColors.success,
          ),
        );
        context.go('/inventory');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: SpazaColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: SpazaColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(_repoProvider).deleteProduct(widget.productId!);
      if (mounted) context.go('/inventory');
    }
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      _expiryCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameTswanaCtrl.dispose();
    _skuCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _qtyCtrl.dispose();
    _lowStockCtrl.dispose();
    _expiryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: SpazaColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: SpazaColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit product' : 'Add product'),
        backgroundColor: SpazaColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/inventory'),
        ),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white70),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionLabel('Product details'),
            _FormField(
              label: 'Product name *',
              controller: _nameCtrl,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _FormField(
              label: 'Name in Setswana',
              controller: _nameTswanaCtrl,
              hint: 'Optional Setswana name',
            ),
            const SizedBox(height: 12),
            _FormField(
              label: 'SKU / Barcode',
              controller: _skuCtrl,
              hint: 'Optional',
            ),
            const SizedBox(height: 12),
            // Category
            DropdownButtonFormField<String>(
              value: _category,
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
              decoration: _inputDeco('Category'),
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: SpazaColors.onBackground,
                  fontSize: 15),
            ),
            const SizedBox(height: 20),
            _SectionLabel('Pricing'),
            Row(
              children: [
                Expanded(
                  child: _FormField(
                    label: 'Selling price (BWP) *',
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FormField(
                    label: 'Cost price (BWP)',
                    controller: _costCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel('Stock'),
            Row(
              children: [
                Expanded(
                  child: _FormField(
                    label: 'Current quantity *',
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (int.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FormField(
                    label: 'Low stock alert at',
                    controller: _lowStockCtrl,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickExpiry,
              child: AbsorbPointer(
                child: _FormField(
                  label: 'Expiry date (optional)',
                  controller: _expiryCtrl,
                  hint: 'Tap to select',
                  suffixIcon: Icons.calendar_today_outlined,
                ),
              ),
            ),
            if (_isEdit && _existingProduct?.nfcTagId != null) ...[
              const SizedBox(height: 20),
              _SectionLabel('NFC Tag'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SpazaColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SpazaColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.nfc_rounded, color: SpazaColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      'NFC tag linked',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        color: SpazaColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpazaColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _isEdit ? 'Save changes' : 'Add product',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, {String? hint, IconData? suffix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: SpazaColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SpazaColors.primary, width: 2),
        ),
        suffixIcon: suffix != null ? Icon(suffix) : null,
      );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: SpazaColors.primary,
          ),
        ),
      );
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final IconData? suffixIcon;

  const _FormField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: SpazaColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: SpazaColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: SpazaColors.error, width: 1.5),
          ),
          suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
        ),
      );
}
