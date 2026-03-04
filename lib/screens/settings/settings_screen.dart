import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../database/db_helper.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DBHelper();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _shopNameCtrl;
  late final TextEditingController _shopAddressCtrl;
  late final TextEditingController _shopPhoneCtrl;
  late final TextEditingController _taxCtrl;
  String _currency = 'PKR';
  bool _loading = true;

  final List<String> _currencies = [
    'PKR', 'USD', 'EUR', 'GBP', 'INR', 'AED', 'SAR', 'BDT'
  ];

  @override
  void initState() {
    super.initState();
    _shopNameCtrl = TextEditingController();
    _shopAddressCtrl = TextEditingController();
    _shopPhoneCtrl = TextEditingController();
    _taxCtrl = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await _db.getAllSettings();
    setState(() {
      _shopNameCtrl.text = s['shopName'] ?? 'My Shop';
      _shopAddressCtrl.text = s['shopAddress'] ?? '';
      _shopPhoneCtrl.text = s['shopPhone'] ?? '';
      _taxCtrl.text = s['taxPercent'] ?? '0';
      _currency = s['currency'] ?? 'PKR';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopAddressCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await _db.setSetting('shopName', _shopNameCtrl.text.trim());
    await _db.setSetting('shopAddress', _shopAddressCtrl.text.trim());
    await _db.setSetting('shopPhone', _shopPhoneCtrl.text.trim());
    await _db.setSetting('taxPercent', _taxCtrl.text);
    await _db.setSetting('currency', _currency);
    CurrencyFormat.setCurrency(_currency);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Settings saved!'),
            backgroundColor: AppTheme.success),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save',
                style: GoogleFonts.poppins(
                    color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Shop info
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
                        Row(
                          children: [
                            const Icon(Icons.store_rounded,
                                color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text('Shop Information',
                                style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _field('Shop Name *', _shopNameCtrl,
                            icon: Icons.store_rounded,
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Required' : null),
                        const SizedBox(height: 12),
                        _field('Address', _shopAddressCtrl,
                            icon: Icons.location_on_rounded, maxLines: 2),
                        const SizedBox(height: 12),
                        _field('Phone Number', _shopPhoneCtrl,
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Financial settings
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
                        Row(
                          children: [
                            const Icon(Icons.monetization_on_rounded,
                                color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text('Financial',
                                style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _currency,
                          decoration: const InputDecoration(
                              labelText: 'Currency',
                              prefixIcon: Icon(Icons.currency_exchange_rounded)),
                          items: _currencies
                              .map((c) => DropdownMenuItem(
                                  value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => _currency = v!),
                          style: GoogleFonts.poppins(
                              color: AppTheme.textPrimary, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        _field('Default Tax %', _taxCtrl,
                            icon: Icons.percent_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                double.tryParse(v ?? '') == null
                                    ? 'Invalid'
                                    : null),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // App info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      children: [
                        _InfoTile(
                          icon: Icons.info_outline_rounded,
                          title: 'App Version',
                          value: '1.0.0',
                        ),
                        const Divider(height: 20),
                        _InfoTile(
                          icon: Icons.storage_rounded,
                          title: 'Storage',
                          value: 'Local Device',
                        ),
                        const Divider(height: 20),
                        _InfoTile(
                          icon: Icons.wifi_off_rounded,
                          title: 'Mode',
                          value: 'Fully Offline',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Settings'),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
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
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        ),
      );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 12),
        Text(title,
            style: GoogleFonts.poppins(
                color: AppTheme.textPrimary, fontSize: 14)),
        const Spacer(),
        Text(value,
            style: GoogleFonts.poppins(
                color: AppTheme.textSecondary, fontSize: 13)),
      ],
    );
  }
}
