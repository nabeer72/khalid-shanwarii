import 'package:flutter/material.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/receipt_screen.dart';

import 'package:mobile_app/services/sync_service.dart';

class SalesHistoryScreen extends StatefulWidget {
  final String? startTime;
  final String? endTime;
  final int? shiftId;
  final bool isShiftHistory;

  const SalesHistoryScreen({
    super.key,
    this.startTime,
    this.endTime,
    this.shiftId,
    this.isShiftHistory = false,
  });

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final theme = ThemeProvider.instance;
  String _filter = 'all'; // all, today, week
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _showOnlyRefunds = false;
  bool _isOnlineSearch = false;
  final SyncService _syncService = SyncService();

  List<Map<String, dynamic>> _sales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    try {
      // 1. Try local search first
      final localData = await DatabaseHelper.instance.getSales(
        startTime: widget.startTime,
        endTime: widget.endTime,
        shiftId: widget.shiftId,
      );

      List<Map<String, dynamic>> finalData = localData;

      // 2. If locally empty and searching, try online automatically
      if (_query.isNotEmpty && !_isOnlineSearch) {
        // Filter local first to see if we REALLY have nothing
        final q = _query.toLowerCase();
        final localFiltered = localData.where((s) {
          final customerName = (s['customer_name'] ?? '').toString().toLowerCase();
          final customerPhone = (s['customer_phone'] ?? '').toString().toLowerCase();
          final invoiceNum = s['id'].toString();
          final date = (s['created_at'] ?? '').toString().toLowerCase();
          return customerName.contains(q) || customerPhone.contains(q) || invoiceNum.contains(q) || date.contains(q);
        }).toList();

        if (localFiltered.isEmpty) {
          final onlineData = await _syncService.searchOnline(_query, 'sales');
          if (onlineData.isNotEmpty) {
            finalData = onlineData;
            _isOnlineSearch = true;
          }
        }
      } else if (_isOnlineSearch) {
        // We are already in online mode, just refresh from server
        finalData = await _syncService.searchOnline(_query, 'sales');
      }

      if (mounted) {
        setState(() {
          _sales = finalData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading sales history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredSales {
    List<Map<String, dynamic>> filtered = _sales;

    // Apply time/shift filter
    if (widget.isShiftHistory) {
      filtered = _sales;
    } else {
      final now = DateTime.now();
      if (_filter == 'today') {
        filtered = _sales.where((s) {
          final ts = DateTime.tryParse(s['created_at'] ?? '')?.toLocal();
          return ts != null && ts.day == now.day && ts.month == now.month && ts.year == now.year;
        }).toList();
      } else if (_filter == 'week') {
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = _sales.where((s) {
          final ts = DateTime.tryParse(s['created_at'] ?? '')?.toLocal();
          return ts != null && ts.isAfter(weekAgo);
        }).toList();
      }
    }

    // Apply refund filter
    if (_showOnlyRefunds) {
      filtered = filtered.where((s) => s['is_return'] == 1).toList();
    }

    // Apply search query (Local filter only if NOT online search)
    if (_query.isNotEmpty && !_isOnlineSearch) {
      final q = _query.toLowerCase();
      filtered = filtered.where((s) {
        final customerName = (s['customer_name'] ?? '').toString().toLowerCase();
        final customerPhone = (s['customer_phone'] ?? '').toString().toLowerCase();
        final employeeName = (s['employee_name'] ?? '').toString().toLowerCase();
        final invoiceNum = s['id'].toString();
        final date = (s['created_at'] ?? '').toString().toLowerCase();
        
        return customerName.contains(q) || 
               customerPhone.contains(q) || 
               employeeName.contains(q) || 
               invoiceNum.contains(q) || 
               date.contains(q);
      }).toList();
    }

    return filtered;
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
          widget.isShiftHistory ? 'Shift History' : 'Sales History',
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
                              style: TextStyle(color: theme.textHint, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text('${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(_totalAmount)}', 
                              style: TextStyle(color: theme.highlight, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: theme.whiteAlpha(0.05), borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                        child: Row(
                          children: [
                            Icon(Icons.analytics_rounded, color: theme.highlight, size: 20),
                            const SizedBox(width: 8),
                            Text('${_filteredSales.length} SALES', 
                              style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search & Filter Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: theme.glassDecoration,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v),
                          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Search records...',
                            hintStyle: TextStyle(color: theme.textHint),
                            prefixIcon: Icon(Icons.search_rounded, color: theme.highlight),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'REFUNDS',
                      selected: _showOnlyRefunds,
                      onTap: () => setState(() => _showOnlyRefunds = !_showOnlyRefunds),
                    ),
                  ],
                ),
              ),
              
              if (!widget.isShiftHistory)
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
                              child: Icon(
                                _isOnlineSearch ? Icons.cloud_off_rounded : Icons.receipt_long_rounded, 
                                size: 60, 
                                color: theme.iconColor
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(_isOnlineSearch ? 'No records found on server' : 'No activity recorded', 
                              style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                            Text(_isOnlineSearch ? 'Try a different search term' : 'Transactions will appear here', 
                              style: TextStyle(color: theme.textSecondary, fontSize: 14)),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          if (_isOnlineSearch)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.cloud_done_rounded, color: theme.highlight, size: 16),
                                  const SizedBox(width: 8),
                                  Text('SHOWING RESULTS FROM SERVER', 
                                    style: TextStyle(color: theme.highlight, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isOnlineSearch = false;
                                        _loadSales();
                                      });
                                    },
                                    child: const Text('BACK TO LOCAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                              itemCount: _filteredSales.length,
                              itemBuilder: (context, index) {
                                final sale = _filteredSales[_filteredSales.length - 1 - index]; // Reverse order
                                return _SaleTile(
                                  sale: sale, 
                                  onTap: () => _showSaleDetail(sale),
                                  onPrint: () => _showSaleDetail(sale),
                                  onRefund: () => _handleRefund(sale),
                                  isOnline: _isOnlineSearch,
                                );
                              },
                            ),
                          ),
                          if (!_isOnlineSearch && _query.isNotEmpty && _filteredSales.isNotEmpty)
                             Padding(
                               padding: const EdgeInsets.only(bottom: 24),
                               child: Text('SEARCHING LOCAL ONLY. TRY MORE SPECIFIC QUERY FOR ONLINE AUTO-SEARCH.', 
                                 textAlign: TextAlign.center,
                                 style: TextStyle(color: theme.textHint, fontSize: 8, fontWeight: FontWeight.w700)),
                             ),
                        ],
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

  void _handleRefund(Map<String, dynamic> sale) {
    Navigator.pop(context, sale); // Return to caller with sale data
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
          borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
          border: Border.all(color: selected ? theme.highlight : theme.whiteAlpha(0.1)),
          boxShadow: selected ? [BoxShadow(color: theme.highlight.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final Map<String, dynamic> sale;
  final VoidCallback onTap;
  final VoidCallback onPrint;
  final VoidCallback onRefund;
  final bool isOnline;

  const _SaleTile({
    required this.sale, 
    required this.onTap,
    required this.onPrint,
    required this.onRefund,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final timestamp = DateTime.tryParse(sale['created_at'] ?? '');
    final isReturn = sale['is_return'] == 1;
    final total = (sale['total'] as num? ?? 0).toDouble();
    final paymentMethod = sale['payment_method'] ?? 'Cash';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: theme.glassDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: onTap,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isReturn ? 'REFUND' : 'SALE', 
                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            if (sale['customer_name'] != null)
              Text(sale['customer_name'].toString().toUpperCase(), 
                  style: TextStyle(color: theme.highlight, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timestamp != null ? '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')} | ${timestamp.day}/${timestamp.month}/${timestamp.year}' : 'Unknown',
                style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              if (sale['employee_name'] != null)
                Text(
                  'BY: ${sale['employee_name']}',
                  style: TextStyle(color: theme.textHint, fontSize: 9, fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isReturn ? 'REFUND #${sale['id'] ?? '??'}' : 'BILL #${sale['id'] ?? '??'}',
                  style: TextStyle(color: theme.textPrimary, fontSize: 10, fontWeight: FontWeight.w900),
                ),
                Text(
                  '${isReturn ? "-" : ""}${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(total.abs())}',
                  style: TextStyle(color: isReturn ? ThemeProvider.warning : theme.highlight, fontWeight: FontWeight.w900, fontSize: 13),
                ),
                if (isOnline)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: theme.highlight.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text('ONLINE', style: TextStyle(color: theme.highlight, fontSize: 7, fontWeight: FontWeight.w900)),
                  ),
                Text(
                  paymentMethod.toUpperCase(),
                  style: TextStyle(color: theme.textHint, fontSize: 8, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.print_rounded, color: theme.textSecondary, size: 22),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: onPrint,
              tooltip: 'Print Receipt',
            ),
            if (!isReturn)
              IconButton(
                icon: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ThemeProvider.warning.withOpacity(0.15),
                  ),
                  child: const Icon(Icons.undo, color: ThemeProvider.warning, size: 16),
                ),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: onRefund,
                tooltip: 'Refund Sale',
              ),
          ],
        ),
      ),
    );
  }
}
