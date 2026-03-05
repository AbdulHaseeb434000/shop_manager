import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../database/db_helper.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../theme/app_theme.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DBHelper();
  List<Category> _categories = [];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _buyPriceCtrl;
  late final TextEditingController _sellPriceCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _lowStockCtrl;
  late final TextEditingController _barcodeCtrl;
  String _unit = 'pcs';
  int? _categoryId;

  final List<String> _units = [
    'pcs', 'kg', 'g', 'ltr', 'ml', 'box', 'dozen', 'pack', 'meter', 'foot'
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _buyPriceCtrl = TextEditingController(text: p?.buyPrice.toString() ?? '0');
    _sellPriceCtrl = TextEditingController(text: p?.sellPrice.toString() ?? '0');
    _quantityCtrl = TextEditingController(text: p?.quantity.toString() ?? '0');
    _lowStockCtrl = TextEditingController(text: p?.lowStockAlert.toString() ?? '5');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _unit = p?.unit ?? 'pcs';
    _categoryId = p?.categoryId;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _db.getCategories();
    if (mounted) setState(() => _categories = cats);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _buyPriceCtrl.dispose();
    _sellPriceCtrl.dispose();
    _quantityCtrl.dispose();
    _lowStockCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final product = Product(
      id: widget.product?.id,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      buyPrice: double.parse(_buyPriceCtrl.text),
      sellPrice: double.parse(_sellPriceCtrl.text),
      quantity: double.parse(_quantityCtrl.text),
      unit: _unit,
      categoryId: _categoryId,
      barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      lowStockAlert: double.parse(_lowStockCtrl.text),
    );
    if (widget.product == null) {
      await _db.insertProduct(product);
    } else {
      await _db.updateProduct(product);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save',
                style: GoogleFonts.poppins(
                    color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Basic Info', [
              _field('Product Name *', _nameCtrl,
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Name is required' : null),
              const SizedBox(height: 12),
              _field('Description (optional)', _descCtrl, maxLines: 2),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                key: ValueKey(_categories.length),
                value: _categoryId,
                decoration:
                    const InputDecoration(labelText: 'Category (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No Category')),
                  ..._categories.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.icon} ${c.name}'),
                      )),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
                style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary, fontSize: 14),
              ),
            ]),

            const SizedBox(height: 16),
            _section('Pricing', [
              Row(
                children: [
                  Expanded(
                    child: _field('Buy Price *', _buyPriceCtrl,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final d = double.tryParse(v ?? '');
                          if (d == null || d < 0) return 'Cannot be negative';
                          return null;
                        }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field('Sell Price *', _sellPriceCtrl,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final d = double.tryParse(v ?? '');
                          if (d == null || d <= 0) return 'Must be > 0';
                          return null;
                        }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Profit preview
              ValueListenableBuilder(
                valueListenable: _sellPriceCtrl,
                builder: (_, __, ___) => ValueListenableBuilder(
                  valueListenable: _buyPriceCtrl,
                  builder: (_, __, ___) {
                    final buy = double.tryParse(_buyPriceCtrl.text) ?? 0;
                    final sell = double.tryParse(_sellPriceCtrl.text) ?? 0;
                    final profit = sell - buy;
                    final pct = buy > 0 ? (profit / buy * 100) : 0;
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: profit >= 0
                            ? AppTheme.success.withOpacity(0.1)
                            : AppTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            profit >= 0
                                ? Icons.trending_up_rounded
                                : Icons.trending_down_rounded,
                            color: profit >= 0 ? AppTheme.success : AppTheme.error,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Profit: ${profit.toStringAsFixed(2)} (${pct.toStringAsFixed(1)}%)',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: profit >= 0 ? AppTheme.success : AppTheme.error,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ]),

            const SizedBox(height: 16),
            _section('Stock', [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _field('Quantity *', _quantityCtrl,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final d = double.tryParse(v ?? '');
                          if (d == null || d < 0) return 'Cannot be negative';
                          return null;
                        }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: _units
                          .map((u) => DropdownMenuItem(
                              value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setState(() => _unit = v!),
                      style: GoogleFonts.poppins(
                          color: AppTheme.textPrimary, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field('Low Stock Alert', _lowStockCtrl,
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? 'Invalid' : null),
            ]),

            const SizedBox(height: 16),
            _section('Other', [
              _field('Barcode (optional)', _barcodeCtrl),
            ]),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(widget.product == null ? 'Add Product' : 'Save Changes'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary),
        decoration: InputDecoration(labelText: label),
      );
}
