import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../database/db_helper.dart';
import '../../models/invoice.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../widgets/gradient_card.dart';
import 'invoice_detail_screen.dart';

class InvoicesScreen extends StatefulWidget {
  final int? customerId;
  final String? customerName;

  const InvoicesScreen({super.key, this.customerId, this.customerName});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  final _db = DBHelper();
  List<Invoice> _invoices = [];
  bool _loading = true;
  String _search = '';
  late TabController _tabCtrl;
  final List<InvoiceStatus?> _tabs = [null, InvoiceStatus.paid, InvoiceStatus.unpaid, InvoiceStatus.partial];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() => _loadData());
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final status = _tabs[_tabCtrl.index];
    final invoices = await _db.getInvoices(
        status: status,
        customerId: widget.customerId,
        search: _search.isEmpty ? null : _search);
    if (mounted) setState(() {
      _invoices = invoices;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(widget.customerName != null
            ? '${widget.customerName}\'s Invoices'
            : 'Invoices'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Paid'),
            Tab(text: 'Unpaid'),
            Tab(text: 'Partial'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) {
                _search = v;
                _loadData();
              },
              decoration: const InputDecoration(
                hintText: 'Search by invoice # or customer...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _invoices.isEmpty
                    ? const EmptyState(
                        title: 'No Invoices',
                        message: 'Invoices will appear here after making sales',
                        icon: Icons.receipt_long_outlined,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _invoices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) => _InvoiceTile(
                          invoice: _invoices[i],
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InvoiceDetailScreen(
                                    invoice: _invoices[i]),
                              ),
                            );
                            _loadData();
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;

  const _InvoiceTile({required this.invoice, required this.onTap});

  Color get _statusColor {
    switch (invoice.status) {
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                  child: Icon(Icons.receipt_rounded, color: AppTheme.primary, size: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(invoice.invoiceNumber,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                      '${invoice.customerName ?? "Walk-in"} • ${DateFormat2.format(invoice.createdAt)}',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppTheme.textSecondary)),
                  Text('${invoice.items.length} items',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyFormat.format(invoice.totalAmount),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                StatusChip(
                  label: invoice.status.name.toUpperCase(),
                  color: _statusColor,
                  bgColor: _statusColor.withOpacity(0.1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
