import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database_helper.dart';
import 'common_crud.dart';

mixin ExpensesCrud on CommonCrud {
  // Expense Heads
  Future<List<Map<String, dynamic>>> getExpenseHeads() async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [...getBusinessArgs(), ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM expense_heads WHERE status = 1${getBusinessFilter()}$branchFilter ORDER BY name ASC',
      args,
    );
  }

  Future<void> insertExpenseHead(Map<String, dynamic> head) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('expense_heads', {
      ...head,
      ...Map.fromIterables(['business_id', 'user_id'], getBusinessArgs()),
      'branch_id': getSafeInt(head['branch_id'] ?? getCurrentBranchId()),
      'is_synced': 0,
      'created_at': head['created_at'] ?? now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    DatabaseHelper.notifyDataChanged();
  }

  Future<void> deleteExpenseHead(dynamic id) async {
    final db = await database;
    await db.update(
      'expense_heads', 
      {'status': 0, 'is_synced': 0}, 
      where: 'id = ?${getBusinessFilter()}', 
      whereArgs: [id, ...getBusinessArgs()]
    );
    
    DatabaseHelper.notifyDataChanged();
  }

  // Expenses
  Future<List<Map<String, dynamic>>> getExpenses({String? startTime, String? endTime}) async {
    final db = await database;
    final branchFilter = getBranchFilter().replaceAll('branch_id', 'e.branch_id');
    final branchArgs = getBranchArgs();
    
    String dateFilter = '';
    final List<dynamic> args = [...getBusinessArgs(), ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilter = ' AND e.date BETWEEN ? AND ?';
      args.addAll([startTime, endTime]);
    }

    return await db.rawQuery(
      '''
      SELECT e.*, eh.name AS expense_head_name 
      FROM expenses e 
      LEFT JOIN expense_heads eh ON e.expense_head_id = eh.id 
      WHERE e.status = 1${getBusinessFilter().replaceAll('business_id', 'e.business_id').replaceAll('user_id', 'e.user_id')}$branchFilter$dateFilter 
      ORDER BY e.date DESC
      ''',
      args,
    );
  }

  Future<void> insertExpense(Map<String, dynamic> expense) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('expenses', {
      ...expense,
      ...Map.fromIterables(['business_id', 'user_id'], getBusinessArgs()),
      'branch_id': getSafeInt(expense['branch_id'] ?? getCurrentBranchId()),
      'is_synced': 0,
      'created_at': expense['created_at'] ?? now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    DatabaseHelper.notifyDataChanged();
  }

  Future<void> updateExpense(dynamic id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'expenses', 
      {...data, 'is_synced': 0}, 
      where: 'id = ?${getBusinessFilter()}', 
      whereArgs: [id, ...getBusinessArgs()]
    );
    
    DatabaseHelper.notifyDataChanged();
  }

  Future<void> updateExpenseHead(dynamic id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'expense_heads', 
      {...data, 'is_synced': 0}, 
      where: 'id = ?${getBusinessFilter()}', 
      whereArgs: [id, ...getBusinessArgs()]
    );
    
    DatabaseHelper.notifyDataChanged();
  }

  Future<void> deleteExpense(dynamic id) async {
    final db = await database;
    await db.update(
      'expenses', 
      {'status': 0, 'is_synced': 0}, 
      where: 'id = ?${getBusinessFilter()}', 
      whereArgs: [id, ...getBusinessArgs()]
    );
    
    DatabaseHelper.notifyDataChanged();
  }

}
