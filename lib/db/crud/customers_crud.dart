import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database_helper.dart';
import 'common_crud.dart';

mixin CustomersCrud on CommonCrud {
  // Customers
  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [...getBusinessArgs(), ...branchArgs];

    final results = await db.rawQuery(
      'SELECT * FROM customers WHERE status = 1${getBusinessFilter()}$branchFilter ORDER BY name ASC',
      args,
    );
    return results;
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await database;
    return await db.rawQuery(
      'SELECT * FROM customers WHERE status = 1${getBusinessFilter()} ORDER BY name ASC',
      getBusinessArgs(),
    );
  }

  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    final db = await database;
    final result = await db.insert('customers', {
      ...customer,
      ...Map.fromIterables(['business_id', 'user_id'], getBusinessArgs()),
      'branch_id': customer['branch_id'] ?? getCurrentBranchId(),
      'is_synced': 0
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<int> updateCustomer(dynamic id, Map<String, dynamic> data) async {
    final db = await database;
    final result = await db.update(
      'customers', 
      {...data, 'is_synced': 0}, 
      where: 'id = ?${getBusinessFilter()}', 
      whereArgs: [id, ...getBusinessArgs()]
    );
    
    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<Map<String, dynamic>?> getCustomer(dynamic id) async {
    final db = await database;
    final results = await db.query(
      'customers', 
      where: 'id = ?${getBusinessFilter()}', 
      whereArgs: [id, ...getBusinessArgs()]
    );
    return results.firstOrNull;
  }
}
