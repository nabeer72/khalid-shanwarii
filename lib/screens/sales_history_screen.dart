import 'package:flutter/material.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/receipt_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final theme = ThemeProvider.instance;
  String _filter = 'all'; // all, today, week

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
      print('Error loading sales history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredSales {
    final now = DateTime.now();
    final sales = _sales;
    
    if (_filter == 'today') {
      return sales.where((s) {
        final ts = DateTime.tryParse(s['created_at'] ?? '');
        return ts != null && ts.day == now.day && ts.month == now.month && ts.year == now.year;
      }).toList();
    } else if (_filter == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      return sales.where((s) {
        final ts = DateTime.tryParse(s['created_at'] ?? '');
        return ts != null && ts.isAfter(weekAgo);
      }).toList();
    }
    return sales;
  }

  double get _totalAmount => _filteredSales.fold(0.0, (sum, s) => sum + (s['total'] as num? ?? 0).toDouble());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Sales History',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
        actions: [
          IconButton(
            icon: Icon(theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: theme.iconColor),
            onPressed: () => setState(() => theme.toggleTheme()),
          ),
        ],
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Filter tabs & Summary
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: theme.glassDecoration,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TOTAL REVENUE', 
                              style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text('${BusinessConfig.instance.currency}. ${_totalAmount.toStringAsFixed(2)}', 
                              style: TextStyle(color: theme.highlight, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: theme.whiteAlpha(0.05), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Icon(Icons.analytics_rounded, color: theme.highlight, size: 20),
                            const SizedBox(width: 8),
                            Text('${_filteredSales.length} SALES', 
                              style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _FilterChip(label: 'ALL', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'TODAY', selected: _filter == 'today', onTap: () => setState(() => _filter = 'today')),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'WEEK', selected: _filter == 'week', onTap: () => setState(() => _filter = 'week')),
                  ],
                ),
              ),

              // Sales list
              Expanded(
                child: _isLoading 
                ? Center(child: CircularProgressIndicator(color: theme.highlight))
                : _filteredSales.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: theme.glassCircleDecoration,
                              child: Icon(Icons.receipt_long_rounded, size: 60, color: theme.iconColor),
                            ),
                            const SizedBox(height: 20),
                            Text('No activity recorded', 
                              style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                            Text('Transactions will appear here', 
                              style: TextStyle(color: theme.textSecondary, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: _filteredSales.length,
                        itemBuilder: (context, index) {
                          final sale = _filteredSales[_filteredSales.length - 1 - index]; // Reverse order
                          return _SaleTile(sale: sale, onTap: () => _showSaleDetail(sale));
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSaleDetail(Map<String, dynamic> sale) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(sale: sale)));
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.highlight : theme.whiteAlpha(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? theme.highlight : theme.whiteAlpha(0.1)),
          boxShadow: selected ? [BoxShadow(color: theme.highlight.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final Map<String, dynamic> sale;
  final VoidCallback onTap;

  const _SaleTile({required this.sale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final timestamp = DateTime.tryParse(sale['created_at'] ?? '');
    final isReturn = sale['is_return'] == 1;
    final total = (sale['total'] as num? ?? 0).toDouble();
    final paymentMethod = sale['payment_method'] ?? 'Cash';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: theme.glassDecoration,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: theme.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isReturn ? Icons.assignment_return_rounded : Icons.receipt_long_rounded, 
                      color: isReturn ? ThemeProvider.warning : ThemeProvider.success,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(isReturn ? 'REFUND' : 'SALE', 
                              style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('#${sale['id'] ?? '??'}', 
                                style: TextStyle(color: theme.textHint, fontSize: 9, fontWeight: FontWeight.w900),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timestamp != null ? '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')} • ${timestamp.day}/${timestamp.month}/${timestamp.year}' : 'Unknown',
                          style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                        Text(paymentMethod.toUpperCase(), 
                          style: TextStyle(color: theme.textHint, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isReturn ? "-" : ""}${BusinessConfig.instance.currency}. ${total.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isReturn ? ThemeProvider.warning : theme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: theme.iconColor, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
