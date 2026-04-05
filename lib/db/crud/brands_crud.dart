import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database_helper.dart';
import '../mock_data.dart';
import 'common_crud.dart';

mixin BrandsCrud on CommonCrud {
  Future<List<Map<String, dynamic>>> getBrands() async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final bid = BusinessConfig.instance.businessId;
    String query = 'SELECT * FROM brands WHERE status = 1 AND business_id = ?$branchFilter ORDER BY name ASC';
    List<dynamic> args = [bid, ...branchArgs];
    
    return await db.rawQuery(query, args);
  }

  Future<int> insertBrand(Map<String, dynamic> brand) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.insert('brands', {
      ...brand,
      'business_id': BusinessConfig.instance.businessId,
      'branch_id': getSafeInt(brand['branch_id'] ?? getCurrentBranchId()),
      'admin_id': getSafeInt(brand['admin_id'] ?? BusinessConfig.instance.adminId),
      'is_synced': 0,
      'created_at': brand['created_at'] ?? now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<int> deleteBrand(dynamic id) async {
    final db = await database;
    final result = await db.update('brands', {
      'status': 0,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [getSafeInt(id)]);
    
    DatabaseHelper.notifyDataChanged();
    return result;
  }
}
