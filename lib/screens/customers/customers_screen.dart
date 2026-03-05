import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../database/db_helper.dart';
import '../../models/customer.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../widgets/gradient_card.dart';
import 'add_edit_customer_screen.dart';
import '../billing/invoices_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _db = DBHelper();
  List<Customer> _customers = [];
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final customers =
        await _db.getCustomers(search: _search.isEmpty ? null : _search);
    if (mounted) setState(() {
      _customers = customers;
      _loading = false;
    });
  }

  Future<void> _delete(Customer c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Customer'),
        content: Text('Delete "${c.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteCustomer(c.id!);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Customers')),
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
                hintText: 'Search customers...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? EmptyState(
                        title: 'No Customers',
                        message: 'Add customers to track their purchases',
                        icon: Icons.people_outline_rounded,
                        actionLabel: 'Add Customer',
                        onAction: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AddEditCustomerScreen()));
                          _loadData();
                        },
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _customers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final c = _customers[i];
                          return Slidable(
                            endActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (_) async {
                                    await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                AddEditCustomerScreen(customer: c)));
                                    _loadData();
                                  },
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  icon: Icons.edit_rounded,
                                  label: 'Edit',
                                  borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(12)),
                                ),
                                SlidableAction(
                                  onPressed: (_) => _delete(c),
                                  backgroundColor: AppTheme.error,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete_rounded,
                                  label: 'Delete',
                                  borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(12)),
                                ),
                              ],
                            ),
                            child: GestureDetector(
                              onTap: () => _showCustomerDetail(c),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.divider),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor:
                                          AppTheme.primary.withOpacity(0.12),
                                      child: Text(
                                        c.name.isNotEmpty
                                            ? c.name[0].toUpperCase()
                                            : '?',
                                        style: GoogleFonts.poppins(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(c.name,
                                              style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14)),
                                          if (c.phone != null)
                                            Text(c.phone!,
                                                style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color:
                                                        AppTheme.textSecondary)),
                                          if (c.address != null)
                                            Text(c.address!,
                                                style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color:
                                                        AppTheme.textSecondary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Total',
                                          style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              color: AppTheme.textSecondary),
                                        ),
                                        Text(
                                          CurrencyFormat.formatCompact(
                                              c.totalPurchases),
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppTheme.success),
                                        ),
                                        if (c.balance > 0)
                                          StatusChip(
                                            label: 'Due: ${CurrencyFormat.formatCompact(c.balance)}',
                                            color: AppTheme.error,
                                            bgColor: AppTheme.error.withOpacity(0.1),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AddEditCustomerScreen()));
          _loadData();
        },
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }

  void _showCustomerDetail(Customer c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.primary.withOpacity(0.12),
              child: Text(c.name[0].toUpperCase(),
                  style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary)),
            ),
            const SizedBox(height: 12),
            Text(c.name,
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            if (c.phone != null)
              Text(c.phone!,
                  style: GoogleFonts.poppins(
                      color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child: _StatBox(
                        'Total Purchases',
                        CurrencyFormat.format(c.totalPurchases),
                        AppTheme.success)),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatBox('Balance Due',
                        CurrencyFormat.format(c.balance), AppTheme.error)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => InvoicesScreen(
                            customerId: c.id,
                            customerName: c.name,
                          )));
                    },
                    icon: const Icon(Icons.receipt_rounded),
                    label: const Text('Invoices'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddEditCustomerScreen(customer: c)));
                      _loadData();
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color)),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
