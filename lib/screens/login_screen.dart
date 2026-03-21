import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  Future<void> _proceedToHome(bool isQuickLogin, String email) async {
    if (!mounted) return;
    
    print('🏠 [LOGIN] Auth successful, checking saved credentials...');
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

    setState(() => _loading = true);
    print('⏳ [LOGIN] Loading state set to true');

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();
    final cleanEmail = email.toLowerCase();

    try {
      // First, try local authentication (for offline signup users)
      print('🔍 [LOGIN] Checking local database for User...');
      final localUser = await _dbHelper.getUserByEmail(cleanEmail);

      if (localUser != null) {
        print('👤 [LOGIN] Found user in local database');
        // Check password (in production, use proper hashing)
        if (localUser['password'] == password) {
          print('✅ [LOGIN] Local authentication successful!');

          // Store user session
          await _storage.write(key: 'user_id', value: localUser['id'].toString());
          await _storage.write(key: 'user_email', value: localUser['email']);
          await _storage.write(
              key: 'business_id', value: localUser['business_id'].toString());

          // Load business info
          if (localUser['business_id'] != null) {
            final business =
                await _dbHelper.getBusiness(localUser['business_id']);
            if (business != null) {
              BusinessConfig.instance.businessType =
                  business['business_type'] ?? 'general';
              BusinessConfig.instance.businessName =
                  business['name'] ?? 'My Business';
            }
          }

          BusinessConfig.instance.adminId = localUser['id'];
          BusinessConfig.instance.staffId = null; // Admin login
          await _storage.delete(key: 'staff_id');

          if (localUser['branch_id'] != null) {
            final String bid = localUser['branch_id'].toString();
            await _storage.write(key: 'branch_id', value: bid);
          }

          // Load user settings (currency, etc.)
          await _dbHelper.loadSettings();

          // Background Sync: Verify credentials or push/pull data in background
          _syncLoginToBackend();
          SyncService().syncPull().then((_) => _dbHelper.loadSettings()).catchError((e) {
            print('⚠️ [LOGIN] Background sync failed (offline?): $e');
          });

          await _proceedToHome(isQuickLogin, email);
          return;
        } else {
          print('❌ [LOGIN] Local password mismatch');
        }
      } else {
        print('💡 [LOGIN] User not found locally, checking for Staff...');
        // Try Staff Login (Email + PIN/Password)
        final staff =
            await _dbHelper.getEmployeeByEmailAndPin(cleanEmail, password);
        if (staff != null) {
          print('👤 [LOGIN] Staff member found!');

          // Store staff session
          await _storage.write(
              key: 'user_id', value: staff['admin_id']); // Context is admin
          await _storage.write(key: 'staff_id', value: staff['id']);
          await _storage.write(key: 'user_email', value: staff['email']);
          await _storage.write(key: 'business_id', value: staff['business_id']);

          // Initialize BusinessConfig for Staff
          BusinessConfig.instance.adminId = staff['admin_id']; // For data isolation
          BusinessConfig.instance.staffId = staff['id']; // For identity

          if (staff['branch_id'] != null) {
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
      }

      // If local auth fails or user not found, try API
      print('📡 [LOGIN] Calling API login...');
      await _api.login(email, password);
      print('✅ [LOGIN] API call successful!');

      // Start initial sync to get company data and settings
      print('🔄 [LOGIN] Running initial sync...');
      final pullData = await SyncService().syncPull();

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

            if (uid != null) {
              if (aid != null && aid != uid) {
                BusinessConfig.instance.adminId = aid;
                BusinessConfig.instance.staffId = uid;
                BusinessConfig.instance.branchId = brid;
                await storage.write(key: 'user_id', value: aid.toString());
                await storage.write(key: 'staff_id', value: uid.toString());
              } else {
                BusinessConfig.instance.adminId = uid;
                BusinessConfig.instance.staffId = null;
                BusinessConfig.instance.branchId = brid;
                await storage.write(key: 'user_id', value: uid.toString());
                await storage.delete(key: 'staff_id');
              }
              if (brid != null) await storage.write(key: 'branch_id', value: brid.toString());
            }

            if (bid != null) {
              BusinessConfig.instance.businessId = bid;
              await storage.write(key: 'business_id', value: bid.toString());
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
      print('🔍 [LOGIN] Error type: ${e.runtimeType}');
      if (mounted) {
        print('📱 [LOGIN] Showing error snackbar');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Invalid credentials'),
            backgroundColor: ThemeProvider.error));
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
    final email = _emailCtrl.text.trim();
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
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Logo Section
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: theme.isDark
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                                      border: Border.all(
                                          color: theme.iconColor.withOpacity(0.1)),
                                    ),
                                    child: Icon(Icons.store_rounded,
                                        color: theme.iconColor, size: 52),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'SATA POS',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      color: theme.textPrimary,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  Text(
                                    'Premium Point of Sale',
                                    style: TextStyle(
                                      color: theme.textSecondary.withOpacity(0.8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  if (kIsWeb)
                                    Container(
                                      margin: const EdgeInsets.only(top: 12),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
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
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 32),

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
                            padding: const EdgeInsets.all(24),
                            decoration: theme.glassDecoration,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Text(
                                'SIGN IN',
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 24),

                              if (!kIsWeb) ...[
                                TextFormField(
                                  controller: _emailCtrl,
                                  style: TextStyle(
                                      color: theme.textPrimary,
                                      fontWeight: FontWeight.w500),
                                  decoration: theme.glassInputDecoration(
                                      'Email Address', Icons.email_outlined),
                                ),
                                const SizedBox(height: 20),
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
                                  const SizedBox(height: 20),
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

                              const SizedBox(height: 16),

                              SizedBox(
                                width: double.infinity,
                                height: 60,
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

                        const SizedBox(height: 32),

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
