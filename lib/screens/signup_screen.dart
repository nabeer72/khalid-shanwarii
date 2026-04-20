import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:mobile_app/services/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_app/services/sync_service.dart';
import 'package:mobile_app/screens/home_screen.dart';
import 'package:mobile_app/screens/setup_profile_screen.dart';
import 'package:mobile_app/widgets/pin_dialogs.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final theme = ThemeProvider.instance;
  final _businessNameCtrl = TextEditingController(text: 'General Store');
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _api = ApiService();
  final _dbHelper = DatabaseHelper.instance;
  final _storage = const FlutterSecureStorage();
  final _connectivity = ConnectivityService.instance;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedBusinessType = 'general';
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<Map<String, dynamic>> _businessTypes = [
    {
      'id': 'general',
      'name': 'General Store',
      'icon': '🏪',
      'desc': 'Retail, convenience'
    },
    {
      'id': 'garments',
      'name': 'Garments',
      'icon': '👕',
      'desc': 'Clothing, fashion'
    },
    {
      'id': 'produce',
      'name': 'Produce',
      'icon': '🥬',
      'desc': 'Fruits, vegetables'
    },
    {
      'id': 'restaurant',
      'name': 'Restaurant',
      'icon': '🍽️',
      'desc': 'Food, cafe, bakery'
    },
    {
      'id': 'electronics',
      'name': 'Electronics',
      'icon': '📱',
      'desc': 'Gadgets, tech'
    },
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _businessNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _signup() async {
    // Validate fields
    if (_businessNameCtrl.text.isEmpty) {
      _showError('Please enter a business name');
      return;
    }
    
    final email = _emailCtrl.text.trim();
    final cleanEmail = email.toLowerCase();
    if (email.isEmpty) {
      _showError('Please enter an email');
      return;
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }
    if (_passCtrl.text.isEmpty) {
      _showError('Please enter a password');
      return;
    }
    if (_passCtrl.text != _confirmPassCtrl.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _loading = true);

    try {
      // Check if email already exists locally for immediate feedback
      final localUser = await _dbHelper.getUserByEmail(cleanEmail);
      if (localUser != null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Account Exists'),
              content: const Text('An account with this email already exists locally. Please login instead.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        setState(() => _loading = false);
        return;
      }

      // Check connection status
      final status = await _connectivity.getConnectionStatus();
      print('🌐 [SIGNUP] Connection status: $status');

      if (status == ConnectionStatus.offline) {
        _showError('No internet connection. Signup requires internet to register your account.');
        setState(() => _loading = false);
        return;
      }

      // Show PIN dialog before proceeding
      if (mounted) {
        _showSetPinDialog(cleanEmail);
      }
    } catch (e) {
      if (mounted) {
        print('❌ [SIGNUP] Validation error: $e');
        _showError('Validation failed: $e');
        setState(() => _loading = false);
      }
    }
  }

  void _showSetPinDialog(String cleanEmail) async {
    final pin = await PinDialogs.showSetupPinDialog(context);
    if (pin != null) {
      _proceedSignup(cleanEmail, pin);
    } else {
      setState(() => _loading = false);
    }
  }

  void _proceedSignup(String cleanEmail, String pin) async {
    setState(() => _loading = true);

    try {
      // IDs will be generated by the database
      int? businessId;
      int? userId;
      int? branchId;
      final String now = DateTime.now().toIso8601String();

      bool apiSuccess = false;
      int isSynced = 0;

      // Online & Fast (or slow), now REQUIRED to try API first
      try {
        final response = await _api
            .signup(
              email: cleanEmail,
              password: _passCtrl.text,
              businessName: _businessNameCtrl.text,
              businessType: _selectedBusinessType,
              pin: pin,
            )
            .timeout(const Duration(seconds: 15));

        if (response?.statusCode == 200 || response?.statusCode == 201) {
          apiSuccess = true;
          isSynced = 1;
          print('✅ [SIGNUP] API signup successful');

          if (response?.data['token'] != null) {
            await _storage.write(
                key: 'auth_token', value: response!.data['token']);
          }
          if (response?.data['user']?['id'] != null) {
            userId = int.tryParse(response!.data['user']['id'].toString());
          }
          if (response?.data['user']?['business_id'] != null) {
            businessId = int.tryParse(response!.data['user']['business_id'].toString());
          }
          if (response?.data['user']?['branch_id'] != null) {
            branchId = int.tryParse(response!.data['user']['branch_id'].toString());
            await _storage.write(key: 'branch_id', value: branchId.toString());
          }
        } else {
           _showError('Signup failed: ${response?.data['message'] ?? 'Server error'}');
           setState(() => _loading = false);
           return;
        }
      } catch (e) {
        print('⚠️ [SIGNUP] API signup error: $e');
        String errMsg = 'Signup failed. Please try again.';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map) {
            if (data['message']?.toString().contains('already exists') == true || 
                data['errors']?.toString().contains('taken') == true) {
               errMsg = 'An account with this email already exists. Please login instead.';
            } else {
               errMsg = data['message'] ?? data['errors']?.toString() ?? errMsg;
            }
          } else if (e.type == DioExceptionType.connectionTimeout) {
            errMsg = 'Connection timed out. Please check your internet.';
          } else if (e.type == DioExceptionType.connectionError) {
            errMsg = 'Unable to connect to server. Internet required for signup.';
          }
        }
        _showError(errMsg);
        setState(() => _loading = false);
        return;
      }

      // If we made it here, API was successful (apiSuccess should be true)
      if (!apiSuccess) {
         _showError('Signup failed. Please try again later.');
         setState(() => _loading = false);
         return;
      }

      // Save business to local database
      final businessData = {
        if (businessId != null) 'id': businessId,
        if (userId != null) 'owner_user_id': userId,
        'name': _businessNameCtrl.text,
        'business_type': _selectedBusinessType,
        'status': 1,
        'created_at': now,
        'updated_at': now,
      };
      
      final insertedBusinessId = await _dbHelper.insertBusiness(businessData, isSynced: isSynced);
      businessId ??= insertedBusinessId;

      // Save user to local database (must be done before branch to get userId for admin_id)
      final userData = {
        if (userId != null) 'id': userId,
        'business_id': businessId,
        'name': _businessNameCtrl.text,
        'email': cleanEmail,
        'password': _passCtrl.text,
        'pin': pin,
        'role': 'admin',
        'status': 1,
        'created_at': now,
        'updated_at': now,
      };

      final insertedUserId = await _dbHelper.insertUser(userData, isSynced: isSynced);
      userId ??= insertedUserId;

      // If we just generated the userId locally, we should update the business's owner
      // ignore: unnecessary_null_comparison
      if (insertedUserId != null) {
        final db = await _dbHelper.database;
        await db.update('businesses', {'owner_user_id': userId}, where: 'id = ?', whereArgs: [businessId]);
      }

      // Create a default Main Branch for the business
      branchId ??= 1; // Use API branch ID if available, else fallback to 1
      final branchData = {
        'id': branchId,
        'business_id': businessId,
        'user_id': userId,
        'name': 'Main Branch',
        'branch_title': 'Main Branch',
        'branch_code': 'MAIN',
        'status': 1,
        'is_main_branch': '1',
        'created_at': now,
        'updated_at': now,
      };

      await _dbHelper.insertBranch(branchData);

      // Ensure branch insertion is synced if API was successful
      // ignore: unnecessary_null_comparison
      if (isSynced == 1 && branchId != null) {
          final db = await _dbHelper.database;
          await db.update('branches', {'is_synced': 1}, where: 'id = ?', whereArgs: [branchId]);
      }

      // [FIX] Establish user-business link if missing
      // ignore: unnecessary_null_comparison
      if (userId != null && businessId != null) {
        await _dbHelper.addUserBusiness(userId, businessId);
      }

      // Store unit IDs and email in secure storage
      await _storage.write(key: 'user_id', value: userId.toString());
      await _storage.write(key: 'user_email', value: cleanEmail);
      await _storage.write(key: 'business_id', value: businessId.toString());

      // Set business configuration using centralized setContext
      BusinessConfig.instance.setContext(
        bid: businessId,
        uid: userId,
        brid: branchId,
        bName: _businessNameCtrl.text,
        bType: _selectedBusinessType,
        activeBranches: [branchId],
      );

      // Persist to settings table
      await _dbHelper.setSetting('business_name', _businessNameCtrl.text);
      await _dbHelper.setSetting('business_type', _selectedBusinessType);

      // [FIX] Save the account for Quick Login after successful signup
      try {
        final jsonStr = await _storage.read(key: 'saved_accounts');
        List<Map<String, dynamic>> accounts = [];
        if (jsonStr != null) {
          accounts = List<Map<String, dynamic>>.from(jsonDecode(jsonStr));
        }

        // Remove if exists (unlikely in signup but safe)
        accounts.removeWhere((acc) => acc['email'].toString().toLowerCase().trim() == cleanEmail);

        accounts.add({
          'email': cleanEmail,
          'password': _passCtrl.text,
          'pin': pin,
          'name': _businessNameCtrl.text,
          'business_id': businessId,
          'branch_id': branchId,
        });

        await _storage.write(key: 'saved_accounts', value: jsonEncode(accounts));
        print('💾 [SIGNUP] New account saved for Quick Login');
      } catch (e) {
        print('⚠️ [SIGNUP] Failed to save account for Quick Login: $e');
      }

      // Navigate to home screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Account created and synced successfully!'),
        ));
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SetupProfileScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        print('❌ [SIGNUP] Signup error: $e');
        _showError('Signup failed: $e');
        setState(() => _loading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: ThemeProvider.error));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.background, theme.surface],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row with back button and title
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(Icons.arrow_back_rounded,
                                  color: theme.iconColor),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.person_add_rounded,
                                color: theme.iconColor, size: 28),
                            const SizedBox(width: 10),
                            Text('Create Account',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textPrimary)),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Business Type Selection
                        Text('Select Your Business Type',
                            style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _businessTypes.length,
                            itemBuilder: (ctx, i) {
                              final bt = _businessTypes[i];
                              final selected =
                                  _selectedBusinessType == bt['id'];
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedBusinessType = bt['id'];
                                    // Auto-fill business name based on selected type
                                    _businessNameCtrl.text = bt['name'];
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 72,
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? ThemeProvider.businessColors[bt['id']]
                                        : theme.card,
                                    borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                                    border: Border.all(
                                        color: selected
                                            ? ThemeProvider
                                                .businessColors[bt['id']]!
                                            : theme.divider,
                                        width: 2),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                                color: ThemeProvider
                                                    .businessColors[bt['id']]!
                                                    .withAlpha(60),
                                                blurRadius: 12)
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(bt['icon'],
                                          style: const TextStyle(fontSize: 20)),
                                      const SizedBox(height: 2),
                                      Text(bt['name'],
                                          style: TextStyle(
                                              color: selected
                                                  ? Colors.white
                                                  : theme.textPrimary,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600),
                                          textAlign: TextAlign.center),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Business Name
                        Text('Business Name',
                            style: TextStyle(
                                color: theme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 2),
                        TextField(
                          controller: _businessNameCtrl,
                          style: TextStyle(color: theme.textPrimary),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                            hintText: 'Enter your business name',
                            hintStyle: TextStyle(color: theme.textHint),
                            prefixIcon: Icon(Icons.store_outlined,
                                color: theme.iconColor),
                            filled: true,
                            fillColor: theme.card,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
                                borderSide: BorderSide(
                                    color: theme.isDark
                                        ? Colors.transparent
                                        : Colors.black.withOpacity(0.3))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
                                borderSide: BorderSide(
                                    color: theme.isDark
                                        ? theme.highlight
                                        : Colors.black.withOpacity(0.6),
                                    width: 2)),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Email
                        Text('Email',
                            style: TextStyle(
                                color: theme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 2),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: theme.textPrimary),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                            hintText: 'admin@example.com',
                            hintStyle: TextStyle(color: theme.textHint),
                            prefixIcon: Icon(Icons.email_outlined,
                                color: theme.iconColor),
                            filled: true,
                            fillColor: theme.card,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
                                borderSide: BorderSide(
                                    color: theme.isDark
                                        ? Colors.transparent
                                        : Colors.black.withOpacity(0.3))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
                                borderSide: BorderSide(
                                    color: theme.isDark
                                        ? theme.highlight
                                        : Colors.black.withOpacity(0.6),
                                    width: 2)),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Password
                        Text('Password',
                            style: TextStyle(
                                color: theme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 2),
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: theme.textPrimary),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                            hintText: '••••••••',
                            hintStyle: TextStyle(color: theme.textHint),
                            prefixIcon: Icon(Icons.lock_outlined,
                                color: theme.iconColor),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: theme.iconColor,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: theme.card,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
                                borderSide: BorderSide(
                                    color: theme.isDark
                                        ? Colors.transparent
                                        : Colors.black.withOpacity(0.3))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
                                borderSide: BorderSide(
                                    color: theme.isDark
                                        ? theme.highlight
                                        : Colors.black.withOpacity(0.6),
                                    width: 2)),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Confirm Password
                        Text('Confirm Password',
                            style: TextStyle(
                                color: theme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 2),
                        TextField(
                          controller: _confirmPassCtrl,
                          obscureText: _obscureConfirmPassword,
                          style: TextStyle(color: theme.textPrimary),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                            hintText: '••••••••',
                            hintStyle: TextStyle(color: theme.textHint),
                            prefixIcon: Icon(Icons.lock_outlined,
                                color: theme.iconColor),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: theme.iconColor,
                              ),
                              onPressed: () => setState(() =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword),
                            ),
                            filled: true,
                            fillColor: theme.card,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
                                borderSide: BorderSide(
                                    color: theme.isDark
                                        ? Colors.transparent
                                        : Colors.black.withOpacity(0.3))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
                                borderSide: BorderSide(
                                    color: theme.isDark
                                        ? theme.highlight
                                        : Colors.black.withOpacity(0.6),
                                    width: 2)),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Signup Button
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: _loading
                              ? Center(
                                  child: CircularProgressIndicator(
                                      color: theme.highlight))
                              : ElevatedButton(
                                  onPressed: _signup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ThemeProvider
                                        .businessColors[_selectedBusinessType],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(ThemeProvider.radiusList)),
                                    elevation: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Text('CREATE ACCOUNT',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold)),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded, size: 20),
                                    ],
                                  ),
                                ),
                        ),

                        const SizedBox(height: 8),

                        // Login link
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Already have an account? ',
                                  style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0)),
                                child: Text('Login',
                                    style: TextStyle(
                                        color: ThemeProvider.businessColors[
                                            _selectedBusinessType],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Theme toggle
                        Center(
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => theme.toggleTheme()),
                            icon: Icon(
                                theme.isDark
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                                color: theme.iconColor,
                                size: 16),
                            label: Text(
                                theme.isDark ? 'Light Mode' : 'Dark Mode',
                                style: TextStyle(color: theme.textSecondary, fontSize: 12)),
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
}
