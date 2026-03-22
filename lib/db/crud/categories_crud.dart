import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'common_crud.dart';

mixin CategoriesCrud on CommonCrud {
  // Categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    String query = 'SELECT * FROM categories WHERE status = 1 AND parent_id IS NULL AND business_id = ? AND admin_id = ?$branchFilter';
    List<dynamic> args = [bid, aid, ...branchArgs];
    
    query += ' ORDER BY name ASC';
    
    return await db.rawQuery(query, args);
  }

  Future<int> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = BusinessConfig.instance.adminId;
    
    return await db.insert('categories', {
      ...category,
      'business_id': bid,
      'admin_id': aid,
      'branch_id': category['branch_id'] ?? getCurrentBranchId(),
      'is_synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getSubCategories({dynamic categoryId}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    String query = 'SELECT * FROM subcategories WHERE status = 1 AND business_id = ? AND admin_id = ?$branchFilter';
    List<dynamic> args = [bid, aid, ...branchArgs];

    if (categoryId != null) {
      query += ' AND category_id = ?';
      args.add(getSafeInt(categoryId));
    }

    query += ' ORDER BY name ASC';

    return await db.rawQuery(query, args);
  }

  Future<int> insertSubCategory(Map<String, dynamic> subcategory) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = BusinessConfig.instance.adminId;
    
    if (kDebugMode) print('💾 [DB] insertSubCategory: $subcategory (bid=$bid, aid=$aid)');
    
    return await db.insert('subcategories', {
      ...subcategory,
      'business_id': bid,
      'admin_id': aid,
      'branch_id': subcategory['branch_id'] ?? getCurrentBranchId(),
      'is_synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
