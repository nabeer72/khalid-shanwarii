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
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    String query = 'SELECT * FROM categories WHERE status = 1 AND parent_id IS NULL${getBusinessFilter()}$branchFilter';
    List<dynamic> args = [...getBusinessArgs(), ...branchArgs];
    
    query += ' ORDER BY name ASC';
    
    return await db.rawQuery(query, args);
  }

  Future<int> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.insert('categories', {
      ...category,
      ...Map.fromIterables(['business_id', 'admin_id'], getBusinessArgs()),
      'branch_id': getSafeInt(category['branch_id'] ?? getCurrentBranchId()),
      'is_synced': 0,
      'created_at': category['created_at'] ?? now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getSubCategories({dynamic categoryId}) async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    final businessArgs = getBusinessArgs();
    
    // 1. Fetch from subcategories table
    String subQuery = 'SELECT * FROM subcategories WHERE status = 1${getBusinessFilter()}$branchFilter';
    List<dynamic> subArgs = [...businessArgs, ...branchArgs];

    if (categoryId != null) {
      subQuery += ' AND category_id = ?';
      subArgs.add(getSafeInt(categoryId));
    }

    final List<Map<String, dynamic>> subResults = await db.rawQuery(subQuery, subArgs);
    
    // 2. Fetch from categories table (where parent_id is NOT NULL)
    String catQuery = 'SELECT * FROM categories WHERE status = 1 AND parent_id IS NOT NULL${getBusinessFilter()}$branchFilter';
    List<dynamic> catArgs = [...businessArgs, ...branchArgs];
    
    if (categoryId != null) {
      catQuery += ' AND parent_id = ?';
      catArgs.add(getSafeInt(categoryId));
    }
    
    final List<Map<String, dynamic>> catResults = await db.rawQuery(catQuery, catArgs);
    
    // Combine and normalize results
    final List<Map<String, dynamic>> combined = [];
    
    // Map subcategories (normalize category_id to parent_id for consistency)
    for (var row in subResults) {
      combined.add({
        ...row,
        'parent_id': row['category_id'],
      });
    }
    
    // Map categories that are subcategories
    combined.addAll(catResults);
    
    // Sort by name
    combined.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

    return combined;
  }

  Future<int> insertSubCategory(Map<String, dynamic> subcategory) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.insert('subcategories', {
      ...subcategory,
      ...Map.fromIterables(['business_id', 'admin_id'], getBusinessArgs()),
      'branch_id': getSafeInt(subcategory['branch_id'] ?? getCurrentBranchId()),
      'is_synced': 0,
      'created_at': subcategory['created_at'] ?? now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
