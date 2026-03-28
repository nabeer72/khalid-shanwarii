import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/data/currency_list.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:mobile_app/widgets/pin_dialogs.dart';
import 'package:mobile_app/screens/currency_notes_screen.dart';
import 'package:mobile_app/services/sync_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final theme = ThemeProvider.instance;
  final SyncService _syncService = SyncService();
  
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

  void _showEditBusinessDialog({int focusIndex = 0}) {
    final nameCtrl = TextEditingController(text: _businessName);
    final addressCtrl = TextEditingController(text: _businessAddress);
    final phoneCtrl = TextEditingController(text: _businessPhone);
    final footerCtrl = TextEditingController(text: _receiptFooter);

    final List<FocusNode> focusNodes = List.generate(4, (_) => FocusNode());

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

    Widget _buildDialogField(TextEditingController ctrl, FocusNode node, String label, IconData icon, {TextInputType? keyboardType}) {
      return TextField(
        controller: ctrl,
        focusNode: node,
        keyboardType: keyboardType,
        style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600),
        decoration: _dialogInputDecoration(label, icon),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) {
        // Delayed focus to the requested field
        Future.delayed(const Duration(milliseconds: 100), () {
          if (focusIndex >= 0 && focusIndex < focusNodes.length) {
            focusNodes[focusIndex].requestFocus();
          }
        });
        
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
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Business Profile', 
                    style: TextStyle(color: Color(0xFF1F2937), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  const SizedBox(height: 24),
                  _buildDialogField(nameCtrl, focusNodes[0], 'Business Name', Icons.store_rounded),
                  const SizedBox(height: 16),
                  _buildDialogField(addressCtrl, focusNodes[1], 'Physical Address', Icons.location_on_rounded),
                  const SizedBox(height: 16),
                  _buildDialogField(phoneCtrl, focusNodes[2], 'Contact Phone', Icons.phone_rounded, keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  _buildDialogField(footerCtrl, focusNodes[3], 'Receipt Footer Message', Icons.sticky_note_2_rounded),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            for (var node in focusNodes) {
                              node.dispose();
                            }
                            Navigator.pop(ctx);
                          },
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

                            if (BusinessConfig.instance.businessId != null) {
                              await db.updateBusinessSyncStatus(BusinessConfig.instance.businessId, 0);
                            }

                            for (var node in focusNodes) {
                              node.dispose();
                            }
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
        );
      },
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
                width: 360,
                height: MediaQuery.of(context).size.height * 0.6,
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
          width: 320, // Set specific width to fix the "too big" issue
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
                        setState(() => _taxRate = double.tryParse(taxCtrl.text) ?? 0.0);
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
              _SectionHeader(
                title: 'BUSINESS IDENTITY',
                trailing: IconButton(
                  icon: Icon(Icons.edit_square, color: theme.highlight, size: 20),
                  onPressed: () => _showEditBusinessDialog(focusIndex: 0),
                  tooltip: 'Edit Business Profile',
                ),
              ),
              _SettingsTile(
                icon: Icons.store_rounded,
                title: 'Business Name',
                subtitle: _businessName,
                onTap: () => _showEditBusinessDialog(focusIndex: 0),
                showTrailing: false,
              ),
              _SettingsTile(
                icon: Icons.location_on_rounded,
                title: 'Address',
                subtitle: _businessAddress,
                onTap: () => _showEditBusinessDialog(focusIndex: 1),
                showTrailing: false,
              ),
              _SettingsTile(
                icon: Icons.phone_rounded,
                title: 'Phone Number',
                subtitle: _businessPhone,
                onTap: () => _showEditBusinessDialog(focusIndex: 2),
                showTrailing: false,
              ),
              _SettingsTile(
                icon: Icons.sticky_note_2_rounded,
                title: 'Receipt Footer',
                subtitle: _receiptFooter,
                onTap: () => _showEditBusinessDialog(focusIndex: 3),
                showTrailing: false,
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
              _SettingsTile(
                icon: Icons.storage_rounded,
                title: 'Manage Local Storage',
                subtitle: 'Cleanup old synced records to save space',
                showTrailing: false,
                onTap: _showManageStorageDialog,
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
    // ... (existing code, keeping for reference but adding new dialog below)
  }

  void _showManageStorageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.highlight.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.cloud_done_rounded, color: theme.highlight, size: 28),
              ),
              const SizedBox(height: 12),
              const Text('Manage Storage', style: TextStyle(color: Color(0xFF1F2937), fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Have you synced your local data with the cloud server?', 
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                        side: BorderSide(color: theme.highlight.withOpacity(0.5)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _performFullSync();
                      },
                      child: Text('NOT YET', style: TextStyle(color: const Color(0xFF1F2937), fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: theme.highlight,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmCleanup();
                      },
                      child: const Text('YES, SYNCED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
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

  Future<void> _performFullSync() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Starting synchronization...'), backgroundColor: ThemeProvider.info));
    try {
      final result = await _syncService.syncAll();
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync complete! Now you can safely cleanup.'), backgroundColor: ThemeProvider.success));
          _confirmCleanup();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync partial: ${result.pushError ?? result.pullError}'), backgroundColor: ThemeProvider.warning));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e'), backgroundColor: ThemeProvider.error));
      }
    }
  }

  void _confirmCleanup() async {
    // Check if there's still unsynced data
    final hasUnsynced = await _syncService.hasUnsyncedData();
    if (hasUnsynced && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: ThemeProvider.warning.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.warning_amber_rounded, color: ThemeProvider.warning, size: 28),
                ),
                const SizedBox(height: 12),
                const Text('Unsynced Data Detected', style: TextStyle(color: Color(0xFF1F2937), fontSize: 16, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                const SizedBox(height: 6),
                const Text('Some records have not been synced yet. If you cleanup now, those records will NOT be deleted. Proceed?', 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                          side: const BorderSide(color: Color(0xFF9CA3AF)),
                        ),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('CANCEL', style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w900, fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: ThemeProvider.warning,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('PROCEED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (proceed != true) return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ThemeProvider.error.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.delete_sweep_rounded, color: ThemeProvider.error, size: 28),
              ),
              const SizedBox(height: 12),
              const Text('Confirm Cleanup', style: TextStyle(color: Color(0xFF1F2937), fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('This will remove synced transaction records older than one week. You can still view them online.', 
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                        side: const BorderSide(color: Color(0xFF9CA3AF)),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('CANCEL', style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: ThemeProvider.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('CLEANUP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final deletedCount = await DatabaseHelper.instance.cleanupSyncedRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cleanup complete! $deletedCount records removed.'),
          backgroundColor: ThemeProvider.success,
        ));
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title, 
            style: TextStyle(
              color: theme.highlight, 
              fontSize: 12, 
              fontWeight: FontWeight.w900, 
              letterSpacing: 1.5,
            ),
          ),
          if (trailing != null) trailing!,
        ],
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
  final bool showTrailing;

  const _SettingsTile({
    required this.icon, 
    required this.title, 
    required this.subtitle, 
    required this.onTap, 
    this.titleColor,
    this.showTrailing = true,
  });

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
          trailing: showTrailing ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.highlight.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.highlight.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_note_rounded, color: theme.highlight, size: 16),
                const SizedBox(width: 4),
                Text('EDIT', style: TextStyle(color: theme.highlight, fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
          ) : null,
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
