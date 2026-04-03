import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

mixin SettingsCrud {
  Future<Database> get database;

  // Settings
  Future<String?> getSetting(String key) async {
    final db = await database;
    final results = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return results.isNotEmpty ? results.first['value'] as String? : null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveCurrency(String symbol) async {
    await setSetting('currency_symbol', symbol);
    BusinessConfig.instance.currency = symbol;
  }

  Future<void> loadSettings() async {
    final currency = await getSetting('currency_symbol');
    if (currency != null) BusinessConfig.instance.currency = currency;

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

    final reqCust = await getSetting('require_customer');
    if (reqCust != null) BusinessConfig.instance.requireCustomer = reqCust == '1';

    final autoRec = await getSetting('auto_receipt');
    if (autoRec != null) BusinessConfig.instance.autoReceipt = autoRec == '1';

    final openDrawer = await getSetting('open_cash_drawer');
    if (openDrawer != null) BusinessConfig.instance.openCashDrawer = openDrawer == '1';

    final sound = await getSetting('sound_enabled');
    if (sound != null) BusinessConfig.instance.soundEnabled = sound == '1';

    // Load IDs from secure storage
    const storage = FlutterSecureStorage();
    var bid = await storage.read(key: 'business_id');
    if (bid != null) {
      BusinessConfig.instance.businessId = int.tryParse(bid);
    }
    
    var aid = await storage.read(key: 'user_id');
    if (aid != null) {
      BusinessConfig.instance.adminId = int.tryParse(aid);
    }

    var sid = await storage.read(key: 'staff_id');
    if (sid != null) {
      BusinessConfig.instance.staffId = int.tryParse(sid);
    }

    var inactiveStr = await storage.read(key: 'inactive_branches');
    List<int> inactiveIds = [];
    if (inactiveStr != null) {
      inactiveIds = inactiveStr.split(',').where((e) => e.isNotEmpty).map((e) => int.tryParse(e)).whereType<int>().toList();
    }
    BusinessConfig.instance.inactiveBranchIds = inactiveIds;

    var brIdString = await storage.read(key: 'branch_id');
    // Session Guard: Only load branch from storage if it hasn't been set by the current login process
    if (BusinessConfig.instance.branchId == null && brIdString != null && brIdString.isNotEmpty && brIdString != 'NONE') {
      final brIdInt = int.tryParse(brIdString);
      BusinessConfig.instance.branchId = brIdInt;
      
      // If we have a branch ID but no active list yet, initialize it
      if (BusinessConfig.instance.activeBranchIds.isEmpty && brIdInt != null) {
        BusinessConfig.instance.activeBranchIds = [brIdInt];
      }
    }

    // By default, dynamically compute active branches by explicitly excluding inactive ones.
    if (inactiveStr == null || brIdString == null || brIdString == 'NONE') {
      try {
        final db = await database;
        final allBranches = await db.query('branches', columns: ['id']);
        final allBranchIds = allBranches.map((b) => b['id'] as int).toList();
        BusinessConfig.instance.activeBranchIds = allBranchIds.where((id) => !inactiveIds.contains(id)).toList();
      } catch (e) {
        // Ignore if before migration
      }
    }

    print('📦 [DB] Loaded businessId: ${BusinessConfig.instance.businessId}, adminId: ${BusinessConfig.instance.adminId}, activeBranches: ${BusinessConfig.instance.activeBranchIds}');

    // Backfill NULL credit balances for legacy records
    if (BusinessConfig.instance.businessId != null && BusinessConfig.instance.adminId != null) {
      final db = await database;
      await db.update('customers', {'credit_balance': 0}, where: 'credit_balance IS NULL');
    }

    print('📦 [DB] Loaded businessId: ${BusinessConfig.instance.businessId}, adminId: ${BusinessConfig.instance.adminId}');
  }

  // We keep employees, users, businesses, products, and settings to allow local login and offline UX
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete all data on logout to strictly prevent data leaks between businesses and branches.
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

      await txn.delete('users');
      await txn.delete('employees');
      await txn.delete('businesses');
      await txn.delete('branches');
      await txn.delete('settings');
      await txn.delete('user_businesses');
      await txn.delete('employee_roles');
      await txn.delete('role_permissions');
    });

    // Wipe all session context from secure storage EXCEPT saved_accounts
    const storage = FlutterSecureStorage();
    final allKeys = await storage.readAll();
    for (String key in allKeys.keys) {
      if (key != 'saved_accounts') {
        await storage.delete(key: key);
      }
    }
    
    BusinessConfig.instance.reset(keepContext: false);
  }

  // ... (Expense methods overlap with previous file content, ensuring continuity)

}
