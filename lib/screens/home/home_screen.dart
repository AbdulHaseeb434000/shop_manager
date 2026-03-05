import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../database/db_helper.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../widgets/gradient_card.dart';
import '../billing/pos_screen.dart';
import '../billing/invoices_screen.dart';
import '../products/products_screen.dart';
import '../inventory/inventory_screen.dart';
import '../customers/customers_screen.dart';
import '../reports/reports_screen.dart';
import '../utility_bills/utility_bills_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DBHelper();
  Map<String, dynamic> _stats = {};
  String _shopName = 'My Shop';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final stats = await _db.getDashboardStats();
    final name = await _db.getSetting('shopName');
    final currency = await _db.getSetting('currency');
    if (currency != null) CurrencyFormat.setCurrency(currency);
    if (mounted) {
      setState(() {
        _stats = stats;
        _shopName = name ?? 'My Shop';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.primary,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 170,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.bgCard,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    _loadData();
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppTheme.gradientPrimary,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 72, 20, 56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(greeting,
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: Text(_shopName,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sales stats grid
                    const SectionHeader(title: 'Sales Overview'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          GradientStatCard(
                            title: "Today's Sales",
                            value: CurrencyFormat.formatCompact(
                                _stats['todaySales'] ?? 0),
                            icon: Icons.today_rounded,
                            gradient: AppTheme.gradientPrimary,
                            onTap: () async {
                              await Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const InvoicesScreen()));
                              _loadData();
                            },
                          ),
                          GradientStatCard(
                            title: 'This Month',
                            value: CurrencyFormat.formatCompact(
                                _stats['monthSales'] ?? 0),
                            icon: Icons.calendar_month_rounded,
                            gradient: AppTheme.gradientSuccess,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const ReportsScreen())),
                          ),
                          GradientStatCard(
                            title: 'Products',
                            value: '${_stats['totalProducts'] ?? 0}',
                            subtitle:
                                '${_stats['lowStock'] ?? 0} low stock',
                            icon: Icons.inventory_2_rounded,
                            gradient: AppTheme.gradientInfo,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const ProductsScreen())),
                          ),
                          GradientStatCard(
                            title: 'Customers',
                            value: '${_stats['totalCustomers'] ?? 0}',
                            icon: Icons.people_rounded,
                            gradient: AppTheme.gradientRose,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const CustomersScreen())),
                          ),
                        ],
                      ),
                    ),

                    // Alerts
                    if ((_stats['lowStock'] as int? ?? 0) > 0 ||
                        (_stats['outOfStock'] as int? ?? 0) > 0)
                      _buildAlertCard(),

                    if ((_stats['unpaidInvoices'] as double? ?? 0) > 0)
                      _buildUnpaidAlert(),

                    if ((_stats['pendingBills'] as double? ?? 0) > 0)
                      _buildPendingBillsAlert(),

                    // Quick Actions
                    const SectionHeader(title: 'Quick Actions'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.85,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _QuickAction(
                            icon: Icons.point_of_sale_rounded,
                            label: 'New Sale',
                            color: AppTheme.primary,
                            onTap: () async {
                              await Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const POSScreen()));
                              _loadData();
                            },
                          ),
                          _QuickAction(
                            icon: Icons.receipt_long_rounded,
                            label: 'Invoices',
                            color: AppTheme.success,
                            onTap: () async {
                              await Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const InvoicesScreen()));
                              _loadData();
                            },
                          ),
                          _QuickAction(
                            icon: Icons.inventory_rounded,
                            label: 'Inventory',
                            color: const Color(0xFF4FC3F7),
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const InventoryScreen())),
                          ),
                          _QuickAction(
                            icon: Icons.bar_chart_rounded,
                            label: 'Reports',
                            color: AppTheme.warning,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const ReportsScreen())),
                          ),
                          _QuickAction(
                            icon: Icons.add_box_rounded,
                            label: 'Products',
                            color: const Color(0xFF9B59B6),
                            onTap: () async {
                              await Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const ProductsScreen()));
                              _loadData();
                            },
                          ),
                          _QuickAction(
                            icon: Icons.people_outline_rounded,
                            label: 'Customers',
                            color: AppTheme.secondary,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const CustomersScreen())),
                          ),
                          _QuickAction(
                            icon: Icons.electric_bolt_rounded,
                            label: 'Utilities',
                            color: const Color(0xFF26C6DA),
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const UtilityBillsScreen())),
                          ),
                          _QuickAction(
                            icon: Icons.settings_rounded,
                            label: 'Settings',
                            color: AppTheme.textSecondary,
                            onTap: () async {
                              await Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
                              _loadData();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            'Developed by: Abdul Haseeb',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Contact: 03219610808',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
              context, MaterialPageRoute(builder: (_) => const POSScreen()));
          _loadData();
        },
        icon: const Icon(Icons.point_of_sale_rounded),
        label: Text('New Sale',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildAlertCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: InkWell(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock Alert',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    Text(
                        '${_stats['lowStock']} low stock, ${_stats['outOfStock']} out of stock',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnpaidAlert() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
              context, MaterialPageRoute(builder: (_) => const InvoicesScreen()));
          _loadData();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.error.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.money_off_rounded, color: AppTheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unpaid Invoices',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    Text(
                        '${CurrencyFormat.format(_stats['unpaidInvoices'] ?? 0)} pending',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingBillsAlert() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InkWell(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const UtilityBillsScreen())),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.electric_bolt_rounded, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pending Utility Bills',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    Text(
                        '${CurrencyFormat.format(_stats['pendingBills'] ?? 0)} due',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
