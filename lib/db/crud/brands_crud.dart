import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database_helper.dart';
import '../mock_data.dart';
import 'common_crud.dart';

mixin BrandsCrud on CommonCrud {
  Future<List<Map<String, dynamic>>> getBrands() async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [...getBusinessArgs(), ...branchArgs];
    
    return await db.rawQuery(
      'SELECT * FROM brands WHERE status = 1${getBusinessFilter()}$branchFilter ORDER BY name ASC',
      args,
    );
  }

  Future<int> insertBrand(Map<String, dynamic> brand) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.insert('brands', {
      ...brand,
      'business_id': BusinessConfig.instance.businessId,
      'branch_id': getSafeInt(brand['branch_id'] ?? getCurrentBranchId()),
      'user_id': getSafeInt(brand['user_id'] ?? BusinessConfig.instance.userId),
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
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?${getBusinessFilter()}', whereArgs: [getSafeInt(id), ...getBusinessArgs()]);
    
    DatabaseHelper.notifyDataChanged();
    return result;
  }
}
