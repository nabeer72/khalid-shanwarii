import 'package:sqflite/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'common_crud.dart';

mixin ExpensesCrud on CommonCrud {
  // Expense Heads
  Future<List<Map<String, dynamic>>> getExpenseHeads() async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final aid = BusinessConfig.instance.adminId;
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [bid, aid, ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM expense_heads WHERE status = 1 AND business_id = ? AND admin_id = ?$branchFilter ORDER BY name ASC',
      args,
    );
  }

  Future<void> insertExpenseHead(Map<String, dynamic> head) async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final aid = BusinessConfig.instance.adminId;
    
    await db.insert('expense_heads', {
      ...head,
      'business_id': bid,
      'admin_id': aid,
      'branch_id': head['branch_id'] ?? getCurrentBranchId(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteExpenseHead(String id) async {
    final db = await database;
    await db.update('expense_heads', {'status': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // Expenses
  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final aid = BusinessConfig.instance.adminId;
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [bid, aid, ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM expenses WHERE status = 1 AND business_id = ? AND admin_id = ?$branchFilter ORDER BY date DESC',
      args,
    );
  }

  Future<void> insertExpense(Map<String, dynamic> expense) async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final aid = BusinessConfig.instance.adminId;
    
    await db.insert('expenses', {
      ...expense,
      'business_id': bid,
      'admin_id': aid,
      'branch_id': expense['branch_id'] ?? getCurrentBranchId(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateExpense(String id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('expenses', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateExpenseHead(String id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('expense_heads', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteExpense(String id) async {
    final db = await database;
    await db.update('expenses', {'status': 0}, where: 'id = ?', whereArgs: [id]);
  }

}
