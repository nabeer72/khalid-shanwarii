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
        onTap: _isGenerating ? null : onTap,
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
                child: _isGenerating 
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
                            Text('UNIFIED REPORT'.toUpperCase(),
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
    final start = (result['startDate'] as DateTime).toIso8601String().split('T')[0] + ' 00:00:00';
    final end = (result['endDate'] as DateTime).toIso8601String().split('T')[0] + ' 23:59:59';

    setState(() => _isGenerating = true);
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
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _handlePrintTopSelling() async {
    final result = await _showReportOptionsDialog<String>(
      title: 'Top Selling Products',
      labelMapping: (v) => v,
    );

    if (result == null) return;

    final start = (result['startDate'] as DateTime).toIso8601String().split('T')[0] + ' 00:00:00';
    final end = (result['endDate'] as DateTime).toIso8601String().split('T')[0] + ' 23:59:59';

    setState(() => _isGenerating = true);
    try {
      final data = await DatabaseHelper.instance.getTopSellingItems(
        startTime: start,
        endTime: end,
      );
      final title = 'Top Selling Items Analysis';
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
      setState(() => _isGenerating = false);
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
    final start = (result['startDate'] as DateTime).toIso8601String().split('T')[0] + ' 00:00:00';
    final end = (result['endDate'] as DateTime).toIso8601String().split('T')[0] + ' 23:59:59';

    setState(() => _isGenerating = true);
    try {
      final items = await DatabaseHelper.instance.getDetailedSaleItems(
        userId: selectedEmployee?['id'],
        categoryId: selectedCategory?['id'],
        startTime: start,
        endTime: end,
      );
      
      String filterInfo = 'Period: ${start.split(' ')[0]} to ${end.split(' ')[0]}';
      if (selectedCategory != null && selectedCategory['id'] != null) {
        filterInfo += ' | Category: ${selectedCategory['name']}';
      }
      if (selectedEmployee != null && selectedEmployee['id'] != null) {
        filterInfo += ' | Employee: ${selectedEmployee['name']}';
      }

      final title = 'Unified Sales Report';
      final pdf = await _generateSalesPdf(items, title, subtitle: filterInfo);
      _showPreview(pdf, title);
    } finally {
      setState(() => _isGenerating = false);
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
    final start = (result['startDate'] as DateTime).toIso8601String().split('T')[0] + ' 00:00:00';
    final end = (result['endDate'] as DateTime).toIso8601String().split('T')[0] + ' 23:59:59';

    setState(() => _isGenerating = true);
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
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _handlePrintProductWise() async {
    final result = await _showReportOptionsDialog<String>(
      title: 'Detailed Product Report',
      labelMapping: (v) => v,
    );

    if (result == null) return;

    final start = (result['startDate'] as DateTime).toIso8601String().split('T')[0] + ' 00:00:00';
    final end = (result['endDate'] as DateTime).toIso8601String().split('T')[0] + ' 23:59:59';

    setState(() => _isGenerating = true);
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
      setState(() => _isGenerating = false);
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
  pw.Widget _buildReportHeader(pw.Context context, String title, BusinessConfig business, {String userId = 'ADMIN', String? subtitle}) {
    final reportNum = 'REP-${DateFormat('yyyyMMdd').format(DateTime.now())}-${business.businessId ?? "001"}';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text('${business.businessName} ($reportNum)', style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Date : ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('User ID : $userId', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 10),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ),
        if (subtitle != null) ...[
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(subtitle, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ),
        ],
        pw.SizedBox(height: 15),
      ]
    );
  }

  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<pw.Document> _generateSalesPdf(List<Map<String, dynamic>> items, String title, {List<Map<String, dynamic>>? returnItems, String? subtitle}) async {
    final pdf = pw.Document();
    final business = BusinessConfig.instance;

    double grandTotalAmount = 0;
    double grandTotalDiscount = 0;
    double grandTotalProfit = 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(marginLeft: 20, marginRight: 20, marginTop: 20, marginBottom: 20),
        header: (context) => _buildReportHeader(context, title, business, subtitle: subtitle),
        build: (context) {
          grandTotalAmount = 0;
          grandTotalDiscount = 0;
          grandTotalProfit = 0;

          final tableData = List<Map<String, dynamic>>.from(items).asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final qty = _parseAmount(item['quantity']);
            final price = _parseAmount(item['price']);
            final subtotal = _parseAmount(item['subtotal']);
            final discount = _parseAmount(item['discount']);
            final amount = subtotal - discount;
            final cost = _parseAmount(item['purchase_price']) * qty;
            final profit = amount - cost;
            final profitPercent = amount != 0 ? (profit / amount * 100) : 0.0;

            grandTotalAmount += amount;
            grandTotalDiscount += discount;
            grandTotalProfit += profit;

            return [
              (index + 1).toString(),
              item['product_name'] ?? 'Unknown',
              qty.toString(),
              price.toStringAsFixed(2),
              subtotal.toStringAsFixed(2),
              discount.toStringAsFixed(2),
              amount.toStringAsFixed(2),
              '${profitPercent.toStringAsFixed(1)}%',
            ];
          }).toList();

          // Calculate Total Qty and Gross
          double totalQty = 0;
          double totalGross = 0;
          for (var item in items) {
            totalQty += _parseAmount(item['quantity']);
            totalGross += _parseAmount(item['subtotal']);
          }

          // Append Grand Total Row
          tableData.add([
            '',
            'TOTAL',
            totalQty.toString(),
            '',
            totalGross.toStringAsFixed(2),
            grandTotalDiscount.toStringAsFixed(2),
            grandTotalAmount.toStringAsFixed(2),
            '',
          ]);

          final List<pw.Widget> widgets = [];
          
          widgets.add(pw.Text('SALES DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)));
          widgets.add(pw.SizedBox(height: 5));
          widgets.add(pw.TableHelper.fromTextArray(
            headers: ['S#', 'Product Name', 'QTY', 'Price', 'Total', 'Discount', 'Amount', 'Profit %'],
            data: tableData,
            border: const pw.TableBorder(
              top: pw.BorderSide(width: 1),
              bottom: pw.BorderSide(width: 1),
              horizontalInside: pw.BorderSide.none,
              verticalInside: pw.BorderSide.none,
            ),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerAlignment: pw.Alignment.centerLeft,
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignments: {
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
            },
            cellAlignments: {
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
            },
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ));

          widgets.add(pw.SizedBox(height: 10));
          widgets.add(pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total Discount: ${business.currency} ${grandTotalDiscount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text('Net Sales Amount: ${business.currency} ${grandTotalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.Text('Total Profit from Sales: ${business.currency} ${grandTotalProfit.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.green, fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ]
            )
          ));

          if (returnItems != null && returnItems.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 20));
            widgets.add(pw.Text('RETURNS DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)));
            widgets.add(pw.SizedBox(height: 5));
            
            double retQty = 0;
            double retGross = 0;
            double retDisc = 0;
            double retNet = 0;

            final returnData = List<Map<String, dynamic>>.from(returnItems).asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final qty = _parseAmount(item['quantity']);
              final price = _parseAmount(item['price']);
              final gross = _parseAmount(item['subtotal']);
              final disc = _parseAmount(item['discount']);
              final net = gross - disc;

              retQty += qty;
              retGross += gross;
              retDisc += disc;
              retNet += net;

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

            // Append Total Row for Returns
            returnData.add([
              '',
              'TOTAL',
              retQty.toString(),
              '',
              retGross.toStringAsFixed(2),
              retDisc.toStringAsFixed(2),
              retNet.toStringAsFixed(2),
              '',
            ]);

            widgets.add(pw.TableHelper.fromTextArray(
              headers: ['S#', 'Product Name', 'QTY', 'Price', 'Gross', 'Discount', 'Net Refund', 'Date'],
              data: returnData,
              border: const pw.TableBorder(
                top: pw.BorderSide(width: 1),
                bottom: pw.BorderSide(width: 1),
                horizontalInside: pw.BorderSide.none,
                verticalInside: pw.BorderSide.none,
              ),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerAlignment: pw.Alignment.centerLeft,
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignments: {
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
              cellAlignments: {
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            ));
          }

          return widgets;
        },
      ),
    );
    return pdf;
  }

  Future<pw.Document> _generateSummaryPdf(String title, List<Map<String, dynamic>> sections) async {
    final pdf = pw.Document();
    final business = BusinessConfig.instance;

    final currencyKeys = ['total_amount', 'total_discount', 'total_net', 'total_gross', 'total_profit'];
    final numericKeys = ['total_qty', 'total_sales_count', 'total_returns_count', ...currencyKeys];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildReportHeader(context, title, business),
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
            pw.Text(sectionTitle, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
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
              border: const pw.TableBorder(
                top: pw.BorderSide(width: 1),
                bottom: pw.BorderSide(width: 1),
                horizontalInside: pw.BorderSide.none,
                verticalInside: pw.BorderSide.none,
              ),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerAlignment: pw.Alignment.centerLeft,
              headerAlignments: headerAlignments,
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: cellAlignments,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ];
        }).toList(),
      ),
    );
    return pdf;
  }

  Future<pw.Document> _generateStockPdf(List<Map<String, dynamic>> products, String title) async {
    final pdf = pw.Document();
    final business = BusinessConfig.instance;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildReportHeader(context, title, business),
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
            border: const pw.TableBorder(
              top: pw.BorderSide(width: 1),
              bottom: pw.BorderSide(width: 1),
              horizontalInside: pw.BorderSide.none,
              verticalInside: pw.BorderSide.none,
            ),
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
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
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
                pw.Text('End of Report', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            )
          ),
        ],
      ),
    );
    return pdf;
  }

  Future<pw.Document> _generateExpensePdf(List<Map<String, dynamic>> expenses, String title) async {
    final pdf = pw.Document();
    final business = BusinessConfig.instance;

    double total = expenses.fold(0.0, (sum, e) => sum + (e['amount'] as num? ?? 0));
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildReportHeader(context, title, business),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Category', 'Description', 'Amount'],
            data: expenses.map((e) => [
              DateFormat('yyyy-MM-dd').format(DateTime.parse(e['date'])),
              e['expense_head_name'] ?? 'General',
              e['description'] ?? '',
              '${business.currency} ${e['amount']}',
            ]).toList(),
            border: const pw.TableBorder(
              top: pw.BorderSide(width: 1),
              bottom: pw.BorderSide(width: 1),
              horizontalInside: pw.BorderSide.none,
              verticalInside: pw.BorderSide.none,
            ),
            headerAlignment: pw.Alignment.centerLeft,
            headerAlignments: {
              3: pw.Alignment.centerRight,
            },
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              3: pw.Alignment.centerRight,
            },
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
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
                pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('${business.currency} ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            )
          ),
        ],
      ),
    );
    return pdf;
  }
}
