import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database_helper.dart';
import '../mock_data.dart';
import 'common_crud.dart';

mixin PaymentTypesCrud on CommonCrud {
  Future<List<Map<String, dynamic>>> getPaymentTypes() async {
    final db = await database;
    
    final bid = BusinessConfig.instance.businessId;
    String query = 'SELECT * FROM payment_types WHERE status = 1 AND business_id = ? ORDER BY name ASC';
    List<dynamic> args = [bid];
    
    return await db.rawQuery(query, args);
  }

  Future<int> insertPaymentType(Map<String, dynamic> pt) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.insert('payment_types', {
      ...pt,
      'business_id': getSafeInt(pt['business_id'] ?? BusinessConfig.instance.businessId),
      'is_synced': 0,
      'created_at': pt['created_at'] ?? now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<int> deletePaymentType(dynamic id) async {
    final db = await database;
    final result = await db.update('payment_types', {
      'status': 0,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [getSafeInt(id)]);
    
    DatabaseHelper.notifyDataChanged();
    return result;
  }
}
