import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../database/db_helper.dart';
import '../../models/utility_bill.dart';
import '../../theme/app_theme.dart';

class AddEditUtilityScreen extends StatefulWidget {
  final UtilityBill? bill;

  const AddEditUtilityScreen({super.key, this.bill});

  @override
  State<AddEditUtilityScreen> createState() => _AddEditUtilityScreenState();
}

class _AddEditUtilityScreenState extends State<AddEditUtilityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DBHelper();

  late UtilityType _type;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _receiptCtrl;
  late DateTime _billDate;

  static const Map<UtilityType, String> _typeLabels = {
    UtilityType.electricity: 'Electricity',
    UtilityType.water: 'Water',
    UtilityType.gas: 'Gas',
    UtilityType.rent: 'Rent',
    UtilityType.internet: 'Internet',
    UtilityType.phone: 'Phone',
    UtilityType.other: 'Other',
  };

  static const Map<UtilityType, IconData> _typeIcons = {
    UtilityType.electricity: Icons.electric_bolt_rounded,
    UtilityType.water: Icons.water_drop_rounded,
    UtilityType.gas: Icons.local_fire_department_rounded,
    UtilityType.rent: Icons.home_rounded,
    UtilityType.internet: Icons.wifi_rounded,
    UtilityType.phone: Icons.phone_rounded,
    UtilityType.other: Icons.receipt_rounded,
  };

  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    _type = b?.type ?? UtilityType.electricity;
    _titleCtrl = TextEditingController(
        text: b?.title ?? _typeLabels[_type] ?? '');
    _amountCtrl = TextEditingController(text: b?.amount.toString() ?? '0');
    _notesCtrl = TextEditingController(text: b?.notes ?? '');
    _receiptCtrl = TextEditingController(text: b?.receiptNumber ?? '');
    _billDate = b?.billDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _receiptCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBillDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() => _billDate = date);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final bill = UtilityBill(
      id: widget.bill?.id,
      type: _type,
      title: _titleCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text),
      billDate: _billDate,
      dueDate: _billDate,
      paidDate: _billDate,
      status: BillStatus.paid,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      receiptNumber: _receiptCtrl.text.trim().isEmpty ? null : _receiptCtrl.text.trim(),
    );
    if (widget.bill == null) {
      await _db.insertUtilityBill(bill);
    } else {
      await _db.updateUtilityBill(bill);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(widget.bill == null ? 'Add Expense' : 'Edit Expense'),
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
            // Type selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expense Type',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: UtilityType.values.map((t) {
                      final selected = _type == t;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _type = t;
                            if (_titleCtrl.text.isEmpty ||
                                _typeLabels.values
                                    .contains(_titleCtrl.text)) {
                              _titleCtrl.text = _typeLabels[t] ?? '';
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.bgLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: selected
                                    ? AppTheme.primary
                                    : AppTheme.divider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_typeIcons[t],
                                  size: 16,
                                  color: selected
                                      ? Colors.white
                                      : AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                _typeLabels[t] ?? t.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: selected
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expense Details',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleCtrl,
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Title required' : null,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                        labelText: 'Title *',
                        prefixIcon: Icon(Icons.title_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final d = double.tryParse(v ?? '');
                      if (d == null) return 'Invalid amount';
                      if (d <= 0) return 'Amount must be greater than 0';
                      return null;
                    },
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                        labelText: 'Amount *',
                        prefixIcon: Icon(Icons.payments_rounded)),
                  ),
                  const SizedBox(height: 12),
                  // Expense date
                  GestureDetector(
                    onTap: _pickBillDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.bgLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              color: AppTheme.textSecondary, size: 20),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Expense Date',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary)),
                              Text(
                                DateFormat('dd MMM yyyy').format(_billDate),
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _receiptCtrl,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                        labelText: 'Receipt Number (optional)',
                        prefixIcon: Icon(Icons.receipt_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.notes_rounded)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(widget.bill == null ? 'Add Expense' : 'Save Changes'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
