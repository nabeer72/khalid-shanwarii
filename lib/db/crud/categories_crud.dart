import 'package:sqflite/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'common_crud.dart';

mixin CategoriesCrud on CommonCrud {
  // Categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final aid = BusinessConfig.instance.adminId;
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [bid, aid, ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM categories WHERE status = 1 AND business_id = ? AND admin_id = ?$branchFilter ORDER BY name ASC',
      args,
    );
  }

  Future<void> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final aid = BusinessConfig.instance.adminId;
    
    await db.insert('categories', {
      ...category,
      'business_id': bid,
      'admin_id': aid,
      'branch_id': category['branch_id'] ?? getCurrentBranchId(),
      'is_synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

}
