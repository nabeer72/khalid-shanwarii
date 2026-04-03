import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

mixin CommonCrud {
  Future<Database> get database;
  
  // Branch Isolation Helpers
  String getBranchFilter() {
    final activeBranches = BusinessConfig.instance.activeBranchIds;
    final brid = BusinessConfig.instance.branchId;
    final staffId = BusinessConfig.instance.staffId;

    // Staff are strictly isolated to their own branch
    if (staffId != null && brid != null) {
      return ' AND (branch_id = ?)';
    }

    // [FIX] Prioritize current branch ID over the list of all active branches.
    // This prevents sub-branch data from leaking into the main branch view for admins.
    if (brid != null && brid != 'NONE' && brid != 0) {
      return ' AND (branch_id = ?)';
    }

    if (activeBranches.isNotEmpty) {
      final placeholders = List.filled(activeBranches.length, '?').join(', ');
      return ' AND (branch_id IN ($placeholders))';
    }
    // No branch context = show all data
    return '';
  }

  List<dynamic> getBranchArgs() {
    final activeBranches = BusinessConfig.instance.activeBranchIds;
    final brid = BusinessConfig.instance.branchId;
    final staffId = BusinessConfig.instance.staffId;

    // Staff are strictly isolated to their own branch
    if (staffId != null && brid != null) {
      return [getSafeInt(brid)];
    }

    // [FIX] Prioritize current branch ID over the list of all active branches.
    if (brid != null && brid != 'NONE' && brid != 0) {
      return [getSafeInt(brid)];
    }

    if (activeBranches.isNotEmpty) {
      return activeBranches.map((b) => getSafeInt(b)).toList();
    }
    return [];
  }

  // Business Isolation Helpers
  String getBusinessFilter() {
    return ' AND business_id = ? AND admin_id = ?';
  }

  List<dynamic> getBusinessArgs() {
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    return [bid, aid];
  }

  Map<String, dynamic> getBusinessArgsMap() {
    return {
      'business_id': getSafeInt(BusinessConfig.instance.businessId),
      'admin_id': getSafeInt(BusinessConfig.instance.adminId),
    };
  }

  dynamic getCurrentBranchId() {
    // Priority: 
    // 1. Specific branchId set in context (e.g. for assignment)
    final brid = BusinessConfig.instance.branchId;
    if (brid != null) {
      return brid;
    }
    
    // 2. Fallback to first active branch
    final activeBranches = BusinessConfig.instance.activeBranchIds;
    if (activeBranches.isNotEmpty) {
      return activeBranches.first;
    }
    
    return null;
  }

  int? getSafeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  // Users
  Future<int> insertUser(Map<String, dynamic> user, {int? isSynced}) async {
    final db = await database;
    // Sanitize user data to match schema
  final sanitized = {
    'id': user['id'],
    'business_id': user['business_id'],
    'branch_id': user['branch_id'],
    'name': user['name'] ?? '',
    'email': user['email']?.toString().toLowerCase().trim(),
    'password': user['password'],
    'role': user['role'] ?? 'admin',
    'status': (user['status'] == true || user['status'] == 1) ? 1 : 0,
    'is_synced': isSynced ?? (user['is_synced'] ?? 1), // Default to 1 if not specified
    'created_at': user['created_at'],
    'updated_at': user['updated_at'],
  };
    return await db.insert('users', sanitized, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getUser(dynamic id) async {
    final db = await database;
    final results = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final cleanEmail = email.toLowerCase().trim();
    final results = await db.query('users', where: 'LOWER(email) = ?', whereArgs: [cleanEmail], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedUsers() async {
    final db = await database;
    return await db.query('users', where: 'is_synced = 0');
  }

  Future<void> updateUserSyncStatus(dynamic id, int synced) async {
    final db = await database;
    await db.update('users', {'is_synced': synced}, where: 'id = ?', whereArgs: [id]);
  }

  // Businesses
  Future<int> insertBusiness(Map<String, dynamic> business, {int? isSynced}) async {
    final db = await database;
    // Sanitize business data to match schema
    final sanitized = {
      'id': business['id'],
      'name': business['name'] ?? '',
      'business_type': business['business_type'],
      'owner_user_id': business['owner_user_id'],
      'status': (business['status'] == true || business['status'] == 1) ? 1 : 0,
      'is_synced': isSynced ?? (business['is_synced'] ?? 1),
      'created_at': business['created_at'],
      'updated_at': business['updated_at'],
    };
    return await db.insert('businesses', sanitized, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getBusiness(dynamic id) async {
    final db = await database;
    final results = await db.query('businesses', where: 'id = ?', whereArgs: [id], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedBusinesses() async {
    final db = await database;
    return await db.query('businesses', where: 'is_synced = 0');
  }

  Future<void> updateBusinessSyncStatus(dynamic id, int synced) async {
    final db = await database;
    await db.update('businesses', {'is_synced': synced}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getBusinesses() async {
    final db = await database;
    return await db.query('businesses', where: 'status = 1');
  }

  Future<List<Map<String, dynamic>>> getBusinessesForUser(dynamic userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT DISTINCT b.* FROM businesses b
      INNER JOIN user_businesses ub ON b.id = ub.business_id
      WHERE ub.user_id = ? AND b.status = 1
    ''', [userId]);
  }

  Future<void> addUserBusiness(dynamic userId, dynamic businessId) async {
    final db = await database;
    
    // [FIX] Check for existing link to prevent duplicates
    final existing = await db.query('user_businesses', 
      where: 'user_id = ? AND business_id = ?', 
      whereArgs: [userId, businessId],
      limit: 1
    );
    
    if (existing.isEmpty) {
      await db.insert('user_businesses', {
        'user_id': userId,
        'business_id': businessId,
        'is_synced': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }


  // ========== Bank Operations ==========

  Future<List<Map<String, dynamic>>> getBankTransactions() async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final args = [bid, aid, ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM bank_accounts WHERE status = 1 AND business_id IS ? AND admin_id IS ?$branchFilter ORDER BY date DESC',
      args,
    );
  }

  Future<void> insertBankTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    await db.insert('bank_accounts', {
      ...transaction,
      'business_id': bid,
      'admin_id': aid,
      'branch_id': transaction['branch_id'] ?? getCurrentBranchId(),
      'is_synced': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteBankTransaction(dynamic id) async {
    final db = await database;
    await db.update('bank_accounts', {'status': 0, 'is_synced': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // ========== Cleanup Operations ==========

  Future<int> cleanupSyncedRecords({int daysOld = 7}) async {
    final db = await database;
    final dateThreshold = DateTime.now().subtract(Duration(days: daysOld)).toIso8601String();
    
    int totalDeleted = 0;
    final tables = [
      'sales', 'sale_items', 'returns', 'return_items',
      'expenses', 'purchases', 'purchase_items',
      'bank_accounts', 'credit_sales', 'credit_payments',
      'supplier_paybacks', 'supplier_credit_purchases'
    ];

    await db.transaction((txn) async {
      for (var table in tables) {
        // Special case for tables that might not have created_at but have 'date'
        String dateColumn = 'created_at';
        if (table == 'bank_accounts' || table == 'credit_payments' || table == 'supplier_paybacks') {
           dateColumn = 'date';
        }

        try {
          final count = await txn.delete(
            table,
            where: 'is_synced = 1 AND $dateColumn < ?',
            whereArgs: [dateThreshold],
          );
          totalDeleted += count;
        } catch (e) {
          print('Cleanup error for table $table: $e');
        }
      }
    });
    
    return totalDeleted;
  }

}
