import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../database/db_helper.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../widgets/gradient_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final _db = DBHelper();
  List<Map<String, dynamic>> _salesByDay = [];
  List<Map<String, dynamic>> _topProducts = [];
  Map<String, dynamic> _stats = {};
  int _period = 7;
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
    setState(() => _loading = true);
    final sales = await _db.getSalesByDay(_period);
    final topProds = await _db.getTopProducts(10);
    final stats = await _db.getDashboardStats();
    if (mounted) {
      setState(() {
        _salesByDay = sales;
        _topProducts = topProds;
        _stats = stats;
        _loading = false;
      });
    }
  }

  double get _totalForPeriod =>
      _salesByDay.fold(0, (s, d) => s + (d['total'] as num).toDouble());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelStyle: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Sales'),
            Tab(text: 'Products'),
            Tab(text: 'Summary'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildSalesTab(),
                _buildProductsTab(),
                _buildSummaryTab(),
              ],
            ),
    );
  }

  Widget _buildSalesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          Row(
            children: [7, 14, 30, 90].map((days) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _period = days);
                    _loadData();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _period == days
                          ? AppTheme.primary
                          : AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _period == days
                              ? AppTheme.primary
                              : AppTheme.divider),
                    ),
                    child: Text(
                      '${days}d',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _period == days
                            ? Colors.white
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Total for period
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppTheme.gradientPrimary),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Sales ($_period days)',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 12)),
                    Text(
                      CurrencyFormat.format(_totalForPeriod),
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${_salesByDay.length}\ndays',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Chart
          if (_salesByDay.isNotEmpty) ...[
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
                  Text('Daily Sales',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _salesByDay
                                .map((d) => (d['total'] as num).toDouble())
                                .fold(0.0, (a, b) => a > b ? a : b) *
                            1.2,
                        barGroups: _salesByDay.asMap().entries.map((e) {
                          return BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: (e.value['total'] as num).toDouble(),
                                gradient: const LinearGradient(
                                  colors: AppTheme.gradientPrimary,
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                width: _period <= 7 ? 20 : _period <= 14 ? 12 : 8,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6)),
                              ),
                            ],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (v, _) => Text(
                                CurrencyFormat.formatCompact(v)
                                    .replaceAll(CurrencyFormat.symbol, ''),
                                style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    color: AppTheme.textSecondary),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: _period <= 14,
                              reservedSize: 22,
                              getTitlesWidget: (v, _) {
                                final idx = v.toInt();
                                if (idx >= _salesByDay.length)
                                  return const Text('');
                                final date = _salesByDay[idx]['date'] as String;
                                return Text(
                                  DateFormat('dd').format(
                                      DateTime.parse(date)),
                                  style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: AppTheme.textSecondary),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          horizontalInterval: null,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: AppTheme.divider,
                            strokeWidth: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No sales data for this period'),
              ),
            ),

          const SizedBox(height: 16),
          // Daily breakdown list
          if (_salesByDay.isNotEmpty) ...[
            Text('Daily Breakdown',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            ...(_salesByDay.reversed.take(10).map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Text(
                        DateFormat2.format(DateTime.parse(d['date'] as String)),
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppTheme.textPrimary),
                      ),
                      const Spacer(),
                      Text(
                        '${d['count']} sales',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        CurrencyFormat.format(
                            (d['total'] as num).toDouble()),
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary),
                      ),
                    ],
                  ),
                ))),
          ],
        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    return _topProducts.isEmpty
        ? const EmptyState(
            title: 'No Data',
            message: 'Make some sales to see top products',
            icon: Icons.bar_chart_outlined,
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _topProducts.length,
            itemBuilder: (ctx, i) {
              final p = _topProducts[i];
              final maxRevenue = (_topProducts.first['totalRevenue'] as num).toDouble();
              final revenue = (p['totalRevenue'] as num).toDouble();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          child: Text('${i + 1}',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(p['productName'] as String,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        Text(
                          CurrencyFormat.format(revenue),
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: maxRevenue > 0 ? revenue / maxRevenue : 0,
                      backgroundColor: AppTheme.divider,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Text('Qty sold: ${(p['totalQty'] as num).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              );
            },
          );
  }

  Widget _buildSummaryTab() {
    final stats = _stats;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Business Summary',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Current status overview',
              style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          _SummaryCard(
            title: 'Today\'s Revenue',
            value: CurrencyFormat.format(
                (stats['todaySales'] as num?)?.toDouble() ?? 0),
            icon: Icons.today_rounded,
            color: AppTheme.primary,
          ),
          _SummaryCard(
            title: 'Monthly Revenue',
            value: CurrencyFormat.format(
                (stats['monthSales'] as num?)?.toDouble() ?? 0),
            icon: Icons.calendar_month_rounded,
            color: AppTheme.success,
          ),
          _SummaryCard(
            title: 'Total Products',
            value: '${stats['totalProducts'] ?? 0}',
            icon: Icons.inventory_2_rounded,
            color: const Color(0xFF4FC3F7),
          ),
          _SummaryCard(
            title: 'Low Stock Products',
            value: '${stats['lowStock'] ?? 0}',
            icon: Icons.warning_amber_rounded,
            color: AppTheme.warning,
          ),
          _SummaryCard(
            title: 'Out of Stock',
            value: '${stats['outOfStock'] ?? 0}',
            icon: Icons.remove_shopping_cart_rounded,
            color: AppTheme.error,
          ),
          _SummaryCard(
            title: 'Total Customers',
            value: '${stats['totalCustomers'] ?? 0}',
            icon: Icons.people_rounded,
            color: AppTheme.secondary,
          ),
          _SummaryCard(
            title: 'Unpaid Invoices',
            value: CurrencyFormat.format(
                (stats['unpaidInvoices'] as num?)?.toDouble() ?? 0),
            icon: Icons.money_off_rounded,
            color: AppTheme.error,
          ),
          _SummaryCard(
            title: 'Pending Utility Bills',
            value: CurrencyFormat.format(
                (stats['pendingBills'] as num?)?.toDouble() ?? 0),
            icon: Icons.electric_bolt_rounded,
            color: AppTheme.warning,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary, fontSize: 14)),
          ),
          Text(value,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color)),
        ],
      ),
    );
  }
}
