import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import '../database_helper.dart';
import 'common_crud.dart';

mixin BranchesCrud on CommonCrud {
  Future<Database> get database;

  // ========== Branch Operations ==========

  Future<List<Map<String, dynamic>>> getBranches() async {
    final db = await database;
    final activeBranches = BusinessConfig.instance.activeBranchIds;
    final brid = BusinessConfig.instance.branchId;
    final isStaff = BusinessConfig.instance.staffId != null;

    String branchFilter = '';
    if (activeBranches.isNotEmpty) {
      branchFilter = ' AND id IN (${List.filled(activeBranches.length, '?').join(', ')})';
    } else if (brid != null) {
      branchFilter = ' AND id = ?';
    } else if (isStaff) {
      return []; // Staff on global view has no branch, thus shouldn't see branches
    }

    final args = [...getBusinessArgs(), ...(activeBranches.isNotEmpty ? activeBranches : (brid != null ? [brid] : []))];

    return await db.query('branches', where: 'status = 1${getBusinessFilter()}$branchFilter', whereArgs: args);
  }

  Future<List<Map<String, dynamic>>> getBranchesForBusiness(dynamic businessId) async {
    final db = await database;
    return await db.query(
      'branches', 
      where: 'status = 1 AND business_id = ?', 
      whereArgs: [businessId]
    );
  }

  Future<List<Map<String, dynamic>>> getAllBranches() async {
    final db = await database;
    return await db.query(
      'branches', 
      where: 'status = 1${getBusinessFilter()}', 
      whereArgs: getBusinessArgs()
    );
  }

  Future<int> insertBranch(Map<String, dynamic> branch) async {
    final db = await database;
    final data = Map<String, dynamic>.from(branch);
    if (data['id'] == null) {
      data.remove('id');
    }
    data['business_id'] = data['business_id'] ?? getBusinessArgs()[0];
    data['admin_id'] = data['admin_id'] ?? getBusinessArgs()[1];
    
    final result = await db.insert('branches', {
      ...data,
      'is_synced': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    DatabaseHelper.notifyDataChanged();
    return result;
  }

  // ignore: unused_element
  int? _safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> updateBranch(dynamic id, Map<String, dynamic> branch) async {
    final db = await database;
    await db.update('branches', {
      ...branch,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
    
    DatabaseHelper.notifyDataChanged();
  }

  Future<void> deleteBranch(dynamic id) async {
    final db = await database;
    final businessArgs = getBusinessArgs();
    await db.update(
      'branches', 
      {'status': 0, 'is_synced': 0}, 
      where: 'id = ?${getBusinessFilter()}', 
      whereArgs: [id, ...businessArgs]
    );
    
    DatabaseHelper.notifyDataChanged();
  }

}
