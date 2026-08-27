import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:mobile_app/services/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_app/services/sync_service.dart';
import 'package:mobile_app/screens/setup_profile_screen.dart';
import 'package:mobile_app/widgets/pin_dialogs.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/screens/payment_invoice_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final theme = ThemeProvider.instance;
  final _businessNameCtrl = TextEditingController(text: 'General Store');
  final _ownerNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
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
  int? _selectedBusinessTypeId;
  List<dynamic> _businessTypes = [];
  List<dynamic> _subscriptionPlans = [];
  bool _fetchingTypes = true;
  bool _fetchingPlans = true;
  int? _selectedPlanId;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _plansScrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _loadInitialData();
  }

  void _loadInitialData() {
    final config = BusinessConfig.instance;
    
    if (config.businessTypes.isNotEmpty) {
      setState(() {
        _businessTypes = config.businessTypes;
        _selectedBusinessTypeId = _businessTypes[0]['id'];
        _businessNameCtrl.text = _businessTypes[0]['name'];
        _fetchingTypes = false;
      });
    } else {
      _fetchBusinessTypes();
    }

    if (config.subscriptionPlans.isNotEmpty) {
      setState(() {
        _subscriptionPlans = config.subscriptionPlans;
        final freePlan = _subscriptionPlans.firstWhere(
          (p) => (p['price'] as num) <= 0,
          orElse: () => _subscriptionPlans[0]
        );
        _selectedPlanId = freePlan['id'];
        _fetchingPlans = false;
      });
    } else {
      _fetchSubscriptionPlans();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    _plansScrollController.dispose();
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _fetchBusinessTypes() async {
    try {
      final response = await _api.getBusinessTypes();
      if (response != null && response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _businessTypes = response.data;
            if (_businessTypes.isNotEmpty) {
              _selectedBusinessTypeId = _businessTypes[0]['id'];
              _businessNameCtrl.text = _businessTypes[0]['name'];
            }
            _fetchingTypes = false;
          });
        }
      }
    } catch (e) {
      print('❌ [SIGNUP] Failed to fetch types: $e');
      if (mounted) setState(() => _fetchingTypes = false);
    }
  }

  void _fetchSubscriptionPlans() async {
    try {
      final response = await _api.getSubscriptionPlans();
      if (response != null && response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _subscriptionPlans = response.data;
            if (_subscriptionPlans.isNotEmpty) {
              final freePlan = _subscriptionPlans.firstWhere(
                (p) => (p['price'] as num) <= 0,
                orElse: () => _subscriptionPlans[0]
              );
              _selectedPlanId = freePlan['id'];
            }
            _fetchingPlans = false;
          });
        }
      }
    } catch (e) {
      print('❌ [SIGNUP] Failed to fetch plans: $e');
      if (mounted) setState(() => _fetchingPlans = false);
    }
  }

  String _getIcon(String name) {
    name = name.toLowerCase();
    if (name.contains('garment')) return '👕';
    if (name.contains('footwear')) return '👞';
    if (name.contains('cosmetic')) return '💄';
    if (name.contains('restaurant')) return '🍽️';
    if (name.contains('pharmacy')) return '💊';
    if (name.contains('electronic')) return '📱';
    if (name.contains('retail')) return '🏪';
    return '🏢';
  }

  Color _getColor(String name) {
    name = name.toLowerCase();
    if (name.contains('garment')) return const Color(0xFFE91E63);
    if (name.contains('footwear')) return const Color(0xFF795548);
    if (name.contains('cosmetic')) return const Color(0xFF9C27B0);
    if (name.contains('restaurant')) return const Color(0xFFFF5722);
    if (name.contains('pharmacy')) return const Color(0xFF009688);
    if (name.contains('electronic')) return const Color(0xFF2196F3);
    if (name.contains('retail')) return const Color(0xFF4CAF50);
    return const Color(0xFF1A73E8);
  }

  void _signup() async {
    if (_businessNameCtrl.text.trim().isEmpty) { _showError('Please enter a business name'); return; }
    if (_ownerNameCtrl.text.trim().length < 3) { _showError('Owner name must be at least 3 characters'); return; }
    if (_selectedBusinessTypeId == null) { _showError('Please select a business type'); return; }
    if (_selectedPlanId == null) { _showError('Please select a subscription plan'); return; }
    
    final email = _emailCtrl.text.trim();
    final cleanEmail = email.toLowerCase();
    if (email.isEmpty) { _showError('Please enter an email'); return; }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) { _showError('Please enter a valid email address'); return; }
    if (_passCtrl.text.length < 8) { _showError('Password must be at least 8 characters'); return; }
    if (_passCtrl.text != _confirmPassCtrl.text) { _showError('Passwords do not match'); return; }

    setState(() => _loading = true);

    try {
      final localUser = await _dbHelper.getUserByEmail(cleanEmail);
      if (localUser != null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Account Exists'),
              content: const Text('An account with this email already exists locally. Please login instead.'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
            ),
          );
        }
        setState(() => _loading = false);
        return;
      }

      final status = await _connectivity.getConnectionStatus();
      if (status == ConnectionStatus.offline) {
        _showError('No internet connection. Internet required for signup.');
        setState(() => _loading = false);
        return;
      }

      if (mounted) _showSetPinDialog(cleanEmail);
    } catch (e) {
      if (mounted) { _showError('Validation failed: $e'); setState(() => _loading = false); }
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
      int? businessId;
      int? userId;
      int? branchId;
      final String now = DateTime.now().toIso8601String();
      bool apiSuccess = false;
      int isSynced = 0;
      Response? response;

      try {
        response = await _api.signup(
          email: cleanEmail,
          password: _passCtrl.text,
          name: _ownerNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          businessName: _businessNameCtrl.text.trim(),
          businessTypeId: _selectedBusinessTypeId!,
          planId: _selectedPlanId!,
          pin: pin,
        ).timeout(const Duration(seconds: 15));

        if (response?.statusCode == 200 || response?.statusCode == 201) {
          apiSuccess = true;
          isSynced = 1;
          if (response?.data['token'] != null) {
            await _storage.write(key: 'auth_token', value: response!.data['token']);
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
          }
        }
        _showError(errMsg);
        setState(() => _loading = false);
        return;
      }

      if (!apiSuccess) return;

      final businessData = {
        if (businessId != null) 'id': businessId,
        if (userId != null) 'owner_user_id': userId,
        'name': _businessNameCtrl.text,
        'business_type_id': _selectedBusinessTypeId,
        'status': 1,
        'created_at': now,
        'updated_at': now,
      };
      final insertedBusinessId = await _dbHelper.insertBusiness(businessData, isSynced: isSynced);
      businessId ??= insertedBusinessId;

      final userData = {
        if (userId != null) 'id': userId,
        'business_id': businessId,
        'name': _ownerNameCtrl.text.trim(),
        'email': cleanEmail,
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'password': _passCtrl.text,
        'pin': pin,
        'role': 'admin',
        'status': 1,
        'created_at': now,
        'updated_at': now,
      };
      final insertedUserId = await _dbHelper.insertUser(userData, isSynced: isSynced);
      userId ??= insertedUserId;

      final businessName = _businessNameCtrl.text.trim();
      final storeAddress = _addressCtrl.text.trim();
      final storePhone = _phoneCtrl.text.trim();

      branchId ??= 1;
      final branchData = {
        'id': branchId,
        'business_id': businessId,
        'user_id': userId,
        'name': 'Main Branch',
        'branch_title': 'Main Branch',
        'branch_code': 'MAIN',
        if (storeAddress.isNotEmpty) 'branch_address': storeAddress,
        if (storePhone.isNotEmpty) 'contact_number': storePhone,
        'status': 1,
        'is_main_branch': '1',
        'created_at': now,
        'updated_at': now,
      };
      await _dbHelper.insertBranch(branchData);

      await _dbHelper.addUserBusiness(userId!, businessId!);
      await _storage.write(key: 'user_id', value: userId.toString());
      await _storage.write(key: 'user_email', value: cleanEmail);
      await _storage.write(key: 'business_id', value: businessId.toString());
      await _storage.delete(key: 'staff_id');

      BusinessConfig.instance.setContext(
        bid: businessId,
        uid: userId,
        brid: branchId,
        bName: businessName,
        bType: _selectedBusinessTypeId.toString(),
        activeBranches: [branchId],
      );
      BusinessConfig.instance.staffId = null;
      BusinessConfig.instance.businessName = businessName;
      BusinessConfig.instance.businessAddress = storeAddress;
      BusinessConfig.instance.businessPhone = storePhone;

      await _dbHelper.setSetting('business_name', businessName);
      if (storeAddress.isNotEmpty) {
        await _dbHelper.setSetting('business_address', storeAddress);
      }
      if (storePhone.isNotEmpty) {
        await _dbHelper.setSetting('business_phone', storePhone);
      }

      if (mounted) {
        // If it was a paid plan, navigate to Invoice Payment screen
        final plan = _subscriptionPlans.firstWhere((p) => p['id'] == _selectedPlanId, orElse: () => null);
        final subId = response?.data['subscription_id'];
        
        if (plan != null && (plan['price'] as num) > 0 && subId != null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => PaymentInvoiceScreen(
              subscriptionId: int.parse(subId.toString()),
              plan: plan,
            )),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SetupProfileScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) { _showError('Signup failed: $e'); setState(() => _loading = false); }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: ThemeProvider.error));
  }

  Widget _buildScrollButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: theme.card.withOpacity(0.8),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: IconButton(
        icon: Icon(icon, color: theme.highlight, size: 24),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildBusinessTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Your Business Type',
            style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: _fetchingTypes
                    ? Center(child: CircularProgressIndicator(color: theme.highlight))
                    : Row(
                        children: _businessTypes.map((bt) {
                          final typeId = bt['id'] as int;
                          final typeName = bt['name'] as String;
                          final selected = _selectedBusinessTypeId == typeId;
                          final bColor = theme.highlight;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedBusinessTypeId = typeId;
                                _businessNameCtrl.text = typeName;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 85,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? bColor : theme.card,
                                borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                                border: Border.all(color: selected ? bColor : theme.divider, width: 2),
                                boxShadow: selected ? [BoxShadow(color: bColor.withAlpha(60), blurRadius: 12)] : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_getIcon(typeName), style: const TextStyle(fontSize: 24)),
                                  const SizedBox(height: 4),
                                  Text(typeName,
                                      style: TextStyle(
                                          color: selected ? Colors.white : theme.textPrimary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            Positioned(
              left: 0,
              child: _buildScrollButton(Icons.chevron_left_rounded, () {
                _scrollController.animateTo(_scrollController.offset - 100, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              }),
            ),
            Positioned(
              right: 0,
              child: _buildScrollButton(Icons.chevron_right_rounded, () {
                _scrollController.animateTo(_scrollController.offset + 100, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlanSelectionColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose Subscription Plan',
            style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_fetchingPlans)
          Center(child: CircularProgressIndicator(color: theme.highlight))
        else
          ..._subscriptionPlans.map((plan) {
            final isSelected = _selectedPlanId == plan['id'];
            final isFree = (plan['price'] as num) <= 0;
            return GestureDetector(
              onTap: () => setState(() => _selectedPlanId = plan['id']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? theme.highlight.withOpacity(0.1) : theme.card,
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                  border: Border.all(color: isSelected ? theme.highlight : theme.divider, width: 2),
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
                              Text(plan['name'], style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(plan['description'] ?? '', 
                                  style: TextStyle(color: theme.textSecondary, fontSize: 11),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        if (isSelected) Icon(Icons.check_circle_rounded, color: theme.highlight, size: 24),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(isFree ? 'FREE TRIAL' : '${BusinessConfig.instance.currencyDisplay} ${plan['price']} / ${plan['interval']}',
                        style: TextStyle(color: theme.highlight, fontSize: 16, fontWeight: FontWeight.w900)),
                    if (isSelected && plan['features'] != null) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      ...(plan['features'] as List).take(3).map((feat) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.check, size: 12, color: theme.highlight),
                            const SizedBox(width: 8),
                            Expanded(child: Text(feat, style: TextStyle(color: theme.textSecondary, fontSize: 11))),
                          ],
                        ),
                      )).toList(),
                    ],
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 20),
      ],
    );
  }


  Widget _buildPlanCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose Subscription Plan',
            style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: _fetchingPlans 
                ? Center(child: CircularProgressIndicator(color: theme.highlight))
                : SingleChildScrollView(
                    controller: _plansScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _subscriptionPlans.map((plan) {
                        final isSelected = _selectedPlanId == plan['id'];
                        final isFree = (plan['price'] as num) <= 0;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedPlanId = plan['id']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 160,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? theme.highlight.withOpacity(0.1) : theme.card,
                              borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                              border: Border.all(color: isSelected ? theme.highlight : theme.divider, width: 2),
                              boxShadow: isSelected ? [BoxShadow(color: theme.highlight.withAlpha(40), blurRadius: 10)] : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(plan['name'], style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(isFree ? 'FREE TRIAL' : '${BusinessConfig.instance.currencyDisplay} ${plan['price']} / ${plan['interval']}',
                                    style: TextStyle(color: theme.highlight, fontSize: 12, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 6),
                                Text(plan['description'] ?? '', 
                                  style: TextStyle(color: theme.textSecondary, fontSize: 9, fontStyle: FontStyle.italic),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 10, color: theme.textSecondary),
                                    const SizedBox(width: 4),
                                    Text('${plan['max_products'] ?? "∞"} Products', style: TextStyle(color: theme.textSecondary, fontSize: 10)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.store_outlined, size: 10, color: theme.textSecondary),
                                    const SizedBox(width: 4),
                                    Text('${plan['max_branches'] ?? "∞"} Branches', style: TextStyle(color: theme.textSecondary, fontSize: 10)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
            ),
            if (!_fetchingPlans) ...[
              Positioned(
                left: 0,
                child: _buildScrollButton(Icons.chevron_left_rounded, () {
                  _plansScrollController.animateTo(_plansScrollController.offset - 100, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }),
              ),
              Positioned(
                right: 0,
                child: _buildScrollButton(Icons.chevron_right_rounded, () {
                  _plansScrollController.animateTo(_plansScrollController.offset + 100, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }),
              ),
            ],
          ],
        ),
      ],
    );
  }


  Widget _buildSignupForm({bool showPlans = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Business Name', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        TextField(
          controller: _businessNameCtrl,
          style: TextStyle(color: theme.textPrimary),
          decoration: theme.glassInputDecoration('Business Name', Icons.store_outlined, isRequired: true).copyWith(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            hintText: 'Enter your business name',
            hintStyle: TextStyle(color: theme.textHint),
          ),
        ),
        const SizedBox(height: 8),
        Text('Owner / Admin Name', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        TextField(
          controller: _ownerNameCtrl,
          style: TextStyle(color: theme.textPrimary),
          textCapitalization: TextCapitalization.words,
          decoration: theme.glassInputDecoration('Owner Name', Icons.person_outlined, isRequired: true).copyWith(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            hintText: 'Your full name',
            hintStyle: TextStyle(color: theme.textHint),
          ),
        ),
        const SizedBox(height: 8),
        Text('Phone (optional)', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: theme.textPrimary),
          decoration: theme.glassInputDecoration('Phone', Icons.phone_outlined).copyWith(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            hintText: '+92 300 0000000',
            hintStyle: TextStyle(color: theme.textHint),
          ),
        ),
        const SizedBox(height: 8),
        Text('Store Address', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        TextField(
          controller: _addressCtrl,
          keyboardType: TextInputType.streetAddress,
          maxLines: 2,
          style: TextStyle(color: theme.textPrimary),
          decoration: theme.glassInputDecoration('Store Address', Icons.location_on_outlined).copyWith(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            hintText: 'Shop #, Street, City',
            hintStyle: TextStyle(color: theme.textHint),
          ),
        ),
        if (showPlans) ...[
          // left empty — plans now shown above the form on mobile
        ],
        const SizedBox(height: 8),
        Text('Email', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: theme.textPrimary),
          decoration: theme.glassInputDecoration('Email', Icons.email_outlined, isRequired: true).copyWith(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            hintText: 'admin@example.com',
            hintStyle: TextStyle(color: theme.textHint),
          ),
        ),
        const SizedBox(height: 8),
        Text('Password', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        TextField(
          controller: _passCtrl,
          obscureText: _obscurePassword,
          style: TextStyle(color: theme.textPrimary),
          decoration: theme.glassInputDecoration('Password', Icons.lock_outlined, isRequired: true).copyWith(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            hintText: '••••••••',
            hintStyle: TextStyle(color: theme.textHint),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: theme.iconColor),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Confirm Password', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        TextField(
          controller: _confirmPassCtrl,
          obscureText: _obscureConfirmPassword,
          style: TextStyle(color: theme.textPrimary),
          decoration: theme.glassInputDecoration('Confirm Password', Icons.lock_outlined, isRequired: true).copyWith(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            hintText: '••••••••',
            hintStyle: TextStyle(color: theme.textHint),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: theme.iconColor),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: _loading
              ? Center(child: CircularProgressIndicator(color: theme.highlight))
              : ElevatedButton(
                  onPressed: _signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.highlight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('CREATE ACCOUNT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account? ', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: Text('Login',
                    style: TextStyle(
                        color: theme.highlight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => theme.toggleTheme()),
            icon: Icon(theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: theme.iconColor, size: 16),
            label: Text(theme.isDark ? 'Light Mode' : 'Dark Mode', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.background, theme.surface], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 650;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.arrow_back_rounded, color: theme.iconColor), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                  const SizedBox(width: 12),
                                  Icon(Icons.person_add_rounded, color: theme.iconColor, size: 28),
                                  const SizedBox(width: 10),
                                  Text('Create Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        children: [
                                          _buildBusinessTypeSection(),
                                          const SizedBox(height: 24),
                                          _buildSignupForm(showPlans: false),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 32),
                                    Expanded(flex: 2, child: _buildPlanSelectionColumn()),
                                  ],
                                )
                              else ...[
                                _buildBusinessTypeSection(),
                                const SizedBox(height: 12),
                                _buildPlanCarousel(),
                                const SizedBox(height: 12),
                                _buildSignupForm(showPlans: false),
                              ],
                            ],
                          );
                        },
                      ),
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
