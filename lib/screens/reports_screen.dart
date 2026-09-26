import 'dart:async';
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
  List<Map<String, dynamic>> _saleItems = [];
  List<Map<String, dynamic>> _returnItems = [];
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;

  StreamSubscription<void>? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
    // Listen for data changes
    _dataSubscription = DatabaseHelper.dataStream.listen((_) {
      if (mounted) {
        _loadAnalyticsData();
      }
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseHelper.instance;
      final results = await Future.wait([
        db.getSales(),
        db.getDetailedSaleItems(),
        db.getDetailedReturnItems(),
        db.getExpenses(),
      ]);
      if (mounted) {
        setState(() {
          _sales = results[0];
          _saleItems = results[1];
          _returnItems = results[2];
          _expenses = results[3];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sales reports: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double _lineItemNet(Map<String, dynamic> item) {
    final qty = _parseAmount(item['quantity']);
    final price = _parseAmount(item['price']);
    double subtotal = _parseAmount(item['subtotal']);
    if (subtotal == 0 && qty > 0 && price > 0) {
      subtotal = qty * price;
    }
    return subtotal - _parseAmount(item['discount']);
  }

  static double _lineItemProfit(Map<String, dynamic> item) {
    final qty = _parseAmount(item['quantity']);
    final cost = _parseAmount(item['purchase_price']) * qty;
    final profit = _lineItemNet(item) - cost;
    return profit;
  }

  DateTime _parseDate(dynamic dateStr) {
    if (dateStr == null) {
      return DateTime(0);
    }
    String str = dateStr.toString();
    // Try parsing as YYYY-MM-DD first
    final parts = str.split('T')[0].split('-');
    if (parts.length >= 3) {
      try {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        return DateTime(year, month, day);
      } catch (_) {
        // fall through
      }
    }
    final parsed = DateTime.tryParse(str);
    if (parsed == null) {
      return DateTime(0);
    }
    final result = DateTime(
        parsed.toLocal().year, parsed.toLocal().month, parsed.toLocal().day);
    return result;
  }

  bool _isInPeriod(DateTime? ts) {
    if (ts == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalizedTs = _parseDate(ts.toIso8601String());
    switch (_period) {
      case 'today':
        return normalizedTs == today;
      case 'week':
        final weekAgo = today.subtract(const Duration(days: 7));
        return normalizedTs.isAfter(weekAgo);
      case 'month':
        return normalizedTs.month == now.month && normalizedTs.year == now.year;
      default:
        return true;
    }
  }

  List<Map<String, dynamic>> get _salesForPeriod {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sales = _sales;

    switch (_period) {
      case 'today':
        return sales.where((s) {
          final ts = DateTime.tryParse(s['created_at'] ?? '');
          if (ts == null) {
            return false;
          }
          final parsedDate = _parseDate(ts.toIso8601String());
          final isToday = parsedDate == today;
          return isToday;
        }).toList();
      case 'week':
        final weekAgo = today.subtract(const Duration(days: 7));
        return sales.where((s) {
          final ts = DateTime.tryParse(s['created_at'] ?? '');
          if (ts == null) return false;
          return _parseDate(ts.toIso8601String()).isAfter(weekAgo);
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

  double get _totalSales {
    final val = _salesForPeriod
        .where((s) => s['is_return'] != 1)
        .fold(0.0, (sum, s) => sum + (s['total'] as num? ?? 0).toDouble());
    return val;
  }

  double get _totalReturns {
    final val = _salesForPeriod.where((s) => s['is_return'] == 1).fold(
        0.0, (sum, s) => sum + (s['total'] as num? ?? 0).abs().toDouble());
    return val;
  }

  double get _netSales {
    final val = _totalSales - _totalReturns;
    return val;
  }

  double get _totalTax => _salesForPeriod
      .where((s) => s['is_return'] != 1)
      .fold(0.0, (sum, s) => sum + (s['tax'] as num? ?? 0).toDouble());
  double get _totalTips => _salesForPeriod
      .where((s) => s['is_return'] != 1)
      .fold(0.0, (sum, s) => sum + (s['tip'] as num? ?? 0).toDouble());
  double get _totalDiscounts => _salesForPeriod
      .where((s) => s['is_return'] != 1)
      .fold(0.0, (sum, s) => sum + (s['discount'] as num? ?? 0).toDouble());
  int get _transactionCount =>
      _salesForPeriod.where((s) => s['is_return'] != 1).length;
  double get _avgTransaction =>
      _transactionCount > 0 ? _netSales / _transactionCount : 0;

  List<Map<String, dynamic>> get _saleItemsForPeriod {
    return _saleItems.where((item) {
      final ts = DateTime.tryParse(item['created_at']?.toString() ?? '');
      return _isInPeriod(ts);
    }).toList();
  }

  List<Map<String, dynamic>> get _returnItemsForPeriod {
    return _returnItems.where((item) {
      final ts = DateTime.tryParse(item['created_at']?.toString() ?? '');
      return _isInPeriod(ts);
    }).toList();
  }

  /// Same as print report: sum(line net − cost) for sales minus returns.
  double get _salesProfit {
    final val = _saleItemsForPeriod.fold(
        0.0, (sum, item) => sum + _lineItemProfit(item));
    return val;
  }

  double get _returnsProfit {
    final val = _returnItemsForPeriod
        .fold(0.0, (sum, item) => sum + _lineItemProfit(item))
        .abs();
    return val;
  }

  List<Map<String, dynamic>> get _expensesForPeriod {
    return _expenses.where((item) {
      final ts = DateTime.tryParse(
          item['date']?.toString() ?? item['created_at']?.toString() ?? '');
      final inPeriod = _isInPeriod(ts);
      return inPeriod;
    }).toList();
  }

  double get _totalExpenses {
    final val = _expensesForPeriod.fold(
        0.0, (sum, e) => sum + (e['amount'] as num? ?? 0).toDouble());
    return val;
  }

  double get _profitBeforeExpenses => _salesProfit - _returnsProfit;

  double get _netProfit => _profitBeforeExpenses - _totalExpenses;

  Map<String, double> get _salesByPaymentMethod {
    final Map<String, double> result = {};
    for (var sale in _salesForPeriod.where((s) => s['is_return'] != 1)) {
      final method = sale['payment_method'] ?? 'Cash';
      final amount = (sale['total'] as num? ?? 0).toDouble();
      result[method] = (result[method] ?? 0) + amount;
    }
    return result;
  }

  String get _periodLabel {
    switch (_period) {
      case 'today':
        return 'Today';
      case 'week':
        return 'This Week';
      case 'month':
        return 'This Month';
      default:
        return 'All Time';
    }
  }

  static IconData _paymentIcon(String method) {
    final m = method.toLowerCase();
    if (m.contains('cash')) return Icons.payments_rounded;
    if (m.contains('card')) return Icons.credit_card_rounded;
    if (m.contains('mobile')) return Icons.phone_android_rounded;
    if (m.contains('credit')) return Icons.account_balance_wallet_outlined;
    return Icons.payment_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final currency = BusinessConfig.instance.currencyDisplay;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Business overview · $_periodLabel',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        leading: BackButton(color: theme.textPrimary),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodSelector(),
                    const SizedBox(height: 20),
                    _buildHeroCard(currency),
                    const SizedBox(height: 20),
                    _buildSummaryCards(),
                    const SizedBox(height: 28),
                    _buildSectionHeader(
                      'Financial Breakdown',
                      icon: Icons.receipt_long_rounded,
                    ),
                    _buildSalesBreakdown(currency),
                    const SizedBox(height: 28),
                    _buildSectionHeader(
                      'Payment Distribution',
                      icon: Icons.pie_chart_outline_rounded,
                    ),
                    _buildPaymentMethodsChart(currency),
                    const SizedBox(height: 28),
                    _buildSectionHeader(
                      'Top Performance',
                      icon: Icons.leaderboard_rounded,
                    ),
                    _buildTopProducts(),
                  ],
                ),
              ),
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    color: theme.background.withValues(alpha: 0.65),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 22),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: theme.divider.withValues(alpha: 0.6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: theme.highlight,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Loading analytics…',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.divider.withValues(alpha: 0.7)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _PeriodChip(
                label: 'Today',
                selected: _period == 'today',
                onTap: () => setState(() => _period = 'today')),
            _PeriodChip(
                label: 'Week',
                selected: _period == 'week',
                onTap: () => setState(() => _period = 'week')),
            _PeriodChip(
                label: 'Month',
                selected: _period == 'month',
                onTap: () => setState(() => _period = 'month')),
            _PeriodChip(
                label: 'All',
                selected: _period == 'all',
                onTap: () => setState(() => _period = 'all')),
          ],
        ),
      ),
    );
  }

  // ── Dashboard icon palette (same as _ModuleCard colours) ──────────────

  Color _paymentColor(String method) {
    return theme.highlight;
  }

  Widget _buildHeroCard(String currency) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
        border: Border.all(
          color: theme.divider,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            child: Icon(Icons.insights_rounded,
                color: theme.highlight, size: isTablet ? 34 : 26),
          ),
          Text(
            'Performance Snapshot',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: isTablet ? 26 : 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text('Business overview · $_periodLabel',
              style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _QuickStat(
                  icon: Icons.receipt_long_outlined,
                  value: _transactionCount,
                  label: 'SALES'),
              _QuickStat(
                icon: Icons.account_balance_rounded,
                value: _netSales,
                label: 'NET REVENUE',
                isCurrency: true,
              ),
              _QuickStat(
                icon: Icons.savings_rounded,
                value: _netProfit,
                label: 'NET PROFIT',
                isCurrency: true,
              ),
              _QuickStat(
                icon: Icons.shopping_basket_rounded,
                value: _avgTransaction,
                label: 'AVG. CART',
                isCurrency: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: theme.highlight),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
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
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 4 : 2,
        mainAxisExtent: isTablet ? 120 : 132,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      children: [
        _SummaryCard(
            title: 'Gross Sales',
            value: _totalSales,
            icon: Icons.receipt_long_outlined,
            color: theme.highlight),
        _SummaryCard(
            title: 'Returns',
            value: _totalReturns,
            icon: Icons.keyboard_return_rounded,
            color: theme.highlight),
        _SummaryCard(
            title: 'Net Profit',
            value: _netProfit,
            icon: Icons.paid_rounded,
            color: theme.highlight),
        _SummaryCard(
            title: 'Avg. Cart',
            value: _avgTransaction,
            icon: Icons.shopping_basket_rounded,
            color: theme.highlight,
            isCurrency: true),
      ],
    );
  }

  Widget _buildSalesBreakdown(String currency) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          _BreakdownGroup(
            title: 'Revenue',
            color: theme.highlight,
            children: [
              _BreakdownRow(
                  label: 'Gross Sales',
                  value: _totalSales,
                  icon: Icons.receipt_long_outlined,
                  iconColor: theme.highlight),
              _BreakdownRow(
                  label: 'Returns',
                  value: -_totalReturns,
                  icon: Icons.keyboard_return_rounded,
                  iconColor: theme.highlight),
              _BreakdownRow(
                  label: 'Discounts',
                  value: -_totalDiscounts,
                  icon: Icons.local_offer_outlined,
                  iconColor: theme.highlight),
              _BreakdownRow(
                  label: 'Net Sales',
                  value: _netSales,
                  icon: Icons.account_balance_rounded,
                  iconColor: theme.highlight,
                  bold: true),
            ],
          ),
          Divider(height: 1, color: theme.divider.withValues(alpha: 0.5)),
          _BreakdownGroup(
            title: 'Profit Before Expenses',
            color: theme.highlight,
            children: [
              _BreakdownRow(
                  label: 'Sales Profit',
                  value: _salesProfit,
                  icon: Icons.savings_outlined,
                  iconColor: theme.highlight),
              if (_returnsProfit != 0)
                _BreakdownRow(
                    label: 'Return Impact',
                    value: -_returnsProfit,
                    icon: Icons.remove_circle_outline_rounded,
                    iconColor: theme.highlight),
            ],
          ),
          Divider(height: 1, color: theme.divider.withValues(alpha: 0.5)),
          _BreakdownGroup(
            title: 'Other',
            color: theme.highlight,
            children: [
              _BreakdownRow(
                  label: 'Tax Collected',
                  value: _totalTax,
                  icon: Icons.receipt_outlined,
                  iconColor: theme.highlight),
              _BreakdownRow(
                  label: 'Service Tips',
                  value: _totalTips,
                  icon: Icons.volunteer_activism_outlined,
                  iconColor: theme.highlight),
            ],
          ),
          Divider(height: 1, color: theme.divider.withValues(alpha: 0.5)),
          _BreakdownGroup(
            title: 'Expenses',
            color: theme.highlight,
            children: [
              _BreakdownRow(
                label: 'Total Expenses',
                value: -_totalExpenses,
                icon: Icons.money_off_rounded,
                iconColor: theme.highlight,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.highlight, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.highlight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.paid_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Net Profit After Expenses',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_netProfit < 0 ? '−' : ''}$currency ${_netProfit.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            color: theme.highlight,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsChart(String currency) {
    if (_salesByPaymentMethod.isEmpty) {
      return Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.divider.withValues(alpha: 0.6)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments_outlined, color: theme.textHint, size: 36),
            const SizedBox(height: 10),
            Text(
              'No payments in this period',
              style: TextStyle(
                  color: theme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ],
        ),
      );
    }

    final total = _salesByPaymentMethod.values.fold(0.0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        children:
            _salesByPaymentMethod.entries.toList().asMap().entries.map((entry) {
          final method = entry.value.key;
          final amount = entry.value.value;
          final percent = total > 0 ? (amount / total * 100) : 0.0;
          final isLast = entry.key == _salesByPaymentMethod.length - 1;
          final methodColor = _paymentColor(method);

          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: methodColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_paymentIcon(method),
                          color: methodColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  method,
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${percent.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: methodColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$currency ${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 8,
                    backgroundColor: theme.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(methodColor),
                  ),
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
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.highlight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 36, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'Product insights',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Top sellers and category trends will appear here in a future update.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final dynamic value; // Can be int or double
  final String label;
  final bool isCurrency;

  const _QuickStat({
    required this.icon,
    required this.value,
    required this.label,
    this.isCurrency = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final isNegative = (value is num) ? value < 0 : false;
    final displayValue = (value is num) ? value.abs() : value;
    final displayPrefix = isNegative ? '−' : '';

    String displayText;
    if (isCurrency) {
      displayText =
          '$displayPrefix${BusinessConfig.instance.currencyDisplay} ${displayValue.toStringAsFixed(0)}';
    } else {
      displayText = '$displayPrefix$displayValue';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: theme.iconColor, size: 14),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(displayText,
              style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ]),
      ],
    );
  }
}

class _BreakdownGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color? color;

  const _BreakdownGroup(
      {required this.title, required this.children, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (color != null) ...[
                Container(
                  width: 4,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: color ?? theme.textHint,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.highlight : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : theme.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
  final bool isCurrency;
  final Color color;

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
    final isNegative = value < 0;
    final displayValue = isNegative ? value.abs() : value;
    final displayPrefix = isNegative ? '−' : '';
    final displayColor = isNegative ? theme.highlight : color;

    final display = isCurrency
        ? '$displayPrefix${BusinessConfig.instance.currencyDisplay} ${displayValue.toStringAsFixed(2)}'
        : '$displayPrefix${displayValue.toInt().toString()}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: displayColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: displayColor, size: 18),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              display,
              style: TextStyle(
                color: displayColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
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
  final bool bold;
  final IconData? icon;
  final Color? iconColor;

  const _BreakdownRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final prefix = value < 0 ? '−' : '';
    final effectiveIconColor = iconColor ?? theme.highlight;
    // Amount colour: negative values (returns/discounts) use highlight, positive use icon colour
    final amountColor = value < 0 ? theme.highlight : effectiveIconColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: effectiveIconColor),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? theme.textPrimary : theme.textSecondary,
                fontSize: bold ? 15 : 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$prefix${BusinessConfig.instance.currencyDisplay} ${value.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: amountColor,
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
