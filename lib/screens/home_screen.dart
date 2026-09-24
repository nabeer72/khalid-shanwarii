import 'dart:convert';
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
import 'package:mobile_app/services/sync_service.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final theme = ThemeProvider.instance;
  final SyncService _syncService = SyncService();
  String? _lastSync;
  Timer? _autoSyncTimer;

  int _productCount = 0;
  int _customerCount = 0;
  int _dealCount = 0;
  int _saleCount = 0;
  String _topSellingName = '';
  int _topSellingQty = 0;
  double _todaySalesAmount = 0.0;
  double _todayRecoveryAmount = 0.0;
  double _todayReturnsAmount = 0.0;
  int _heldCount = 0;

  List<Map<String, dynamic>> _branches = [];
  String? _currentBranchName;
  String _storeAddress = '';

  StreamSubscription<void>? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _loadLastSync();
    _loadStats();
    _loadBranches();

    // Listen for real-time data changes across the app (including after background sync)
    _dataSubscription = DatabaseHelper.dataStream.listen((_) {
      if (mounted) {
        _loadStats();
        _loadBranches();
      }
    });

    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSync(silent: true);
        _checkFirstTimeWelcome();
      });
      // Auto-sync every 5 minutes so web-dashboard changes reflect without logout
      _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        if (mounted && !_syncService.isSyncing) {
          _syncService.triggerDebouncedSync(delayMs: 0);
        }
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
              'Use the Sync button regularly to keep data updated.',
            ],
            () {});
      }
    }
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadLastSync() async {
    if (kIsWeb) return;
    final lastSync = await _syncService.getLastSyncTime();
    if (mounted) setState(() => _lastSync = lastSync);
  }

  /// Reloads subscription data from the local `businesses` table into
  /// [BusinessConfig] and triggers a rebuild so the subscription banner
  /// updates automatically once the server approves a renewal (picked up
  /// by the next sync without requiring a logout/login).
  Future<void> _refreshSubscriptionStatus() async {
    // Subscription concept removed
  }

  String? _branchDisplayName(Map<String, dynamic> branch) {
    final title = branch['branch_title']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;
    final name = branch['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return null;
  }

  String? _branchAddress(Map<String, dynamic> branch) {
    final addr = branch['branch_address']?.toString().trim();
    if (addr != null && addr.isNotEmpty) return addr;
    return null;
  }

  Future<String> _resolveStoreAddress({Map<String, dynamic>? branch}) async {
    final branchAddr = branch != null ? _branchAddress(branch) : null;
    if (branchAddr != null) return branchAddr;

    var address = BusinessConfig.instance.businessAddress.trim();
    if (address.isEmpty) {
      final fromDb =
          await DatabaseHelper.instance.getSetting('business_address');
      address = fromDb?.trim() ?? '';
      if (address.isNotEmpty) {
        BusinessConfig.instance.businessAddress = address;
      }
    }
    return address;
  }

  Future<String?> _fetchBranchNameById(
      dynamic businessId, dynamic branchId) async {
    if (businessId == null || branchId == null) return null;
    final rawDb = await DatabaseHelper.instance.database;
    final rows = await rawDb.query(
      'branches',
      where: 'business_id = ? AND id = ? AND status = 1',
      whereArgs: [businessId, branchId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _branchDisplayName(rows.first);
  }

  Future<void> _loadBranches() async {
    if (kIsWeb) return;
    final bid = BusinessConfig.instance.businessId;
    if (bid == null) return;
    try {
      if (mounted) {
        setState(() {
          _branches = [];
          _currentBranchName = 'Main Branch';
          _storeAddress = 'Main Store';
        });
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ [HOME] Failed to load branches: $e');
    }
  }

  Future<void> _switchBranch(Map<String, dynamic> branch) async {
    // Branches removed
  }

  Widget _buildBranchHeaderIcon() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
        border: Border.all(color: theme.divider, width: 1.0),
      ),
      child: Icon(Icons.store_rounded, color: theme.highlight, size: 24),
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
      String topName = '';
      int topQty = 0;
      if (topItems.isNotEmpty) {
        topName = topItems.first['product_name']?.toString().trim() ?? '';
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

      // 4. Optimized Held Orders Count
      final heldCountRes = await rawDb.rawQuery(
        'SELECT COUNT(*) as total FROM held_orders WHERE 1=1$bFilter$brFilter',
        queryArgs,
      );
      final heldCount = (heldCountRes.isNotEmpty
                  ? heldCountRes.first.values.first as num?
                  : 0)
              ?.toInt() ??
          0;

      // 5. Optimized Deals Count
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
          _heldCount = heldCount;
          _topSellingName = topName;
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

  Future<void> _performSync({bool silent = false}) async {
    if (kIsWeb) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sync only available on native app'),
              backgroundColor: ThemeProvider.warning),
        );
      }
      return;
    }

    try {
      final result = await _syncService.syncAll();
      if (mounted) {
        await _loadLastSync();
        await _loadStats();
        await _refreshSubscriptionStatus(); // [FIX] Reflect renewed subscription without re-login
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sync complete!'),
              backgroundColor: ThemeProvider.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Sync error: $e'),
              backgroundColor: ThemeProvider.error),
        );
      }
    } finally {
      if (mounted) setState(() {}); // Refresh last-sync icon color after sync
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    // ignore: unused_local_variable
    final heldCount = _heldCount;

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
                        ListenableBuilder(
                          listenable: _syncService.isSyncingNotifier,
                          builder: (context, _) {
                            if (_syncService.isSyncing) {
                              return Container(
                                padding: const EdgeInsets.all(8),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.highlight,
                                  ),
                                ),
                              );
                            }
                            return IconButton(
                              icon: Icon(
                                Icons.sync_rounded,
                                color: _lastSync != null
                                    ? ThemeProvider.success
                                    : theme.iconColor,
                                size: 22,
                              ),
                              onPressed: _performSync,
                            );
                          },
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

                    // Hero - New Sale (Glass Style)
                    GestureDetector(
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
                        padding: EdgeInsets.all(isTablet ? 24 : 20),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius:
                              BorderRadius.circular(ThemeProvider.radiusCard),
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
                              child: Icon(Icons.point_of_sale,
                                  color: theme.highlight,
                                  size: isTablet ? 34 : 26),
                            ),
                            Text(
                              'Launch Register',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: isTablet ? 26 : 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Start a new transaction',
                                style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _QuickStat(
                                      icon: Icons.receipt,
                                      value: '$_saleCount',
                                      label: 'SALES'),
                                  const SizedBox(width: 16),
                                  _QuickStat(
                                    icon: Icons.payments_rounded,
                                    value:
                                        '${BusinessConfig.instance.currencyDisplay} ${_todayRecoveryAmount.toStringAsFixed(0)}',
                                    label: 'RECOVERY',
                                  ),
                                  const SizedBox(width: 16),
                                  _QuickStat(
                                    icon: Icons.assignment_return_rounded,
                                    value:
                                        '${BusinessConfig.instance.currencyDisplay} ${_todayReturnsAmount.toStringAsFixed(0)}',
                                    label: 'REFUND',
                                  ),
                                  const SizedBox(width: 16),
                                  _QuickStat(
                                    icon: BusinessConfig.instance.currencyIcon,
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
    final theme = ThemeProvider.instance;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: theme.iconColor, size: 14),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1,
                style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(18),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    maxLines: 1,
                    style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label.toUpperCase(),
                    maxLines: 1,
                    style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
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
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                label,
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
}
