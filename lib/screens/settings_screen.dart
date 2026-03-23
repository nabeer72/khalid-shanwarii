import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/data/currency_list.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:mobile_app/widgets/pin_dialogs.dart';
import 'package:mobile_app/screens/currency_notes_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final theme = ThemeProvider.instance;
  
  // Settings state
  // Settings state
  String _businessName = BusinessConfig.instance.businessName;
  String _businessAddress = BusinessConfig.instance.businessAddress;
  String _businessPhone = BusinessConfig.instance.businessPhone;
  String _receiptFooter = BusinessConfig.instance.receiptFooter;
  double _taxRate = BusinessConfig.instance.taxRate;
  bool _requireCustomer = BusinessConfig.instance.requireCustomer;
  bool _autoReceipt = BusinessConfig.instance.autoReceipt;
  bool _openCashDrawer = BusinessConfig.instance.openCashDrawer;
  bool _soundEnabled = BusinessConfig.instance.soundEnabled;

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
      decoration: theme.glassInputDecoration(label, icon),
    );
  }

  void _showEditBusinessDialog() {
    final nameCtrl = TextEditingController(text: _businessName);
    final addressCtrl = TextEditingController(text: _businessAddress);
    final phoneCtrl = TextEditingController(text: _businessPhone);
    final footerCtrl = TextEditingController(text: _receiptFooter);

    InputDecoration _dialogInputDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        prefixIcon: Icon(icon, color: const Color(0xFF4B5563)),
        filled: true,
        fillColor: Colors.black.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
        ),
      );
    }

    Widget _buildDialogField(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboardType}) {
      return TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600),
        decoration: _dialogInputDecoration(label, icon),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
          ),
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Business Profile', 
                  style: TextStyle(color: Color(0xFF1F2937), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 24),
                _buildDialogField(nameCtrl, 'Business Name', Icons.store_rounded),
                const SizedBox(height: 16),
                _buildDialogField(addressCtrl, 'Physical Address', Icons.location_on_rounded),
                const SizedBox(height: 16),
                _buildDialogField(phoneCtrl, 'Contact Phone', Icons.phone_rounded, keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                _buildDialogField(footerCtrl, 'Receipt Footer Message', Icons.sticky_note_2_rounded),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('CANCEL', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeProvider.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                        ),
                        onPressed: () async {
                          setState(() {
                            _businessName = nameCtrl.text;
                            _businessAddress = addressCtrl.text;
                            _businessPhone = phoneCtrl.text;
                            _receiptFooter = footerCtrl.text;
                          });
                          
                          BusinessConfig.instance.businessName = _businessName;
                          BusinessConfig.instance.businessAddress = _businessAddress;
                          BusinessConfig.instance.businessPhone = _businessPhone;
                          BusinessConfig.instance.receiptFooter = _receiptFooter;

                          final db = DatabaseHelper.instance;
                          await db.setSetting('business_name', _businessName);
                          await db.setSetting('business_address', _businessAddress);
                          await db.setSetting('business_phone', _businessPhone);
                          await db.setSetting('receipt_footer', _receiptFooter);

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business info updated!'), backgroundColor: ThemeProvider.success));
                        },
                        child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCurrencyDialog() {
    InputDecoration _dialogInputDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        prefixIcon: Icon(icon, color: const Color(0xFF4B5563)),
        filled: true,
        fillColor: Colors.black.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        List<Currency> filteredList = currencyList;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              content: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                ),
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Currency', 
                      style: TextStyle(color: Color(0xFF1F2937), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 20),
                    TextField(
                      autofocus: true,
                      style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600),
                      decoration: _dialogInputDecoration('Search currency...', Icons.search_rounded),
                      onChanged: (val) {
                        setDialogState(() {
                          query = val.toLowerCase();
                          filteredList = currencyList.where((c) => 
                            c.name.toLowerCase().contains(query) || 
                            c.code.toLowerCase().contains(query) || 
                            c.symbol.contains(query)
                          ).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredList.length,
                        itemBuilder: (ctx, i) {
                          final currency = filteredList[i];
                          final isSelected = BusinessConfig.instance.currency == currency.symbol;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () {
                                setState(() => BusinessConfig.instance.currency = currency.symbol);
                                DatabaseHelper.instance.saveCurrency(currency.symbol);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Currency set to ${currency.name}'), backgroundColor: ThemeProvider.success));
                              },
                              borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? theme.highlight.withOpacity(0.1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                                  border: Border.all(color: isSelected ? theme.highlight.withOpacity(0.3) : Colors.transparent),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelected ? theme.highlight : const Color(0xFFF3F4F6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(currency.symbol, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF1F2937), fontSize: 18, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(currency.name, style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w800, fontSize: 14)),
                                          Text(currency.code, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                    if (isSelected) const Icon(Icons.check_circle_rounded, color: ThemeProvider.success, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.highlight,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showCustomCurrencyDialog();
                            },
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: const Text('CUSTOM', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomCurrencyDialog() {
    final customCtrl = TextEditingController();
    InputDecoration _dialogInputDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        prefixIcon: Icon(icon, color: const Color(0xFF4B5563)),
        filled: true,
        fillColor: Colors.black.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Custom Symbol', 
                style: TextStyle(color: Color(0xFF1F2937), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 24),
              TextField(
                controller: customCtrl,
                autofocus: true,
                style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600),
                decoration: _dialogInputDecoration('Enter symbol (e.g. ₿)', Icons.currency_exchange_rounded),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('CANCEL', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeProvider.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                      ),
                      onPressed: () {
                         if (customCtrl.text.isNotEmpty) {
                          setState(() => BusinessConfig.instance.currency = customCtrl.text);
                          DatabaseHelper.instance.saveCurrency(customCtrl.text);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Currency symbol updated'), backgroundColor: ThemeProvider.success));
                        }
                      },
                      child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaxDialog() {
    final taxCtrl = TextEditingController(text: _taxRate.toString());

    InputDecoration _dialogInputDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        prefixIcon: Icon(icon, color: const Color(0xFF4B5563)),
        filled: true,
        fillColor: Colors.black.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GST', 
                style: TextStyle(color: Color(0xFF1F2937), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 24),
              TextField(
                controller: taxCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600),
                decoration: _dialogInputDecoration('Tax Percentage (%)', Icons.percent_rounded),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('CANCEL', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeProvider.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                      ),
                      onPressed: () async {
                        setState(() => _taxRate = double.tryParse(taxCtrl.text) ?? 8.0);
                        BusinessConfig.instance.taxRate = _taxRate;
                        await DatabaseHelper.instance.setSetting('tax_rate', _taxRate.toString());
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tax rate updated to ${_taxRate}%'), backgroundColor: ThemeProvider.success));
                      },
                      child: const Text('UPDATE', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'System Settings',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Business Information
              const _SectionHeader(title: 'BUSINESS IDENTITY'),
              _SettingsTile(
                icon: Icons.store_rounded,
                title: 'Business Name',
                subtitle: _businessName,
                onTap: _showEditBusinessDialog,
              ),
              _SettingsTile(
                icon: Icons.location_on_rounded,
                title: 'Address',
                subtitle: _businessAddress,
                onTap: _showEditBusinessDialog,
              ),
              _SettingsTile(
                icon: Icons.phone_rounded,
                title: 'Phone Number',
                subtitle: _businessPhone,
                onTap: _showEditBusinessDialog,
              ),
              _SettingsTile(
                icon: Icons.sticky_note_2_rounded,
                title: 'Receipt Footer',
                subtitle: _receiptFooter,
                onTap: _showEditBusinessDialog,
              ),
              _SettingsTile(
                icon: BusinessConfig.instance.currencyIcon,
                title: 'Currency Unit',
                subtitle: BusinessConfig.instance.currency,
                onTap: _showCurrencyDialog,
              ),

              const SizedBox(height: 24),
              const _SectionHeader(title: 'FINANCIAL CONFIG'),
              _SettingsTile(
                icon: Icons.receipt_long_rounded,
                title: 'Universal Tax Rate',
                subtitle: '$_taxRate%',
                onTap: _showTaxDialog,
              ),
              _SettingsTile(
                icon: Icons.money_rounded,
                title: 'Currency Notes',
                subtitle: 'Manage denominations for cash counting',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CurrencyNotesScreen()),
                  );
                },
              ),

              const SizedBox(height: 24),
              const _SectionHeader(title: 'PREFERENCES'),
              _SettingsSwitch(
                icon: theme.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                title: 'Aesthetic Dark Mode',
                subtitle: theme.isDark ? 'Professional dark theme' : 'Vibrant light theme',
                value: theme.isDark,
                onChanged: (v) => setState(() => theme.toggleTheme()),
              ),
              _SettingsSwitch(
                icon: Icons.person_add_rounded,
                title: 'Mandatory Customers',
                subtitle: 'Require customer for checkouts',
                value: _requireCustomer,
                onChanged: (v) async {
                  setState(() => _requireCustomer = v);
                  BusinessConfig.instance.requireCustomer = v;
                  await DatabaseHelper.instance.setSetting('require_customer', v ? '1' : '0');
                },
              ),
              _SettingsSwitch(
                icon: Icons.print_rounded,
                title: 'Automated Receipts',
                subtitle: 'Print/Show receipt after success',
                value: _autoReceipt,
                onChanged: (v) async {
                  setState(() => _autoReceipt = v);
                  BusinessConfig.instance.autoReceipt = v;
                  await DatabaseHelper.instance.setSetting('auto_receipt', v ? '1' : '0');
                },
              ),
              _SettingsSwitch(
                icon: Icons.door_sliding_rounded,
                title: 'Open Cash Drawer',
                subtitle: 'Automatically open drawer on cash sales',
                value: _openCashDrawer,
                onChanged: (v) async {
                  setState(() => _openCashDrawer = v);
                  BusinessConfig.instance.openCashDrawer = v;
                  await DatabaseHelper.instance.setSetting('open_cash_drawer', v ? '1' : '0');
                },
              ),
              _SettingsSwitch(
                icon: Icons.volume_up_rounded,
                title: 'UI Feedback Sounds',
                subtitle: 'Auditory feedback for clicks',
                value: _soundEnabled,
                onChanged: (v) async {
                  setState(() => _soundEnabled = v);
                  BusinessConfig.instance.soundEnabled = v;
                  await DatabaseHelper.instance.setSetting('sound_enabled', v ? '1' : '0');
                },
              ),

              const SizedBox(height: 24),
              const _SectionHeader(title: 'MAINTENANCE'),
              _SettingsTile(
                icon: Icons.cloud_sync_rounded,
                title: 'Cloud Synchronization',
                subtitle: 'Last synced: 2 hours ago',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syncing with cloud...'), backgroundColor: ThemeProvider.info)),
              ),

              const _SectionHeader(title: 'SECURITY'),
              _SettingsTile(
                icon: Icons.password_rounded,
                title: 'App PIN Code',
                subtitle: 'Manage 4-digit PIN for quick login',
                onTap: () async {
                  final storage = const FlutterSecureStorage();
                  final currentEmail = await storage.read(key: 'user_email');
                  if (currentEmail == null) return;

                  final pin = await PinDialogs.showSetupPinDialog(context);
                  if (pin != null) {
                    try {
                      final jsonStr = await storage.read(key: 'saved_accounts');
                      List<Map<String, dynamic>> accounts = [];
                      if (jsonStr != null) {
                        accounts = List<Map<String, dynamic>>.from(jsonDecode(jsonStr));
                      }
                      
                      // Check if account already saved, update pin
                      final accIndex = accounts.indexWhere((acc) => acc['email'].toString().toLowerCase() == currentEmail.toLowerCase());
                      if (accIndex != -1) {
                        accounts[accIndex]['pin'] = pin;
                      } else {
                        // Create a basic saved account context if one didn't exist
                        String name = 'User';
                        final dbHelper = DatabaseHelper.instance;
                        final localUser = await dbHelper.getUserByEmail(currentEmail);
                        if (localUser != null) name = localUser['name'] ?? 'User';

                        accounts.add({
                          'email': currentEmail.toLowerCase(),
                          'password': '', // Will prompt password if they don't have it saved, handled normally during quick login fail
                          'name': name,
                          'pin': pin,
                        });
                      }
                      
                      await storage.write(key: 'saved_accounts', value: jsonEncode(accounts));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PIN updated successfully!'), backgroundColor: ThemeProvider.success));
                      }
                    } catch (e) {
                      print('Error saving PIN: $e');
                    }
                  }
                },
              ),

              const SizedBox(height: 24),
              const _SectionHeader(title: 'SYSTEM INFO'),
              _SettingsTile(
                icon: Icons.terminal_rounded,
                title: 'Build Version',
                subtitle: 'Premium v1.0.84 - Stable',
                onTap: () {},
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: ThemeProvider.error.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.warning_rounded, color: ThemeProvider.error, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Wipe Local Data?', style: TextStyle(color: Color(0xFF1F2937), fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('This will permanently delete all cached sales and configs on this device.', 
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 24),
              Row(
                children: [
                   Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('CANCEL', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeProvider.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache has been cleared'), backgroundColor: ThemeProvider.error));
                      },
                      child: const Text('WIPE DATA', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
      child: Text(
        title, 
        style: TextStyle(
          color: theme.highlight, 
          fontSize: 12, 
          fontWeight: FontWeight.w900, 
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.titleColor});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: theme.glassDecoration,
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: theme.whiteAlpha(0.05), borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
            child: Icon(icon, color: theme.highlight, size: 22),
          ),
          title: Text(title, style: TextStyle(color: titleColor ?? theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
          subtitle: Text(subtitle, style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          trailing: Icon(Icons.arrow_forward_ios_rounded, color: theme.iconColor, size: 14),
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: theme.glassDecoration,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: theme.whiteAlpha(0.05), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: theme.highlight, size: 22),
          ),
          title: Text(title, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
          subtitle: Text(subtitle, style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          trailing: Switch(
            value: value, 
            onChanged: onChanged, 
            activeColor: ThemeProvider.success,
            activeTrackColor: ThemeProvider.success.withOpacity(0.3),
            inactiveThumbColor: theme.textHint,
            inactiveTrackColor: theme.whiteAlpha(0.1),
          ),
        ),
      ),
    );
  }
}
