
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
  String? _generatingReportTitle;
  pw.Font? _cachedFont;
  pw.Font? _cachedBoldFont;

  Future<void> _ensureFontsLoaded() async {
    _cachedFont ??= await PdfGoogleFonts.notoSansRegular();
    _cachedBoldFont ??= await PdfGoogleFonts.notoSansBold();
  }

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
              
              _buildSliverSectionHeader('ADVANCED SALES REPORTS'),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: MediaQuery.of(context).size.width > 600 ? 210 : 160,
                    mainAxisExtent: 115,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildReportCard(
                      title: 'Grand Summary',
                      subtitle: 'All reports combined',
                      icon: Icons.summarize_rounded,
                      color: const Color(0xFF4F46E5), // Indigo 600
                      onTap: _handlePrintGrandSummary,
                    ),
                    _buildReportCard(
                      title: 'Sales Report',
                      subtitle: 'Full sales overview',
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFF6366F1), // Indigo
                      onTap: _handlePrintGeneralSales,
                    ),
                    _buildReportCard(
                      title: 'Category Wise',
                      subtitle: 'Sales by category',
                      icon: Icons.category_rounded,
                      color: const Color(0xFF10B981),
                      onTap: _handlePrintCategoryWise,
                    ),
                    _buildReportCard(
                      title: 'Top Selling',
                      subtitle: 'Popular products',
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFFF59E0B),
                      onTap: _handlePrintTopSelling,
                    ),
                    _buildReportCard(
                      title: 'Employee Wise',
                      subtitle: 'Staff performance',
                      icon: Icons.people_rounded,
                      color: const Color(0xFF3B82F6),
                      onTap: _handlePrintEmployeeWise,
                    ),
                    _buildReportCard(
                      title: 'Product Wise',
                      subtitle: 'Detailed product sales',
                      icon: Icons.list_alt_rounded,
                      color: const Color(0xFF6366F1),
                      onTap: _handlePrintProductWise,
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
                    maxCrossAxisExtent: MediaQuery.of(context).size.width > 600 ? 210 : 160,
                    mainAxisExtent: 115,
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
                    maxCrossAxisExtent: MediaQuery.of(context).size.width > 600 ? 210 : 160,
                    mainAxisExtent: 115,
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
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _generatingReportTitle != null ? null : onTap,
        borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
        child: Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
            border: Border.all(
              color: theme.divider.withValues(alpha: 0.5),
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: _generatingReportTitle == title 
                  ? SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                  : Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showReportOptionsDialog<T>({
    required String title,
    List<T>? options,
    required String Function(T) labelMapping,
    IconData icon = Icons.list_rounded,
  }) async {
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    T? selectedOption;
    String searchQuery = '';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.transparent,
          child: Container(
            width: 450,
            constraints: const BoxConstraints(maxHeight: 700),
            padding: const EdgeInsets.all(24),
            decoration: theme.glassDecoration.copyWith(
              borderRadius: BorderRadius.circular(20),
              color: theme.surface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('REPORT PARAMETERS',
                              style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5)),
                          const SizedBox(height: 4),
                          Text(title,
                              style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded, color: theme.textSecondary),
                      style: IconButton.styleFrom(
                        backgroundColor: theme.divider.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Date Selection Section
                Text('SELECT PERIOD',
                    style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateInput(
                        label: 'Start Date',
                        date: startDate,
                        onTap: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setLocalState(() => startDate = d);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateInput(
                        label: 'End Date',
                        date: endDate,
                        onTap: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: endDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setLocalState(() => endDate = d);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Entity Selection (Searchable Dropdown/List)
                if (options != null) ...[
                  Text('SELECT ${title.split(' ')[0].toUpperCase()}',
                      style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.divider.withValues(alpha: 0.5)),
                    ),
                    child: TextField(
                      onChanged: (v) => setLocalState(() => searchQuery = v),
                      style: TextStyle(color: theme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        icon: Icon(Icons.search_rounded, color: theme.textSecondary, size: 20),
                        hintText: 'Search...',
                        hintStyle: TextStyle(color: theme.textHint),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, __) {
                        final option = options[__];
                        final label = labelMapping(option);
                        if (searchQuery.isNotEmpty && !label.toLowerCase().contains(searchQuery.toLowerCase())) {
                          return const SizedBox.shrink();
                        }
                        return const SizedBox(height: 8);
                      },
                      itemBuilder: (ctx, index) {
                        final option = options[index];
                        final label = labelMapping(option);
                        
                        bool isAllOption = false;
                        if (option is Map) isAllOption = option['id'] == null;

                        if (searchQuery.isNotEmpty && !label.toLowerCase().contains(searchQuery.toLowerCase()) && !isAllOption) {
                          return const SizedBox.shrink();
                        }

                        final isSelected = selectedOption == option || (selectedOption == null && isAllOption);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setLocalState(() => selectedOption = option),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? theme.primary : theme.divider.withValues(alpha: 0.3),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                                color: isSelected 
                                  ? theme.primary.withValues(alpha: 0.1) 
                                  : (theme.isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isAllOption ? Icons.all_inclusive_rounded : icon,
                                    color: isSelected ? theme.primary : theme.textSecondary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: isSelected ? theme.primary : theme.textPrimary,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (isSelected) 
                                    Icon(Icons.check_circle_rounded, color: theme.primary, size: 18),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                
                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx, {
                        'selection': selectedOption,
                        'startDate': startDate,
                        'endDate': endDate,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('GENERATE REPORT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showUnifiedReportDialog({
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> employees,
  }) async {
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    Map<String, dynamic>? selectedCategory;
    Map<String, dynamic>? selectedEmployee;

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.transparent,
              child: Container(
                width: 450,
                padding: const EdgeInsets.all(24),
                decoration: theme.glassDecoration.copyWith(
                  borderRadius: BorderRadius.circular(20),
                  color: theme.surface,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(' REPORT'.toUpperCase(),
                                style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5)),
                            const SizedBox(height: 4),
                            Text('Sales Parameters',
                                style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, color: theme.textSecondary),
                          style: IconButton.styleFrom(
                            backgroundColor: theme.divider.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Date Selection
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateInput(
                            label: 'Start Date',
                            date: startDate,
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) setLocalState(() => startDate = d);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateInput(
                            label: 'End Date',
                            date: endDate,
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: endDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) setLocalState(() => endDate = d);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Category Selector
                    _buildSearchableSelector(
                      label: 'Category',
                      selectedValue: selectedCategory?['name'] ?? 'All Categories',
                      icon: Icons.category_rounded,
                      onTap: () async {
                        final result = await _showFilterPicker(
                          title: 'Select Category',
                          options: [{'id': null, 'name': 'All Categories'}, ...categories],
                          labelMapping: (c) => c['name'],
                          icon: Icons.category_rounded,
                        );
                        if (result != null) setLocalState(() => selectedCategory = result);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Employee Selector
                    _buildSearchableSelector(
                      label: 'Employee',
                      selectedValue: selectedEmployee?['name'] ?? 'All Employees',
                      icon: Icons.person_rounded,
                      onTap: () async {
                        final result = await _showFilterPicker(
                          title: 'Select Employee',
                          options: [{'id': null, 'name': 'All Employees'}, ...employees],
                          labelMapping: (e) => e['name'],
                          icon: Icons.person_rounded,
                        );
                        if (result != null) setLocalState(() => selectedEmployee = result);
                      },
                    ),

                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx, {
                            'category': selectedCategory,
                            'employee': selectedEmployee,
                            'startDate': startDate,
                            'endDate': endDate,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('GENERATE REPORT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildSearchableSelector({
    required String label,
    required String selectedValue,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: theme.textSecondary, fontSize: 8, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.divider.withValues(alpha: 0.5)),
              color: theme.isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
            ),
            child: Row(
              children: [
                Icon(icon, color: theme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedValue,
                    style: TextStyle(
                      color: selectedValue.contains('All') ? theme.textSecondary : theme.textPrimary,
                      fontWeight: selectedValue.contains('All') ? FontWeight.normal : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: theme.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<T?> _showFilterPicker<T>({
    required String title,
    required List<T> options,
    required String Function(T) labelMapping,
    required IconData icon,
  }) async {
    String searchQuery = '';
    return await showDialog<T>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final filtered = options.where((opt) {
              final label = labelMapping(opt);
              return label.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: theme.surface,
              child: Container(
                width: 350,
                constraints: const BoxConstraints(maxHeight: 500),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (v) => setLocalState(() => searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search, color: theme.textSecondary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final opt = filtered[i];
                          return ListTile(
                            leading: Icon(icon, color: theme.primary, size: 20),
                            title: Text(labelMapping(opt), style: TextStyle(color: theme.textPrimary)),
                            onTap: () => Navigator.pop(ctx, opt),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildDateInput({required String label, required DateTime date, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: theme.textSecondary, fontSize: 8, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.divider.withValues(alpha: 0.5)),
              color: theme.isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: theme.primary, size: 16),
                const SizedBox(width: 8),
                Text(
                  DateFormat('yyyy-MM-dd').format(date),
                  style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }



  Future<void> _handlePrintCategoryWise() async {
    final categories = await DatabaseHelper.instance.getCategories();
    final result = await _showReportOptionsDialog<Map<String, dynamic>>(
      title: 'Category Wise Report',
      options: [
        {'id': null, 'name': 'All Categories'},
        ...categories,
      ],
      labelMapping: (c) => c['name'],
      icon: Icons.category_rounded,
    );

    if (result == null) return;

    final selectedCategory = result['selection'] as Map?;
    final start = (result['startDate'] as DateTime).toIso8601String().split('T')[0] + 'T00:00:00';
    final end = (result['endDate'] as DateTime).toIso8601String().split('T')[0] + 'T23:59:59';

    setState(() => _generatingReportTitle = 'Category Wise');
    try {
      final salesSummary = await DatabaseHelper.instance.getCategorySalesSummary(
        categoryId: selectedCategory?['id'],
        startTime: start,
        endTime: end,
      );
      final returnsSummary = await DatabaseHelper.instance.getCategoryReturnsSummary(
        categoryId: selectedCategory?['id'],
        startTime: start,
        endTime: end,
      );
      
      final title = selectedCategory?['id'] == null ? 'Overall Category Sales Report' : 'Category Report: ${selectedCategory?['name']}';
      
      final pdf = await _generateSummaryPdf(title, [
        {
          'title': 'SALES SUMMARY',
          'headers': ['Category', 'Qty', 'Gross', 'Discount', 'Net Amount'], 
          'keys': ['category_name', 'total_qty', 'total_amount', 'total_discount', 'total_net'],
          'data': salesSummary,
        },
        {
          'title': 'RETURNS SUMMARY',
          'headers': ['Category', 'Qty', 'Gross', 'Discount', 'Net Amount'], 
          'keys': ['category_name', 'total_qty', 'total_amount', 'total_discount', 'total_net'],
          'data': returnsSummary,
        }
      ]);
      _showPreview(pdf, title);
    } finally {
      setState(() => _generatingReportTitle = null);
    }
  }

  Future<void> _handlePrintTopSelling() async {
    final result = await _showReportOptionsDialog<String>(
      title: 'Top Selling Products',
      labelMapping: (v) => v,
    );

    if (result == null) return;

    final start = (result['startDate'] as DateTime).toIso8601String().split('T')[0] + 'T00:00:00';
    final end = (result['endDate'] as DateTime).toIso8601String().split('T')[0] + 'T23:59:59';

    setState(() => _generatingReportTitle = 'Top Selling');
    try {
      final data = await DatabaseHelper.instance.getTopSellingItems(
        startTime: start,
        endTime: end,
      );
      final title = 'Top Selling Items ';
      final pdf = await _generateSummaryPdf(title, [
        {
          'title': 'TOP SELLING PRODUCTS',
          'headers': ['Product Name', 'Quantity Sold', 'Total Revenue'],
          'keys': ['product_name', 'total_qty', 'total_amount'],
          'data': data,
        }
      ]);
      _showPreview(pdf, title);
    } finally {
      setState(() => _generatingReportTitle = null);
    }
  }
  Future<void> _handlePrintGrandSummary() async {
    final categories = await DatabaseHelper.instance.getCategories();
    final employees = await DatabaseHelper.instance.getEmployees();
    
    final result = await _showUnifiedReportDialog(
      categories: categories,
      employees: employees,
    );

    if (result == null) return;

    final start = (result['startDate'] as DateTime).toIso8601String().split('T')[0] + 'T00:00:00';
    final end = (result['endDate'] as DateTime).toIso8601String().split('T')[0] + 'T23:59:59';

    setState(() => _generatingReportTitle = 'Grand Summary');
    try {
      final categorySales = await DatabaseHelper.instance.getCategorySalesSummary(startTime: start, endTime: end);
      final categoryReturns = await DatabaseHelper.instance.getCategoryReturnsSummary(startTime: start, endTime: end);
      final employeeSales = await DatabaseHelper.instance.getEmployeeSalesSummary(startTime: start, endTime: end);
      final paymentSummary = await DatabaseHelper.instance.getPaymentMethodSummary(startTime: start, endTime: end);
      final expenses = await DatabaseHelper.instance.getExpenses(startTime: start, endTime: end);

      final title = 'Grand Summary Report';
      final subtitle = 'Period: ${DateFormat('dd MMM yyyy').format(result['startDate'])} to ${DateFormat('dd MMM yyyy').format(result['endDate'])}';

      final pdf = await _generateSummaryPdf(title, [
        {
          'title': 'PAYMENT METHODS BREAKDOWN',
          'headers': ['Method', 'Txn Count', 'Total Amount'],
          'keys': ['payment_method', 'total_count', 'total_amount'],
          'data': paymentSummary,
        },
        {
          'title': 'SALES BY CATEGORY',
          'headers': ['Category', 'Qty Sold', 'Gross', 'Discount', 'Net Sales'],
          'keys': ['category_name', 'total_qty', 'total_amount', 'total_discount', 'total_net'],
          'data': categorySales,
        },
        if (categoryReturns.isNotEmpty) {
          'title': 'RETURNS BY CATEGORY',
          'headers': ['Category', 'Qty Returned', 'Refund Amount'],
          'keys': ['category_name', 'total_qty', 'total_net'],
          'data': categoryReturns,
        },
        {
          'title': 'STAFF PERFORMANCE SUMMARY',
          'headers': ['Employee', 'Sales Count', 'Net Amount Sold'],
          'keys': ['employee_name', 'total_sales_count', 'total_amount'],
          'data': employeeSales,
        },
        if (expenses.isNotEmpty) {
          'title': 'EXPENSES SUMMARY',
          'headers': ['Expense Head', 'Description', 'Amount', 'Date'],
          'keys': ['expense_head_name', 'description', 'amount', 'date'],
          'data': expenses.map((e) => {
            ...e,
            'date': e['date']?.toString().split('T')[0] ?? '',
          }).toList(),
        },
      ], subtitle: subtitle);

      _showPreview(pdf, title);
    } finally {
      setState(() => _generatingReportTitle = null);
    }
  }

  Future<void> _handlePrintGeneralSales() async {
    final categories = await DatabaseHelper.instance.getCategories();
    final employees = await DatabaseHelper.instance.getEmployees();

    final result = await _showUnifiedReportDialog(
      categories: categories,
      employees: employees,
    );

    if (result == null) return;

    final selectedCategory = result['category'] as Map?;
    final selectedEmployee = result['employee'] as Map?;
    final start = (result['startDate'] as DateTime).toIso8601String().split('T')[0] + 'T00:00:00';
    final end = (result['endDate'] as DateTime).toIso8601String().split('T')[0] + 'T23:59:59';

    setState(() => _generatingReportTitle = 'Sales Report');
    try {
      final items = await DatabaseHelper.instance.getDetailedSaleItems(
        userId: selectedEmployee?['id'],
        categoryId: selectedCategory?['id'],
        startTime: start,
        endTime: end,
      );
      final paymentSummary = await DatabaseHelper.instance.getPaymentMethodSummary(
        userId: selectedEmployee?['id'],
        startTime: start,
        endTime: end,
      );
      final returns = await DatabaseHelper.instance.getDetailedReturnItems(
        startTime: start,
        endTime: end,
      );
      
      String filterInfo = 'Period: ${start.split('T')[0]} to ${end.split('T')[0]}';
      if (selectedCategory != null && selectedCategory['id'] != null) {
        filterInfo += ' | Category: ${selectedCategory['name']}';
      }
      if (selectedEmployee != null && selectedEmployee['id'] != null) {
        filterInfo += ' | Employee: ${selectedEmployee['name']}';
      }

      final title = 'Sales Report';
      final pdf = await _generateSalesPdf(items, title, subtitle: filterInfo, returnItems: returns, paymentMethodSummary: paymentSummary);
      _showPreview(pdf, title);
    } finally {
      setState(() => _generatingReportTitle = null);
    }
  }


  Future<void> _handlePrintEmployeeWise() async {
    final employees = await DatabaseHelper.instance.getEmployees(); // Using getEmployees from EmployeesCrud
    final result = await _showReportOptionsDialog<Map<String, dynamic>>(
      title: 'Employee Performance',
      options: [
        {'id': null, 'name': 'All Employees'},
        ...employees,
      ],
      labelMapping: (e) => e['name'],
      icon: Icons.person_rounded,
    );

    if (result == null) return;

    final selectedEmployee = result['selection'] as Map?;
    final start = (result['startDate'] as DateTime).toIso8601String().split('T')[0] + 'T00:00:00';
    final end = (result['endDate'] as DateTime).toIso8601String().split('T')[0] + 'T23:59:59';

    setState(() => _generatingReportTitle = 'Employee Wise');
    try {
      final salesSummary = await DatabaseHelper.instance.getEmployeeSalesSummary(
        userId: selectedEmployee?['id'],
        startTime: start,
        endTime: end,
      );
      final returnsSummary = await DatabaseHelper.instance.getEmployeeReturnsSummary(
        userId: selectedEmployee?['id'],
        startTime: start,
        endTime: end,
      );
      
      final title = selectedEmployee?['id'] == null ? 'Employee Performance Report' : 'Employee Report: ${selectedEmployee?['name']}';
      
      final pdf = await _generateSummaryPdf(title, [
        {
          'title': 'SALES SUMMARY',
          'headers': ['Employee', 'Count', 'Gross', 'Discount', 'Net Amount'], 
          'keys': ['employee_name', 'total_sales_count', 'total_gross', 'total_discount', 'total_amount'],
          'data': salesSummary,
        },
        {
          'title': 'RETURNS SUMMARY',
          'headers': ['Employee', 'Returns Count', 'Refund Amount'], 
          'keys': ['employee_name', 'total_returns_count', 'total_amount'],
          'data': returnsSummary,
        }
      ]);
      _showPreview(pdf, title);
    } finally {
      setState(() => _generatingReportTitle = null);
    }
  }

  Future<void> _handlePrintProductWise() async {
    final result = await _showReportOptionsDialog<String>(
      title: 'Detailed Product Report',
      labelMapping: (v) => v,
    );

    if (result == null) return;

    final start = (result['startDate'] as DateTime).toIso8601String().split('T')[0] + 'T00:00:00';
    final end = (result['endDate'] as DateTime).toIso8601String().split('T')[0] + 'T23:59:59';

    setState(() => _generatingReportTitle = 'Product Wise');
    try {
      final items = await DatabaseHelper.instance.getDetailedSaleItems(
        startTime: start,
        endTime: end,
      );
      final returns = await DatabaseHelper.instance.getDetailedReturnItems(
        startTime: start,
        endTime: end,
      );
      final title = 'Detailed Sales & Returns Report';
      final pdf = await _generateSalesPdf(items, title, returnItems: returns);
      _showPreview(pdf, title);
    } finally {
      setState(() => _generatingReportTitle = null);
    }
  }

  Future<void> _handlePrintStockReport({bool onlyLow = false}) async {
    setState(() => _generatingReportTitle = onlyLow ? 'Low Stock Alert' : 'Current Stock');
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
      setState(() => _generatingReportTitle = null);
    }
  }

  Future<void> _handlePrintExpenseReport() async {
    setState(() => _generatingReportTitle = 'Expense Summary');
    try {
      final expenses = await DatabaseHelper.instance.getExpenses();
      final title = 'Operational Expense Report';
      final pdf = await _generateExpensePdf(expenses, title);
      _showPreview(pdf, title);
    } finally {
      setState(() => _generatingReportTitle = null);
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
  // ignore: unused_element
  Future<pw.TextStyle> _getStyle({bool bold = false, double fontSize = 10, PdfColor? color}) async {
    await _ensureFontsLoaded();
    final font = bold ? _cachedBoldFont! : _cachedFont!;
    return pw.TextStyle(font: font, fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color);
  }

  pw.Widget _buildReportHeader(pw.Context context, String title, BusinessConfig business, pw.Font font, pw.Font boldFont, {String userId = 'ADMIN', String? subtitle}) {
    final reportDate = DateFormat('dd MMM yyyy • HH:mm a').format(DateTime.now());
    final reportNum = 'REP-${DateFormat('yyyyMMdd').format(DateTime.now())}-${business.businessId ?? "001"}';
    final primaryColor = PdfColor.fromHex('#1E3A8A'); 
    
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(business.businessName.toUpperCase(), style: pw.TextStyle(font: boldFont, fontSize: 16, color: primaryColor, letterSpacing: 1.2)),
                    if (subtitle != null) ...[
                      pw.SizedBox(height: 6),
                      pw.Text(subtitle, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Text('Report ID: $reportNum', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey500)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(title.toUpperCase(), style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColors.white, letterSpacing: 1)),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('GENERATED BY: ${userId.toUpperCase()}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text(reportDate, style: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.grey900)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(thickness: 2, color: primaryColor),
        ],
      )
    );
  }

  pw.Widget _buildReportFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(width: 0.5, color: PdfColors.grey300)),
      ),
      child: pw.Text(
        'PAGE ${context.pageNumber} OF ${context.pagesCount}',
        style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600),
      ),
    );
  }

  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<pw.Document> _generateSalesPdf(List<Map<String, dynamic>> items, String title, {List<Map<String, dynamic>>? returnItems, String? subtitle, List<Map<String, dynamic>>? paymentMethodSummary}) async {
    await _ensureFontsLoaded();
    final font = _cachedFont!;
    final boldFont = _cachedBoldFont!;
    final pdf = pw.Document();
    final business = BusinessConfig.instance;

    // ignore: unused_local_variable
    double grandTotalAmount = 0;
    // ignore: unused_local_variable
    double grandTotalDiscount = 0;
    // ignore: unused_local_variable
    double grandTotalProfit = 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(marginLeft: 20, marginRight: 20, marginTop: 20, marginBottom: 20),
        header: (context) => _buildReportHeader(context, title, business, font, boldFont, subtitle: subtitle),
        footer: (context) => _buildReportFooter(context, font),
        build: (context) {
          double totalSalesGross = 0;
          double totalSalesDiscount = 0;
          double totalSalesNet = 0;
          double totalSalesProfit = 0;
          double totalSalesQty = 0;

          // Process Sales Data
          final tableData = List<Map<String, dynamic>>.from(items).asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final qty = _parseAmount(item['quantity']);
            final price = _parseAmount(item['price']);
            double subtotal = _parseAmount(item['subtotal']);
            
            // Fallback for historical data where subtotal might be 0
            if (subtotal == 0 && qty > 0 && price > 0) {
              subtotal = qty * price;
            }
            
            final discount = _parseAmount(item['discount']);
            final net = subtotal - discount;
            final cost = _parseAmount(item['purchase_price']) * qty;
            final profit = net - cost;
            final profitPercent = net != 0 ? (profit / net * 100) : 0.0;

            totalSalesQty += qty;
            totalSalesGross += subtotal;
            totalSalesDiscount += discount;
            totalSalesNet += net;
            totalSalesProfit += profit;

            return [
              (index + 1).toString(),
              item['product_name'] ?? 'Unknown',
              qty.toString(),
              price.toStringAsFixed(2),
              subtotal.toStringAsFixed(2),
              discount.toStringAsFixed(2),
              net.toStringAsFixed(2),
              '${profitPercent.toStringAsFixed(1)}%',
            ];
          }).toList();

          tableData.add([
            '',
            'TOTAL SALES',
            totalSalesQty.toString(),
            '',
            totalSalesGross.toStringAsFixed(2),
            totalSalesDiscount.toStringAsFixed(2),
            totalSalesNet.toStringAsFixed(2),
            '',
          ]);

          // Process Return Data
          double retQty = 0;
          double retGross = 0;
          double retDisc = 0;
          double retNet = 0;
          double totalReturnsProfit = 0;
          List<List<dynamic>> returnTableData = [];

          if (returnItems != null && returnItems.isNotEmpty) {
            returnTableData = List<Map<String, dynamic>>.from(returnItems).asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final qty = _parseAmount(item['quantity']);
              final price = _parseAmount(item['price']);
              double gross = _parseAmount(item['subtotal']);
              
              // Fallback for historical data
              if (gross == 0 && qty > 0 && price > 0) {
                gross = qty * price;
              }
              
              final disc = _parseAmount(item['discount']);
              final net = gross - disc;
              final cost = _parseAmount(item['purchase_price']) * qty;
              final profit = net - cost;

              retQty += qty;
              retGross += gross;
              retDisc += disc;
              retNet += net;
              totalReturnsProfit += profit;

              return [
                (index + 1).toString(),
                item['product_name'] ?? 'Unknown',
                qty.toString(),
                price.toStringAsFixed(2),
                gross.toStringAsFixed(2),
                disc.toStringAsFixed(2),
                net.toStringAsFixed(2),
                item['created_at']?.split('T')[0] ?? '',
              ];
            }).toList();

            returnTableData.add([
              '',
              'TOTAL RETURNS',
              retQty.toString(),
              '',
              retGross.toStringAsFixed(2),
              retDisc.toStringAsFixed(2),
              retNet.toStringAsFixed(2),
              '',
            ]);
          }

          final List<pw.Widget> widgets = [];
          
          // 1. Sales Details
          widgets.add(pw.Text('SALES DETAILS', style: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold, fontSize: 12)));
          widgets.add(pw.SizedBox(height: 5));
          widgets.add(pw.TableHelper.fromTextArray(
            headers: ['S#', 'Product Name', 'QTY', 'Price', 'Total', 'Discount', 'Amount', 'Profit %'],
            data: tableData,
            border: pw.TableBorder.all(width: 1, color: PdfColor.fromHex('#E2E8F0')),
            headerStyle: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
            cellStyle: pw.TextStyle(font: font, fontSize: 8, color: PdfColor.fromHex('#334155')),
            headerAlignment: pw.Alignment.centerLeft,
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignments: {
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
              7: pw.Alignment.center,
            },
            cellAlignments: {
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
              7: pw.Alignment.center,
            },
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3A8A')),
          ));

          // 2. Returns Details (Move before summary)
          if (returnTableData.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 20));
            widgets.add(pw.Text('RETURNS DETAILS', style: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold, fontSize: 12)));
            widgets.add(pw.SizedBox(height: 5));
            widgets.add(pw.TableHelper.fromTextArray(
              headers: ['S#', 'Product Name', 'QTY', 'Price', 'Gross', 'Discount', 'Net Refund', 'Date'],
              data: returnTableData,
              border: pw.TableBorder.all(width: 1, color: PdfColor.fromHex('#E2E8F0')),
              headerStyle: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              cellStyle: pw.TextStyle(font: font, fontSize: 8, color: PdfColor.fromHex('#334155')),
              headerAlignment: pw.Alignment.centerLeft,
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignments: {
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
                6: pw.Alignment.center,
              },
              cellAlignments: {
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
                6: pw.Alignment.center,
              },
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3A8A')),
            ));
          }

          // 3. Final Summary Section (At the end)
          widgets.add(pw.SizedBox(height: 20));

          // Build payment method amounts
          double cashAmount = 0;
          double creditAmount = 0;
          double mobileAmount = 0;
          double cardAmount = 0;

          if (paymentMethodSummary != null) {
            for (var row in paymentMethodSummary) {
              final method = (row['payment_method']?.toString() ?? '').toLowerCase();
              final amount = (row['total_amount'] as num? ?? 0).toDouble();
              if (method == 'cash') {
                cashAmount = amount;
              } else if (method == 'credit') {
                creditAmount = amount;
              } else if (method.contains('mobile')) {
                mobileAmount = amount;
              } else if (method.contains('card')) {
                cardAmount = amount;
              }
            }
          }

          pw.Widget summaryRow(String label, String value, {bool bold = false, PdfColor? color}) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(label, style: pw.TextStyle(font: bold ? boldFont : font, fontSize: bold ? 11 : 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
                  pw.Text(value, style: pw.TextStyle(font: bold ? boldFont : font, fontSize: bold ? 11 : 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
                ],
              ),
            );
          }

          final finalNetAmount = totalSalesNet - retNet;
          final finalProfit = totalSalesProfit - totalReturnsProfit; // Simple profit - refund subtraction
          
          final summaryContent = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text('FINANCIAL SUMMARY', style: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColor.fromHex('#1E3A8A'))),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), thickness: 1),
              pw.SizedBox(height: 12),
              
              summaryRow('Total Sales (Gross)', '${business.currency} ${totalSalesGross.toStringAsFixed(2)}'),
              summaryRow('Total Sales Discount', '${business.currency} ${totalSalesDiscount.toStringAsFixed(2)}'),
              summaryRow('Net Sales Amount', '${business.currency} ${totalSalesNet.toStringAsFixed(2)}', bold: true),
              
              if (retNet > 0) ...[
                pw.SizedBox(height: 4),
                summaryRow('Total Returns (Net)', '${business.currency} ${retNet.toStringAsFixed(2)}', color: PdfColors.red700),
                pw.SizedBox(height: 4),
                summaryRow('GRAND TOTAL (NET)', '${business.currency} ${finalNetAmount.toStringAsFixed(2)}', bold: true, color: PdfColor.fromHex('#1E3A8A')),
              ],

              pw.SizedBox(height: 10),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, color: PdfColor.fromHex('#94A3B8'), thickness: 0.5),
              pw.SizedBox(height: 10),
              
              summaryRow('Cash Received', '${business.currency} ${cashAmount.toStringAsFixed(2)}'),
              summaryRow('Credit Amount', '${business.currency} ${creditAmount.toStringAsFixed(2)}'),
              summaryRow('Mobile Transfer', '${business.currency} ${mobileAmount.toStringAsFixed(2)}'),
              summaryRow('Card Payments', '${business.currency} ${cardAmount.toStringAsFixed(2)}'),
              
              pw.SizedBox(height: 10),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, color: PdfColor.fromHex('#94A3B8'), thickness: 0.5),
              pw.SizedBox(height: 10),
              
              summaryRow('Final Business Profit', '${business.currency} ${finalProfit.toStringAsFixed(2)}', bold: true, color: PdfColors.green700),
            ]
          );

          widgets.add(pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFC'),
              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: summaryContent,
          ));

          return widgets;
        },
      ),
    );
    return pdf;
  }

  Future<pw.Document> _generateSummaryPdf(String title, List<Map<String, dynamic>> sections, {String? subtitle}) async {
    await _ensureFontsLoaded();
    final font = _cachedFont!;
    final boldFont = _cachedBoldFont!;
    final pdf = pw.Document();
    final business = BusinessConfig.instance;

    final currencyKeys = ['total_amount', 'total_discount', 'total_net', 'total_gross', 'total_profit'];
    final numericKeys = ['total_qty', 'total_sales_count', 'total_returns_count', ...currencyKeys];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildReportHeader(context, title, business, font, boldFont, subtitle: subtitle),
        footer: (context) => _buildReportFooter(context, font),
        build: (context) => sections.expand((section) {
          final headers = section['headers'] as List<String>;
          final keys = section['keys'] as List<String>;
          final data = section['data'] as List<Map<String, dynamic>>;
          final sectionTitle = section['title'] as String;

          final headerAlignments = <int, pw.Alignment>{};
          final cellAlignments = <int, pw.Alignment>{};

          for (int i = 0; i < keys.length; i++) {
            if (numericKeys.contains(keys[i])) {
              headerAlignments[i] = pw.Alignment.centerRight;
              cellAlignments[i] = pw.Alignment.centerRight;
            } else {
              headerAlignments[i] = pw.Alignment.centerLeft;
              cellAlignments[i] = pw.Alignment.centerLeft;
            }
          }

          return [
            pw.SizedBox(height: 15),
            pw.Text(sectionTitle, style: pw.TextStyle(font: boldFont, fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data.isEmpty 
                ? [List.filled(headers.length, 'No Data')]
                : (() {
                    final rows = data.map((row) {
                      return keys.map((key) {
                        var value = row[key];
                        if (currencyKeys.contains(key)) {
                          final numVal = _parseAmount(value);
                          return '${business.currency} ${numVal.toStringAsFixed(2)}';
                        }
                        return value?.toString() ?? '0';
                      }).toList();
                    }).toList();

                    // Calculate Summary Totals
                    final totals = List.filled(headers.length, '');
                    totals[0] = 'TOTAL';
                    for (int i = 0; i < keys.length; i++) {
                      final key = keys[i];
                      if (numericKeys.contains(key)) {
                        double sum = 0;
                        for (var row in data) {
                          sum += _parseAmount(row[key]);
                        }
                        if (currencyKeys.contains(key)) {
                          totals[i] = '${business.currency} ${sum.toStringAsFixed(2)}';
                        } else {
                          totals[i] = (sum == sum.toInt()) ? sum.toInt().toString() : sum.toStringAsFixed(2);
                        }
                      }
                    }
                    rows.add(totals);
                    return rows;
                  })(),
              border: pw.TableBorder.all(width: 1, color: PdfColor.fromHex('#E2E8F0')),
              headerStyle: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
              cellStyle: pw.TextStyle(font: font, fontSize: 9, color: PdfColor.fromHex('#334155')),
              headerAlignment: pw.Alignment.centerLeft,
              headerAlignments: headerAlignments,
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: cellAlignments,
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3A8A')),
            ),
          ];
        }).toList(),
      ),
    );
    return pdf;
  }

  Future<pw.Document> _generateStockPdf(List<Map<String, dynamic>> products, String title) async {
    await _ensureFontsLoaded();
    final font = _cachedFont!;
    final boldFont = _cachedBoldFont!;
    final pdf = pw.Document();
    final business = BusinessConfig.instance;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildReportHeader(context, title, business, font, boldFont),
        footer: (context) => _buildReportFooter(context, font),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Product Name', 'Category', 'Current Stock', 'Stock Limit'],
            data: (() {
              final rows = products.map((p) => [
                p['name'],
                p['category_name'] ?? 'General',
                p['total_stock'].toString(),
                p['stock_limit'].toString(),
              ]).toList();
              
              double totalQty = 0;
              for (var p in products) {
                totalQty += (p['total_stock'] as num).toDouble();
              }
              rows.add(['TOTAL', '', totalQty.toString(), '']);
              return rows;
            })(),
            border: pw.TableBorder.all(width: 1, color: PdfColor.fromHex('#E2E8F0')),
            headerAlignment: pw.Alignment.centerLeft,
            headerAlignments: {
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            headerStyle: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            cellStyle: pw.TextStyle(font: font, fontSize: 9, color: PdfColor.fromHex('#334155')),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3A8A')),
          ),
          pw.SizedBox(height: 5),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 1),
                bottom: pw.BorderSide(width: 2, style: pw.BorderStyle.solid),
              )
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('End of Report', style: pw.TextStyle(font: boldFont, fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            )
          ),
        ],
      ),
    );
    return pdf;
  }

  Future<pw.Document> _generateExpensePdf(List<Map<String, dynamic>> expenses, String title) async {
    await _ensureFontsLoaded();
    final font = _cachedFont!;
    final boldFont = _cachedBoldFont!;
    final pdf = pw.Document();
    final business = BusinessConfig.instance;

    double total = expenses.fold(0.0, (sum, e) => sum + (e['amount'] as num? ?? 0));
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildReportHeader(context, title, business, font, boldFont),
        footer: (context) => _buildReportFooter(context, font),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Category', 'Description', 'Amount'],
            data: expenses.map((e) {
              String dateStr = '-';
              try {
                if (e['date'] != null && e['date'].toString().isNotEmpty) {
                  dateStr = DateFormat('yyyy-MM-dd').format(DateTime.parse(e['date'].toString()));
                }
              } catch (_) {
                dateStr = e['date']?.toString() ?? '-';
              }
              final amount = _parseAmount(e['amount']);
              return [
                dateStr,
                e['expense_head_name'] ?? 'General',
                e['description'] ?? '',
                '${business.currency} ${amount.toStringAsFixed(2)}',
              ];
            }).toList(),
            border: pw.TableBorder.all(width: 1, color: PdfColor.fromHex('#E2E8F0')),
            headerAlignment: pw.Alignment.centerLeft,
            headerAlignments: {
              3: pw.Alignment.centerRight,
            },
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              3: pw.Alignment.centerRight,
            },
            headerStyle: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            cellStyle: pw.TextStyle(font: font, fontSize: 9, color: PdfColor.fromHex('#334155')),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3A8A')),
          ),
          pw.SizedBox(height: 5),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 1),
                bottom: pw.BorderSide(width: 2, style: pw.BorderStyle.solid),
              )
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Grand Total:', style: pw.TextStyle(font: boldFont, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('${business.currency} ${total.toStringAsFixed(2)}', style: pw.TextStyle(font: boldFont, fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            )
          ),
        ],
      ),
    );
    return pdf;
  }
}
