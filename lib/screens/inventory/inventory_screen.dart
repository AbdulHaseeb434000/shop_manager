import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../database/db_helper.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../widgets/gradient_card.dart';
import '../products/products_screen.dart';
import '../products/add_edit_product_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  final _db = DBHelper();
  List<Product> _allProducts = [];
  List<Product> _lowStock = [];
  bool _loading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final all = await _db.getProducts();
    final low = await _db.getLowStockProducts();
    if (mounted) {
      setState(() {
        _allProducts = all;
        _lowStock = low;
        _loading = false;
      });
    }
  }

  List<Product> get _outOfStock =>
      _allProducts.where((p) => p.isOutOfStock).toList();

  Future<void> _adjustStock(Product p) async {
    final ctrl = TextEditingController(text: p.quantity.toString());
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Adjust Stock: ${p.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'New Quantity (${p.unit})',
            suffixText: p.unit,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              if (v != null && v >= 0) Navigator.pop(ctx, v);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (result != null) {
      await _db.updateProductQuantity(p.id!, result);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddEditProductScreen()));
              _loadData();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelStyle: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          tabs: [
            Tab(text: 'All (${_allProducts.length})'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Low Stock'),
                  if (_lowStock.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_lowStock.length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Out of Stock'),
                  if (_outOfStock.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_outOfStock.length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildProductList(_allProducts),
                _buildProductList(_lowStock,
                    emptyMessage: 'All products are well-stocked! 🎉'),
                _buildProductList(_outOfStock,
                    emptyMessage: 'No products are out of stock!'),
              ],
            ),
    );
  }

  Widget _buildProductList(List<Product> products, {String? emptyMessage}) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 64, color: AppTheme.success),
            const SizedBox(height: 12),
            Text(emptyMessage ?? 'No products',
                style: GoogleFonts.poppins(
                    fontSize: 16, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final p = products[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: p.isOutOfStock
                  ? AppTheme.error.withOpacity(0.3)
                  : p.isLowStock
                      ? AppTheme.warning.withOpacity(0.3)
                      : AppTheme.divider,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: (p.isOutOfStock
                          ? AppTheme.error
                          : p.isLowStock
                              ? AppTheme.warning
                              : AppTheme.success)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: p.isOutOfStock
                          ? AppTheme.error
                          : p.isLowStock
                              ? AppTheme.warning
                              : AppTheme.success,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(
                      'Sell: ${CurrencyFormat.format(p.sellPrice)} | Alert: ${p.lowStockAlert} ${p.unit}',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${p.quantity} ${p.unit}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: p.isOutOfStock
                          ? AppTheme.error
                          : p.isLowStock
                              ? AppTheme.warning
                              : AppTheme.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _adjustStock(p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_rounded,
                              size: 12, color: AppTheme.primary),
                          const SizedBox(width: 3),
                          Text('Adjust',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
