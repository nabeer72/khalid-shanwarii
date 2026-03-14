import 'package:sqflite/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'common_crud.dart';

mixin CustomersCrud on CommonCrud {
  // Customers
  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final aid = BusinessConfig.instance.adminId;
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [bid, aid, ...branchArgs];

    final results = await db.rawQuery(
      'SELECT * FROM customers WHERE status = 1 AND business_id = ? AND admin_id = ?$branchFilter ORDER BY name ASC',
      args,
    );
    return results;
  }

  Future<void> insertCustomer(Map<String, dynamic> customer) async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final aid = BusinessConfig.instance.adminId;
    
    await db.insert('customers', {
      ...customer,
      'business_id': bid,
      'admin_id': aid,
      'branch_id': customer['branch_id'] ?? getCurrentBranchId(),
      'is_synced': 0
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCustomer(String id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('customers', {...data, 'is_synced': 0}, where: 'id = ?', whereArgs: [id]);
  }

}
