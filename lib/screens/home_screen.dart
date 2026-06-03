import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:mobile_app/screens/pos_screen.dart';
import 'package:mobile_app/utils/logout_helper.dart';
import 'package:mobile_app/screens/product_list_screen.dart';
import 'package:mobile_app/screens/customer_list_screen.dart';
import 'package:mobile_app/screens/sales_history_screen.dart';
import 'package:mobile_app/screens/stock_report_screen.dart'; // Import Stock Report
import 'package:mobile_app/screens/support_screen.dart'; // Import Support Screen
import 'package:mobile_app/screens/reports_screen.dart';
import 'package:mobile_app/screens/reports_printing_screen.dart';
import 'package:mobile_app/screens/employee_list_screen.dart';
import 'package:mobile_app/screens/settings_screen.dart';
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
  String? _lastSync;
  Employee? _currentStaff;
  Timer? _autoSyncTimer;

  int _productCount = 0;
  int _customerCount = 0;
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
    _loadCurrentStaff();
    
    // Listen for real-time data changes across the app (including after background sync)
    _dataSubscription = DatabaseHelper.dataStream.listen((_) {
      if (mounted) {
        _loadStats();
        _loadBranches();
        _loadCurrentStaff(); // [FIX] Re-check permissions after every sync/data change
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
        await _handleModuleTap('welcome', 'Dashboard', [
          'Welcome to your business dashboard!',
          'Manage all aspects of your store from this screen.',
          'Tap any card to view detailed module tutorials.',
          'Use the Sync button regularly to keep data updated.',
        ], () {});
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

  Future<void> _loadCurrentStaff() async {
    dynamic sid = BusinessConfig.instance.staffId;
    if (sid != null) {
      final db = DatabaseHelper.instance;

      // [FIX] Use getEmployeeById (only filters by id + business_id).
      // The old getEmployees() filtered by user_id which is the ADMIN's user ID,
      // but BusinessConfig.userId held the staff's own user ID — mismatch meant
      // the employee was never found and _currentStaff stayed null.
      Map<String, dynamic>? staffData = await db.getEmployeeById(sid);

      if (staffData == null) {
        // Fallback: staffId in storage may be from users table, not employees table.
        final String? userEmail = await (const FlutterSecureStorage()).read(key: 'user_email');
        if (userEmail != null) {
          staffData = await db.getEmployeeByEmail(userEmail.toLowerCase());
          if (staffData != null) {
            BusinessConfig.instance.staffId = staffData['id'];
            sid = staffData['id'];
          }
        }
      }

      // Backfill userId from the employee record so subsequent DB queries
      // (which filter by user_id) use the correct admin-scoped user ID.
      if (staffData != null && staffData['user_id'] != null) {
        BusinessConfig.instance.userId = staffData['user_id'];
      }

      final finalStaff = staffData;
      if (finalStaff != null) {
        List<String> perms = [];

        // 1. Load legacy permissions column if present
        if (finalStaff['permissions'] != null) {
          try {
            perms = List<String>.from(jsonDecode(finalStaff['permissions']));
          } catch (e) {}
        }

        // 2. Load RBAC permissions from assigned roles
        final rbacPerms = await DatabaseHelper.instance.getEmployeePermissions(sid);
        for (var p in rbacPerms) {
          if (!perms.contains(p)) perms.add(p);
        }

        if (mounted) {
          setState(() {
            _currentStaff = Employee(
              id: finalStaff['id'],
              name: finalStaff['name'],
              role: finalStaff['role'] ?? 'cashier',
              email: finalStaff['email'],
              phone: finalStaff['phone'],
              pin: finalStaff['pin'],
              isActive: finalStaff['status'] == 1,
              permissions: perms,
            );
          });
        }
        BusinessConfig.instance.staffName = finalStaff['name'] ?? '';
      }
    }
  }

  bool _hasPerm(String perm) {
    // Admin has ALL, Staff has ONLY assigned
    final isStaff = BusinessConfig.instance.staffId != null;
    if (!isStaff) return true; // Admin case
    
    // Staff case: explicitly check list of assigned permissions
    return _currentStaff?.permissions.contains(perm) ?? false;
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
      final fromDb = await DatabaseHelper.instance.getSetting('business_address');
      address = fromDb?.trim() ?? '';
      if (address.isNotEmpty) {
        BusinessConfig.instance.businessAddress = address;
      }
    }
    return address;
  }

  Future<String?> _fetchBranchNameById(dynamic businessId, dynamic branchId) async {
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
      var brid = BusinessConfig.instance.branchId;
      if (brid == null) {
        const storage = FlutterSecureStorage();
        final stored = await storage.read(key: 'branch_id');
        if (stored != null && stored.isNotEmpty && stored != 'NONE') {
          brid = int.tryParse(stored) ?? stored;
          BusinessConfig.instance.branchId = brid;
        }
      }

      final list = await DatabaseHelper.instance.getBranchesForBusiness(bid);
      String? name;
      Map<String, dynamic>? currentBranch;
      for (final b in list) {
        if (b['id'].toString() == brid?.toString()) {
          name = _branchDisplayName(b);
          currentBranch = b;
          break;
        }
      }
      name ??= await _fetchBranchNameById(bid, brid);
      if (currentBranch == null && name != null && list.isNotEmpty) {
        currentBranch = list.firstWhere(
          (b) => _branchDisplayName(b) == name,
          orElse: () => list.first,
        );
      }
      name ??= list.isNotEmpty ? _branchDisplayName(list.first) : null;
      currentBranch ??= list.isNotEmpty ? list.first : null;
      final address = await _resolveStoreAddress(branch: currentBranch);

      if (mounted) {
        setState(() {
          _branches = list;
          _currentBranchName = name;
          _storeAddress = address;
        });
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ [HOME] Failed to load branches: $e');
    }
  }

  Future<void> _switchBranch(Map<String, dynamic> branch) async {
    final id = branch['id'];
    if (id == null) return;

    BusinessConfig.instance.branchId = id;
    const storage = FlutterSecureStorage();
    await storage.write(key: 'branch_id', value: id.toString());

    if (mounted) {
      final address = await _resolveStoreAddress(branch: branch);
      setState(() {
        _currentBranchName = _branchDisplayName(branch);
        _storeAddress = address;
      });
      await _loadStats();
      DatabaseHelper.notifyDataChanged(triggerSync: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${_branchDisplayName(branch) ?? 'branch'}'),
          backgroundColor: ThemeProvider.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildBranchHeaderIcon() {
    final isAdmin = BusinessConfig.instance.staffId == null;
    final showDropdown = isAdmin && _branches.length > 1;

    final iconBox = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
        border: Border.all(color: theme.divider, width: 1.0),
      ),
      child: Icon(Icons.store_rounded, color: theme.primary, size: 24),
    );

    if (!showDropdown) {
      return iconBox;
    }

    return PopupMenuButton<Map<String, dynamic>>(
      offset: const Offset(0, 48),
      tooltip: 'Switch branch',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: _switchBranch,
      itemBuilder: (context) {
        return _branches.map((b) {
          final selected = b['id'].toString() == BusinessConfig.instance.branchId?.toString();
          final isMain = b['is_main_branch'] == 1 || b['is_main_branch'] == '1';
          return PopupMenuItem<Map<String, dynamic>>(
            value: b,
            child: Row(
              children: [
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.check_circle_rounded, color: theme.highlight, size: 18),
                  )
                else
                  const SizedBox(width: 26),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _branchDisplayName(b) ?? 'Branch',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      if (isMain)
                        Text(
                          'Main branch',
                          style: TextStyle(fontSize: 11, color: theme.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconBox,
          Icon(Icons.arrow_drop_down_rounded, color: theme.textSecondary, size: 22),
        ],
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
      final productCount = (prodCountRes.isNotEmpty ? prodCountRes.first.values.first as num? : 0)?.toInt() ?? 0;

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
      final customerCount = (customerCountRes.isNotEmpty ? customerCountRes.first.values.first as num? : 0)?.toInt() ?? 0;

      // 4. Optimized Held Orders Count
      final heldCountRes = await rawDb.rawQuery(
        'SELECT COUNT(*) as total FROM held_orders WHERE 1=1$bFilter$brFilter',
        queryArgs,
      );
      final heldCount = (heldCountRes.isNotEmpty ? heldCountRes.first.values.first as num? : 0)?.toInt() ?? 0;

      if (mounted) {
        setState(() {
          _productCount = productCount;
          _customerCount = customerCount;
          _heldCount = heldCount;
          _topSellingName = topName;
          _topSellingQty = topQty;
        });
      }

      // Sales query is isolated so a failure doesn't zero out other counts
      try {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
        final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toIso8601String();

        // Retrieve only today's sales and returns
        final todaySales = await db.getSales(startTime: todayStart, endTime: todayEnd);
        
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
        final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
        final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toIso8601String();

        // Query today's credit payments recovery amount
        final recoveryRes = await rawDb.rawQuery(
          'SELECT SUM(amount) as total FROM credit_payments WHERE payment_date >= ? AND payment_date <= ?$bFilter$brFilter',
          [todayStart, todayEnd, ...queryArgs],
        );
        final recoveryTotal = (recoveryRes.isNotEmpty && recoveryRes.first['total'] != null ? recoveryRes.first['total'] as num : 0.0).toDouble();

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
        await _loadCurrentStaff(); // [FIX] Refresh permissions after manual sync
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 1),
                                        child: Icon(
                                          Icons.location_on_outlined,
                                          size: 13,
                                          color: theme.textSecondary.withOpacity(0.85),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _storeAddress,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.textSecondary.withOpacity(0.9),
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

                    // Subscription Alert Banner
                    if (!BusinessConfig.instance.isSubscriptionActive)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ThemeProvider.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                          border: Border.all(color: ThemeProvider.error.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: ThemeProvider.error, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    BusinessConfig.instance.subscriptionStatus == 'expired' 
                                        ? 'Subscription Expired' 
                                        : 'Subscription Inactive',
                                    style: const TextStyle(color: ThemeProvider.error, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    'Please renew your subscription to continue using the register and adding products.',
                                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (BusinessConfig.instance.subscriptionEndDate != null && 
                             BusinessConfig.instance.subscriptionEndDate!.difference(DateTime.now()).inDays <= 5)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ThemeProvider.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                          border: Border.all(color: ThemeProvider.warning.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: ThemeProvider.warning, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Subscription Expiring Soon',
                                    style: TextStyle(color: ThemeProvider.warning, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    'Your ${BusinessConfig.instance.subscriptionPlanName} plan expires in ${BusinessConfig.instance.subscriptionEndDate!.difference(DateTime.now()).inDays} days.',
                                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Hero - New Sale (Glass Style)
                    if (_hasPerm(AppPermissions.newSale) ||
                        _hasPerm(AppPermissions.posAccess))
                      GestureDetector(
                        onTap: () async {
                          if (!BusinessConfig.instance.isSubscriptionActive) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Access Denied: Your subscription is inactive or expired.'),
                                backgroundColor: ThemeProvider.error,
                              ),
                            );
                            return;
                          }
                          final activeShift = await DatabaseHelper.instance.getActiveShift();
                          final bool skipShift = !BusinessConfig.instance.enableShiftManagement;

                          if (activeShift != null || skipShift) {
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
                                child: Icon(Icons.point_of_sale,
                                    color: theme.primary,
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
                                        '${BusinessConfig.instance.currencyDisplay} ${_todayRecoveryAmount.toStringAsFixed(0)}',
                                    label: 'RECOVERY',
                                  ),
                                  _QuickStat(
                                    icon: Icons.assignment_return_rounded,
                                    value:
                                        '${BusinessConfig.instance.currencyDisplay} ${_todayReturnsAmount.toStringAsFixed(0)}',
                                    label: 'REFUND',
                                  ),
                                  _QuickStat(
                                    icon: BusinessConfig.instance.currencyIcon,
                                    value:
                                        '${BusinessConfig.instance.currencyDisplay} ${_todaySalesAmount.toStringAsFixed(0)}',
                                    label: 'TODAY',
                                  ),
                                ],
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
                        if (_hasPerm(AppPermissions.productManage) || _hasPerm(AppPermissions.products))
                          _ModuleCard(
                              icon: Icons.inventory_2_outlined,
                              label: 'Products',
                              color: const Color(0xFF3366FF),
                              onTap: () => _handleModuleTap('products', 'Products', [
                                    'Add and manage your inventory items.',
                                    'Set product prices and cost details.',
                                    'Organize products by categories and units.',
                                    'Track low stock alerts and favorites.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen())).then((_) => _loadStats()))),
                        
                        // 2. Purchases
                        if (_hasPerm(AppPermissions.purchasesManage))
                          _ModuleCard(
                              icon: Icons.shopping_cart_outlined,
                              label: 'Purchases',
                              color: const Color(0xFF64748B),
                              onTap: () => _handleModuleTap('purchases', 'Purchases', [
                                    'Record new stock purchases from suppliers.',
                                    'Track purchase history and invoices.',
                                    'Manage unpaid purchase balances.',
                                    'Update inventory automatically on purchase.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasesScreen())).then((_) => setState(() {})))),
                        
                        // 3. Expenses
                        if (_hasPerm(AppPermissions.expensesManage))
                          _ModuleCard(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Expenses',
                              color: const Color(0xFFEF4444),
                              onTap: () => _handleModuleTap('expenses', 'Expenses', [
                                    'Log daily business expenses (e.g., rent, bills).',
                                    'Categorize expenses for better tracking.',
                                    'View expense history and totals.',
                                    'Analyze spending to maximize profit.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen())).then((_) => setState(() {})))),
                        
                        // 4. Recovery
                        if (_hasPerm(AppPermissions.recovery))
                          _ModuleCard(
                              icon: Icons.payments_outlined,
                              label: 'Recovery',
                              color: const Color(0xFF0EA5E9),
                              onTap: () => _handleModuleTap('recovery', 'Recovery', [
                                    'Track outstanding customer balances.',
                                    'Record partial or full payments received.',
                                    'View payment history for each customer.',
                                    'Settle credit sales easily.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecoveryScreen())).then((_) => _loadStats()))),
                        
                        // 5. Suppliers
                        if (_hasPerm(AppPermissions.suppliersManage))
                          _ModuleCard(
                              icon: Icons.business_outlined,
                              label: 'Suppliers',
                              color: const Color(0xFF84CC16),
                              onTap: () => _handleModuleTap('suppliers', 'Suppliers', [
                                    'Maintain a list of your vendors and suppliers.',
                                    'Track contact details and addresses.',
                                    'Monitor total payable amounts to each supplier.',
                                    'View purchase history by supplier.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen())).then((_) => setState(() {})))),
                        
                        // 5b. Supplier Payback
                        if (_hasPerm(AppPermissions.paybackManage))
                          _ModuleCard(
                              icon: Icons.payments_outlined,
                              label: 'Payback',
                              color: const Color(0xFF10B981),
                              onTap: () => _handleModuleTap('payback', 'Payback', [
                                    'Manage payments made to your suppliers.',
                                    'Clear outstanding purchase balances.',
                                    'Track the history of supplier payments.',
                                    'Keep accurate vendor accounts.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierPaybackScreen())).then((_) => _loadStats()))),
                        
                        // 6. Stock
                        if (_hasPerm(AppPermissions.productManage) || _hasPerm(AppPermissions.reportsView) || _hasPerm(AppPermissions.stockView))
                          _ModuleCard(
                              icon: Icons.analytics_outlined,
                              label: 'Stock',
                              color: const Color(0xFF8B5CF6),
                              onTap: () => _handleModuleTap('stock', 'Stock', [
                                    'View real-time inventory levels.',
                                    'Check stock valuation and potential profit.',
                                    'Identify low-stock and out-of-stock items.',
                                    'Generate comprehensive stock reports.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockReportScreen())))),

                        // 7. Roles
                        if (_hasPerm(AppPermissions.staffManage))
                          _ModuleCard(
                              icon: Icons.badge_outlined,
                              label: 'Roles',
                              color: const Color(0xFFF59E0B),
                              onTap: () => _handleModuleTap('roles', 'Roles', [
                                    'Create custom roles for your staff.',
                                    'Assign specific permissions (e.g., cashier, manager).',
                                    'Control access to sensitive modules.',
                                    'Ensure secure system management.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RolesScreen())))),
                        
                        // 7. Sales
                        if (_hasPerm(AppPermissions.salesHistory))
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
                                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesHistoryScreen()));
                                _loadStats();
                                if (result != null && result is Map && mounted) {
                                  final Map<String, dynamic> castedResult = Map<String, dynamic>.from(result);
                                   final activeShift = await DatabaseHelper.instance.getActiveShift();
                                   final bool skipShift = !BusinessConfig.instance.enableShiftManagement;
                                   if (activeShift != null || skipShift) {
                                     Navigator.push(context, MaterialPageRoute(builder: (_) => POSScreen(returnSale: castedResult))).then((_) => _loadStats());
                                   } else {
                                    final clockedIn = await showDialog<bool>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (ctx) => const ClockInDialog(),
                                    );
                                    if (clockedIn == true && mounted) {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => POSScreen(returnSale: castedResult))).then((_) => _loadStats());
                                    }
                                  }
                                }
                              })),
                        
                        // 8. Reports
                        if (_hasPerm(AppPermissions.reportsView))
                          _ModuleCard(
                              icon: Icons.bar_chart_outlined,
                              label: 'Reports',
                              color: const Color(0xFFF59E0B),
                              onTap: () => _handleModuleTap('reports', 'Reports', [
                                    'Analyze business performance and profits.',
                                    'View sales, expense, and tax summaries.',
                                    'Track best-selling products.',
                                    'Export data for accounting purposes.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())).then((_) => setState(() {})))),
                        
                        // 8b. Print Reports
                        if (_hasPerm(AppPermissions.reportsPrint) || _hasPerm(AppPermissions.reportsView))
                          _ModuleCard(
                              icon: Icons.print_outlined,
                              label: 'Print Reports',
                              color: const Color(0xFF0EA5E9),
                              onTap: () => _handleModuleTap('print_reports', 'Print Reports', [
                                    'Generate formatted reports for printing.',
                                    'Print via Bluetooth or Wi-Fi thermal printers.',
                                    'Share reports directly via PDF.',
                                    'Keep physical records of your business.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPrintingScreen())))),
                        
                        // 9. Staff
                        if (_hasPerm(AppPermissions.staffManage))
                          _ModuleCard(
                              icon: Icons.badge_outlined,
                              label: 'Staff',
                              color: const Color(0xFF6366F1),
                              onTap: () => _handleModuleTap('staff', 'Staff', [
                                    'Manage employee profiles and details.',
                                    'Assign roles and secure login PINs.',
                                    'Track staff activity and sales.',
                                    'Manage shift timings and attendance.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeListScreen())).then((_) => setState(() {})))),
                        
                        // 10. Settings
                        if (_hasPerm(AppPermissions.settingsManage))
                          _ModuleCard(
                              icon: Icons.settings_outlined,
                              label: 'Settings',
                              color: const Color(0xFF6366F1),
                              onTap: () => _handleModuleTap('settings', 'Settings', [
                                    'Configure business details and currency.',
                                    'Set up printer and hardware preferences.',
                                    'Manage tax rates and application theme.',
                                    'Backup and restore your database.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())))),
                        
                        // 11. Branches
                        if (_hasPerm(AppPermissions.branchesManage))
                          _ModuleCard(
                              icon: Icons.alt_route_rounded,
                              label: 'Branches',
                              color: const Color(0xFF8B5CF6),
                              onTap: () => _handleModuleTap('branches', 'Branches', [
                                    'Manage multiple store locations.',
                                    'Switch between different branches.',
                                    'Track performance across branches.',
                                    'Centralize multi-store management.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BranchManagementScreen())))),
                        
                        // 12. Bank
                        if (_hasPerm(AppPermissions.bankManage))
                          _ModuleCard(
                              icon: Icons.account_balance_rounded,
                              label: 'Bank',
                              color: const Color(0xFF10B981),
                              onTap: () => _handleModuleTap('bank', 'Bank', [
                                    'Manage your linked bank accounts.',
                                    'Track bank deposits and withdrawals.',
                                    'Monitor digital payment methods.',
                                    'Reconcile bank statements.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankManagementScreen())))),
                        
                        // 13. Support
                        if (_hasPerm(AppPermissions.supportView))
                          _ModuleCard(
                              icon: Icons.help_outline_rounded,
                              label: 'Support',
                              color: const Color(0xFFF59E0B),
                              onTap: () => _handleModuleTap('support', 'Support', [
                                    'Contact technical support for help.',
                                    'View tutorials and guides.',
                                    'Report bugs or request new features.',
                                    'Check for application updates.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen())))),
                        
                        // 14. Customers
                        if (_hasPerm(AppPermissions.customerManage))
                          _ModuleCard(
                              icon: Icons.groups_outlined,
                              label: 'Customers',
                              color: const Color(0xFF06B6D4),
                              onTap: () => _handleModuleTap('customers', 'Customers', [
                                    'Maintain a database of your customers.',
                                    'Track individual purchase history.',
                                    'Monitor customer credit and balances.',
                                    'Reward frequent shoppers.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen())).then((_) => _loadStats()))),

                        // 15. Gift Cards
                        if (_hasPerm(AppPermissions.giftCards))
                          _ModuleCard(
                              icon: Icons.card_giftcard_outlined,
                              label: 'Gift Cards',
                              color: const Color(0xFF14B8A6),
                              onTap: () => _handleModuleTap('gift_cards', 'Gift Cards', [
                                    'Create and issue gift cards.',
                                    'Track gift card balances and usage.',
                                    'Accept gift cards as payment.',
                                    'Boost sales with prepaid cards.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GiftCardsScreen())).then((_) => setState(() {})))),
                        
                        // 16. Loyalty
                        if (_hasPerm(AppPermissions.loyalty))
                          _ModuleCard(
                              icon: Icons.loyalty_outlined,
                              label: 'Loyalty',
                              color: const Color(0xFFEAB308),
                              onTap: () => _handleModuleTap('loyalty', 'Loyalty', [
                                    'Set up a customer loyalty program.',
                                    'Award points for customer purchases.',
                                    'Allow points redemption for discounts.',
                                    'Increase customer retention.'
                                  ], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoyaltyScreen())).then((_) => setState(() {})))),
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

  Future<void> _handleModuleTap(
      String moduleKey, String moduleName, List<String> tutorialLines, VoidCallback onNavigate) async {
    const storage = FlutterSecureStorage();
    final userId = BusinessConfig.instance.userId;
    final storageKey = userId != null ? 'tutorial_shown_${moduleKey}_$userId' : 'tutorial_shown_$moduleKey';
    final hasShown = await storage.read(key: storageKey);
    
    if (hasShown == null) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
            title: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: theme.highlight),
                const SizedBox(width: 8),
                Text('$moduleName Guide', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
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
                            Icon(Icons.check_circle_outline, color: theme.highlight, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(line, style: TextStyle(color: theme.textSecondary, fontSize: 13))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('GOT IT', style: TextStyle(color: theme.highlight, fontWeight: FontWeight.bold)),
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
          Text(value,
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
                      fontSize: 12,
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
