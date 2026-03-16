import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_app/screens/pos_screen.dart';
import 'package:mobile_app/screens/login_screen.dart';
import 'package:mobile_app/screens/product_list_screen.dart';
import 'package:mobile_app/screens/customer_list_screen.dart';
import 'package:mobile_app/screens/sales_history_screen.dart';
import 'package:mobile_app/screens/stock_report_screen.dart'; // Import Stock Report
import 'package:mobile_app/screens/support_screen.dart'; // Import Support Screen
import 'package:mobile_app/screens/reports_screen.dart';
import 'package:mobile_app/screens/employee_list_screen.dart';
import 'package:mobile_app/screens/settings_screen.dart';
import 'package:mobile_app/screens/held_orders_screen.dart';
import 'package:mobile_app/screens/gift_cards_screen.dart';
import 'package:mobile_app/screens/loyalty_screen.dart';
import 'package:mobile_app/screens/expenses_screen.dart';
import 'package:mobile_app/screens/suppliers_screen.dart';
import 'package:mobile_app/screens/purchases_screen.dart';
import 'package:mobile_app/screens/recovery_screen.dart';
import 'package:mobile_app/screens/supplier_payback_screen.dart';
import 'package:mobile_app/screens/branch_management_screen.dart';
import 'package:mobile_app/screens/bank_management_screen.dart';
import 'package:mobile_app/screens/roles_screen.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/services/sync_service.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/models/branch.dart';
import 'package:mobile_app/widgets/shift_dialogs.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final theme = ThemeProvider.instance;
  final SyncService _syncService = SyncService();
  bool _isSyncing = false;
  String? _lastSync;
  Employee? _currentStaff;

  int _productCount = 0;
  int _customerCount = 0;
  int _saleCount = 0;
  int _favoritesCount = 0;
  double _todaySalesAmount = 0.0;
  double _todayRecoveryAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadLastSync();
    _loadStats();
    _loadCurrentStaff();
    if (!kIsWeb) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _performSync(silent: true));
    }
  }

  Future<void> _loadLastSync() async {
    if (kIsWeb) return;
    final lastSync = await _syncService.getLastSyncTime();
    if (mounted) setState(() => _lastSync = lastSync);
  }

  Future<void> _loadCurrentStaff() async {
    final sid = BusinessConfig.instance.staffId;
    if (sid != null) {
      final dbData = await DatabaseHelper.instance.getEmployees();
      final staffData = dbData.where((e) => e['id'] == sid).firstOrNull;
      if (staffData != null) {
        List<String> perms = [];
        
        // 1. Load legacy permissions if present
        if (staffData['permissions'] != null) {
          try {
            perms = List<String>.from(jsonDecode(staffData['permissions']));
          } catch (e) {}
        }

        // 2. Load RBAC permissions if role_id is present
        final roleId = staffData['role_id'];
        if (roleId != null) {
          final db = await DatabaseHelper.instance.database;
          final rolePerms = await db.rawQuery('''
            SELECT p.name 
            FROM role_permissions rp
            JOIN permissions p ON rp.permission_id = p.id
            WHERE rp.role_id = ?
          ''', [roleId]);
          
          final rbacPerms = rolePerms.map((p) => p['name'].toString()).toList();
          // Union of legacy and RBAC for safety during transition
          for (var p in rbacPerms) {
            if (!perms.contains(p)) perms.add(p);
          }
        }

        setState(() {
          _currentStaff = Employee(
            id: staffData['id'],
            name: staffData['name'],
            role: staffData['role'] ?? 'cashier',
            email: staffData['email'],
            phone: staffData['phone'],
            pin: staffData['pin'],
            isActive: staffData['status'] == 1,
            permissions: perms,
          );
        });
      }
    }
  }

  bool _hasPerm(String perm) {
    if (BusinessConfig.instance.staffId == null) return true; // Admin has all
    return _currentStaff?.permissions.contains(perm) ?? false;
  }

  Future<void> _loadStats() async {
    try {
      final db = DatabaseHelper.instance;
      final products = await db.getProducts();
      final customers = await db.getCustomers();
      final sales = await db.getSales();

      double todayTotal = 0;
      double recoveryTotal = 0;
      final now = DateTime.now();

      for (var s in sales) {
        final ts = DateTime.tryParse(s['created_at'] ?? '');
        if (ts != null &&
            ts.day == now.day &&
            ts.month == now.month &&
            ts.year == now.year) {
          todayTotal += (s['total'] as num? ?? 0).toDouble();
        }
      }

      final payments = await db.getCreditPayments();
      for (var p in payments) {
        final ts = DateTime.tryParse(p['payment_date'] ?? '');
        if (ts != null &&
            ts.day == now.day &&
            ts.month == now.month &&
            ts.year == now.year) {
          recoveryTotal += (p['amount'] as num? ?? 0).toDouble();
        }
      }

      if (mounted) {
        setState(() {
          final uniqueProductNames = products.map((p) => p['name'] as String).toSet();
          _productCount = uniqueProductNames.length;
          _customerCount = customers.length;
          _saleCount = sales.length;
          _favoritesCount = products
              .where((p) => (p['is_favorite'] ?? 0) == 1)
              .map((p) => p['name'] as String)
              .toSet()
              .length;
          _todaySalesAmount = todayTotal;
          _todayRecoveryAmount = recoveryTotal;
        });
      }
    } catch (e) {
      print('Error loading stats: $e');
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

    setState(() => _isSyncing = true);
    try {
      final result = await _syncService.syncAll();
      if (mounted) {
        await _loadLastSync();
        await _loadStats();
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.success
                  ? 'Sync complete!'
                  : 'Sync partial: ${result.pullError ?? result.pushError}'),
              backgroundColor: result.success
                  ? ThemeProvider.success
                  : ThemeProvider.warning,
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
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final heldCount = HeldOrdersStore.instance.orders.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: theme.glassBackground(
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
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.highlight
                                .withOpacity(theme.isDark ? 0.1 : 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.highlight
                                  .withOpacity(theme.isDark ? 0.25 : 0.18),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.highlight
                                    .withOpacity(theme.isDark ? 0.12 : 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.store_rounded,
                              color: theme.highlight, size: 24),
                        ),
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
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: ThemeProvider.businessColors[
                                                BusinessConfig
                                                    .instance.businessType]
                                            ?.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                      BusinessConfig.instance.businessType
                                          .toUpperCase(),
                                      style: TextStyle(
                                          color: ThemeProvider.businessColors[
                                              BusinessConfig
                                                  .instance.businessType],
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (_lastSync != null) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.cloud_done,
                                        size: 12, color: ThemeProvider.success),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (_isSyncing)
                          Container(
                            padding: const EdgeInsets.all(8),
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: theme.highlight)),
                          )
                        else
                          IconButton(
                            icon: Icon(Icons.sync_rounded,
                                color: _lastSync != null
                                    ? ThemeProvider.success
                                    : theme.iconColor,
                                size: 22),
                            onPressed: _performSync,
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
                    if (_hasPerm(AppPermissions.newSale) ||
                        _hasPerm(AppPermissions.posAccess))
                      GestureDetector(
                        onTap: () async {
                          final activeShift = await DatabaseHelper.instance.getActiveShift();
                          if (activeShift != null) {
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const POSScreen()))
                                  .then((_) => _loadStats());
                            }
                          } else {
                            if (mounted) {
                              final clockedIn = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => const ClockInDialog(),
                              );
                              if (clockedIn == true && mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const POSScreen()))
                                    .then((_) => _loadStats());
                              }
                            }
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isTablet ? 24 : 20),
                          decoration: BoxDecoration(
                            color: theme.isDark
                                ? theme.highlight.withOpacity(0.08)
                                : theme.highlight.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: theme.highlight
                                  .withOpacity(theme.isDark ? 0.25 : 0.18),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.highlight
                                    .withOpacity(theme.isDark ? 0.15 : 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(theme.isDark ? 0.25 : 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
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
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  _QuickStat(
                                      icon: Icons.receipt,
                                      value: '$_saleCount',
                                      label: 'SALES'),
                                  _QuickStat(
                                    icon: Icons.payments_rounded,
                                    value:
                                        '${BusinessConfig.instance.currency}. ${_todayRecoveryAmount.toStringAsFixed(0)}',
                                    label: 'RECOVERY',
                                  ),
                                  _QuickStat(
                                    icon: BusinessConfig.instance.currencyIcon,
                                    value:
                                        '${BusinessConfig.instance.currency}. ${_todaySalesAmount.toStringAsFixed(0)}',
                                    label: 'TODAY',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Held Orders Alert
                    if (heldCount > 0) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const HeldOrdersScreen()))
                            .then((_) => setState(() {})),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: theme.glassDecoration.copyWith(
                            color: theme.isDark
                                ? ThemeProvider.warning.withOpacity(0.1)
                                : ThemeProvider.warning.withOpacity(0.1),
                            border: Border.all(
                                color: ThemeProvider.warning.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.pause_circle,
                                  color: ThemeProvider.warning),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      '$heldCount pending order${heldCount > 1 ? 's' : ''}',
                                      style: TextStyle(
                                          color: theme.textPrimary,
                                          fontWeight: FontWeight.w700))),
                              Icon(Icons.arrow_forward_ios,
                                  color: theme.iconColor, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],

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
                            icon: Icons.star,
                            value: '$_favoritesCount',
                            label: 'Favorites',
                            color: ThemeProvider.warning,
                            onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ProductListScreen()))
                                .then((_) => _loadStats()),
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
                          fontSize: 12,
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
                        if (_hasPerm(AppPermissions.productManage) || _hasPerm(AppPermissions.products))
                          _ModuleCard(
                              icon: Icons.inventory_2_outlined,
                              label: 'Products',
                              color: const Color(0xFF3366FF),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen())).then((_) => _loadStats())),
                        
                        // 2. Purchases
                        if (_hasPerm(AppPermissions.purchasesManage))
                          _ModuleCard(
                              icon: Icons.shopping_cart_outlined,
                              label: 'Purchases',
                              color: const Color(0xFF64748B),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasesScreen())).then((_) => setState(() {}))),
                        
                        // 3. Expenses
                        if (_hasPerm(AppPermissions.expensesManage))
                          _ModuleCard(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Expenses',
                              color: const Color(0xFFEF4444),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen())).then((_) => setState(() {}))),
                        
                        // 4. Recovery
                        if (_hasPerm(AppPermissions.recovery))
                          _ModuleCard(
                              icon: Icons.payments_outlined,
                              label: 'Recovery',
                              color: const Color(0xFF0EA5E9),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecoveryScreen())).then((_) => _loadStats())),
                        
                        // 5. Suppliers
                        if (_hasPerm(AppPermissions.suppliersManage))
                          _ModuleCard(
                              icon: Icons.business_outlined,
                              label: 'Suppliers',
                              color: const Color(0xFF84CC16),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen())).then((_) => setState(() {}))),
                        
                        // 5b. Supplier Payback
                        if (_hasPerm(AppPermissions.paybackManage))
                          _ModuleCard(
                              icon: Icons.payments_outlined,
                              label: 'Payback',
                              color: const Color(0xFF10B981),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierPaybackScreen())).then((_) => _loadStats())),
                        
                        // 6. Stock
                        if (_hasPerm(AppPermissions.productManage) || _hasPerm(AppPermissions.reportsView) || _hasPerm(AppPermissions.stockView))
                          _ModuleCard(
                              icon: Icons.analytics_outlined,
                              label: 'Stock',
                              color: const Color(0xFF8B5CF6),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockReportScreen()))),

                        // 7. Roles
                        if (_hasPerm(AppPermissions.staffManage))
                          _ModuleCard(
                              icon: Icons.badge_outlined,
                              label: 'Roles',
                              color: const Color(0xFFF59E0B),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RolesScreen()))),
                        
                        // 7. Sales
                        if (_hasPerm(AppPermissions.salesHistory))
                          _ModuleCard(
                              icon: Icons.receipt_long_outlined,
                              label: 'Sales',
                              color: const Color(0xFF22C55E),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesHistoryScreen())).then((_) => _loadStats())),
                        
                        // 8. Reports
                        if (_hasPerm(AppPermissions.reportsView))
                          _ModuleCard(
                              icon: Icons.bar_chart_outlined,
                              label: 'Reports',
                              color: const Color(0xFFF59E0B),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())).then((_) => setState(() {}))),
                        
                        // 9. Staff
                        if (_hasPerm(AppPermissions.staffManage))
                          _ModuleCard(
                              icon: Icons.badge_outlined,
                              label: 'Staff',
                              color: const Color(0xFF6366F1),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeListScreen())).then((_) => setState(() {}))),
                        
                        // 10. Settings
                        if (_hasPerm(AppPermissions.settingsManage))
                          _ModuleCard(
                              icon: Icons.settings_outlined,
                              label: 'Settings',
                              color: const Color(0xFF6366F1),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                        
                        // 11. Branches
                        if (_hasPerm(AppPermissions.branchesManage))
                          _ModuleCard(
                              icon: Icons.alt_route_rounded,
                              label: 'Branches',
                              color: const Color(0xFF8B5CF6),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BranchManagementScreen()))),
                        
                        // 12. Bank
                        if (_hasPerm(AppPermissions.bankManage))
                          _ModuleCard(
                              icon: Icons.account_balance_rounded,
                              label: 'Bank',
                              color: const Color(0xFF10B981),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankManagementScreen()))),
                        
                        // 13. Support
                        if (_hasPerm(AppPermissions.supportView))
                          _ModuleCard(
                              icon: Icons.help_outline_rounded,
                              label: 'Support',
                              color: const Color(0xFFF59E0B),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()))),
                        
                        // 14. Customers
                        if (_hasPerm(AppPermissions.customerManage))
                          _ModuleCard(
                              icon: Icons.groups_outlined,
                              label: 'Customers',
                              color: const Color(0xFF06B6D4),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen())).then((_) => _loadStats())),

                        // 15. Gift Cards
                        if (_hasPerm(AppPermissions.giftCards))
                          _ModuleCard(
                              icon: Icons.card_giftcard_outlined,
                              label: 'Gift Cards',
                              color: const Color(0xFF14B8A6),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GiftCardsScreen())).then((_) => setState(() {}))),
                        
                        // 16. Loyalty
                        if (_hasPerm(AppPermissions.loyalty))
                          _ModuleCard(
                              icon: Icons.loyalty_outlined,
                              label: 'Loyalty',
                              color: const Color(0xFFEAB308),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoyaltyScreen())).then((_) => setState(() {}))),
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

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Logout', style: TextStyle(color: theme.textPrimary)),
        content: Text(
            'Are you sure you want to logout? Any unsynced data will be permanently lost.',
            style: TextStyle(color: theme.textSecondary)),
        backgroundColor: theme.surface,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  Text('Cancel', style: TextStyle(color: theme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('LOGOUT',
                  style: TextStyle(
                      color: ThemeProvider.error,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSyncing = true); // Visual feedback

    try {
      // 1. Invalidate session on server
      await _syncService.logout();

      // 2. Clear local session, wipe secure storage, and reset BusinessConfig
      await DatabaseHelper.instance.clearAllData();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Logout error: $e'),
            backgroundColor: ThemeProvider.error));
        setState(() => _isSyncing = false);
      }
    }
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
          Text(value,
              style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 9,
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
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
            borderRadius: BorderRadius.circular(20),
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
              Text(value,
                  style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text(label.toUpperCase(),
                  style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0)),
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(theme.isDark ? 0.15 : 0.12),
                color.withOpacity(theme.isDark ? 0.05 : 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(theme.isDark ? 0.3 : 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(theme.isDark ? 0.15 : 0.08),
                blurRadius: 14,
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
                  fontSize: 13,
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
