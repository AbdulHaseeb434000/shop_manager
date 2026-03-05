import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../database/db_helper.dart';
import '../../models/invoice.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../utils/pdf_generator.dart';
import '../../widgets/gradient_card.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final Invoice invoice;

  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final _db = DBHelper();
  Map<String, String> _settings = {};
  bool _generating = false;
  late Invoice _invoice;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _loadSettings();
  }

  Future<void> _recordPayment() async {
    final due = _invoice.dueAmount;
    final ctrl = TextEditingController(text: due.toStringAsFixed(2));
    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Due: ${CurrencyFormat.format(due)}',
                style: GoogleFonts.poppins(
                    color: AppTheme.error, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount Received',
                prefixText: '${CurrencyFormat.symbol} ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                final v = double.tryParse(ctrl.text);
                Navigator.pop(ctx, v);
              },
              child: const Text('Confirm')),
        ],
      ),
    );
    if (result == null || result <= 0) return;
    final newPaid = (_invoice.paidAmount + result).clamp(0.0, _invoice.totalAmount);
    final newStatus = newPaid >= _invoice.totalAmount
        ? InvoiceStatus.paid
        : InvoiceStatus.partial;
    await _db.updateInvoiceStatus(_invoice.id!, newStatus, newPaid);
    final updated = await _db.getInvoiceById(_invoice.id!);
    if (mounted && updated != null) setState(() => _invoice = updated);
  }

  Future<void> _loadSettings() async {
    final s = await _db.getAllSettings();
    if (mounted) setState(() => _settings = s);
  }

  Future<void> _share() async {
    setState(() => _generating = true);
    try {
      await PdfGenerator.shareInvoice(
        widget.invoice,
        shopName: _settings['shopName'] ?? 'My Shop',
        shopAddress: _settings['shopAddress'] ?? '',
        shopPhone: _settings['shopPhone'] ?? '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _print() async {
    setState(() => _generating = true);
    try {
      await PdfGenerator.printInvoice(
        widget.invoice,
        shopName: _settings['shopName'] ?? 'My Shop',
        shopAddress: _settings['shopAddress'] ?? '',
        shopPhone: _settings['shopPhone'] ?? '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Color get _statusColor {
    switch (widget.invoice.status) {
      case InvoiceStatus.paid:
        return AppTheme.success;
      case InvoiceStatus.partial:
        return AppTheme.warning;
      case InvoiceStatus.unpaid:
        return AppTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = _invoice;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text('Invoice ${inv.invoiceNumber}'),
        actions: [
          IconButton(
            icon: _generating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print_rounded),
            onPressed: _generating ? null : _print,
            tooltip: 'Print',
          ),
          IconButton(
            icon: _generating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share_rounded),
            onPressed: _generating ? null : _share,
            tooltip: 'Share',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Success header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: inv.status == InvoiceStatus.paid
                      ? AppTheme.gradientSuccess
                      : AppTheme.gradientWarning,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      inv.status == InvoiceStatus.paid
                          ? Icons.check_circle_rounded
                          : Icons.pending_actions_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv.status == InvoiceStatus.paid
                              ? 'Payment Received!'
                              : inv.status == InvoiceStatus.partial
                                  ? 'Partial Payment'
                                  : 'Payment Pending',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          CurrencyFormat.format(inv.totalAmount),
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Invoice info
            _InfoCard(
              children: [
                _InfoRow('Invoice #', inv.invoiceNumber),
                _InfoRow('Date', DateFormat2.formatWithTime(inv.createdAt)),
                _InfoRow('Customer', inv.customerName ?? 'Walk-in Customer'),
                if (inv.customerPhone != null)
                  _InfoRow('Phone', inv.customerPhone!),
                _InfoRow('Payment', inv.paymentMethod.name.toUpperCase()),
                _InfoRow(
                  'Status',
                  inv.status.name.toUpperCase(),
                  valueColor: _statusColor,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Items
            Container(
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text('Items',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary)),
                  ),
                  const Divider(height: 0),
                  // Header
                  Container(
                    color: AppTheme.bgLight,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                            flex: 4,
                            child: Text('Item',
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Qty',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Price',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Total',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary))),
                      ],
                    ),
                  ),
                  ...inv.items.asMap().entries.map((e) {
                    final item = e.value;
                    return Container(
                      color: e.key % 2 == 0 ? Colors.white : AppTheme.bgLight,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(item.productName,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                                '${item.quantity} ${item.unit}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(fontSize: 12)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                                CurrencyFormat.format(item.price),
                                textAlign: TextAlign.right,
                                style: GoogleFonts.poppins(fontSize: 12)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                                CurrencyFormat.format(item.total),
                                textAlign: TextAlign.right,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Totals
            _InfoCard(children: [
              _InfoRow('Subtotal', CurrencyFormat.format(inv.subtotal)),
              if (inv.discountAmount > 0)
                _InfoRow(
                    'Discount',
                    '- ${CurrencyFormat.format(inv.discountAmount)}',
                    valueColor: AppTheme.error),
              if (inv.taxAmount > 0)
                _InfoRow(
                    'Tax (${inv.taxPercent}%)', CurrencyFormat.format(inv.taxAmount)),
              const Divider(),
              _InfoRow('Total', CurrencyFormat.format(inv.totalAmount),
                  bold: true, valueColor: AppTheme.primary),
              if (inv.dueAmount > 0) ...[
                _InfoRow('Paid', CurrencyFormat.format(inv.paidAmount),
                    valueColor: AppTheme.success),
                _InfoRow('Due', CurrencyFormat.format(inv.dueAmount),
                    valueColor: AppTheme.error, bold: true),
              ],
            ]),

            const SizedBox(height: 20),

            // Record Payment button for unpaid/partial invoices
            if (inv.status != InvoiceStatus.paid) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _recordPayment,
                  icon: const Icon(Icons.payments_rounded),
                  label: Text(
                    inv.status == InvoiceStatus.unpaid
                        ? 'Record Payment  (Due: ${CurrencyFormat.format(inv.dueAmount)})'
                        : 'Record More Payment  (Due: ${CurrencyFormat.format(inv.dueAmount)})',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppTheme.success,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _generating ? null : _print,
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Print'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generating ? null : _share,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share PDF'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _InfoRow(this.label, this.value,
      {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppTheme.textSecondary)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: valueColor ?? AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
