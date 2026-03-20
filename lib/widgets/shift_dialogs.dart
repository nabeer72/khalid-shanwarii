import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart'; // For BusinessConfig
import 'package:mobile_app/db/mock_data.dart'; // For BusinessConfig
import 'package:mobile_app/services/report_service.dart';

class ClockInDialog extends StatefulWidget {
  const ClockInDialog({super.key});

  @override
  State<ClockInDialog> createState() => _ClockInDialogState();
}

class _ClockInDialogState extends State<ClockInDialog> {
  final Map<String, int> _denominations = {
    '5000': 0,
    '1000': 0,
    '500': 0,
    '100': 0,
    '50': 0,
    '20': 0,
    '10': 0,
  };

  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (var denom in _denominations.keys) {
      _controllers[denom] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _totalOpeningCash {
    double total = 0;
    _denominations.forEach((key, value) {
      total += int.parse(key) * value;
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      content: theme.glassDecorationWidget(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: theme.glassCircleDecoration,
                      child: Icon(Icons.login_rounded, color: theme.highlight, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text('Shift Clock-In', 
                      style: TextStyle(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Enter opening cash denominations:', 
                  style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                Column(
                  children: _denominations.keys.map((denom) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(denom, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove_circle_outline, size: 18, color: theme.textSecondary),
                                    onPressed: () {
                                      final current = int.tryParse(_controllers[denom]!.text) ?? 0;
                                      if (current > 0) {
                                        final newValue = current - 1;
                                        _controllers[denom]!.text = newValue.toString();
                                        setState(() => _denominations[denom] = newValue);
                                      }
                                    },
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _controllers[denom],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                                        border: InputBorder.none,
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _denominations[denom] = int.tryParse(val) ?? 0;
                                        });
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add_circle_outline, size: 18, color: theme.highlight),
                                    onPressed: () {
                                      final current = int.tryParse(_controllers[denom]!.text) ?? 0;
                                      final newValue = current + 1;
                                      _controllers[denom]!.text = newValue.toString();
                                      setState(() => _denominations[denom] = newValue);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Opening Cash:', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w500)),
                    Text('${BusinessConfig.instance.currencyDisplay} ${_totalOpeningCash.toStringAsFixed(0)}', 
                      style: TextStyle(color: theme.highlight, fontSize: 20, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.highlight,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                    ),
                    onPressed: () => _handleClockIn(context),
                    child: const Text('START SHIFT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleClockIn(BuildContext context) async {
    final now = DateTime.now();
    final shiftData = {
      'user_id': BusinessConfig.instance.adminId ?? 1,
      'staff_id': BusinessConfig.instance.staffId,
      'start_time': now.toIso8601String(),
      'opening_cash': _totalOpeningCash,
      'opening_denominations': jsonEncode(_denominations),
      'status': 1,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    await DatabaseHelper.instance.startShift(shiftData);
    if (context.mounted) {
      Navigator.pop(context, true);
    }
  }
}

class ClockOutDenominationsDialog extends StatefulWidget {
  const ClockOutDenominationsDialog({super.key});

  @override
  State<ClockOutDenominationsDialog> createState() => _ClockOutDenominationsDialogState();
}

class _ClockOutDenominationsDialogState extends State<ClockOutDenominationsDialog> {
  final Map<String, int> _denominations = {
    '5000': 0,
    '1000': 0,
    '500': 0,
    '100': 0,
    '50': 0,
    '20': 0,
    '10': 0,
  };

  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (var denom in _denominations.keys) {
      _controllers[denom] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _totalClosingCash {
    double total = 0;
    _denominations.forEach((key, value) {
      total += int.parse(key) * value;
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      content: theme.glassDecorationWidget(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: theme.glassCircleDecoration,
                      child: Icon(Icons.money_off_rounded, color: theme.highlight, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text('Closing Cash Count', 
                      style: TextStyle(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Enter remaining cash denominations in drawer:', 
                  style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                Column(
                  children: _denominations.keys.map((denom) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(denom, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove_circle_outline, size: 18, color: theme.textSecondary),
                                    onPressed: () {
                                      final current = int.tryParse(_controllers[denom]!.text) ?? 0;
                                      if (current > 0) {
                                        final newValue = current - 1;
                                        _controllers[denom]!.text = newValue.toString();
                                        setState(() => _denominations[denom] = newValue);
                                      }
                                    },
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _controllers[denom],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                                        border: InputBorder.none,
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _denominations[denom] = int.tryParse(val) ?? 0;
                                        });
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add_circle_outline, size: 18, color: theme.highlight),
                                    onPressed: () {
                                      final current = int.tryParse(_controllers[denom]!.text) ?? 0;
                                      final newValue = current + 1;
                                      _controllers[denom]!.text = newValue.toString();
                                      setState(() => _denominations[denom] = newValue);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Closing Cash:', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w500)),
                  Text('${BusinessConfig.instance.currencyDisplay} ${_totalClosingCash.toStringAsFixed(0)}', 
                    style: TextStyle(color: theme.highlight, fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.highlight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                  ),
                  onPressed: () => Navigator.pop(context, {
                    'total': _totalClosingCash,
                    'denominations': jsonEncode(_denominations),
                  }),
                  child: const Text('PROCEED TO SUMMARY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
              ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}

class ClockOutDialog extends StatefulWidget {
  final Map<String, dynamic> activeShift;
  final double closingCash;
  final String closingDenominations;
  const ClockOutDialog({
    super.key, 
    required this.activeShift,
    required this.closingCash,
    required this.closingDenominations,
  });

  @override
  State<ClockOutDialog> createState() => _ClockOutDialogState();
}

class _ClockOutDialogState extends State<ClockOutDialog> {
  Map<String, double>? _totals;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTotals();
  }

  Future<void> _loadTotals() async {
    final startTime = widget.activeShift['start_time'];
    final now = DateTime.now();
    final totals = await DatabaseHelper.instance.getShiftTotals(startTime, now.toIso8601String());
    if (mounted) {
      setState(() {
        _totals = totals;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final openingCash = (widget.activeShift['opening_cash'] as num).toDouble();
    final cashSales = _totals?['cash_sales'] ?? 0;
    final mobileSales = _totals?['mobile_sales'] ?? 0;
    final cardSales = _totals?['card_sales'] ?? 0;
    final creditSalesTotal = _totals?['credit_sales_total'] ?? 0;
    final creditReceived = _totals?['credit_received'] ?? 0;
    final totalExpenses = _totals?['total_expenses'] ?? 0;
    final totalPurchases = _totals?['total_purchases'] ?? 0;
    
    final totalShiftRevenue = (cashSales + mobileSales + cardSales + creditSalesTotal);
    final totalCashExpected = (openingCash + cashSales + creditReceived);
    final netCashExpected = totalCashExpected - openingCash;
    
    final discrepancy = widget.closingCash - totalCashExpected;

    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      content: theme.glassDecorationWidget(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: _loading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: theme.glassCircleDecoration,
                        child: Icon(Icons.assessment_rounded, color: theme.highlight, size: 24),
                      ),
                      const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Shift Summary', 
                              style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('Reconciliation & Breakdown', 
                              style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Financial Breakdown
                  _SummaryRow(label: 'Opening Cash', value: openingCash, color: theme.textSecondary),
                  _SummaryRow(label: 'Cash Sales', value: cashSales, color: theme.textPrimary),
                  _SummaryRow(label: 'Credit Received (Paid)', value: creditReceived, color: ThemeProvider.success),
                  const Divider(height: 16),
                  _SummaryRow(label: 'Expected Cash in Drawer', value: totalCashExpected, color: theme.textPrimary, isBold: true),
                  _SummaryRow(label: 'Actual Cash Counted', value: widget.closingCash, color: theme.highlight, isBold: true),
                  
                  if (discrepancy != 0)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (discrepancy > 0 ? ThemeProvider.success : ThemeProvider.error).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(discrepancy > 0 ? 'Surplus:' : 'Shortage:', 
                            style: TextStyle(color: discrepancy > 0 ? ThemeProvider.success : ThemeProvider.error, fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('${BusinessConfig.instance.currencyDisplay} ${discrepancy.abs().toStringAsFixed(0)}', 
                            style: TextStyle(color: discrepancy > 0 ? ThemeProvider.success : ThemeProvider.error, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),

                  const Divider(height: 24),
                  
                  _SummaryRow(label: 'Mobile Transfer', value: mobileSales, color: ThemeProvider.info),
                  _SummaryRow(label: 'Card Payments', value: cardSales, color: ThemeProvider.info),
                  _SummaryRow(label: 'Credit (Outstanding)', value: creditSalesTotal - creditReceived, color: ThemeProvider.warning),
                  
                  const Divider(height: 16),
                  // New Section for Expenses and Purchases
                  _SummaryRow(label: 'Daily Expenses', value: totalExpenses, color: ThemeProvider.error),
                  _SummaryRow(label: 'Total Purchases', value: totalPurchases, color: ThemeProvider.warning),

                  const Divider(height: 24, thickness: 1.2),
                  _SummaryRow(label: 'TOTAL SHIFT REVENUE', value: totalShiftRevenue, color: theme.textPrimary, isBold: true),

                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _generateReport(context),
                          icon: const Icon(Icons.description_outlined, size: 18),
                          label: const Text('REPORT'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.highlight),
                            foregroundColor: theme.highlight,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleClockOut(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeProvider.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('CLOCK OUT', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Go Back', style: TextStyle(color: theme.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Future<void> _handleClockOut(BuildContext context) async {
    final closingData = {
      'end_time': DateTime.now().toIso8601String(),
      'closing_cash': widget.closingCash,
      'closing_denominations': widget.closingDenominations,
      'total_sales': _totals?['total_revenue'] ?? 0,
      'total_cash_received': _totals?['cash_sales'] ?? 0,
      'total_online_received': (_totals?['mobile_sales'] ?? 0) + (_totals?['card_sales'] ?? 0),
      'total_credit_received': _totals?['credit_received'] ?? 0,
      'status': 0, // Mark as inactive
    };

    await DatabaseHelper.instance.endShift(widget.activeShift['id'], closingData);
    if (context.mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _generateReport(BuildContext context) async {
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating shift report...'), duration: Duration(seconds: 1)),
        );
      }

      final reportData = {
        'activeShift': widget.activeShift,
        'totals': _totals,
        'businessName': BusinessConfig.instance.businessName,
        'currency': BusinessConfig.instance.currency,
      };
      
      await ReportService.generateShiftReport(reportData);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isBold;
  final double fontSize;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.textSecondary, fontSize: fontSize - 1)),
          Text('${BusinessConfig.instance.currencyDisplay} ${value.toStringAsFixed(0)}', 
            style: TextStyle(
              color: color, 
              fontSize: fontSize, 
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600
            )),
        ],
      ),
    );
  }
}

extension ThemeProviderExt on ThemeProvider {
  Widget glassDecorationWidget({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.8) : Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: child,
      ),
    );
  }
}
