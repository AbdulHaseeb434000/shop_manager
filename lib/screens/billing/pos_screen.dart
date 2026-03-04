import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../database/db_helper.dart';
import '../../models/invoice.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../utils/pdf_generator.dart';
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
  Customer? _selectedCustomer;
  String _productSearch = '';
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  double _discountPercent = 0;
  double _taxPercent = 0;
  String _notes = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  double get _subtotal =>
      _cartItems.fold(0, (sum, item) => sum + item.total);

  double get _discountAmount => _subtotal * _discountPercent / 100;

  double get _taxAmount =>
      (_subtotal - _discountAmount) * _taxPercent / 100;

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

  void _removeFromCart(int index) {
    setState(() => _cartItems.removeAt(index));
  }

  void _updateQuantity(int index, double qty) {
    if (qty <= 0) {
      _removeFromCart(index);
    } else {
      setState(() {
        _cartItems[index] = _cartItems[index].copyWith(quantity: qty);
      });
    }
  }

  Future<void> _checkout() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty!')),
      );
      return;
    }

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckoutSheet(
        total: _total,
        paymentMethod: _paymentMethod,
        customers: _customers,
        selectedCustomer: _selectedCustomer,
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
      notes: _notes.isEmpty ? null : _notes,
    );

    final invId = await _db.insertInvoice(invoice);
    final savedInvoice = await _db.getInvoiceById(invId);

    if (mounted && savedInvoice != null) {
      setState(() => _cartItems.clear());

      // Show success and navigate to invoice
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailScreen(invoice: savedInvoice),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Point of Sale'),
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
          : Row(
              children: [
                // Products panel
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: TextField(
                          onChanged: (v) =>
                              setState(() => _productSearch = v),
                          decoration: const InputDecoration(
                            hintText: 'Search products...',
                            prefixIcon:
                                Icon(Icons.search_rounded, size: 20),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _filteredProducts.isEmpty
                            ? const Center(child: Text('No products found'))
                            : GridView.builder(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 1.0,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: _filteredProducts.length,
                                itemBuilder: (ctx, i) {
                                  final p = _filteredProducts[i];
                                  return _ProductTile(
                                    product: p,
                                    onTap: () => _addToCart(p),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),

                // Cart panel
                Container(
                  width: 280,
                  decoration: const BoxDecoration(
                    color: AppTheme.bgCard,
                    border: Border(
                        left: BorderSide(color: AppTheme.divider)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppTheme.gradientPrimary,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shopping_cart_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Cart (${_cartItems.length})',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _cartItems.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.shopping_cart_outlined,
                                        size: 48,
                                        color: AppTheme.textSecondary
                                            .withOpacity(0.4)),
                                    const SizedBox(height: 8),
                                    Text('Cart is empty',
                                        style: GoogleFonts.poppins(
                                            color:
                                                AppTheme.textSecondary)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _cartItems.length,
                                itemBuilder: (ctx, i) => _CartItemTile(
                                  item: _cartItems[i],
                                  onRemove: () => _removeFromCart(i),
                                  onQuantityChange: (q) =>
                                      _updateQuantity(i, q),
                                ),
                              ),
                      ),
                      // Totals & checkout
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          border: Border(
                              top: BorderSide(color: AppTheme.divider)),
                        ),
                        child: Column(
                          children: [
                            _TotalRow('Subtotal',
                                CurrencyFormat.format(_subtotal)),
                            if (_discountPercent > 0)
                              _TotalRow(
                                  'Discount ($_discountPercent%)',
                                  '- ${CurrencyFormat.format(_discountAmount)}',
                                  color: AppTheme.error),
                            if (_taxPercent > 0)
                              _TotalRow('Tax ($_taxPercent%)',
                                  CurrencyFormat.format(_taxAmount)),
                            const Divider(),
                            _TotalRow(
                              'Total',
                              CurrencyFormat.format(_total),
                              bold: true,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(height: 10),
                            // Discount slider
                            Row(
                              children: [
                                Text('Disc:',
                                    style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary)),
                                Expanded(
                                  child: Slider(
                                    value: _discountPercent,
                                    min: 0,
                                    max: 50,
                                    divisions: 50,
                                    label:
                                        '${_discountPercent.toInt()}%',
                                    onChanged: (v) => setState(
                                        () => _discountPercent = v),
                                    activeColor: AppTheme.primary,
                                  ),
                                ),
                                Text('${_discountPercent.toInt()}%',
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
                                onPressed:
                                    _cartItems.isNotEmpty ? _checkout : null,
                                icon: const Icon(Icons.payment_rounded),
                                label: Text(
                                    'Checkout  ${CurrencyFormat.format(_total)}',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: product.isOutOfStock
              ? Colors.grey.withOpacity(0.1)
              : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: product.isOutOfStock
                        ? Colors.grey.withOpacity(0.1)
                        : AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      product.name.isNotEmpty
                          ? product.name[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: product.isOutOfStock
                            ? Colors.grey
                            : AppTheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(
              product.name,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: product.isOutOfStock
                    ? AppTheme.textSecondary
                    : AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  CurrencyFormat.format(product.sellPrice),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.success,
                  ),
                ),
                Text(
                  '${product.quantity} ${product.unit}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: product.isOutOfStock
                        ? AppTheme.error
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            if (product.isOutOfStock)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Out of Stock',
                    style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final InvoiceItem item;
  final VoidCallback onRemove;
  final Function(double) onQuantityChange;

  const _CartItemTile({
    required this.item,
    required this.onRemove,
    required this.onQuantityChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(CurrencyFormat.format(item.price),
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => onQuantityChange(item.quantity - 1),
                icon: const Icon(Icons.remove_circle_outline_rounded),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: AppTheme.primary,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('${item.quantity.toInt()}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              IconButton(
                onPressed: () => onQuantityChange(item.quantity + 1),
                icon: const Icon(Icons.add_circle_outline_rounded),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormat.format(item.total),
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: AppTheme.error,
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

  const _TotalRow(this.label, this.value,
      {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textSecondary)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: color ?? AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  final double total;
  final PaymentMethod paymentMethod;
  final List<Customer> customers;
  final Customer? selectedCustomer;
  final Function(PaymentMethod, double, Customer?) onCheckout;

  const _CheckoutSheet({
    required this.total,
    required this.paymentMethod,
    required this.customers,
    required this.selectedCustomer,
    required this.onCheckout,
  });

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  late PaymentMethod _method;
  late TextEditingController _paidCtrl;
  Customer? _customer;

  @override
  void initState() {
    super.initState();
    _method = widget.paymentMethod;
    _paidCtrl = TextEditingController(
        text: widget.total.toStringAsFixed(2));
    _customer = widget.selectedCustomer;
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

          // Customer selection
          DropdownButtonFormField<Customer?>(
            value: _customer,
            decoration: const InputDecoration(
                labelText: 'Customer', prefixIcon: Icon(Icons.person_rounded)),
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('Walk-in Customer')),
              ...widget.customers.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text('${c.name} ${c.phone != null ? "(${c.phone})" : ""}'),
                  )),
            ],
            onChanged: (v) => setState(() => _customer = v),
            style: GoogleFonts.poppins(
                color: AppTheme.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 12),

          // Payment method
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
                  onTap: () => setState(() => _method = m),
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
                            color:
                                _method == m ? Colors.white : AppTheme.textSecondary,
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

          // Amount paid
          TextFormField(
            controller: _paidCtrl,
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Amount Received',
              prefixText: '${CurrencyFormat.symbol} ',
              prefixStyle: GoogleFonts.poppins(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final paid = double.tryParse(_paidCtrl.text) ?? widget.total;
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
