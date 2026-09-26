import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:mobile_app/screens/pos_screen.dart';
import 'package:mobile_app/utils/logout_helper.dart';
import 'package:mobile_app/screens/product_list_screen.dart';
import 'package:mobile_app/screens/customer_list_screen.dart';
import 'package:mobile_app/screens/sales_history_screen.dart';
import 'package:mobile_app/screens/deals_list_screen.dart';
import 'package:mobile_app/screens/stock_report_screen.dart'; // Import Stock Report
import 'package:mobile_app/screens/support_screen.dart'; // Import Support Screen
import 'package:mobile_app/screens/reports_screen.dart';
import 'package:mobile_app/screens/reports_printing_screen.dart';
import 'package:mobile_app/screens/settings_screen.dart';

import 'package:mobile_app/screens/expenses_screen.dart';
import 'package:mobile_app/screens/suppliers_screen.dart';
import 'package:mobile_app/screens/purchases_screen.dart';
import 'package:mobile_app/screens/recovery_screen.dart';
import 'package:mobile_app/screens/supplier_payback_screen.dart';

import 'package:mobile_app/screens/bank_management_screen.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final theme = ThemeProvider.instance;

  int _productCount = 0;
  int _customerCount = 0;
  int _dealCount = 0;
  int _saleCount = 0;
  int _topSellingQty = 0;
  double _todaySalesAmount = 0.0;
  double _todayRecoveryAmount = 0.0;
  double _todayReturnsAmount = 0.0;

  String? _currentBranchName;
  String _storeAddress = '';

  StreamSubscription<void>? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadBranches();

    // Listen for real-time data changes across the app
    _dataSubscription = DatabaseHelper.dataStream.listen((_) {
      if (mounted) {
        _loadStats();
        _loadBranches();
      }
    });

    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkFirstTimeWelcome();
      });
    }
  }

  Future<void> _checkFirstTimeWelcome() async {
    const storage = FlutterSecureStorage();
    final userId = BusinessConfig.instance.userId;
    if (userId == null) return;

    final hasShown = await storage.read(key: 'tutorial_shown_welcome_$userId');
    if (hasShown == null) {
      if (mounted) {
        await _handleModuleTap(
            'welcome',
            'Dashboard',
            [
              'Welcome to your business dashboard!',
              'Manage all aspects of your store from this screen.',
              'Tap any card to view detailed module tutorials.',
            ],
            () {});
      }
    }
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    if (kIsWeb) return;
    final bid = BusinessConfig.instance.businessId;
    if (bid == null) return;
    try {
      if (mounted) {
        setState(() {
          _currentBranchName = BusinessConfig.instance.businessPhone.trim();
          _storeAddress = BusinessConfig.instance.businessAddress.trim();
        });
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ [HOME] Failed to load branches: $e');
    }
  }

  Widget _buildBranchHeaderIcon() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
        border: Border.all(color: theme.divider, width: 1.0),
      ),
      child: Image.asset(
        'asset/icon.png',
        width: 44,
        height: 44,
        fit: BoxFit.contain,
      ),
    );
  }

  Future<void> _loadStats() async {
    if (kIsWeb) return;
    try {
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;

      final bFilter = db.getBusinessFilter();
      final bArgs = db.getBusinessArgs();
      final brFilter = db.getBranchFilter();
      final brArgs = db.getBranchArgs();

      final queryArgs = [...bArgs, ...brArgs];

      // 1. Optimized Product Count (distinct names)
      final prodCountRes = await rawDb.rawQuery(
        'SELECT COUNT(DISTINCT name) as total FROM products WHERE status = 1$bFilter$brFilter',
        queryArgs,
      );
      final productCount = (prodCountRes.isNotEmpty
                  ? prodCountRes.first.values.first as num?
                  : 0)
              ?.toInt() ??
          0;

      // 2. Top selling item (by quantity sold)
      final topItems = await db.getTopSellingItems(limit: 1);
      int topQty = 0;
      if (topItems.isNotEmpty) {
        topQty = (topItems.first['total_qty'] as num?)?.toInt() ?? 0;
      }

      // 3. Optimized Customer Count
      final customerCountRes = await rawDb.rawQuery(
        'SELECT COUNT(*) as total FROM customers WHERE status = 1$bFilter$brFilter',
        queryArgs,
      );
      final customerCount = (customerCountRes.isNotEmpty
                  ? customerCountRes.first.values.first as num?
                  : 0)
              ?.toInt() ??
          0;

      // Deals count
      final bid = BusinessConfig.instance.businessId;
      final dealWhere = bid == null
          ? 'business_id IS NULL'
          : 'business_id = ${bid is int ? bid : int.tryParse(bid.toString()) ?? 0}';
      final dealCountRes = await rawDb.rawQuery(
        'SELECT COUNT(*) as total FROM deals WHERE status = 1 AND $dealWhere',
      );
      final dealCount = (dealCountRes.isNotEmpty
                  ? dealCountRes.first.values.first as num?
                  : 0)
              ?.toInt() ??
          0;

      if (mounted) {
        setState(() {
          _productCount = productCount;
          _customerCount = customerCount;
          _dealCount = dealCount;
          _topSellingQty = topQty;
        });
      }

      // Sales query is isolated so a failure doesn't zero out other counts
      try {
        final now = DateTime.now();
        final todayStart =
            DateTime(now.year, now.month, now.day).toIso8601String();
        final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
            .toIso8601String();

        // Retrieve only today's sales and returns
        final todaySales =
            await db.getSales(startTime: todayStart, endTime: todayEnd);

        double todayTotal = 0;
        int todaySaleCount = 0;
        double returnTotal = 0;

        for (var s in todaySales) {
          final isReturn = (s['is_return'] ?? 0) == 1;
          final amt = (s['total'] as num? ?? 0).toDouble();

          if (isReturn) {
            returnTotal += amt;
          } else {
            todayTotal += amt;
            todaySaleCount++;
          }
        }

        if (mounted) {
          setState(() {
            _saleCount = todaySaleCount;
            _todaySalesAmount = todayTotal;
            _todayReturnsAmount = returnTotal;
          });
        }
      } catch (e) {
        debugPrint('Error loading sales stats: $e');
      }

      try {
        final now = DateTime.now();
        final todayStart =
            DateTime(now.year, now.month, now.day).toIso8601String();
        final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
            .toIso8601String();

        // Query today's credit payments recovery amount
        final recoveryRes = await rawDb.rawQuery(
          'SELECT SUM(amount) as total FROM credit_payments WHERE payment_date >= ? AND payment_date <= ?$bFilter$brFilter',
          [todayStart, todayEnd, ...queryArgs],
        );
        final recoveryTotal =
            (recoveryRes.isNotEmpty && recoveryRes.first['total'] != null
                    ? recoveryRes.first['total'] as num
                    : 0.0)
                .toDouble();

        if (mounted) {
          setState(() {
            _todayRecoveryAmount = recoveryTotal;
          });
        }
      } catch (e) {
        debugPrint('Error loading recovery stats: $e');
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: theme.background,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isTablet ? 32 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with sync
                    Row(
                      children: [
                        _buildBranchHeaderIcon(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                BusinessConfig.instance.businessName,
                                style: TextStyle(
                                    fontSize: isTablet ? 20 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_currentBranchName != null &&
                                  _currentBranchName!.isNotEmpty)
                                Text(
                                  _currentBranchName!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (_storeAddress.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 1),
                                        child: Icon(
                                          Icons.location_on_outlined,
                                          size: 13,
                                          color: theme.textSecondary
                                              .withOpacity(0.85),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _storeAddress,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.textSecondary
                                                .withOpacity(0.9),
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                              theme.isDark ? Icons.light_mode : Icons.dark_mode,
                              color: theme.iconColor,
                              size: 22),
                          onPressed: () => setState(() => theme.toggleTheme()),
                        ),
                        IconButton(
                          icon: Icon(Icons.logout,
                              color: theme.iconColor, size: 22),
                          onPressed: _logout,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Hero - New Sale (Premium Gradient)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(ThemeProvider.radiusHero),
                        onTap: () async {
                          if (mounted) {
                            Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const POSScreen()))
                                .then((_) => _loadStats());
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isTablet ? 28 : 22),
                          decoration: theme.statCardDecoration(
                            ThemeProvider.gradientGold,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(
                                          ThemeProvider.radiusList),
                                      border: Border.all(
                                          color:
                                              Colors.white.withOpacity(0.22)),
                                    ),
                                    child: Icon(Icons.point_of_sale_rounded,
                                        color: Colors.white,
                                        size: isTablet ? 34 : 28),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Launch Register',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isTablet ? 26 : 22,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Start a new transaction',
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.88),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.18),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.2)),
                                    ),
                                    child: const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    _QuickStat(
                                        icon: Icons.receipt_long_rounded,
                                        value: '$_saleCount',
                                        label: 'SALES'),
                                    const SizedBox(width: 14),
                                    _QuickStat(
                                      icon: Icons.payments_rounded,
                                      value:
                                          '${BusinessConfig.instance.currencyDisplay} ${_todayRecoveryAmount.toStringAsFixed(0)}',
                                      label: 'RECOVERY',
                                    ),
                                    const SizedBox(width: 14),
                                    _QuickStat(
                                      icon: Icons.assignment_return_rounded,
                                      value:
                                          '${BusinessConfig.instance.currencyDisplay} ${_todayReturnsAmount.toStringAsFixed(0)}',
                                      label: 'REFUND',
                                    ),
                                    const SizedBox(width: 14),
                                    _QuickStat(
                                      icon:
                                          BusinessConfig.instance.currencyIcon,
                                      value:
                                          '${BusinessConfig.instance.currencyDisplay} ${_todaySalesAmount.toStringAsFixed(0)}',
                                      label: 'TODAY',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Held Orders Alert removed from here

                    const SizedBox(height: 24),

                    // Quick Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.inventory_2,
                            value: '$_productCount',
                            label: 'Products',
                            color: theme.accent,
                            onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ProductListScreen()))
                                .then((_) => _loadStats()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.people,
                            value: '$_customerCount',
                            label: 'Customers',
                            color: ThemeProvider.info,
                            onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const CustomerListScreen()))
                                .then((_) => _loadStats()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.local_offer_outlined,
                            value: '$_dealCount',
                            label: 'Deals',
                            color: const Color(0xFFF59E0B),
                            onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const DealsListScreen()))
                                .then((_) => _loadStats()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.trending_up_rounded,
                            value: _topSellingQty > 0 ? '$_topSellingQty' : '—',
                            label: 'Top Selling',
                            color: ThemeProvider.warning,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Modules Grid
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 16),
                      child: Text(
                        'QUICK ACTIONS',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isTablet ? 240 : 160,
                        mainAxisExtent: 140,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      children: [
                        // 1. Products
                        _ModuleCard(
                            icon: Icons.inventory_2_outlined,
                            label: 'Products',
                            color: const Color(0xFF3366FF),
                            onTap: () => _handleModuleTap(
                                'products',
                                'Products',
                                [
                                  'Add and manage your inventory items.',
                                  'Set product prices and cost details.',
                                  'Organize products by categories and units.',
                                  'Track low stock alerts and favorites.'
                                ],
                                () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const ProductListScreen()))
                                    .then((_) => _loadStats()))),

                        // 2. Purchases
                        _ModuleCard(
                            icon: Icons.shopping_cart_outlined,
                            label: 'Purchases',
                            color: const Color(0xFF64748B),
                            onTap: () => _handleModuleTap(
                                'purchases',
                                'Purchases',
                                [
                                  'Record new stock purchases from suppliers.',
                                  'Track purchase history and invoices.',
                                  'Manage unpaid purchase balances.',
                                  'Update inventory automatically on purchase.'
                                ],
                                () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const PurchasesScreen()))
                                    .then((_) => setState(() {})))),

                        // 3. Expenses
                        _ModuleCard(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Expenses',
                            color: const Color(0xFFEF4444),
                            onTap: () => _handleModuleTap(
                                'expenses',
                                'Expenses',
                                [
                                  'Log daily business expenses (e.g., rent, bills).',
                                  'Categorize expenses for better tracking.',
                                  'View expense history and totals.',
                                  'Analyze spending to maximize profit.'
                                ],
                                () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const ExpensesScreen()))
                                    .then((_) => setState(() {})))),

                        // 4. Recovery
                        _ModuleCard(
                            icon: Icons.payments_outlined,
                            label: 'Recovery',
                            color: const Color(0xFF0EA5E9),
                            onTap: () => _handleModuleTap(
                                'recovery',
                                'Recovery',
                                [
                                  'Track outstanding customer balances.',
                                  'Record partial or full payments received.',
                                  'View payment history for each customer.',
                                  'Settle credit sales easily.'
                                ],
                                () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const RecoveryScreen()))
                                    .then((_) => _loadStats()))),

                        // 5. Suppliers
                        _ModuleCard(
                            icon: Icons.business_outlined,
                            label: 'Suppliers',
                            color: const Color(0xFF84CC16),
                            onTap: () => _handleModuleTap(
                                'suppliers',
                                'Suppliers',
                                [
                                  'Maintain a list of your vendors and suppliers.',
                                  'Track contact details and addresses.',
                                  'Monitor total payable amounts to each supplier.',
                                  'View purchase history by supplier.'
                                ],
                                () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const SuppliersScreen()))
                                    .then((_) => setState(() {})))),

                        // 5b. Supplier Payback
                        _ModuleCard(
                            icon: Icons.payments_outlined,
                            label: 'Payback',
                            color: const Color(0xFF10B981),
                            onTap: () => _handleModuleTap(
                                'payback',
                                'Payback',
                                [
                                  'Manage payments made to your suppliers.',
                                  'Clear outstanding purchase balances.',
                                  'Track the history of supplier payments.',
                                  'Keep accurate vendor accounts.'
                                ],
                                () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const SupplierPaybackScreen()))
                                    .then((_) => _loadStats()))),

                        // 5c. Deals
                        _ModuleCard(
                            icon: Icons.local_offer_outlined,
                            label: 'Deals',
                            color: const Color(0xFFF59E0B),
                            onTap: () => _handleModuleTap(
                                'deals',
                                'Deals',
                                [
                                  'Create composite product deals.',
                                  'Offer discounted bundles.',
                                  'Manage combo items.',
                                  'Boost sales with special offers.'
                                ],
                                () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const DealsListScreen()))
                                    .then((_) => _loadStats()))),

                        // 6. Stock
                        _ModuleCard(
                            icon: Icons.analytics_outlined,
                            label: 'Stock',
                            color: const Color(0xFF8B5CF6),
                            onTap: () => _handleModuleTap(
                                'stock',
                                'Stock',
                                [
                                  'View real-time inventory levels.',
                                  'Check stock valuation and potential profit.',
                                  'Identify low-stock and out-of-stock items.',
                                  'Generate comprehensive stock reports.'
                                ],
                                () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const StockReportScreen())))),

                        // 7. Sales
                        _ModuleCard(
                            icon: Icons.receipt_long_outlined,
                            label: 'Sales',
                            color: const Color(0xFF22C55E),
                            onTap: () => _handleModuleTap('sales', 'Sales', [
                                  'View a complete history of all transactions.',
                                  'Reprint receipts for past sales.',
                                  'Process returns and refunds.',
                                  'Track daily, weekly, and monthly revenue.'
                                ], () async {
                                  final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const SalesHistoryScreen()));
                                  _loadStats();
                                  if (result != null &&
                                      result is Map &&
                                      mounted) {
                                    final Map<String, dynamic> castedResult =
                                        Map<String, dynamic>.from(result);
                                    Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => POSScreen(
                                                    returnSale: castedResult)))
                                        .then((_) => _loadStats());
                                  }
                                })),

                        // 8. Reports
                        _ModuleCard(
                            icon: Icons.bar_chart_outlined,
                            label: 'Reports',
                            color: const Color(0xFFF59E0B),
                            onTap: () => _handleModuleTap(
                                'reports',
                                'Reports',
                                [
                                  'Analyze business performance and profits.',
                                  'View sales, expense, and tax summaries.',
                                  'Track best-selling products.',
                                  'Export data for accounting purposes.'
                                ],
                                () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const ReportsScreen()))
                                    .then((_) => setState(() {})))),

                        // 8b. Print Reports
                        _ModuleCard(
                            icon: Icons.print_outlined,
                            label: 'Print Reports',
                            color: const Color(0xFF0EA5E9),
                            onTap: () => _handleModuleTap(
                                'print_reports',
                                'Print Reports',
                                [
                                  'Generate formatted reports for printing.',
                                  'Print via Bluetooth or Wi-Fi thermal printers.',
                                  'Share reports directly via PDF.',
                                  'Keep physical records of your business.'
                                ],
                                () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ReportsPrintingScreen())))),

                        // 10. Settings
                        _ModuleCard(
                            icon: Icons.settings_outlined,
                            label: 'Settings',
                            color: const Color(0xFF6366F1),
                            onTap: () => _handleModuleTap(
                                'settings',
                                'Settings',
                                [
                                  'Configure business details and currency.',
                                  'Set up printer and hardware preferences.',
                                  'Manage tax rates and application theme.',
                                  'Backup and restore your database.'
                                ],
                                () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const SettingsScreen())))),

                        // 13. Support
                        _ModuleCard(
                            icon: Icons.help_outline_rounded,
                            label: 'Support',
                            color: const Color(0xFFF59E0B),
                            onTap: () => _handleModuleTap(
                                'support',
                                'Support',
                                [
                                  'Contact technical support for help.',
                                  'View tutorials and guides.',
                                  'Report bugs or request new features.',
                                  'Check for application updates.'
                                ],
                                () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const SupportScreen())))),

                        // 14. Customers
                        _ModuleCard(
                            icon: Icons.groups_outlined,
                            label: 'Customers',
                            color: const Color(0xFF06B6D4),
                            onTap: () => _handleModuleTap(
                                'customers',
                                'Customers',
                                [
                                  'Maintain a database of your customers.',
                                  'Track individual purchase history.',
                                  'Monitor customer credit and balances.',
                                  'Reward frequent shoppers.'
                                ],
                                () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const CustomerListScreen()))
                                    .then((_) => _loadStats()))),

                        // 15. Bank
                        _ModuleCard(
                            icon: Icons.account_balance_outlined,
                            label: 'Bank',
                            color: const Color(0xFF7C3AED),
                            onTap: () => _handleModuleTap(
                                'bank',
                                'Bank',
                                [
                                  'Manage your bank accounts and transactions.',
                                  'Record deposits, withdrawals, and transfers.',
                                  'Track bank balances in real time.',
                                  'View detailed transaction history.'
                                ],
                                () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const BankManagementScreen())))),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleModuleTap(String moduleKey, String moduleName,
      List<String> tutorialLines, VoidCallback onNavigate) async {
    const storage = FlutterSecureStorage();
    final userId = BusinessConfig.instance.userId;
    final storageKey = userId != null
        ? 'tutorial_shown_${moduleKey}_$userId'
        : 'tutorial_shown_$moduleKey';
    final hasShown = await storage.read(key: storageKey);

    if (hasShown == null) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
            title: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: theme.highlight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$moduleName Guide',
                      style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: tutorialLines
                  .map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: theme.highlight, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(line,
                                    style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 13))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('GOT IT',
                    style: TextStyle(
                        color: theme.highlight, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        await storage.write(key: storageKey, value: 'true');
        onNavigate();
      }
    } else {
      onNavigate();
    }
  }

  Future<void> _logout() async {
    await LogoutHelper.handleLogout(context);
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _QuickStat(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    maxLines: 1,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3)),
              ),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  static List<Color> _gradientFor(Color color) {
    final c = color;
    final int r = c.red;
    final int g = c.green;
    final int b = c.blue;
    final darker = Color.fromRGBO(
      (r * 0.78).round().clamp(0, 255),
      (g * 0.78).round().clamp(0, 255),
      (b * 0.78).round().clamp(0, 255),
      1.0,
    );
    return [color, darker];
  }

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final gradient = _gradientFor(color);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: theme.statCardDecoration(gradient),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius:
                          BorderRadius.circular(ThemeProvider.radiusList),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.white.withOpacity(0.9), size: 20),
                ],
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    maxLines: 1,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label.toUpperCase(),
                    maxLines: 1,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: theme.elevatedCardDecoration,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                flex: 3,
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: theme.glassCircleDecoration(color: color),
                    child: Icon(icon, color: color, size: 26),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                flex: 2,
                fit: FlexFit.loose,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                flex: 1,
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: theme.badgeDecoration(color),
                    child: Text(
                      'Open',
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
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
}
