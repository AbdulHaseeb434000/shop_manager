import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../database/db_helper.dart';
import '../../models/utility_bill.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../widgets/gradient_card.dart';
import 'add_edit_utility_screen.dart';

class UtilityBillsScreen extends StatefulWidget {
  const UtilityBillsScreen({super.key});

  @override
  State<UtilityBillsScreen> createState() => _UtilityBillsScreenState();
}

class _UtilityBillsScreenState extends State<UtilityBillsScreen>
    with SingleTickerProviderStateMixin {
  final _db = DBHelper();
  List<UtilityBill> _bills = [];
  bool _loading = true;
  late TabController _tabCtrl;
  final List<BillStatus?> _filters = [null, BillStatus.pending, BillStatus.paid, BillStatus.overdue];

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
    final status = _filters[_tabCtrl.index];
    List<UtilityBill> bills = await _db.getUtilityBills(status: status);
    // For overdue tab, filter manually since DB doesn't store derived status
    if (status == BillStatus.overdue) {
      bills = (await _db.getUtilityBills()).where((b) => b.isOverdue).toList();
    }
    if (mounted) setState(() {
      _bills = bills;
      _loading = false;
    });
  }

  double get _totalPending => _bills
      .where((b) => b.status != BillStatus.paid)
      .fold(0, (s, b) => s + b.amount);

  static const Map<UtilityType, IconData> _typeIcons = {
    UtilityType.electricity: Icons.electric_bolt_rounded,
    UtilityType.water: Icons.water_drop_rounded,
    UtilityType.gas: Icons.local_fire_department_rounded,
    UtilityType.rent: Icons.home_rounded,
    UtilityType.internet: Icons.wifi_rounded,
    UtilityType.phone: Icons.phone_rounded,
    UtilityType.other: Icons.receipt_rounded,
  };

  static const Map<UtilityType, Color> _typeColors = {
    UtilityType.electricity: Color(0xFFFFB74D),
    UtilityType.water: Color(0xFF4FC3F7),
    UtilityType.gas: Color(0xFFEF5350),
    UtilityType.rent: Color(0xFF6C63FF),
    UtilityType.internet: Color(0xFF43E97B),
    UtilityType.phone: Color(0xFFFF6584),
    UtilityType.other: Color(0xFF9093A4),
  };

  Future<void> _markPaid(UtilityBill bill) async {
    final receiptCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Paid'),
        content: TextField(
          controller: receiptCtrl,
          decoration: const InputDecoration(
            labelText: 'Receipt Number (optional)',
            prefixIcon: Icon(Icons.receipt_rounded),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok == true) {
      await _db.updateUtilityBill(bill.copyWith(
        status: BillStatus.paid,
        paidDate: DateTime.now(),
        receiptNumber: receiptCtrl.text.trim().isEmpty ? null : receiptCtrl.text.trim(),
      ));
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Expenses'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Paid'),
            Tab(text: 'Overdue'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_totalPending > 0 && _tabCtrl.index == 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppTheme.gradientWarning),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Pending',
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 11)),
                      Text(CurrencyFormat.format(_totalPending),
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _bills.isEmpty
                    ? EmptyState(
                        title: 'No Expenses',
                        message: 'Track your business expenses here',
                        icon: Icons.receipt_long_outlined,
                        actionLabel: 'Add Expense',
                        onAction: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AddEditUtilityScreen()));
                          _loadData();
                        },
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: _bills.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final b = _bills[i];
                          final color = _typeColors[b.type] ?? AppTheme.primary;
                          final isOverdue = b.isOverdue;

                          return Slidable(
                            endActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              children: [
                                if (b.status != BillStatus.paid)
                                  SlidableAction(
                                    onPressed: (_) => _markPaid(b),
                                    backgroundColor: AppTheme.success,
                                    foregroundColor: Colors.white,
                                    icon: Icons.check_circle_rounded,
                                    label: 'Paid',
                                    borderRadius: const BorderRadius.horizontal(
                                        left: Radius.circular(12)),
                                  ),
                                SlidableAction(
                                  onPressed: (_) async {
                                    await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                AddEditUtilityScreen(bill: b)));
                                    _loadData();
                                  },
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  icon: Icons.edit_rounded,
                                  label: 'Edit',
                                ),
                                SlidableAction(
                                  onPressed: (_) async {
                                    await _db.deleteUtilityBill(b.id!);
                                    _loadData();
                                  },
                                  backgroundColor: AppTheme.error,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete_rounded,
                                  label: 'Delete',
                                  borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(12)),
                                ),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.bgCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isOverdue
                                      ? AppTheme.error.withOpacity(0.3)
                                      : AppTheme.divider,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                        _typeIcons[b.type] ?? Icons.receipt_rounded,
                                        color: color,
                                        size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(b.title,
                                            style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13)),
                                        Text(
                                          'Due: ${DateFormat2.format(b.dueDate)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: isOverdue
                                                ? AppTheme.error
                                                : AppTheme.textSecondary,
                                          ),
                                        ),
                                        if (b.receiptNumber != null)
                                          Text('Receipt: ${b.receiptNumber}',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormat.format(b.amount),
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      StatusChip(
                                        label: isOverdue
                                            ? 'OVERDUE'
                                            : b.status.name.toUpperCase(),
                                        color: b.status == BillStatus.paid
                                            ? AppTheme.success
                                            : isOverdue
                                                ? AppTheme.error
                                                : AppTheme.warning,
                                        bgColor: (b.status == BillStatus.paid
                                                ? AppTheme.success
                                                : isOverdue
                                                    ? AppTheme.error
                                                    : AppTheme.warning)
                                            .withOpacity(0.1),
                                      ),
                                    ],
                                  ),
                                ],
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
                  builder: (_) => const AddEditUtilityScreen()));
          _loadData();
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
