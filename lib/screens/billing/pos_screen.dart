import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../database/db_helper.dart';
import '../../models/invoice.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import 'invoice_detail_screen.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final _db = DBHelper();
  List<Product> _products = [];
  List<Customer> _customers = [];
  final List<InvoiceItem> _cartItems = [];
  String _productSearch = '';
  double _discountPercent = 0;
  double _taxPercent = 0;
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prods = await _db.getProducts();
    final custs = await _db.getCustomers();
    final tax = await _db.getSetting('taxPercent');
    if (mounted) {
      setState(() {
        _products = prods;
        _customers = custs;
        _taxPercent = double.tryParse(tax ?? '0') ?? 0;
        _loading = false;
      });
    }
  }

  List<Product> get _filteredProducts {
    if (_productSearch.isEmpty) return _products;
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(_productSearch.toLowerCase()))
        .toList();
  }

  double get _subtotal => _cartItems.fold(0, (sum, item) => sum + item.total);
  double get _discountAmount => _subtotal * _discountPercent / 100;
  double get _taxAmount => (_subtotal - _discountAmount) * _taxPercent / 100;
  double get _total => _subtotal - _discountAmount + _taxAmount;

  void _addToCart(Product p) {
    if (p.isOutOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${p.name} is out of stock!')),
      );
      return;
    }
    setState(() {
      final existing = _cartItems.indexWhere((i) => i.productId == p.id);
      if (existing >= 0) {
        final item = _cartItems[existing];
        if (item.quantity >= p.quantity) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Max stock reached for ${p.name}')),
          );
          return;
        }
        _cartItems[existing] = item.copyWith(quantity: item.quantity + 1);
      } else {
        _cartItems.add(InvoiceItem(
          productId: p.id!,
          productName: p.name,
          quantity: 1,
          unit: p.unit,
          price: p.sellPrice,
        ));
      }
    });
  }

  void _updateQuantity(int index, double qty) {
    setState(() {
      if (qty <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index] = _cartItems[index].copyWith(quantity: qty);
      }
    });
  }

  Future<void> _checkout() async {
    if (_cartItems.isEmpty) return;

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckoutSheet(
        total: _total,
        customers: _customers,
        onCheckout: (method, paid, customer) =>
            Navigator.pop(context, {
          'method': method,
          'paid': paid,
          'customer': customer,
        }),
      ),
    );

    if (result == null) return;

    final paid = result['paid'] as double;
    final method = result['method'] as PaymentMethod;
    final customer = result['customer'] as Customer?;

    InvoiceStatus status;
    if (paid >= _total) {
      status = InvoiceStatus.paid;
    } else if (paid > 0) {
      status = InvoiceStatus.partial;
    } else {
      status = InvoiceStatus.unpaid;
    }

    final invoiceNum = await _db.generateInvoiceNumber();
    final invoice = Invoice(
      invoiceNumber: invoiceNum,
      customerId: customer?.id,
      customerName: customer?.name ?? 'Walk-in Customer',
      customerPhone: customer?.phone,
      items: List.from(_cartItems),
      subtotal: _subtotal,
      discountAmount: _discountAmount,
      taxPercent: _taxPercent,
      taxAmount: _taxAmount,
      totalAmount: _total,
      paidAmount: paid,
      paymentMethod: method,
      status: status,
      notes: null,
    );

    final invId = await _db.insertInvoice(invoice);
    final savedInvoice = await _db.getInvoiceById(invId);

    if (mounted && savedInvoice != null) {
      setState(() => _cartItems.clear());
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailScreen(invoice: savedInvoice),
        ),
      );
    }
  }

  void _showBillSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => _BillSheet(
          cartItems: _cartItems,
          discountPercent: _discountPercent,
          subtotal: _subtotal,
          discountAmount: _discountAmount,
          taxPercent: _taxPercent,
          taxAmount: _taxAmount,
          total: _total,
          onQuantityChange: (i, q) {
            _updateQuantity(i, q);
            setSheetState(() {});
          },
          onDiscountChange: (v) {
            setState(() => _discountPercent = v);
            setSheetState(() {});
          },
          onCheckout: () {
            Navigator.pop(ctx);
            _checkout();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text('New Sale',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          if (_cartItems.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _cartItems.clear()),
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: Text('Clear',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppTheme.error)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => _productSearch = v),
                    decoration: InputDecoration(
                      hintText: 'Search and add products...',
                      prefixIcon:
                          const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _productSearch.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _productSearch = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                // Product count
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '${_filteredProducts.length} products available',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Product list
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? Center(
                          child: Text('No products found',
                              style: GoogleFonts.poppins(
                                  color: AppTheme.textSecondary)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: _filteredProducts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final p = _filteredProducts[i];
                            final cartIdx = _cartItems
                                .indexWhere((item) => item.productId == p.id);
                            final inCart = cartIdx >= 0;
                            return _ProductListTile(
                              product: p,
                              quantity: inCart
                                  ? _cartItems[cartIdx].quantity
                                  : 0,
                              onAdd: () => _addToCart(p),
                              onRemove: inCart
                                  ? () => _updateQuantity(cartIdx,
                                      _cartItems[cartIdx].quantity - 1)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
      // Persistent bottom bar when items are in bill
      bottomNavigationBar: _cartItems.isEmpty
          ? null
          : SafeArea(
              child: GestureDetector(
                onTap: _showBillSheet,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: AppTheme.gradientPrimary),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_cartItems.length} item${_cartItems.length > 1 ? 's' : ''}',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        CurrencyFormat.format(_total),
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'View Bill',
                          style: GoogleFonts.poppins(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ProductListTile extends StatelessWidget {
  final Product product;
  final double quantity;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  const _ProductListTile({
    required this.product,
    required this.quantity,
    required this.onAdd,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final inCart = quantity > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: inCart
            ? AppTheme.primary.withOpacity(0.05)
            : AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: inCart
              ? AppTheme.primary.withOpacity(0.3)
              : AppTheme.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: product.isOutOfStock
                  ? Colors.grey.withOpacity(0.1)
                  : AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                product.name.isNotEmpty
                    ? product.name[0].toUpperCase()
                    : '?',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: product.isOutOfStock
                      ? Colors.grey
                      : AppTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: product.isOutOfStock
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${CurrencyFormat.format(product.sellPrice)}  •  ${(product.quantity - quantity).toInt()} ${product.unit} left',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (product.isOutOfStock)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Out of\nStock',
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: AppTheme.error),
                  textAlign: TextAlign.center),
            )
          else if (inCart)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.remove_rounded,
                        size: 18, color: AppTheme.primary),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '${quantity.toInt()}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.primary),
                  ),
                ),
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

class _BillSheet extends StatelessWidget {
  final List<InvoiceItem> cartItems;
  final double discountPercent;
  final double subtotal;
  final double discountAmount;
  final double taxPercent;
  final double taxAmount;
  final double total;
  final Function(int, double) onQuantityChange;
  final Function(double) onDiscountChange;
  final VoidCallback onCheckout;

  const _BillSheet({
    required this.cartItems,
    required this.discountPercent,
    required this.subtotal,
    required this.discountAmount,
    required this.taxPercent,
    required this.taxAmount,
    required this.total,
    required this.onQuantityChange,
    required this.onDiscountChange,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text('Bill Items',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(
                      '${cartItems.length} item${cartItems.length > 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: cartItems.length,
                itemBuilder: (ctx, i) => _BillItemTile(
                  item: cartItems[i],
                  onRemove: () => onQuantityChange(i, 0),
                  onQuantityChange: (q) => onQuantityChange(i, q),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.divider)),
              ),
              child: Column(
                children: [
                  _TotalRow(
                      'Subtotal', CurrencyFormat.format(subtotal)),
                  if (discountPercent > 0)
                    _TotalRow(
                        'Discount ($discountPercent%)',
                        '- ${CurrencyFormat.format(discountAmount)}',
                        color: AppTheme.error),
                  if (taxPercent > 0)
                    _TotalRow('Tax ($taxPercent%)',
                        CurrencyFormat.format(taxAmount)),
                  const Divider(),
                  _TotalRow('Total', CurrencyFormat.format(total),
                      bold: true, color: AppTheme.primary),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Disc:',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),
                      Expanded(
                        child: Slider(
                          value: discountPercent,
                          min: 0,
                          max: 50,
                          divisions: 50,
                          label: '${discountPercent.toInt()}%',
                          onChanged: onDiscountChange,
                          activeColor: AppTheme.primary,
                        ),
                      ),
                      Text('${discountPercent.toInt()}%',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onCheckout,
                      icon: const Icon(Icons.payment_rounded),
                      label: Text(
                          'Checkout  ${CurrencyFormat.format(total)}',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillItemTile extends StatelessWidget {
  final InvoiceItem item;
  final VoidCallback onRemove;
  final Function(double) onQuantityChange;

  const _BillItemTile({
    required this.item,
    required this.onRemove,
    required this.onQuantityChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                    '${CurrencyFormat.format(item.price)} × ${item.quantity.toInt()}',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => onQuantityChange(item.quantity - 1),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.remove_rounded,
                      size: 16, color: AppTheme.primary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('${item.quantity.toInt()}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              GestureDetector(
                onTap: () => onQuantityChange(item.quantity + 1),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.add_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormat.format(item.total),
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
              ),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppTheme.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _TotalRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppTheme.textSecondary)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.w500,
                  color: color ?? AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  final double total;
  final List<Customer> customers;
  final Function(PaymentMethod, double, Customer?) onCheckout;

  const _CheckoutSheet({
    required this.total,
    required this.customers,
    required this.onCheckout,
  });

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  PaymentMethod _method = PaymentMethod.cash;
  late TextEditingController _paidCtrl;
  Customer? _customer;

  @override
  void initState() {
    super.initState();
    _paidCtrl =
        TextEditingController(text: widget.total.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Checkout',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Total: ${CurrencyFormat.format(widget.total)}',
              style: GoogleFonts.poppins(
                  color: AppTheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          DropdownButtonFormField<Customer?>(
            value: _customer,
            decoration: const InputDecoration(
                labelText: 'Customer',
                prefixIcon: Icon(Icons.person_rounded)),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('Walk-in Customer')),
              ...widget.customers.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(
                        '${c.name}${c.phone != null ? " (${c.phone})" : ""}'),
                  )),
            ],
            onChanged: (v) => setState(() => _customer = v),
            style: GoogleFonts.poppins(
                color: AppTheme.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Text('Payment Method',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: PaymentMethod.values.map((m) {
              final icons = {
                PaymentMethod.cash: Icons.payments_rounded,
                PaymentMethod.card: Icons.credit_card_rounded,
                PaymentMethod.upi: Icons.phone_android_rounded,
                PaymentMethod.credit: Icons.person_add_rounded,
              };
              final labels = {
                PaymentMethod.cash: 'Cash',
                PaymentMethod.card: 'Card',
                PaymentMethod.upi: 'UPI',
                PaymentMethod.credit: 'Credit',
              };
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _method = m;
                    if (m == PaymentMethod.credit) {
                      _paidCtrl.text = '0.00';
                    } else {
                      _paidCtrl.text = widget.total.toStringAsFixed(2);
                    }
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _method == m
                          ? AppTheme.primary
                          : AppTheme.bgLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _method == m
                              ? AppTheme.primary
                              : AppTheme.divider),
                    ),
                    child: Column(
                      children: [
                        Icon(icons[m],
                            color: _method == m
                                ? Colors.white
                                : AppTheme.textSecondary,
                            size: 20),
                        const SizedBox(height: 2),
                        Text(labels[m]!,
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: _method == m
                                    ? Colors.white
                                    : AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _paidCtrl,
            keyboardType: TextInputType.number,
            enabled: _method != PaymentMethod.credit,
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: _method == PaymentMethod.credit
                  ? 'Credit Sale (no payment now)'
                  : 'Amount Received',
              prefixText: _method != PaymentMethod.credit
                  ? '${CurrencyFormat.symbol} '
                  : null,
              prefixStyle: GoogleFonts.poppins(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final paid =
                    double.tryParse(_paidCtrl.text) ?? widget.total;
                widget.onCheckout(_method, paid, _customer);
              },
              icon: const Icon(Icons.check_circle_rounded),
              label: Text('Confirm Payment',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
