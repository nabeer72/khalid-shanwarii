import 'package:sqflite/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

mixin BranchesCrud {
  Future<Database> get database;

  // ========== Branch Operations ==========

  Future<List<Map<String, dynamic>>> getBranches() async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
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

    final args = [bid, ...(activeBranches.isNotEmpty ? activeBranches : (brid != null ? [brid] : []))];

    return await db.query('branches', where: 'status = 1 AND business_id = ?$branchFilter', whereArgs: args);
  }

  Future<List<Map<String, dynamic>>> getAllBranches() async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    return await db.query('branches', where: 'status = 1 AND business_id = ?', whereArgs: [bid]);
  }

  Future<void> insertBranch(Map<String, dynamic> branch) async {
    final db = await database;
    await db.insert('branches', {
      ...branch,
      'is_synced': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateBranch(String id, Map<String, dynamic> branch) async {
    final db = await database;
    await db.update('branches', {
      ...branch,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBranch(String id) async {
    final db = await database;
    await db.update('branches', {'status': 0, 'is_synced': 0}, where: 'id = ?', whereArgs: [id]);
  }

}
