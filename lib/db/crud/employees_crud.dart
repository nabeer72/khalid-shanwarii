import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'dart:convert';
import '../database_helper.dart';
import 'common_crud.dart';

mixin EmployeesCrud on CommonCrud {
  // Employees
  Future<List<Map<String, dynamic>>> getEmployees() async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [...getBusinessArgs(), ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM employees WHERE 1=1 ${getBusinessFilter()} $branchFilter',
      args,
    );
  }

  Future<List<Map<String, dynamic>>> getAllEmployees() async {
    final db = await database;
    return await db.rawQuery(
      'SELECT * FROM employees WHERE 1=1 ${getBusinessFilter()}',
      getBusinessArgs(),
    );
  }

  Future<int> insertEmployee(Map<String, dynamic> employee) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final uid = getSafeInt(BusinessConfig.instance.userId);
    
    final Map<String, dynamic> data = Map.from(employee);
    final bIdToUse = getSafeInt(data['business_id']) ?? bid;
    final uIdToUse = getSafeInt(data['user_id']) ?? uid;

    if (data['permissions'] is List) {
      data['permissions'] = jsonEncode(data['permissions']);
    }
    
    if (data['email'] != null) {
      data['email'] = data['email'].toString().toLowerCase().trim();
    }

    // Branch ID logic: preserve provided (for Global selection), otherwise use current.
    if (!data.containsKey('branch_id') || data['branch_id'] == null) {
      data['branch_id'] = getCurrentBranchId();
    }
    // Ensure branch_id is stored as int
    if (data['branch_id'] != null && data['branch_id'] is String) {
      data['branch_id'] = int.tryParse(data['branch_id']);
    }

    final result = await db.insert('employees', {
      ...data,
      'business_id': bIdToUse,
      'user_id': uIdToUse,
      'is_synced': 0
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<Map<String, dynamic>?> getEmployeeByEmail(String email) async {
    final db = await database;
    final results = await db.query('employees', where: 'email = ?', whereArgs: [email], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getEmployeeByEmailAndPin(String email, String pin) async {
    final db = await database;
    final cleanEmail = email.toLowerCase().trim();
    
    final List<Map<String, dynamic>> results = await db.query(
      'employees',
      where: 'LOWER(email) = ? AND pin = ? AND status = 1${getBusinessFilter()}',
      whereArgs: [cleanEmail, pin, ...getBusinessArgs()],
      limit: 1,
    );
    
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateEmployeePin(dynamic id, String pin) async {
    final db = await database;
    await db.update('employees', {
      'pin': pin,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteEmployee(dynamic id) async {
    final db = await database;
    await db.delete('employees', where: 'id = ?', whereArgs: [id]);
    
    DatabaseHelper.notifyDataChanged();
  }

  Future<List<Map<String, dynamic>>> getRoles() async {
    final db = await database;
    return await db.rawQuery(
      'SELECT * FROM roles WHERE status = 1${getBusinessFilter()}',
      getBusinessArgs()
    );
  }

  Future<Map<String, dynamic>?> getRoleById(dynamic id) async {
    final db = await database;
    final res = await db.query('roles', where: 'id = ?', whereArgs: [id]);
    return res.firstOrNull;
  }


  Future<int> insertRole(Map<String, dynamic> role) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final uid = getSafeInt(BusinessConfig.instance.userId);
    
    final insertData = Map<String, dynamic>.from(role);
    if (insertData['id'] == null || insertData['id'] == 0 || insertData['id'] == 'null') {
      insertData.remove('id');
    }

    insertData['business_id'] = bid;
    insertData['user_id'] = uid;
    if (insertData['branch_id'] != null && insertData['branch_id'] is String) {
      insertData['branch_id'] = int.tryParse(insertData['branch_id']);
    }
    insertData['is_synced'] = 0;
    insertData['status'] = 1; // Ensure new roles are active and visible immediately
    insertData['created_at'] = insertData['created_at'] ?? DateTime.now().toIso8601String();
    insertData['updated_at'] = DateTime.now().toIso8601String();

    final result = await db.insert('roles', insertData, conflictAlgorithm: ConflictAlgorithm.replace);
    
    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<void> insertRolePermissions(dynamic roleId, List<dynamic> permissionIds) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('role_permissions', where: 'role_id = ?', whereArgs: [roleId]);
      for (var pid in permissionIds) {
        await txn.insert('role_permissions', {
          'role_id': roleId,
          'permission_id': pid,
        });
      }
    });
    DatabaseHelper.notifyDataChanged();
  }

  Future<List<dynamic>> getRolePermissions(dynamic roleId) async {
    final db = await database;
    final res = await db.query('role_permissions', where: 'role_id = ?', whereArgs: [roleId]);
    return res.map((r) => r['permission_id']).toList();
  }

  Future<List<Map<String, dynamic>>> getPermissions() async {
    final db = await database;
    final res = await db.query('permissions');
    if (res.isEmpty) {
      await seedPermissions(db);
      return await db.query('permissions');
    }
    return res;
  }

  Future<void> seedPermissions(Database db) async {
    final perms = [
      {'name': 'pos_access', 'label': 'POS Access'},
      {'name': 'new_sale', 'label': 'Create New Sale'},
      {'name': 'reports_view', 'label': 'View Reports'},
      {'name': 'product_manage', 'label': 'Manage Products'},
      {'name': 'customer_manage', 'label': 'Manage Customers'},
      {'name': 'staff_manage', 'label': 'Manage Staff'},
      {'name': 'settings_manage', 'label': 'Manage Settings'},
      {'name': 'expenses_manage', 'label': 'Manage Expenses'},
      {'name': 'suppliers_manage', 'label': 'Manage Suppliers'},
      {'name': 'purchases_manage', 'label': 'Manage Purchases'},
      {'name': 'sales_history', 'label': 'View Sales History'},
      {'name': 'recovery', 'label': 'Credit Recovery'},
      {'name': 'stock_view', 'label': 'View Stock Reports'},
      {'name': 'gift_cards', 'label': 'Manage Gift Cards'},
      {'name': 'loyalty', 'label': 'Manage Loyalty'},
      {'name': 'support_view', 'label': 'Contact Support'},
      {'name': 'payback_manage', 'label': 'Manage Supplier Payback'},
      {'name': 'branches_manage', 'label': 'Manage Branches'},
      {'name': 'bank_manage', 'label': 'Manage Bank'},
    ];

    await db.transaction((txn) async {
      for (var p in perms) {
        await txn.insert('permissions', {
          ...p,
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    DatabaseHelper.notifyDataChanged();
  }

  Future<List<String>> getEmployeePermissions(dynamic employeeId) async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.rawQuery('''
      SELECT DISTINCT p.name 
      FROM employee_roles er
      JOIN role_permissions rp ON er.role_id = rp.role_id
      JOIN permissions p ON rp.permission_id = p.id
      WHERE er.employee_id = ?
    ''', [employeeId]);
    
    return res.map((r) => r['name'].toString()).toList();
  }

  Future<List<int>> getEmployeeRoleIds(dynamic employeeId) async {
    final db = await database;
    final res = await db.query('employee_roles', columns: ['role_id'], where: 'employee_id = ?', whereArgs: [employeeId]);
    return res.map((r) => int.tryParse(r['role_id'].toString()) ?? 0).where((id) => id > 0).toList();
  }

  Future<void> updateEmployeeRoles(dynamic employeeId, List<int> roleIds) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('employee_roles', where: 'employee_id = ?', whereArgs: [employeeId]);
      for (var rid in roleIds) {
        await txn.insert('employee_roles', {
          'employee_id': employeeId,
          'role_id': rid,
        });
      }
    });
    DatabaseHelper.notifyDataChanged();
  }
}
