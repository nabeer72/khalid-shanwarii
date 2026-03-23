import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsPrintingScreen extends StatefulWidget {
  const ReportsPrintingScreen({super.key});

  @override
  State<ReportsPrintingScreen> createState() => _ReportsPrintingScreenState();
}

class _ReportsPrintingScreenState extends State<ReportsPrintingScreen> {
  final theme = ThemeProvider.instance;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Reports & Analytics',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildSliverSectionHeader('SALES REPORTS'),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: MediaQuery.of(context).size.width > 600 ? 240 : 160,
                    mainAxisExtent: 140,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildReportCard(
                      title: 'Daily Sales',
                      subtitle: 'Today\'s transaction summary',
                      icon: Icons.summarize_rounded,
                      color: theme.primary,
                      onTap: () => _handlePrintDailySales(DateTime.now()),
                    ),
                    _buildReportCard(
                      title: 'Custom Sales',
                      subtitle: 'Select custom period',
                      icon: Icons.date_range_rounded,
                      color: theme.secondary,
                      onTap: _handlePrintCustomRange,
                    ),
                  ]),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              _buildSliverSectionHeader('INVENTORY & STOCK'),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: MediaQuery.of(context).size.width > 600 ? 240 : 160,
                    mainAxisExtent: 140,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildReportCard(
                      title: 'Current Stock',
                      subtitle: 'All products status',
                      icon: Icons.inventory_rounded,
                      color: const Color(0xFF8B5CF6),
                      onTap: _handlePrintStockReport,
                    ),
                    _buildReportCard(
                      title: 'Low Stock Alert',
                      subtitle: 'Items below limit',
                      icon: Icons.warning_amber_rounded,
                      color: ThemeProvider.error,
                      onTap: () => _handlePrintStockReport(onlyLow: true),
                    ),
                  ]),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              _buildSliverSectionHeader('FINANCIALS'),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: MediaQuery.of(context).size.width > 600 ? 240 : 160,
                    mainAxisExtent: 140,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildReportCard(
                      title: 'Expense Summary',
                      subtitle: 'Operational expenses',
                      icon: Icons.account_balance_wallet_rounded,
                      color: const Color(0xFFEF4444),
                      onTap: _handlePrintExpenseReport,
                    ),
                  ]),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverSectionHeader(String title) {
    return SliverPadding(
      padding: const EdgeInsets.only(left: 24, bottom: 16, right: 24),
      sliver: SliverToBoxAdapter(
        child: Text(
          title,
          style: TextStyle(
            color: theme.textSecondary.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String subtitle, // Keeps API compatible, but hidden from UI to match Home Screen purely.
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isGenerating ? null : onTap,
        borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
        child: Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
            border: Border.all(
              color: theme.divider,
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: _isGenerating 
                  ? SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: color))
                  : Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePrintDailySales(DateTime date) async {
    setState(() => _isGenerating = true);
    try {
      final sales = await DatabaseHelper.instance.getSales();
      final daySales = sales.where((s) {
        final ts = DateTime.tryParse(s['created_at'] ?? '');
        return ts != null && ts.day == date.day && ts.month == date.month && ts.year == date.year;
      }).toList();

      final title = 'Daily Sales Report - ${DateFormat('yyyy-MM-dd').format(date)}';
      final pdf = await _generateSalesPdf(daySales, title);
      _showPreview(pdf, title);
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _handlePrintCustomRange() async {
    DateTime? start;
    DateTime? end;
    
    final range = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: theme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Select Period', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: theme.glassDecoration,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(start == null ? 'Start Date' : DateFormat('yyyy-MM-dd').format(start!), 
                        style: TextStyle(color: start == null ? theme.textSecondary : theme.textPrimary)),
                      trailing: Icon(Icons.date_range, color: theme.primary),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: start ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: theme.primary, surface: theme.surface)),
                            child: child!,
                          ),
                        );
                        if (date != null) setState(() => start = date);
                      },
                    ),
                  ),
                  Container(
                    decoration: theme.glassDecoration,
                    child: ListTile(
                      title: Text(end == null ? 'End Date' : DateFormat('yyyy-MM-dd').format(end!),
                        style: TextStyle(color: end == null ? theme.textSecondary : theme.textPrimary)),
                      trailing: Icon(Icons.date_range, color: theme.secondary),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: end ?? start ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: theme.secondary, surface: theme.surface)),
                            child: child!,
                          ),
                        );
                        if (date != null) setState(() => end = date);
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: start != null && end != null 
                      ? () => Navigator.pop(context, DateTimeRange(start: start!, end: end!))
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: theme.primary.withOpacity(0.3),
                  ),
                  child: const Text('Generate'),
                ),
              ],
            );
          }
        );
      },
    );

    if (range != null) {
      setState(() => _isGenerating = true);
      try {
        final sales = await DatabaseHelper.instance.getSales();
        final periodSales = sales.where((s) {
          final ts = DateTime.tryParse(s['created_at'] ?? '');
          return ts != null && ts.isAfter(range.start) && ts.isBefore(range.end.add(const Duration(days: 1)));
        }).toList();

        final title = 'Sales Report: ${DateFormat('MM/dd').format(range.start)} - ${DateFormat('MM/dd').format(range.end)}';
        final pdf = await _generateSalesPdf(periodSales, title);
        _showPreview(pdf, title);
      } finally {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _handlePrintStockReport({bool onlyLow = false}) async {
    setState(() => _isGenerating = true);
    try {
      final products = await DatabaseHelper.instance.getProducts();
      final categoriesData = await DatabaseHelper.instance.getCategories();
      final categoryMap = {for (var c in categoriesData) c['id']: c['name']};

      List<Map<String, dynamic>> augmentedProducts = products.map((p) {
        final mutable = Map<String, dynamic>.from(p);
        
        final stocks = p['stocks'] as List<dynamic>? ?? [];
        double totalStock = 0;
        if (stocks.isNotEmpty) {
           for (var s in stocks) {
             totalStock += (s['quantity'] as num?)?.toDouble() ?? 0.0;
           }
        } else {
           totalStock = (p['stock_quantity'] as num?)?.toDouble() ?? 0.0;
        }
        mutable['total_stock'] = totalStock;
        
        mutable['category_name'] = categoryMap[p['category_id']] ?? 'General';
        
        return mutable;
      }).toList();

      List<Map<String, dynamic>> filtered = augmentedProducts;
      if (onlyLow) {
        filtered = augmentedProducts.where((p) => (p['total_stock'] as num) <= (p['stock_limit'] ?? 0)).toList();
      }

      final title = onlyLow ? 'Low Stock Alert Report' : 'Current Inventory Status';
      final pdf = await _generateStockPdf(filtered, title);
      _showPreview(pdf, title);
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _handlePrintExpenseReport() async {
    setState(() => _isGenerating = true);
    try {
      final expenses = await DatabaseHelper.instance.getExpenses();
      final title = 'Operational Expense Report';
      final pdf = await _generateExpensePdf(expenses, title);
      _showPreview(pdf, title);
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _showPreview(pw.Document pdf, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            title: Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            backgroundColor: theme.surface,
            elevation: 0,
            leading: BackButton(color: theme.textPrimary),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: PdfPreview(
                build: (format) async => pdf.save(),
                allowPrinting: true,
                allowSharing: true,
                canChangeOrientation: false,
                canChangePageFormat: false,
                initialPageFormat: PdfPageFormat.a4,
                previewPageMargin: const EdgeInsets.all(8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // PDF Generation Helpers
  Future<pw.Document> _generateSalesPdf(List<Map<String, dynamic>> sales, String title) async {
    final pdf = pw.Document();
    final business = BusinessConfig.instance;

    double gross = 0;
    double net = 0;
    double disc = 0;
    for (var s in sales) {
      gross += (s['total'] as num? ?? 0).toDouble() + (s['discount'] as num? ?? 0).toDouble();
      disc += (s['discount'] as num? ?? 0).toDouble();
      net += (s['total'] as num? ?? 0).toDouble();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.Text('Business: ${business.businessName}', style: const pw.TextStyle(fontSize: 14)),
          pw.Text('Date Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 20),
          
          pw.TableHelper.fromTextArray(
            headers: ['Invoice #', 'Date', 'Customer', 'Method', 'Total'],
            data: sales.map((s) => [
              s['invoice_number'] ?? '#${s['id']}',
              DateFormat('MM/dd HH:mm').format(DateTime.parse(s['created_at'])),
              s['customer_name'] ?? 'Walk-In',
              s['payment_method'] ?? 'Cash',
              '${business.currency} ${s['total']}',
            ]).toList(),
          ),
          
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Gross Sales: ${business.currency} ${gross.toStringAsFixed(2)}'),
                  pw.Text('Total Discounts: -${business.currency} ${disc.toStringAsFixed(2)}'),
                  pw.Text('Net Revenue: ${business.currency} ${net.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    return pdf;
  }

  Future<pw.Document> _generateStockPdf(List<Map<String, dynamic>> products, String title) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Product Name', 'Category', 'Current Stock', 'Stock Limit'],
            data: products.map((p) => [
              p['name'],
              p['category_name'] ?? 'General',
              p['total_stock'].toString(),
              p['stock_limit'].toString(),
            ]).toList(),
          ),
        ],
      ),
    );
    return pdf;
  }

  Future<pw.Document> _generateExpensePdf(List<Map<String, dynamic>> expenses, String title) async {
    final pdf = pw.Document();
    double total = expenses.fold(0.0, (sum, e) => sum + (e['amount'] as num? ?? 0));
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Category', 'Description', 'Amount'],
            data: expenses.map((e) => [
              DateFormat('yyyy-MM-dd').format(DateTime.parse(e['date'])),
              e['expense_head_name'] ?? 'General',
              e['description'] ?? '',
              '${BusinessConfig.instance.currency} ${e['amount']}',
            ]).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Total Expenses: ${BusinessConfig.instance.currency} ${total.toStringAsFixed(2)}', 
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
    return pdf;
  }
}
