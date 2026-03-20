import 'package:flutter/material.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final theme = ThemeProvider.instance;
  String _period = 'today';

  List<Map<String, dynamic>> _sales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getSales();
      if (mounted) {
        setState(() {
          _sales = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading sales reports: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _salesForPeriod {
    final now = DateTime.now();
    final sales = _sales;
    
    switch (_period) {
      case 'today':
        return sales.where((s) {
          final ts = DateTime.tryParse(s['created_at'] ?? '');
          return ts != null && ts.day == now.day && ts.month == now.month && ts.year == now.year;
        }).toList();
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return sales.where((s) {
          final ts = DateTime.tryParse(s['created_at'] ?? '');
          return ts != null && ts.isAfter(weekAgo);
        }).toList();
      case 'month':
        return sales.where((s) {
          final ts = DateTime.tryParse(s['created_at'] ?? '');
          return ts != null && ts.month == now.month && ts.year == now.year;
        }).toList();
      default:
        return sales;
    }
  }

  double get _totalSales => _salesForPeriod.where((s) => s['is_return'] != 1).fold(0.0, (sum, s) => sum + (s['total'] as num? ?? 0).toDouble());
  double get _totalReturns => _salesForPeriod.where((s) => s['is_return'] == 1).fold(0.0, (sum, s) => sum + (s['total'] as num? ?? 0).abs().toDouble());
  double get _netSales => _totalSales - _totalReturns;
  double get _totalTax => _salesForPeriod.fold(0.0, (sum, s) => sum + (s['tax'] as num? ?? 0).toDouble());
  double get _totalTips => _salesForPeriod.fold(0.0, (sum, s) => sum + (s['tip'] as num? ?? 0).toDouble());
  double get _totalDiscounts => _salesForPeriod.fold(0.0, (sum, s) => sum + (s['discount'] as num? ?? 0).toDouble());
  int get _transactionCount => _salesForPeriod.length;
  double get _avgTransaction => _transactionCount > 0 ? _netSales / _transactionCount : 0;

  Map<String, double> get _salesByPaymentMethod {
    final Map<String, double> result = {};
    for (var sale in _salesForPeriod) {
      final method = sale['payment_method'] ?? 'Cash';
      final amount = (sale['total'] as num? ?? 0).abs().toDouble();
      result[method] = (result[method] ?? 0) + amount;
    }
    return result;
  }

  Map<String, int> get _topProducts {
    final Map<String, int> result = {};
    for (var sale in _salesForPeriod) {
      final items = sale['items'] as List? ?? [];
      for (var item in items) {
        final name = item['name'] ?? 'Unknown';
        final qty = item['quantity'] as int? ?? 1;
        result[name] = (result[name] ?? 0) + qty;
      }
    }
    return Map.fromEntries(result.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Analytics',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium Period Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _PeriodChip(label: 'Today', selected: _period == 'today', onTap: () => setState(() => _period = 'today')),
                      const SizedBox(width: 8),
                      _PeriodChip(label: 'This Week', selected: _period == 'week', onTap: () => setState(() => _period = 'week')),
                      const SizedBox(width: 8),
                      _PeriodChip(label: 'This Month', selected: _period == 'month', onTap: () => setState(() => _period = 'month')),
                      const SizedBox(width: 8),
                      _PeriodChip(label: 'All Time', selected: _period == 'all', onTap: () => setState(() => _period = 'all')),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Hero Stats - Net Sales
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: theme.glassDecoration.copyWith(
                    gradient: LinearGradient(
                      colors: [theme.highlight, theme.highlight.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: theme.highlight.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('NET REVENUE', 
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          Icon(Icons.auto_graph_rounded, color: Colors.white.withOpacity(0.9), size: 20),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${BusinessConfig.instance.currencyDisplay} ${_netSales.toStringAsFixed(2)}', 
                        style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$_transactionCount transactions completed', 
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Summary Grid
                _buildSummaryCards(),
                const SizedBox(height: 32),

                // Detailed Breakdown Section
                _buildSectionHeader('FINANCIAL BREAKDOWN'),
                _buildSalesBreakdown(),
                const SizedBox(height: 32),

                // Payment Methods
                _buildSectionHeader('PAYMENT DISTRIBUTION'),
                _buildPaymentMethodsChart(),
                const SizedBox(height: 32),

                // Products (Placeholder for now but styled)
                _buildSectionHeader('TOP PERFORMANCE'),
                _buildTopProducts(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: theme.highlight, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    return GridView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isTablet ? 240 : 300,
        mainAxisExtent: isTablet ? 140 : 160,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      children: [
        _SummaryCard(title: 'Gross Sales', value: _totalSales, icon: Icons.trending_up_rounded, color: ThemeProvider.success),
        _SummaryCard(title: 'Returns', value: _totalReturns, icon: Icons.keyboard_return_rounded, color: ThemeProvider.error),
        _SummaryCard(title: 'Avg. Cart', value: _avgTransaction, icon: Icons.shopping_basket_rounded, color: theme.accent, isCurrency: true),
        _SummaryCard(title: 'Tax Collected', value: _totalTax, icon: Icons.account_balance_rounded, color: theme.secondary),
      ],
    );
  }

  Widget _buildSalesBreakdown() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: theme.glassDecoration,
      child: Column(
        children: [
          _BreakdownRow(label: 'Total Revenue', value: _totalSales, color: theme.textPrimary),
          _BreakdownRow(label: 'Returns Applied', value: -_totalReturns, color: ThemeProvider.error),
          _BreakdownRow(label: 'Total Discounts', value: -_totalDiscounts, color: ThemeProvider.warning),
          const SizedBox(height: 12),
          Divider(color: theme.whiteAlpha(0.1), height: 1),
          const SizedBox(height: 12),
          _BreakdownRow(label: 'Actual Net Sales', value: _netSales, color: theme.highlight, bold: true),
          const SizedBox(height: 12),
          _BreakdownRow(label: 'Taxes Collected', value: _totalTax, color: theme.textSecondary, small: true),
          _BreakdownRow(label: 'Service Tips', value: _totalTips, color: ThemeProvider.success, small: true),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsChart() {
    if (_salesByPaymentMethod.isEmpty) {
      return Container(
        height: 120,
        width: double.infinity,
        decoration: theme.glassDecoration,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.payments_outlined, color: theme.iconColor.withOpacity(0.5), size: 32),
              const SizedBox(height: 8),
              Text('No data for this period', style: TextStyle(color: theme.textHint, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    final total = _salesByPaymentMethod.values.fold(0.0, (a, b) => a + b);
    final colors = [theme.highlight, theme.accent, ThemeProvider.success, theme.secondary, const Color(0xFF6B4A9E)];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: theme.glassDecoration,
      child: Column(
        children: _salesByPaymentMethod.entries.toList().asMap().entries.map((entry) {
          final method = entry.value.key;
          final amount = entry.value.value;
          final percent = total > 0 ? (amount / total * 100) : 0;
          final color = colors[entry.key % colors.length];

          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(method.toUpperCase(), 
                        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${BusinessConfig.instance.currencyDisplay} ${amount.toStringAsFixed(2)}', 
                      style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 10),
                Stack(
                  children: [
                    Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(color: theme.whiteAlpha(0.05), borderRadius: BorderRadius.circular(5)),
                    ),
                    FractionallySizedBox(
                      widthFactor: percent / 100,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10)],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopProducts() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: theme.glassDecoration,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.highlight.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.rocket_launch_rounded, size: 40, color: theme.highlight.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text('Inventory Insights', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Personalized analysis coming soon', style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? theme.highlight : theme.whiteAlpha(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? theme.highlight : theme.whiteAlpha(0.1), width: 1.5),
          boxShadow: selected ? [BoxShadow(color: theme.highlight.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
        ),
        child: Text(
          label.toUpperCase(), 
          style: TextStyle(
            color: selected ? Colors.white : theme.textSecondary, 
            fontSize: 12, 
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double value;
  final IconData icon;
  final Color color;
  final bool isCurrency;

  const _SummaryCard({
    required this.title, 
    required this.value, 
    required this.icon, 
    required this.color,
    this.isCurrency = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final currency = BusinessConfig.instance.currency;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(theme.isDark ? 0.15 : 0.12),
            color.withOpacity(theme.isDark ? 0.05 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
        border: Border.all(
          color: color.withOpacity(theme.isDark ? 0.3 : 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(theme.isDark ? 0.12 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: theme.isDark
                ? Colors.black26
                : Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isCurrency 
                    ? '${BusinessConfig.instance.currencyDisplay} ${value.toStringAsFixed(0)}' 
                    : value.toInt().toString(),
                style: TextStyle(
                  color: theme.textPrimary, 
                  fontSize: 22, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: -0.5
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title.toUpperCase(), 
            style: TextStyle(
              color: theme.textSecondary, 
              fontSize: 12, 
              fontWeight: FontWeight.w800, 
              letterSpacing: 1.0
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool bold;
  final bool small;

  const _BreakdownRow({required this.label, required this.value, required this.color, this.bold = false, this.small = false});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: bold ? 12 : 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label, 
              style: TextStyle(
                color: bold ? theme.textPrimary : theme.textSecondary, 
                fontSize: bold ? 16 : (small ? 12 : 14), 
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${value < 0 ? "-" : ""}${BusinessConfig.instance.currencyDisplay} ${value.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: color, 
              fontSize: bold ? 20 : (small ? 13 : 15), 
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
