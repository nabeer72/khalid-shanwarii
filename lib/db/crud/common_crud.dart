import 'package:sqflite/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

mixin CommonCrud {
  Future<Database> get database;
  
  // Branch Isolation Helpers
  String getBranchFilter() {
    final activeBranches = BusinessConfig.instance.activeBranchIds;
    final brid = BusinessConfig.instance.branchId;

    if (activeBranches.isNotEmpty) {
      final placeholders = List.filled(activeBranches.length, '?').join(', ');
      // STRICT ISOLATION: When branches are selected, only show data for those branches.
      // (Used to include IS NULL or empty branch but user wants strict separation now)
      return ' AND (branch_id IN ($placeholders))';
    } else if (brid != null && brid.isNotEmpty) {
      return ' AND (branch_id = ?)';
    }
    // No branch context = show all data
    return '';
  }

  List<dynamic> getBranchArgs() {
    final activeBranches = BusinessConfig.instance.activeBranchIds;
    final brid = BusinessConfig.instance.branchId;

    if (activeBranches.isNotEmpty) {
      return activeBranches.map((id) => id.toString().toLowerCase()).toList();
    } else if (brid != null) {
      return [brid.toString().toLowerCase()];
    }
    return [];
  }

  String? getCurrentBranchId() {
    // Priority: 
    // 1. Specific branchId set in context (e.g. for assignment)
    final brid = BusinessConfig.instance.branchId;
    if (brid != null && brid.trim().isNotEmpty) {
      return brid.trim().toLowerCase();
    }
    
    // 2. Fallback to first active branch
    final activeBranches = BusinessConfig.instance.activeBranchIds;
    if (activeBranches.isNotEmpty) {
      final fallback = activeBranches.first.toString().trim().toLowerCase();
      if (fallback.isNotEmpty) return fallback;
    }
    
    return null;
  }

  // Users
  Future<void> insertUser(Map<String, dynamic> user, {int? isSynced}) async {
    final db = await database;
    // Sanitize user data to match schema
  final sanitized = {
    'id': user['id']?.toString().toLowerCase(),
    'business_id': user['business_id']?.toString().toLowerCase(),
    'branch_id': user['branch_id']?.toString().toLowerCase(),
    'name': user['name'] ?? '',
    'email': user['email']?.toString().toLowerCase(),
    'password': user['password'],
    'role': user['role'] ?? 'admin',
    'status': (user['status'] == true || user['status'] == 1) ? 1 : 0,
    'is_synced': isSynced ?? (user['is_synced'] ?? 1), // Default to 1 if not specified
    'created_at': user['created_at'],
    'updated_at': user['updated_at'],
  };
    await db.insert('users', sanitized, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getUser(String id) async {
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

  Future<void> updateUserSyncStatus(String id, int synced) async {
    final db = await database;
    await db.update('users', {'is_synced': synced}, where: 'id = ?', whereArgs: [id]);
  }

  // Businesses
  Future<void> insertBusiness(Map<String, dynamic> business, {int? isSynced}) async {
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
    await db.insert('businesses', sanitized, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getBusiness(String id) async {
    final db = await database;
    final results = await db.query('businesses', where: 'id = ?', whereArgs: [id], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedBusinesses() async {
    final db = await database;
    return await db.query('businesses', where: 'is_synced = 0');
  }

  Future<void> updateBusinessSyncStatus(String id, int synced) async {
    final db = await database;
    await db.update('businesses', {'is_synced': synced}, where: 'id = ?', whereArgs: [id]);
  }

  // ========== Bank Operations ==========

  Future<List<Map<String, dynamic>>> getBankTransactions() async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final aid = BusinessConfig.instance.adminId;
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final args = [bid, aid, ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM bank_accounts WHERE status = 1 AND business_id = ? AND admin_id = ?$branchFilter ORDER BY date DESC',
      args,
    );
  }

  Future<void> insertBankTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final aid = BusinessConfig.instance.adminId;
    
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

  Future<void> deleteBankTransaction(String id) async {
    final db = await database;
    await db.update('bank_accounts', {'status': 0, 'is_synced': 0}, where: 'id = ?', whereArgs: [id]);
  }

}
