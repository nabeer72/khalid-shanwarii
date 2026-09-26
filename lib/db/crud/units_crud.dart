import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database_helper.dart';
import '../mock_data.dart';
import 'common_crud.dart';

mixin UnitsCrud on CommonCrud {
  Future<List<Map<String, dynamic>>> getUnits() async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final bid = BusinessConfig.instance.businessId;
    final uid = BusinessConfig.instance.userId;

    final String businessFilter;
    final List<dynamic> businessArgs;

    if (bid == null && uid == null) {
      businessFilter = ' AND (business_id IS NULL OR business_id IS NOT NULL)';
      businessArgs = [];
    } else {
      // Include rows matching (bid, uid) exactly, plus rows where both are NULL (master seed)
      businessFilter =
          ' AND ((business_id IS ? AND user_id IS ?) OR (business_id IS NULL AND user_id IS NULL))';
      businessArgs = [
        (bid is int || bid == null) ? bid : int.tryParse(bid.toString()),
        (uid is int || uid == null) ? uid : int.tryParse(uid.toString()),
      ];
    }

    String query = 'SELECT * FROM units WHERE status = 1$businessFilter$branchFilter ORDER BY name ASC';
    List<dynamic> args = [...businessArgs, ...branchArgs];
    
    return await db.rawQuery(query, args);
  }

  Future<List<Map<String, dynamic>>> getAllUnitsWithBusiness() async {
    final db = await database;
    String query = '''
      SELECT u.*, COALESCE(b.name, 'Default Units') as business_name 
      FROM units u 
      LEFT JOIN businesses b ON u.business_id = b.id 
      WHERE u.status = 1
      ORDER BY business_name ASC, u.name ASC
    ''';
    return await db.rawQuery(query);
  }

  Future<int> insertUnit(Map<String, dynamic> unit) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.insert('units', {
      ...unit,
      'business_id': BusinessConfig.instance.businessId,
      'branch_id': getSafeInt(unit['branch_id'] ?? getCurrentBranchId()),
      'user_id': getSafeInt(unit['user_id'] ?? BusinessConfig.instance.userId),
      'created_at': unit['created_at'] ?? now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<int> deleteUnit(dynamic id) async {
    final db = await database;
    final result = await db.update('units', {
      'status': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [getSafeInt(id)]);
    
    DatabaseHelper.notifyDataChanged();
    return result;
  }
}
