import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

mixin BranchesCrud {
  Future<Database> get database;

  // ========== Branch Operations ==========

  Future<List<Map<String, dynamic>>> getBranches() async {
    final db = await database;
    final bid = _safeInt(BusinessConfig.instance.businessId);
    final activeBranches = BusinessConfig.instance.activeBranchIds;
    final brid = BusinessConfig.instance.branchId;
    final isStaff = BusinessConfig.instance.staffId != null;

    String branchFilter = '';
    if (activeBranches.isNotEmpty) {
      branchFilter = ' AND id IN (${List.filled(activeBranches.length, '?').join(', ')})';
    } else if (brid != null) {
      branchFilter = ' AND id = ?';
    } else if (isStaff) {
      return []; // Staff on global view has no branch, thus shouldn't see branches
    }

    final aid = _safeInt(BusinessConfig.instance.adminId);
    final args = [bid, aid, ...(activeBranches.isNotEmpty ? activeBranches : (brid != null ? [brid] : []))];

    return await db.query('branches', where: 'status = 1 AND business_id = ? AND admin_id = ?$branchFilter', whereArgs: args);
  }

  Future<List<Map<String, dynamic>>> getAllBranches() async {
    final db = await database;
    final bid = _safeInt(BusinessConfig.instance.businessId);
    final aid = _safeInt(BusinessConfig.instance.adminId);
    return await db.query('branches', where: 'status = 1 AND business_id = ? AND admin_id = ?', whereArgs: [bid, aid]);
  }

  Future<int> insertBranch(Map<String, dynamic> branch) async {
    final db = await database;
    final bid = _safeInt(BusinessConfig.instance.businessId);
    final aid = _safeInt(BusinessConfig.instance.adminId);
    
    final insertData = Map<String, dynamic>.from(branch);
    // Remove null id so AUTOINCREMENT works
    if (insertData['id'] == null) {
      insertData.remove('id');
    }
    insertData['business_id'] = bid;
    insertData['admin_id'] = aid;
    
    return await db.insert('branches', {
      ...insertData,
      'is_synced': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  int? _safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> updateBranch(dynamic id, Map<String, dynamic> branch) async {
    final db = await database;
    await db.update('branches', {
      ...branch,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBranch(dynamic id) async {
    final db = await database;
    await db.update('branches', {'status': 0, 'is_synced': 0}, where: 'id = ?', whereArgs: [id]);
  }

}
