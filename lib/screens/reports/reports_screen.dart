import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../database/db_helper.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../widgets/gradient_card.dart';
import '../../models/utility_bill.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final _db = DBHelper();
  Map<String, dynamic> _report = {};
  List<Map<String, dynamic>> _salesByDay = [];
  List<Map<String, dynamic>> _topProducts = [];
  int _period = 30;
  bool _loading = true;
  late TabController _tabCtrl;

  final List<_PeriodOption> _periods = [
    _PeriodOption(7, 'Week'),
    _PeriodOption(30, 'Month'),
    _PeriodOption(90, '3 Months'),
    _PeriodOption(365, 'Year'),
  ];

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
    final report = await _db.getBusinessReport(_period);
    final sales = await _db.getSalesByDay(_period);
    final topProds = await _db.getTopProducts(10);
    if (mounted) {
      setState(() {
        _report = report;
        _salesByDay = sales;
        _topProducts = topProds;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Reports & Insights'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelStyle:
              GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Sales'),
            Tab(text: 'Products'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Period selector
          Container(
            color: AppTheme.bgCard,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: _periods.map((p) {
                final selected = _period == p.days;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _period = p.days);
                      _loadData();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primary : AppTheme.bgLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.divider),
                      ),
                      child: Text(
                        p.label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              selected ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildOverviewTab(),
                      _buildSalesTab(),
                      _buildProductsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final revenue = _report['revenue'] as double? ?? 0;
    final expenses = _report['expenses'] as double? ?? 0;
    final profit = _report['profit'] as double? ?? 0;
    final invoiceCount = _report['invoiceCount'] ?? 0;
    final unpaidDue = _report['unpaidDue'] as double? ?? 0;
    final expByType =
        _report['expenseByType'] as List<Map<String, dynamic>>? ?? [];
    final profitMargin =
        revenue > 0 ? (profit / revenue * 100) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key metrics
          Text('Key Metrics',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              GradientStatCard(
                title: 'Revenue',
                value: CurrencyFormat.formatCompact(revenue),
                icon: Icons.trending_up_rounded,
                gradient: AppTheme.gradientSuccess,
              ),
              GradientStatCard(
                title: 'Expenses',
                value: CurrencyFormat.formatCompact(expenses),
                icon: Icons.receipt_long_rounded,
                gradient: AppTheme.gradientWarning,
              ),
              GradientStatCard(
                title: profit >= 0 ? 'Net Profit' : 'Net Loss',
                value: CurrencyFormat.formatCompact(profit.abs()),
                subtitle:
                    '${profitMargin.toStringAsFixed(1)}% margin',
                icon: profit >= 0
                    ? Icons.account_balance_rounded
                    : Icons.trending_down_rounded,
                gradient: profit >= 0
                    ? AppTheme.gradientPrimary
                    : AppTheme.gradientRose,
              ),
              GradientStatCard(
                title: 'Invoices',
                value: '$invoiceCount',
                subtitle: unpaidDue > 0
                    ? '${CurrencyFormat.formatCompact(unpaidDue)} due'
                    : null,
                icon: Icons.receipt_rounded,
                gradient: AppTheme.gradientInfo,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Profit bar
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
                Text('Revenue vs Expenses',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 12),
                _BarCompare(
                    label: 'Revenue',
                    value: revenue,
                    max: revenue > 0 ? revenue : 1,
                    color: AppTheme.success),
                const SizedBox(height: 8),
                _BarCompare(
                    label: 'Expenses',
                    value: expenses,
                    max: revenue > 0 ? revenue : 1,
                    color: AppTheme.warning),
                const SizedBox(height: 8),
                _BarCompare(
                    label: profit >= 0 ? 'Profit' : 'Loss',
                    value: profit.abs(),
                    max: revenue > 0 ? revenue : 1,
                    color: profit >= 0 ? AppTheme.primary : AppTheme.error),
                const SizedBox(height: 8),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Profit Margin',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppTheme.textSecondary)),
                    Text(
                      '${profitMargin.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: profit >= 0
                              ? AppTheme.success
                              : AppTheme.error),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (expByType.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Expense Breakdown',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: expByType.asMap().entries.map((e) {
                  final type = e.value['type'] as String? ?? 'other';
                  final total =
                      (e.value['total'] as num).toDouble();
                  final maxExp = (expByType.first['total'] as num).toDouble();
                  final utType = UtilityType.values.firstWhere(
                      (t) => t.name == type,
                      orElse: () => UtilityType.other);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: e.key < expByType.length - 1
                          ? const Border(
                              bottom: BorderSide(color: AppTheme.divider))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(_typeIcon(utType),
                            color: _typeColor(utType), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(type[0].toUpperCase() + type.substring(1),
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value:
                                    maxExp > 0 ? total / maxExp : 0,
                                backgroundColor: AppTheme.divider,
                                valueColor: AlwaysStoppedAnimation(
                                    _typeColor(utType)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(CurrencyFormat.format(total),
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          if (unpaidDue > 0) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Uncollected Revenue',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.error)),
                        Text(
                            '${CurrencyFormat.format(unpaidDue)} still due from customers',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    final maxY = _salesByDay.isEmpty
        ? 1.0
        : _salesByDay
                .map((d) => (d['total'] as num).toDouble())
                .fold(0.0, (a, b) => a > b ? a : b) *
            1.2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Daily Sales',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary)),
                      FittedBox(
                        child: Text(
                          'Total: ${CurrencyFormat.formatCompact(_report['revenue'] ?? 0)}',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        barGroups:
                            _salesByDay.asMap().entries.map((e) {
                          return BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: (e.value['total'] as num)
                                    .toDouble(),
                                gradient: const LinearGradient(
                                  colors: AppTheme.gradientPrimary,
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                width: _period <= 7
                                    ? 20
                                    : _period <= 30
                                        ? 10
                                        : 5,
                                borderRadius:
                                    const BorderRadius.vertical(
                                        top: Radius.circular(4)),
                              ),
                            ],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 52,
                              getTitlesWidget: (v, _) => Text(
                                CurrencyFormat.formatCompact(v)
                                    .replaceAll(
                                        CurrencyFormat.symbol, ''),
                                style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    color: AppTheme.textSecondary),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: _period <= 30,
                              reservedSize: 22,
                              getTitlesWidget: (v, _) {
                                final idx = v.toInt();
                                if (idx >= _salesByDay.length)
                                  return const Text('');
                                final date = _salesByDay[idx]['date']
                                    as String;
                                return Text(
                                  DateFormat('d/M').format(
                                      DateTime.parse(date)),
                                  style: GoogleFonts.poppins(
                                      fontSize: 8,
                                      color: AppTheme.textSecondary),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                              sideTitles:
                                  SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles:
                                  SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
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
            const SizedBox(height: 16),
            Text('Daily Breakdown',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ...(_salesByDay.reversed.take(15).map((d) => Container(
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
                      Expanded(
                        child: Text(
                          DateFormat2.format(
                              DateTime.parse(d['date'] as String)),
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textPrimary),
                        ),
                      ),
                      Text(
                        '${d['count']} sales',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textSecondary),
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
          ] else
            const EmptyState(
              title: 'No Sales',
              message: 'No sales data for this period',
              icon: Icons.bar_chart_outlined,
            ),
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
              final maxRevenue =
                  (_topProducts.first['totalRevenue'] as num)
                      .toDouble();
              final revenue =
                  (p['totalRevenue'] as num).toDouble();
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
                          backgroundColor:
                              AppTheme.primary.withOpacity(0.1),
                          child: Text('${i + 1}',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              p['productName'] as String,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                        FittedBox(
                          child: Text(
                            CurrencyFormat.format(revenue),
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: maxRevenue > 0
                          ? revenue / maxRevenue
                          : 0,
                      backgroundColor: AppTheme.divider,
                      valueColor: const AlwaysStoppedAnimation(
                          AppTheme.primary),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Qty sold: ${(p['totalQty'] as num).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textSecondary)),
                  ],
                ),
              );
            },
          );
  }

  IconData _typeIcon(UtilityType t) {
    const m = {
      UtilityType.electricity: Icons.electric_bolt_rounded,
      UtilityType.water: Icons.water_drop_rounded,
      UtilityType.gas: Icons.local_fire_department_rounded,
      UtilityType.rent: Icons.home_rounded,
      UtilityType.internet: Icons.wifi_rounded,
      UtilityType.phone: Icons.phone_rounded,
      UtilityType.other: Icons.receipt_rounded,
    };
    return m[t] ?? Icons.receipt_rounded;
  }

  Color _typeColor(UtilityType t) {
    const m = {
      UtilityType.electricity: Color(0xFFFFB74D),
      UtilityType.water: Color(0xFF4FC3F7),
      UtilityType.gas: Color(0xFFEF5350),
      UtilityType.rent: Color(0xFF6C63FF),
      UtilityType.internet: Color(0xFF43E97B),
      UtilityType.phone: Color(0xFFFF6584),
      UtilityType.other: Color(0xFF9093A4),
    };
    return m[t] ?? AppTheme.primary;
  }
}

class _PeriodOption {
  final int days;
  final String label;
  const _PeriodOption(this.days, this.label);
}

class _BarCompare extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;

  const _BarCompare({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppTheme.textSecondary)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: max > 0 ? (value / max).clamp(0.0, 1.0) : 0,
              backgroundColor: AppTheme.divider,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            CurrencyFormat.formatCompact(value),
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
