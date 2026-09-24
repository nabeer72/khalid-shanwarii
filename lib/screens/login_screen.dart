import 'dart:ui';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:mobile_app/screens/home_screen.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/services/sync_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:mobile_app/widgets/pin_dialogs.dart';

class LoginScreen extends StatefulWidget {
  static bool isActive = false;
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final theme = ThemeProvider.instance;
  final _emailCtrl = TextEditingController(text: 'Khalid@gmail.com');
  final _passCtrl = TextEditingController(text: 'Khalid@123');
  final _api = ApiService();
  final _dbHelper = DatabaseHelper.instance;
  final _storage = const FlutterSecureStorage();
  bool _loading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  bool _rememberMe = true;
  List<Map<String, dynamic>> _savedAccounts = [];
  bool _showLoginForm = true;

  @override
  void initState() {
    super.initState();
    LoginScreen.isActive = true;
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    try {
      final jsonStr = await _storage.read(key: 'saved_accounts');
      if (jsonStr != null) {
        final accounts = List<Map<String, dynamic>>.from(jsonDecode(jsonStr));
        if (mounted) {
          setState(() {
            _savedAccounts = accounts;
            if (accounts.isNotEmpty) {
              _showLoginForm = false;
            }
          });
        }
      }
    } catch (e) {
      print('Failed to load saved accounts: $e');
    }
  }

  Future<void> _saveAllAccounts() async {
    const storage = FlutterSecureStorage();
    await storage.write(
        key: 'saved_accounts', value: jsonEncode(_savedAccounts));
  }

  Future<void> _deleteAccount(Map<String, dynamic> account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title:
            Text('Delete Profile', style: TextStyle(color: theme.textPrimary)),
        content: Text('Remove ${account['name']} from this device?',
            style: TextStyle(color: theme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE',
                style: TextStyle(
                    color: ThemeProvider.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final email = account['email'].toString().toLowerCase().trim();
      setState(() {
        _savedAccounts.removeWhere(
            (acc) => acc['email'].toString().toLowerCase().trim() == email);
      });
      await _saveAllAccounts();

      // [FIX] Also wipe this specific user/employee from the local database to keep it clean
      await _dbHelper.database.then((db) async {
        await db.delete('users', where: 'LOWER(email) = ?', whereArgs: [email]);
        await db
            .delete('employees', where: 'LOWER(email) = ?', whereArgs: [email]);
        print('🧹 [CLEANUP] Removed user/employee $email from local database');
      }).catchError((e) {
        print('⚠️ Failed to cleanup local user record: $e');
      });

      if (_savedAccounts.isEmpty) {
        setState(() => _showLoginForm = true);
      }
    }
  }

  Future<void> _saveCurrentAccount(String pin) async {
    try {
      final email = _emailCtrl.text.trim().toLowerCase();
      final password = _passCtrl.text.trim();

      // Determine name (from DB)
      String name = 'User';
      final localUser = await _dbHelper.getUserByEmail(email);
      if (localUser != null) {
        name = localUser['name'] ?? 'User';
        // [FIX] Update PIN in local users table
        await _dbHelper.updateUserPin(localUser['id'], pin);
      } else {
        final staff = await _dbHelper.getEmployeeByEmailAndPin(email, password);
        if (staff != null) {
          name = staff['name'] ?? 'Staff';
          // [FIX] Update PIN in local employees table
          await _dbHelper.updateEmployeePin(staff['id'], pin);
        }
      }

      // [FIX] Store business and branch IDs to allow skipping re-selection during Quick Login
      final bid = BusinessConfig.instance.businessId;

      final account = {
        'email': email,
        'password': password,
        'name': name,
        'pin': pin,
        'business_id': bid,
      };

      // Remove existing account with same email if exists
      _savedAccounts
          .removeWhere((acc) => acc['email'].toString().toLowerCase() == email);
      _savedAccounts.add(account);

      await _storage.write(
          key: 'saved_accounts', value: jsonEncode(_savedAccounts));

      // [FIX] Sync PIN to remote DB in background
      _api
          .updatePin(pin)
          .catchError((e) => print('⚠️ Failed to sync PIN to server: $e'));
    } catch (e) {
      print('Failed to save account: $e');
    }
  }

  void _handleQuickLogin(Map<String, dynamic> account) async {
    final enteredPin =
        await PinDialogs.showEnterPinDialog(context, account['name']);
    if (enteredPin == null) return;

    if (enteredPin == 'SWITCH_TO_PASSWORD') {
      setState(() {
        _emailCtrl.text = account['email'];
        _showLoginForm = true;
      });
      return;
    }

    if (enteredPin == account['pin']) {
      setState(() {
        _emailCtrl.text = account['email'];
        _passCtrl.text = account['password'];
      });
      // [FIX] Pass the specific account info to login to allow updating the name later
      _login(isQuickLogin: true, existingPin: account['pin']);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Incorrect PIN'),
            backgroundColor: ThemeProvider.error));
      }
    }
  }

  @override
  void dispose() {
    LoginScreen.isActive = false;
    _animController.dispose();
    super.dispose();
  }

  String _businessTypeIcon(String? type) {
    if (type == 'garments') return '👕';
    if (type == 'produce') return '🥬';
    if (type == 'restaurant') return '🍽️';
    if (type == 'electronics') return '📱';
    return '🏪';
  }

  Future<void> _activateSelectedBusiness(
      Map<String, dynamic> selected, dynamic userId) async {
    print('🔄 [LOGIN] Activating business ${selected['id']}...');
    await _dbHelper.activateBusiness(selected, userId: userId);
  }

  Future<void> _showBusinessSelectionDialog(
      dynamic userId, List<Map<String, dynamic>> businesses) async {
    if (!mounted) return;

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.card,
        surfaceTintColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeProvider.radiusDialog)),
        content: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(ThemeProvider.radiusDialog),
            boxShadow: theme.cardShadow,
          ),
          width: 450,
          constraints: const BoxConstraints(maxHeight: 540),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Business',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose which business to open',
                style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: businesses.length,
                  itemBuilder: (context, index) {
                    final b = businesses[index];
                    final type = b['business_type_id']?.toString() ?? '1';
                    final icon = _businessTypeIcon(type);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(ThemeProvider.radiusList),
                          onTap: () => Navigator.pop(ctx, b),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 4),
                            decoration: theme.elevatedTileDecoration,
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: theme.glassCircleDecoration(
                                    color: theme.highlight),
                                child: Text(icon,
                                    style: const TextStyle(fontSize: 18)),
                              ),
                              title: Text(
                                b['name'] ?? 'Unnamed Business',
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  b['business_address']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ==
                                          true
                                      ? b['business_address']
                                      : 'Tap to open',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: theme.textSecondary, fontSize: 12),
                                ),
                              ),
                              trailing: Icon(Icons.chevron_right_rounded,
                                  color: theme.highlight, size: 24),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      await _activateSelectedBusiness(selected, userId);
    } else {
      throw Exception('Business selection required');
    }
  }

  /// Load businesses from live API first, then fall back to local DB.
  Future<List<Map<String, dynamic>>> _fetchAdminBusinessesFromApi(
      dynamic userId) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) {
        print('⚠️ [LOGIN] No auth token — skipping API business fetch');
        return [];
      }

      final response = await _api.getUserBusinesses();
      final raw = response;
      if (raw.isEmpty) return [];

      final businesses = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final b = Map<String, dynamic>.from(item);
        await _dbHelper.saveBusinessFromServer(b, userId);
        businesses.add(b);
      }

      print(
          '🌐 [LOGIN] Fetched ${businesses.length} businesses from API for user $userId');
      return businesses;
    } catch (e) {
      print('⚠️ [LOGIN] API business fetch failed: $e');
      return [];
    }
  }

  Future<void> _handleAdminBusinessSelection(dynamic userId) async {
    final fallbackBid = BusinessConfig.instance.businessId;
    BusinessConfig.instance.businessId = null;

    var businesses = await _fetchAdminBusinessesFromApi(userId);
    if (businesses.isEmpty) {
      businesses = await _dbHelper.getBusinessesForUser(userId);
    }
    print('🏢 [LOGIN] Found ${businesses.length} businesses for user $userId');

    if (businesses.length > 1) {
      try {
        await _showBusinessSelectionDialog(userId, businesses);
      } catch (e) {
        print('⚠️ Business selection cancelled or failed: $e');
        rethrow;
      }
    } else if (businesses.length == 1) {
      await _activateSelectedBusiness(businesses.first, userId);
    } else if (fallbackBid != null) {
      final b = await _dbHelper.getBusiness(fallbackBid);
      if (b != null) {
        await _activateSelectedBusiness(b, userId);
      }
    }
  }

  /// FIXED: Business selection only for admins, not employees
  Future<void> _proceedToHome(bool isQuickLogin, String email,
      {bool isPinLogin = false}) async {
    if (!mounted) return;

    print('🏠 [LOGIN] Auth successful, checking saved credentials...');

    final userId = BusinessConfig.instance.userId;
    final staffId = BusinessConfig.instance.staffId;

    if (userId != null) {
      if (staffId != null) {
        // Staff members skip business selection and go to their pre-set business
        print('🏢 [LOGIN] Staff login - skipping business selection');
        final bid = BusinessConfig.instance.businessId;
        if (bid != null) {
          print('🔄 [LOGIN] Pulling business data for staff context...');
          await SyncService().syncPull(forceFull: true);
          await _dbHelper.loadSettings();
        }
      } else {
        try {
          await _handleAdminBusinessSelection(userId);
        } catch (e) {
          print('⚠️ Business selection cancelled or failed: $e');
          return;
        }
      }
    }

    if (!isQuickLogin) {
      // [FIX] Normalize email comparison to avoid duplicate prompts
      final bool isAlreadySaved = _savedAccounts.any((acc) =>
          acc['email'].toString().toLowerCase() == email.toLowerCase());
      if (!isAlreadySaved && _rememberMe) {
        // [FIX] Check if user already has a PIN in the database (synced from server)
        String? existingPin;
        final localUser = await _dbHelper.getUserByEmail(email);
        if (localUser != null &&
            localUser['pin'] != null &&
            localUser['pin'].toString().isNotEmpty) {
          existingPin = localUser['pin'].toString();
          print(
              '🔐 [LOGIN] Found existing PIN for user, enabling Quick Login automatically');
        } else {
          final staff = await _dbHelper.getEmployeeByEmail(email);
          if (staff != null &&
              staff['pin'] != null &&
              staff['pin'].toString().isNotEmpty) {
            existingPin = staff['pin'].toString();
            print(
                '🔐 [LOGIN] Found existing PIN for staff, enabling Quick Login automatically');
          }
        }

        if (mounted) {
          if (existingPin != null) {
            // Automatically save to Quick Login if PIN exists
            await _saveCurrentAccount(existingPin);
          } else {
            // Otherwise show setup dialog
            final pin = await PinDialogs.showSetupPinDialog(context);
            if (pin != null) {
              await _saveCurrentAccount(pin);
            }
          }
        }
      }
    } else {
      // [FIX] Update the saved name in case it changed on the server, while keeping the pin
      // We pass null for pin to indicate we want to KEEP the existing one
      final pin = (isQuickLogin && _savedAccounts.isNotEmpty)
          ? _savedAccounts.firstWhere((acc) =>
              acc['email'].toString().toLowerCase() ==
              email.toLowerCase())['pin']
          : null;
      if (pin != null) {
        await _saveCurrentAccount(pin);
      }
    }

    if (mounted) {
      print('🏠 [LOGIN] Navigating to HomeScreen');
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  void _login({bool isQuickLogin = false, String? existingPin}) async {
    print('🔐 [LOGIN] Starting login process...');
    print('📧 [LOGIN] Email: ${_emailCtrl.text}');
    print('🌐 [LOGIN] Is Web: $kIsWeb');

    if (kIsWeb) {
      print('✅ [LOGIN] Web mode - skipping API call, navigating to home');
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()));
      return;
    }

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();
    final cleanEmail = email.toLowerCase();

    // Email Validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Please enter a valid email address'),
            backgroundColor: ThemeProvider.error));
      }
      return;
    }

    if (password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Please enter your password'),
            backgroundColor: ThemeProvider.error));
      }
      return;
    }

    setState(() => _loading = true);
    print('⏳ [LOGIN] Loading state set to true');

    try {
      // [FIX] Re-enable local authentication for ALL login types including Quick Login.
      // This allows PIN login to work offline and feel "instant".
      if (true) {
        print('💡 [LOGIN] Checking local database for credentials...');

        // 1. Try Local User (Admin) Login
        final user =
            await _dbHelper.getUserByEmailAndPassword(cleanEmail, password);
        if (user != null) {
          print('👤 [LOGIN] Local Admin found!');

          final uid = user['id'];
          final bid = user['business_id'];
          final aid = user['admin_id'] ?? uid; // Admin is their own admin

          BusinessConfig.instance.setContext(
            bid: bid,
            uid: aid,
          );
          // [FIX] Await the sync so that data is written to the local
          // businesses table BEFORE loadSettings() reads it.
          await SyncService()
              .syncPull(forceFull: true)
              .catchError((e) => print('⚠️ Sync after admin login failed: $e'));

          BusinessConfig.instance.staffName = user['name'] ?? 'Admin';
          BusinessConfig.instance.staffId = null;
          BusinessConfig.instance.userId = uid;
          if (bid != null) await _dbHelper.addUserBusiness(uid, bid);

          await _storage.write(key: 'user_id', value: uid.toString());
          await _storage.write(key: 'user_email', value: user['email']);
          await _storage.delete(key: 'staff_id');

          // Ensure API token exists so business list can be fetched from server
          await _syncLoginToBackend();
          SyncService()
              .syncPull()
              .catchError((e) => print('⚠️ Background sync failed: $e'));

          await _proceedToHome(isQuickLogin, cleanEmail, isPinLogin: false);
          return;
        }

        // 2. Try Staff Login (Email + PIN/Password)
        final staff =
            await _dbHelper.getEmployeeByEmailAndPin(cleanEmail, password);
        if (staff != null) {
          print('👤 [LOGIN] Local Staff member found!');

          // Store staff session
          // [FIX] The employees table has a 'user_id' column (the owner/admin user ID),
          // NOT 'admin_id'. Reading 'admin_id' always returns null, which broke all
          // RBAC permission queries that filter on e.user_id in home_screen.
          await _storage.write(
              key: 'user_id', value: staff['user_id']?.toString());
          await _storage.write(key: 'staff_id', value: staff['id']?.toString());
          await _storage.write(key: 'user_email', value: staff['email']);
          await _storage.write(
              key: 'business_id', value: staff['business_id']?.toString());

          BusinessConfig.instance.businessId = staff['business_id'];
          BusinessConfig.instance.userId = staff['user_id'];
          BusinessConfig.instance.staffId = staff['id'];
          BusinessConfig.instance.staffName = staff['name'] ?? 'Staff';
          // [FIX] Await the sync so that data is written to the local
          // businesses table BEFORE loadSettings() reads it.
          await SyncService()
              .syncPull(forceFull: true)
              .catchError((e) => print('⚠️ Sync after staff login failed: $e'));

          if (staff['business_id'] != null) {
            final business = await _dbHelper.getBusiness(staff['business_id']);
            if (business != null) {
              await _dbHelper.setSetting('business_type_id',
                  business['business_type_id']?.toString() ?? '1');
              BusinessConfig.instance.businessName =
                  business['name'] ?? 'My Business';
            }
          }

          await _dbHelper.loadSettings();
          _syncLoginToBackend();
          SyncService()
              .syncPull()
              .catchError((e) => print('⚠️ Background sync failed: $e'));

          // When logging in via Quick Login (PIN), indicate that this is a PIN login to avoid showing PIN setup again
          await _proceedToHome(isQuickLogin, email, isPinLogin: true);
          return;
        }
      }

      print(
          '💡 [LOGIN] No local record found, attempting server-side (API) login...');

      // If local auth fails or user not found, try API
      print('📡 [LOGIN] Calling API login...');
      await _api.login(cleanEmail, password);
      print('✅ [LOGIN] API call successful!');

      // Start initial sync to get company data (businesses) but don't commit the timestamp yet
      print('🔄 [LOGIN] Running initial sync...');
      final pullData = await SyncService().syncPull(saveTimestamp: false);

      if (pullData != null) {
        final storage = const FlutterSecureStorage();
        dynamic loginUserId;

        // CRITICAL: Update BusinessConfig IMMEDIATELY so UI has access to IDs
        if (pullData['business'] != null) {
          final b = pullData['business'];
          BusinessConfig.instance.businessId = b['id'] is int
              ? (b['id'] as int)
              : int.tryParse(b['id']?.toString() ?? '');
          BusinessConfig.instance.businessName = b['name'];
          BusinessConfig.instance.businessType =
              b['business_type_id']?.toString() ?? '1';
          await _dbHelper.insertBusiness(b);
        }

        if (pullData['user'] != null) {
          final u = pullData['user'];
          // [FIX] Inject the plaintext password so it's hashed and saved locally for offline login
          u['password'] = password;
          await _dbHelper.insertUser(u);
          final uid = u['id'] is int
              ? (u['id'] as int)
              : int.tryParse(u['id']?.toString() ?? '');
          loginUserId = uid;
          final bid = u['business_id'] is int
              ? (u['business_id'] as int)
              : int.tryParse(u['business_id']?.toString() ?? '');
          final brid = u['branch_id'] is int
              ? (u['branch_id'] as int)
              : int.tryParse(u['branch_id']?.toString() ?? '');
          final aid = u['admin_id'] is int
              ? (u['admin_id'] as int)
              : int.tryParse(u['admin_id']?.toString() ?? '');

          // [FIX] Ensure current user-business link exists locally
          if (uid != null && bid != null) {
            await _dbHelper.addUserBusiness(uid, bid);
          }

          if (uid != null) {
            final String role = u['role']?.toString().toLowerCase() ?? '';
            final isStaff = role == 'staff' || role == 'employee';

            int? resolvedStaffId;
            int? resolvedAdminUserId;

            if (isStaff) {
              // [FIX] getEmployeeByEmail now only filters by email + business_id
              // so it correctly finds the employee regardless of userId mismatch.
              final staffRecord = await _dbHelper.getEmployeeByEmail(
                  u['email']?.toString().toLowerCase() ?? '');
              resolvedStaffId = staffRecord?['id'];
              // The employee's user_id = admin's user ID (who created the employee).
              // This is the value needed for all business-scoped DB queries.
              resolvedAdminUserId = staffRecord?['user_id'] != null
                  ? int.tryParse(staffRecord!['user_id'].toString())
                  : null;
              if (kDebugMode) {
                print(
                    '👤 [LOGIN] Resolved Staff ID: $resolvedStaffId, AdminUserId: $resolvedAdminUserId for email: ${u['email']}');
              }
            }

            // For the business context, use the admin's user_id from the employee
            // record if available, otherwise fall back to uid (staff's own user ID).
            final effectiveUserId = (isStaff && resolvedAdminUserId != null)
                ? resolvedAdminUserId
                : uid;

            BusinessConfig.instance.setContext(
              bid: bid,
              uid: effectiveUserId,
            );
            BusinessConfig.instance.staffId = resolvedStaffId;
            BusinessConfig.instance.staffName = u['name'] ?? 'User';

            if (isStaff) {
              await storage.write(
                  key: 'user_id', value: effectiveUserId.toString());
              await storage.write(
                  key: 'staff_id',
                  value: resolvedStaffId?.toString() ?? uid.toString());
            } else {
              await storage.write(key: 'user_id', value: uid.toString());
              await storage.delete(key: 'staff_id');
              BusinessConfig.instance.staffId = null;
            }
            if (brid != null)
              await storage.write(key: 'branch_id', value: brid.toString());
          }

          if (uid != null && bid != null) {
            await _dbHelper.addUserBusiness(uid, bid);
          }
          await storage.write(key: 'user_email', value: u['email']);
        }

        // Link all synced businesses to this admin user
        final changes = pullData['changes'];
        if (changes != null &&
            changes['businesses'] != null &&
            loginUserId != null) {
          for (final b in changes['businesses'] as List) {
            final bId = b['id'];
            if (bId != null) {
              await _dbHelper.addUserBusiness(loginUserId, bId);
            }
          }
        }

        // Let business selection choose the active business (admin only)
        if (BusinessConfig.instance.staffId == null) {
          BusinessConfig.instance.businessId = null;
        }

        print('✅ [LOGIN] Initial setup complete!');
      }

      if (mounted) {
        await _proceedToHome(isQuickLogin, email);
      } else {
        print('⚠️ [LOGIN] Widget not mounted, skipping navigation');
      }
    } catch (e) {
      print('❌ [LOGIN] Error occurred: $e');
      String errorMessage = 'Invalid credentials';

      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) {
          errorMessage =
              data['message'] ?? data['errors']?.toString() ?? errorMessage;
        } else if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage = 'Server connection timeout';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage = 'Server unreachable. Check your internet.';
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(errorMessage),
            backgroundColor: ThemeProvider.error,
            duration: const Duration(seconds: 4)));
      }
    } finally {
      print('🏁 [LOGIN] Finally block - cleaning up');
      if (mounted) {
        setState(() => _loading = false);
        print('⏳ [LOGIN] Loading state set to false');
      }
    }
  }

  // Background sync to verify credentials or register with backend
  Future<void> _syncLoginToBackend() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passCtrl.text.trim();

    try {
      print('🔄 [LOGIN] Syncing login with backend...');
      await _api.login(email, password);
      print('✅ [LOGIN] Backend login successful');

      // Mark local user as synced if they exist
      final localUser = await _dbHelper.getUserByEmail(email);
      if (localUser != null && localUser['is_synced'] == 0) {
        await _dbHelper.updateUserSyncStatus(localUser['id'], 1);
      }
    } catch (e) {
      print('⚠️ [LOGIN] Backend sync failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = ThemeProvider.isWideScreen(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          theme.glassBackground(
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWide ? 960 : 440,
                      ),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: _buildHeroPanel()),
                                const SizedBox(width: 32),
                                SizedBox(
                                  width: 420,
                                  child: _buildAuthColumn(),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _buildHeroPanel(),
                                const SizedBox(height: 28),
                                _buildAuthColumn(),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withOpacity(0.35),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: theme.elevatedCardDecoration,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: theme.highlight,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Signing you in...',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: theme.statCardDecoration(
              ThemeProvider.gradientGold,
            ),
            child: const Icon(
              Icons.store_rounded,
              color: Colors.white,
              size: 52,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Welcome Back',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ThemeProvider.fontHeadline,
            fontWeight: FontWeight.w900,
            color: theme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Khalid Shinwari — Premium POS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        if (kIsWeb)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: theme.badgeDecoration(ThemeProvider.warning),
              child: Text(
                'WEB DEMO MODE',
                style: TextStyle(
                  color: ThemeProvider.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAuthColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_savedAccounts.isNotEmpty && !_showLoginForm) ...[
          _buildSectionLabel('QUICK LOGIN'),
          const SizedBox(height: 14),
          _buildQuickLoginGrid(),
          const SizedBox(height: 18),
          Center(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _showLoginForm = true),
                style: theme.primaryButtonStyle,
                icon: const Icon(Icons.email_outlined, size: 18),
                label: const Text(
                  'LOGIN WITH EMAIL',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ] else if (_showLoginForm) ...[
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(ThemeProvider.radiusHero),
              border: Border.all(color: theme.cardBorder, width: 1.0),
              boxShadow: theme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sign In',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter your credentials to continue',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration:
                          theme.glassCircleDecoration(color: theme.highlight),
                      child: Icon(Icons.lock_open_rounded,
                          color: theme.highlight, size: 26),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (!kIsWeb) ...[
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(
                        color: theme.textPrimary, fontWeight: FontWeight.w600),
                    decoration: theme.glassInputDecoration(
                        'Email Address', Icons.alternate_email_rounded,
                        isRequired: true),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscurePassword,
                    style: TextStyle(
                        color: theme.textPrimary, fontWeight: FontWeight.w600),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _loading ? null : _login(),
                    decoration: theme
                        .glassInputDecoration(
                            'Password', Icons.lock_outline_rounded,
                            isRequired: true)
                        .copyWith(
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: IconButton(
                              splashRadius: 18,
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: theme.iconColor,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        height: 22,
                        width: 22,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? false),
                          activeColor: theme.highlight,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          side: BorderSide(color: theme.divider, width: 1.2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Remember Me',
                          style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                              color: theme.highlight,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _login,
                    style: theme.primaryButtonStyle,
                    icon: Icon(
                      kIsWeb ? Icons.play_arrow_rounded : Icons.login_rounded,
                      size: 20,
                    ),
                    label: Text(
                      kIsWeb ? 'START DEMO' : 'SIGN IN',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2),
                    ),
                  ),
                ),
                if (_savedAccounts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showLoginForm = false),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('BACK TO QUICK LOGIN',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0)),
                        style: TextButton.styleFrom(
                            foregroundColor: theme.textSecondary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 26),
        _buildThemeToggle(),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.2,
        ),
      ),
    );
  }

  Widget _buildQuickLoginGrid() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      alignment: WrapAlignment.center,
      children: _savedAccounts.map((acc) {
        return SizedBox(
          width: 132,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                child: InkWell(
                  onTap: () => _handleQuickLogin(acc),
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 12),
                    decoration: theme.elevatedCardDecoration,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: ThemeProvider.gradientGold,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            backgroundColor: Colors.white.withOpacity(0.08),
                            radius: 28,
                            child: const Icon(Icons.person_rounded,
                                color: Colors.white, size: 30),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          acc['name']?.toString() ?? 'User',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          acc['email']?.toString().toLowerCase() ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: theme.badgeDecoration(theme.highlight),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fingerprint_rounded,
                                  size: 12, color: theme.highlight),
                              const SizedBox(width: 4),
                              Text(
                                'Tap for PIN',
                                style: TextStyle(
                                  color: theme.highlight,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -8,
                right: -8,
                child: GestureDetector(
                  onTap: () => _deleteAccount(acc),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ThemeProvider.error,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ThemeProvider.error.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildThemeToggle() {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeProvider.radiusPill),
          onTap: () => setState(() => theme.toggleTheme()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: theme.elevatedTileDecoration,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration:
                      theme.glassCircleDecoration(color: theme.highlight),
                  child: Icon(
                    theme.isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    color: theme.highlight,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  theme.isDark ? 'SWITCH TO LIGHT MODE' : 'SWITCH TO DARK MODE',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
