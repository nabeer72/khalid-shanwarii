import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database_helper.dart';

mixin SettingsCrud {
  Future<Database> get database;

  // Settings
  Future<String?> getSetting(String key) async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final uid = BusinessConfig.instance.userId;

    // Build WHERE clause dynamically: sqflite_sqlcipher does not accept null bind
    // values, so we use IS NULL directly in SQL when the IDs are not set.
    final List<dynamic> args = [key];
    String bidClause;
    if (bid == null) {
      bidClause = 'business_id IS NULL';
    } else {
      bidClause = 'business_id = ?';
      args.add(bid);
    }
    String uidClause;
    if (uid == null) {
      uidClause = 'user_id IS NULL';
    } else {
      uidClause = 'user_id = ?';
      args.add(uid);
    }

    final results = await db.query(
      'settings',
      where: 'key = ? AND $bidClause AND $uidClause',
      whereArgs: args,
    );
    return results.isNotEmpty ? results.first['value'] as String? : null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final uid = BusinessConfig.instance.userId;

    await db.insert('settings', {
      'key': key,
      'value': value,
      'business_id': bid,
      'user_id': uid,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveCurrency(String symbol) async {
    await setSetting('currency_symbol', symbol);
    BusinessConfig.instance.currency = symbol;
  }

  Future<void> setHasSeenOnboarding(bool value) async {
    await setSetting('has_seen_onboarding', value ? '1' : '0');
    BusinessConfig.instance.hasSeenOnboarding = value;
  }

  Future<void> loadSettings() async {
    // 1. Load IDs from secure storage FIRST so that getSetting uses the correct context
    const storage = FlutterSecureStorage();
    var bid = await storage.read(key: 'business_id');
    if (bid != null) {
      BusinessConfig.instance.businessId = int.tryParse(bid);
    }
    
    var uid = await storage.read(key: 'user_id');
    if (uid != null) {
      BusinessConfig.instance.userId = int.tryParse(uid);
    }

    var sid = await storage.read(key: 'staff_id');
    if (sid != null) {
      BusinessConfig.instance.staffId = int.tryParse(sid);
    }



    // 2. Load business-specific settings using the now-loaded IDs
    final currency = await getSetting('currency_symbol');
    if (currency == '\$') {
      await setSetting('currency_symbol', 'Rs');
      BusinessConfig.instance.currency = 'Rs';
    } else if (currency != null) {
      BusinessConfig.instance.currency = currency;
    }

    final name = await getSetting('business_name');
    if (name != null) BusinessConfig.instance.businessName = name;

    final address = await getSetting('business_address');
    if (address != null) BusinessConfig.instance.businessAddress = address;

    final phone = await getSetting('business_phone');
    if (phone != null) BusinessConfig.instance.businessPhone = phone;

    final footer = await getSetting('receipt_footer');
    if (footer != null) BusinessConfig.instance.receiptFooter = footer;
    final type = await getSetting('business_type');
    if (type != null) BusinessConfig.instance.businessType = type;
    
    final tax = await getSetting('tax_rate');
    if (tax != null) BusinessConfig.instance.taxRate = double.tryParse(tax) ?? 0.0;

    final enableT = await getSetting('enable_tax');
    if (enableT != null) BusinessConfig.instance.enableTax = enableT == '1';

    final enableGD = await getSetting('enable_global_discount');
    if (enableGD != null) BusinessConfig.instance.enableGlobalDiscount = enableGD == '1';

    final gdLimit = await getSetting('global_discount_limit');
    if (gdLimit != null) BusinessConfig.instance.globalDiscountLimit = double.tryParse(gdLimit) ?? 0;

    final gdLimitType = await getSetting('global_discount_limit_type');
    if (gdLimitType != null) BusinessConfig.instance.globalDiscountLimitType = gdLimitType;

    final reqCust = await getSetting('require_customer');
    if (reqCust != null) BusinessConfig.instance.requireCustomer = reqCust == '1';

    final autoRec = await getSetting('auto_receipt');
    if (autoRec != null) BusinessConfig.instance.autoReceipt = autoRec == '1';

    final openDrawer = await getSetting('open_cash_drawer');
    if (openDrawer != null) BusinessConfig.instance.openCashDrawer = openDrawer == '1';

    final sound = await getSetting('sound_enabled');
    if (sound != null) BusinessConfig.instance.soundEnabled = sound == '1';

    final onboarding = await getSetting('has_seen_onboarding');
    if (onboarding != null) BusinessConfig.instance.hasSeenOnboarding = onboarding == '1';







    // Backfill NULL credit balances for legacy records
    if (BusinessConfig.instance.businessId != null && BusinessConfig.instance.userId != null) {
      final db = await database;
      await db.update('customers', {'credit_balance': 0}, where: 'credit_balance IS NULL');
    }

    print('📦 [DB] Loaded businessId: ${BusinessConfig.instance.businessId}, userId: ${BusinessConfig.instance.userId}');
  }

  /// Switch active business: persist context, pull server data, reload settings.
  Future<void> activateBusiness(
    Map<String, dynamic> business, {
    dynamic? userId,
    bool syncFromServer = true,
  }) async {
    const storage = FlutterSecureStorage();
    final bid = business['id'];
    if (bid == null) return;

    final aid = business['owner_user_id'] ??
        business['admin_id'] ??
        userId ??
        BusinessConfig.instance.userId;

    BusinessConfig.instance.setContext(
      bid: bid,
      uid: aid,
      bName: business['name']?.toString(),
      bType: business['business_type_id']?.toString(),
    );

    await storage.write(key: 'business_id', value: bid.toString());
    if (aid != null) {
      await storage.write(key: 'user_id', value: aid.toString());
    }

    if (business['name'] != null) {
      await setSetting('business_name', business['name'].toString());
    }
    await setSetting(
      'business_type_id',
      business['business_type_id']?.toString() ?? '1',
    );

    await loadSettings();
    DatabaseHelper.notifyDataChanged();
  }

  // Clears session-specific context from storage and memory without wiping the database
  Future<void> clearSessionContext() async {
    const storage = FlutterSecureStorage();
    
    // Wipe session context from secure storage EXCEPT saved_accounts, encryption keys, and tutorial flags
    final allKeys = await storage.readAll();
    for (String key in allKeys.keys) {
      if (key != 'saved_accounts' && key != 'db_encryption_key' && !key.startsWith('tutorial_shown_')) {
        await storage.delete(key: key);
      }
    }
    
    // [REMOVED] Deleting settings from the DB is no longer necessary now that the
    // settings table is isolated by (key, business_id, user_id).
    // The reset() call below ensures the next user doesn't see this session's state.

    // Reset in-memory config
    BusinessConfig.instance.reset(keepContext: false);
  }

  // We keep employees, users, businesses, products, and settings to allow local login and offline UX
  Future<void> clearAllData() async {
    const storage = FlutterSecureStorage();
    
    // [FIX] Identify which users/employees to preserve for Quick Login
    final jsonStr = await storage.read(key: 'saved_accounts');
    List<String> preserveEmails = [];
    if (jsonStr != null) {
      try {
        final accounts = List<Map<String, dynamic>>.from(jsonDecode(jsonStr));
        preserveEmails = accounts.map((a) => a['email'].toString().toLowerCase().trim()).toList();
      } catch (e) {
        print('⚠️ Error parsing saved accounts during logout: $e');
      }
    }

    final db = await database;
    await db.transaction((txn) async {
      // 1. Wipe all transactional and inventory data (CRITICAL for security/isolation)
      await txn.delete('sale_items');
      await txn.delete('sales');
      await txn.delete('products'); 
      await txn.delete('categories'); 
      await txn.delete('subcategories');
      await txn.delete('stocks');
      await txn.delete('customers'); 
      await txn.delete('gift_cards');
      await txn.delete('held_orders');
      await txn.delete('expenses');
      await txn.delete('expense_heads');
      await txn.delete('purchase_items');
      await txn.delete('purchases');
      await txn.delete('suppliers'); 
      await txn.delete('credit_sales');
      await txn.delete('credit_payments');
      await txn.delete('shifts');
      await txn.delete('bank_accounts');
      await txn.delete('supplier_paybacks');
      await txn.delete('supplier_credit_purchases');
      await txn.delete('currency_notes');
      await txn.delete('returns');
      await txn.delete('return_items');
      await txn.delete('units');
      await txn.delete('brands');

      // 2. Conditionally wipe identity data
      if (preserveEmails.isEmpty) {
        print('🧹 [WIPE] No saved accounts, clearing all identity data');
        await txn.delete('users');
        await txn.delete('employees');
        await txn.delete('businesses');
        await txn.delete('branches');
        await txn.delete('user_businesses');
        await txn.delete('employee_roles');
        await txn.delete('role_permissions');
        await txn.delete('settings');
      } else {
        print('🧹 [WIPE] Preserving identity data for ${preserveEmails.length} saved accounts');
        final placeholders = List.filled(preserveEmails.length, '?').join(', ');
        
        await txn.delete('users', where: 'LOWER(email) NOT IN ($placeholders)', whereArgs: preserveEmails);
        await txn.delete('employees', where: 'LOWER(email) NOT IN ($placeholders)', whereArgs: preserveEmails);
        
        // [IMPORTANT] We keep ALL businesses, branches, roles, and settings to ensure
        // that preserved users have the full context they need to log in offline.
        // These tables are generally small and don't contain sensitive transaction data.
      }
    });

    // Wipe session context from secure storage EXCEPT saved_accounts, encryption keys, and tutorial flags
    final allKeys = await storage.readAll();
    for (String key in allKeys.keys) {
      if (key != 'saved_accounts' && key != 'db_encryption_key' && !key.startsWith('tutorial_shown_')) {
        await storage.delete(key: key);
      }
    }
    
    // Safety Force: Specifically ensure sync timestamps are gone
    
    BusinessConfig.instance.reset(keepContext: false);
  }

  // ... (Expense methods overlap with previous file content, ensuring continuity)

}
