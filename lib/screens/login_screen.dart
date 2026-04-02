import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:mobile_app/screens/home_screen.dart';
import 'package:mobile_app/screens/signup_screen.dart';
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
  final _emailCtrl =
      TextEditingController(text: kIsWeb ? 'admin@test.com' : '');
  final _passCtrl = TextEditingController(text: kIsWeb ? 'password' : '');
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
    await storage.write(key: 'saved_accounts', value: jsonEncode(_savedAccounts));
  }

  Future<void> _deleteAccount(Map<String, dynamic> account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Delete Profile', style: TextStyle(color: theme.textPrimary)),
        content: Text('Remove ${account['name']} from this device?', style: TextStyle(color: theme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE', style: TextStyle(color: ThemeProvider.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _savedAccounts.removeWhere((acc) => acc['email'] == account['email']);
      });
      await _saveAllAccounts();
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
      } else {
        final staff = await _dbHelper.getEmployeeByEmailAndPin(email, password);
        if (staff != null) name = staff['name'] ?? 'Staff';
      }

      final account = {
        'email': email,
        'password': password,
        'name': name,
        'pin': pin,
      };

      // Remove existing account with same email if exists
      _savedAccounts.removeWhere((acc) => acc['email'] == email);
      _savedAccounts.add(account);

      await _storage.write(key: 'saved_accounts', value: jsonEncode(_savedAccounts));
    } catch (e) {
      print('Failed to save account: $e');
    }
  }
  
  void _handleQuickLogin(Map<String, dynamic> account) async {
    final enteredPin = await PinDialogs.showEnterPinDialog(context, account['name']);
    if (enteredPin == null) return;

    if (enteredPin == account['pin']) {
      setState(() {
        _emailCtrl.text = account['email'];
        _passCtrl.text = account['password'];
      });
      _login(isQuickLogin: true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Incorrect PIN'),
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

  Future<void> _showBusinessSelectionDialog(dynamic userId, List<Map<String, dynamic>> businesses) async {
    if (!mounted) return;

    final selected = await showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Business Selection',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: anim1,
            child: PopScope(
              canPop: false,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Center(
                  child: Container(
                    width: 320, // More compact width
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.surface.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Elegant Icon & Header
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.highlight.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.store_rounded, color: theme.highlight, size: 32),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Business Profile',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select a store to manage',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // List of businesses
                          Flexible(
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 300),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: businesses.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final b = businesses[index];
                                  return InkWell(
                                    onTap: () => Navigator.pop(context, b),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [theme.highlight, theme.highlight.withOpacity(0.7)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Text(
                                                (b['name'] ?? 'B').toString().substring(0, 1).toUpperCase(),
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  b['name'] ?? 'Business',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: theme.textPrimary,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                Text(
                                                  b['business_type'] ?? 'General Store',
                                                  style: TextStyle(
                                                    color: theme.textSecondary.withOpacity(0.7),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(Icons.chevron_right_rounded, color: theme.textSecondary.withOpacity(0.5), size: 20),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) {
      final storage = const FlutterSecureStorage();
      final bid = selected['id'];
      final aid = selected['owner_user_id'] ?? selected['admin_id'];
      
      // Fetch branches for this business to set initial context
      final branches = await _dbHelper.getBranchesForBusiness(bid);
      final mainBranch = branches.firstWhere((b) => b['is_main_branch'] == 1 || b['is_main_branch'] == '1', orElse: () => branches.isNotEmpty ? branches.first : {'id': null});
      
      BusinessConfig.instance.setContext(
        bid: bid,
        aid: aid,
        brid: mainBranch['id'],
        bName: selected['name'],
        bType: selected['business_type'],
        activeBranches: branches.map((b) => b['id']).toList(),
      );

      // Persist to storage
      await storage.write(key: 'business_id', value: bid.toString());
      if (aid != null) await storage.write(key: 'user_id', value: aid.toString());
      if (mainBranch['id'] != null) await storage.write(key: 'branch_id', value: mainBranch['id'].toString());

      // Sync and load settings - CRITICAL: await this so products are loaded before home
      print('🔄 [LOGIN] Performing full sync for business $bid...');
      await SyncService().syncPull(forceFull: true).catchError((e) => print('⚠️ Quick sync failed: $e'));
      await _dbHelper.loadSettings();
    } else {
      // If they somehow cancelled a non-cancellable dialog, we must stay on login
      throw Exception('Business selection required');
    }
  }

  Future<void> _proceedToHome(bool isQuickLogin, String email) async {
    if (!mounted) return;
    
    print('🏠 [LOGIN] Auth successful, checking saved credentials...');
    
    final userId = BusinessConfig.instance.adminId;
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
        // Admin login logic
        final businesses = await _dbHelper.getBusinessesForUser(userId);
        print('🏢 [LOGIN] Found ${businesses.length} businesses for user $userId');
        
        if (businesses.length > 1) {
          try {
            await _showBusinessSelectionDialog(userId, businesses);
          } catch (e) {
            print('⚠️ Business selection cancelled or failed: $e');
            return; // Stay on login screen
          }
        } else if (businesses.length == 1) {
          // Auto-select the only business
          final b = businesses.first;
          final bid = b['id'];
          final aid = b['owner_user_id'] ?? b['admin_id'];
          
          final branches = await _dbHelper.getBranchesForBusiness(bid);
          final mainBranch = branches.firstWhere(
            (b) => b['is_main_branch'] == 1 || b['is_main_branch'] == '1', 
            orElse: () => branches.isNotEmpty ? branches.first : {'id': null},
          );

          BusinessConfig.instance.setContext(
            bid: bid, 
            aid: aid,
            brid: mainBranch['id'],
            bName: b['name'],
            bType: b['business_type'],
            activeBranches: branches.map((br) => br['id']).toList(),
          );

          await _storage.write(key: 'branch_id', value: mainBranch['id']?.toString() ?? '');

          print('🔄 [LOGIN] Pulling business data for ${b['name']}...');
          await SyncService().syncPull(forceFull: true);
          await _dbHelper.loadSettings();
        } else {
          // Fallback if no businesses found
          final bid = BusinessConfig.instance.businessId;
          if (bid != null) {
            print('🏢 [LOGIN] Fallback: Using direct business ID $bid');
            final b = await _dbHelper.getBusiness(bid);
            if (b != null) {
              final branches = await _dbHelper.getBranchesForBusiness(bid);
              final mainBranch = branches.firstWhere(
                (br) => br['is_main_branch'] == 1 || br['is_main_branch'] == '1', 
                orElse: () => branches.isNotEmpty ? branches.first : {'id': null},
              );
              
              BusinessConfig.instance.setContext(
                bid: bid, 
                aid: b['owner_user_id'] ?? b['admin_id'] ?? userId,
                brid: mainBranch['id'],
                bName: b['name'],
                bType: b['business_type'],
                activeBranches: branches.map((br) => br['id']).toList(),
              );
              
              print('🔄 [LOGIN] Fallback: Pulling business data for ${b['name']}...');
              await SyncService().syncPull(forceFull: true);
              await _dbHelper.loadSettings();
            }
          }
        }
      }
    }

    if (!isQuickLogin) {
      // Check if this account is already saved
      final bool isAlreadySaved = _savedAccounts.any((acc) => acc['email'] == email);
      if (!isAlreadySaved && _rememberMe) {
        // If Remember Me is checked, we go straight to PIN setup
        if (mounted) {
          final pin = await PinDialogs.showSetupPinDialog(context);
          if (pin != null) {
            await _saveCurrentAccount(pin);
          }
        }
      } else if (!isAlreadySaved && !_rememberMe) {
        // Optional: We could still ask if they want to save even if they didn't check it, 
        // but usually unchecking means "don't ask me".
      }
    }

    if (mounted) {
      print('🏠 [LOGIN] Navigating to HomeScreen');
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  void _login({bool isQuickLogin = false}) async {
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
      // PROMPT CHANGE: Bypassing local user login to force API (Live Database) authentication
      // Final fallback to staff member login remains locally for offline employee use.
      print('💡 [LOGIN] Checking for local Staff login fallback...');
      // Try Staff Login (Email + PIN/Password)
      final staff =
          await _dbHelper.getEmployeeByEmailAndPin(cleanEmail, password);
        if (staff != null) {
          print('👤 [LOGIN] Staff member found!');

          // Store staff session
          await _storage.write(
              key: 'user_id', value: staff['admin_id']?.toString()); // Context is admin
          await _storage.write(key: 'staff_id', value: staff['id']?.toString());
          await _storage.write(key: 'user_email', value: staff['email']);
          await _storage.write(key: 'business_id', value: staff['business_id']?.toString());

          // Initialize BusinessConfig for Staff
          BusinessConfig.instance.adminId = staff['admin_id']; // For data isolation
          BusinessConfig.instance.staffId = staff['id']; // For identity

          if (staff['branch_id'] != null) {
            BusinessConfig.instance.branchId = staff['branch_id'];
            final String bid = staff['branch_id'].toString();
            await _storage.write(key: 'branch_id', value: bid);
          }

          // Load business info for staff context
          if (staff['business_id'] != null) {
            final business = await _dbHelper.getBusiness(staff['business_id']);
            if (business != null) {
              BusinessConfig.instance.businessType =
                  business['business_type'] ?? 'general';
              BusinessConfig.instance.businessName =
                  business['name'] ?? 'My Business';
            }
          }

          // Load settings (currency, etc.)
          await _dbHelper.loadSettings();

          // Background Sync: Verify credentials or push/pull data in background
          _syncLoginToBackend();
          SyncService().syncPull().then((_) => _dbHelper.loadSettings()).catchError((e) {
            print('⚠️ [LOGIN] Background sync failed (offline?): $e');
          });

          await _proceedToHome(isQuickLogin, email);
          return;
        }
        print('💡 [LOGIN] No staff found locally, trying API...');

      // If local auth fails or user not found, try API
      print('📡 [LOGIN] Calling API login...');
      await _api.login(cleanEmail, password);
      print('✅ [LOGIN] API call successful!');

      // Start initial sync to get company data (businesses) but don't commit the timestamp yet
      print('🔄 [LOGIN] Running initial sync...');
      final pullData = await SyncService().syncPull(saveTimestamp: false);

        if (pullData != null) {
          final storage = const FlutterSecureStorage();
          
          // CRITICAL: Update BusinessConfig IMMEDIATELY so UI has access to IDs
          if (pullData['business'] != null) {
            final b = pullData['business'];
            BusinessConfig.instance.businessId = b['id'] is int ? (b['id'] as int) : int.tryParse(b['id']?.toString() ?? '');
            BusinessConfig.instance.businessName = b['name'];
            BusinessConfig.instance.businessType = b['business_type'];
            await _dbHelper.insertBusiness(b);
          }

          if (pullData['user'] != null) {
            final u = pullData['user'];
            await _dbHelper.insertUser(u);
            final uid = u['id'] is int ? (u['id'] as int) : int.tryParse(u['id']?.toString() ?? '');
            final bid = u['business_id'] is int ? (u['business_id'] as int) : int.tryParse(u['business_id']?.toString() ?? '');
            final brid = u['branch_id'] is int ? (u['branch_id'] as int) : int.tryParse(u['branch_id']?.toString() ?? '');
            final aid = u['admin_id'] is int ? (u['admin_id'] as int) : int.tryParse(u['admin_id']?.toString() ?? '');

            // [FIX] Ensure current user-business link exists locally
            if (uid != null && bid != null) {
              await _dbHelper.addUserBusiness(uid, bid);
            }

            if (uid != null) {
              // [FIX] Robust staff detection using roles AND admin_id from server
              final String role = u['role']?.toString().toLowerCase() ?? '';
              final isStaff = role == 'staff' || role == 'employee' || (aid != null && aid != uid);
              
              final effectiveAdminId = isStaff ? (aid ?? uid) : uid;
              
              // [CRITICAL] staffId MUST be the ID from the employees table to match RBAC permissions.
              // The User.id (uid) might not match Employee.id on the server.
              int? resolvedStaffId;
              if (isStaff) {
                final staffRecord = await _dbHelper.getEmployeeByEmail(u['email']?.toString().toLowerCase() ?? '');
                resolvedStaffId = staffRecord?['id'];
                if (kDebugMode) print('👤 [LOGIN] Resolved Staff ID: $resolvedStaffId for email: ${u['email']}');
              }

              BusinessConfig.instance.setContext(
                bid: bid, 
                aid: effectiveAdminId,
                brid: brid,
              );
              BusinessConfig.instance.staffId = resolvedStaffId;

              if (isStaff) {
                await storage.write(key: 'user_id', value: effectiveAdminId.toString());
                await storage.write(key: 'staff_id', value: resolvedStaffId?.toString() ?? uid.toString());
              } else {
                await storage.write(key: 'user_id', value: uid.toString());
                await storage.delete(key: 'staff_id');
              }
              if (brid != null) await storage.write(key: 'branch_id', value: brid.toString());
            }

            if (bid != null) {
              BusinessConfig.instance.businessId = bid;
              await storage.write(key: 'business_id', value: bid.toString());
              
              // [FIX] Ensure user-business link exists locally after sync
              if (uid != null) {
                await _dbHelper.addUserBusiness(uid, bid);
              }
            }
            await storage.write(key: 'user_email', value: u['email']);
          }

          await _dbHelper.loadSettings();
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
          errorMessage = data['message'] ?? data['errors']?.toString() ?? errorMessage;
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
      if (e is DioException && e.response?.statusCode == 422) {
        print('💡 [LOGIN] Login mismatch/missing, checking for auto-signup...');

        final localUser = await _dbHelper.getUserByEmail(email);
        if (localUser != null && localUser['is_synced'] == 0) {
          print('📝 [LOGIN] Attempting auto-signup for local-only user...');
          try {
            await _api.signup(
              email: email,
              password: password,
              businessName:
                  BusinessConfig.instance.businessName ?? 'My Business',
              businessType: BusinessConfig.instance.businessType ?? 'general',
            );
            print('✅ [LOGIN] Backend signup successful');
            await _dbHelper.updateUserSyncStatus(localUser['id'], 1);
            return;
          } catch (signupError) {
            print('❌ [LOGIN] Auto-signup failed: $signupError');
          }
        }
      }
      print('⚠️ [LOGIN] Backend sync failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          theme.glassBackground(
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo Section - compact row
                          Center(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.store_rounded,
                                        color: theme.iconColor, size: 32),
                                    const SizedBox(width: 12),
                                    Text(
                                      'SATA POS',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: theme.textPrimary,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Premium Point of Sale',
                                  style: TextStyle(
                                    color: theme.textSecondary.withOpacity(0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                if (kIsWeb)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: ThemeProvider.warning.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                                      border: Border.all(
                                          color: ThemeProvider.warning
                                              .withOpacity(0.3)),
                                    ),
                                    child: const Text(
                                      'WEB DEMO MODE',
                                      style: TextStyle(
                                        color: ThemeProvider.warning,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                        // Saved Accounts Display
                        if (_savedAccounts.isNotEmpty && !_showLoginForm) ...[
                          Text(
                            'QUICK LOGIN',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              alignment: WrapAlignment.center,
                              children: _savedAccounts.map((acc) {
                                  return Stack(
                                    children: [
                                      InkWell(
                                        onTap: () => _handleQuickLogin(acc),
                                        borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                                        child: Container(
                                          width: 120,
                                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: theme.surface.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                                            border: Border.all(color: theme.highlight.withOpacity(0.3), width: 1.5),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.05),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: theme.highlight.withOpacity(0.2),
                                                radius: 32,
                                                child: Icon(Icons.person_rounded, color: theme.highlight, size: 36),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                acc['name'],
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: theme.textPrimary,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Tap to Login',
                                                style: TextStyle(
                                                  color: theme.highlight,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: IconButton(
                                          icon: Icon(Icons.close_rounded, size: 18, color: theme.textHint),
                                          onPressed: () => _deleteAccount(acc),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ),
                                    ],
                                  );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Login Card or Toggle Button
                        if (_showLoginForm) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: theme.glassDecoration,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Text(
                                'SIGN IN',
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 12),

                              if (!kIsWeb) ...[
                                TextFormField(
                                  controller: _emailCtrl,
                                  style: TextStyle(
                                      color: theme.textPrimary,
                                      fontWeight: FontWeight.w500),
                                  decoration: theme.glassInputDecoration(
                                      'Email Address', Icons.email_outlined),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passCtrl,
                                  obscureText: _obscurePassword,
                                  style: TextStyle(
                                      color: theme.textPrimary,
                                      fontWeight: FontWeight.w500),
                                  decoration: theme
                                      .glassInputDecoration(
                                          'Password', Icons.lock_outlined)
                                      .copyWith(
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: theme.iconColor,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(() =>
                                              _obscurePassword =
                                                  !_obscurePassword),
                                        ),
                                      ),
                                ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                          activeColor: theme.highlight,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('Remember Me', style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () {},
                                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                        child: Text(
                                          'Forgot Password?',
                                          style: TextStyle(
                                              color: theme.highlight,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],

                              const SizedBox(height: 12),

                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.highlight,
                                    foregroundColor: Colors.white,
                                    elevation: 8,
                                    shadowColor:
                                        theme.highlight.withOpacity(0.4),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(ThemeProvider.radiusList)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        kIsWeb ? 'START DEMO' : 'SIGN IN',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2),
                                      ),
                                      const SizedBox(width: 12),
                                      const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                          Center(
                            child: TextButton.icon(
                              onPressed: () => setState(() => _showLoginForm = true),
                              icon: Icon(Icons.add_circle_outline_rounded, color: theme.highlight),
                              label: Text(
                                'Login with another account',
                                style: TextStyle(
                                  color: theme.highlight,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                                backgroundColor: theme.surface.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Footer Section
                        if (!kIsWeb)
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Don\'t have an account?',
                                  style: TextStyle(
                                      color: theme.textSecondary,
                                      fontWeight: FontWeight.w500),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => const SignupScreen()),
                                  ),
                                  child: Text(
                                    'Create Account',
                                    style: TextStyle(
                                        color: theme.highlight,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Theme toggle
                        Center(
                          child: GestureDetector(
                            onTap: () => setState(() => theme.toggleTheme()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.surface.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: theme.textHint.withOpacity(0.1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    theme.isDark
                                        ? Icons.light_mode_rounded
                                        : Icons.dark_mode_rounded,
                                    color: theme.iconColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    theme.isDark ? 'LIGHT MODE' : 'DARK MODE',
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: theme.highlight),
                      const SizedBox(height: 20),
                      Text(
                        'Authenticating...',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
