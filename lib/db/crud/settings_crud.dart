import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

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
    if (tax != null) BusinessConfig.instance.taxRate = double.tryParse(tax) ?? 8.0;

    final reqCust = await getSetting('require_customer');
    if (reqCust != null) BusinessConfig.instance.requireCustomer = reqCust == '1';

    final autoRec = await getSetting('auto_receipt');
    if (autoRec != null) BusinessConfig.instance.autoReceipt = autoRec == '1';

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
      
      if (inactiveStr == null) {
        // Legacy fallback
        List<int> loadedIds = [];
        if (brIdString.contains(',')) {
          loadedIds = brIdString.split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toList();
        } else if (brIdInt != null) {
          loadedIds = [brIdInt];
        }
        BusinessConfig.instance.activeBranchIds = loadedIds.toSet().toList();
      }
    }

    // By default, dynamically compute active branches by explicitly excluding inactive ones.
    if (inactiveStr != null || brIdString == null || brIdString == 'NONE') {
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

    // Backfill missing or inconsistent isolation IDs for local data
    if (BusinessConfig.instance.businessId != null && BusinessConfig.instance.adminId != null) {
      final db = await database;
      final currentBid = BusinessConfig.instance.businessId;
      final currentAid = BusinessConfig.instance.adminId;

      // Backfill NULL credit balances
      await db.update('customers', {'credit_balance': 0}, where: 'credit_balance IS NULL');

      final tables = [
        'categories', 'products', 'customers', 'employees', 'sales', 
        'credit_sales', 'credit_payments', 'suppliers', 'purchases', 
        'expense_heads', 'expenses', 'gift_cards', 'held_orders',
        'roles', 'branches'
      ];
      int totalUpdated = 0;
      for (var table in tables) {
        try {
          // Update missing OR mismatched IDs
          int count = await db.rawUpdate('''
            UPDATE $table 
            SET business_id = ?, admin_id = ? 
            WHERE business_id IS NULL OR admin_id IS NULL 
               OR business_id != ? OR admin_id != ?
          ''', [currentBid, currentAid, currentBid, currentAid]);
          totalUpdated += count;
        } catch (e) {
          if (kDebugMode) print('Backfill error for $table: $e');
        }
      }
      if (totalUpdated > 0) {
        print('🔧 [DB] Backfilled/Normalized $totalUpdated records (Business/Admin IDs)');
      }

      // 2. Backfill branch_id if current context has one
      final currentBrid = BusinessConfig.instance.branchId;
      if (currentBrid != null) {
        int totalBranchUpdated = 0;
        final isolationTables = [
            'categories', 'products', 'customers', 'employees', 'sales', 
            'credit_sales', 'credit_payments', 'suppliers', 'purchases', 
            'expense_heads', 'expenses', 'roles', 'branches'
        ];
        
        for (var table in isolationTables) {
          try {
            int count = await db.rawUpdate('''
              UPDATE $table 
              SET branch_id = ? 
              WHERE branch_id IS NULL OR branch_id = 0 OR branch_id = 'null'
            ''', [currentBrid]);
            totalBranchUpdated += count;
          } catch (e) {
             if (kDebugMode) print('Branch backfill error for $table: $e');
          }
        }
        if (totalBranchUpdated > 0) {
            print('🔧 [DB] Backfilled $totalBranchUpdated records to branch: $currentBrid');
        }
      }
    }

    print('📦 [DB] Loaded businessId: ${BusinessConfig.instance.businessId}, adminId: ${BusinessConfig.instance.adminId}');
  }

  // We keep employees, users, businesses, products, and settings to allow local login and offline UX
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      /* 
      // Stop deleting data on logout to ensure persistence. 
      // Hardened query filters in fetchers now handle isolation by branch_id.
      await txn.delete('sale_items');
      await txn.delete('sales');
      await txn.delete('products'); 
      await txn.delete('categories'); 
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
      */
    });

    // Wipe all session context from secure storage
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'auth_token');
    await storage.delete(key: 'user_id');
    await storage.delete(key: 'staff_id');
    // KEEP business_id and branch_id to preserve store environment context after logout
    // await storage.delete(key: 'business_id');
    // await storage.delete(key: 'branch_id');
    // KEEP last_synced_at so that next login does incremental sync instead of 
    // full re-sync which would wipe local unsynced records via ConflictAlgorithm.replace
    // await storage.delete(key: 'last_synced_at');

    BusinessConfig.instance.reset(keepContext: false);
  }

  // ... (Expense methods overlap with previous file content, ensuring continuity)

}
