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
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    return await db.rawQuery(
      'SELECT * FROM employees WHERE 1=1 AND business_id = ?',
      [bid],
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
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    // [FIX] Only filter by email + business_id. employees.user_id = admin's user ID
    // which never matches BusinessConfig.userId (staff's own user ID).
    final results = await db.query(
      'employees',
      where: 'LOWER(email) = ? AND business_id = ?',
      whereArgs: [email.toLowerCase().trim(), bid],
      limit: 1
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getEmployeeByEmailAndPin(String email, String pin) async {
    final db = await database;
    final cleanEmail = email.toLowerCase().trim();
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    // [FIX] Only filter by email + pin + business_id. user_id is the admin's ID
    // and causes a mismatch when BusinessConfig holds the staff's own user ID.
    final List<Map<String, dynamic>> results = await db.query(
      'employees',
      where: 'LOWER(email) = ? AND pin = ? AND status = 1 AND business_id = ?',
      whereArgs: [cleanEmail, pin, bid],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Look up an employee by their server ID without user_id scoping.
  Future<Map<String, dynamic>?> getEmployeeById(dynamic id) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final results = await db.query(
      'employees',
      where: 'id = ? AND business_id = ?',
      whereArgs: [id, bid],
      limit: 1
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateEmployeePin(dynamic id, String pin) async {
    final db = await database;
    await db.update('employees', {
      'pin': pin,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?${getBusinessFilter()}', whereArgs: [id, ...getBusinessArgs()]);
  }

  Future<void> deleteEmployee(dynamic id) async {
    final db = await database;
    await db.delete('employees', where: 'id = ?${getBusinessFilter()}', whereArgs: [id, ...getBusinessArgs()]);
    
    DatabaseHelper.notifyDataChanged();
  }

  Future<List<Map<String, dynamic>>> getRoles() async {
    final db = await database;
    // Roles belong to the business, not a specific user.
    // Do NOT filter by user_id — roles are created on the web dashboard without a user_id.
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    return await db.rawQuery(
      'SELECT * FROM roles WHERE status = 1 AND business_id = ?',
      [bid]
    );
  }

  Future<Map<String, dynamic>?> getRoleById(dynamic id) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final res = await db.query('roles',
      where: 'id = ? AND business_id = ?',
      whereArgs: [id, bid]);
    return res.firstOrNull;
  }


  Future<int> insertRole(Map<String, dynamic> role) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);

    final insertData = Map<String, dynamic>.from(role);
    if (insertData['id'] == null || insertData['id'] == 0 || insertData['id'] == 'null') {
      insertData.remove('id');
    }

    insertData['business_id'] = bid;
    // Removed user_id assignment because roles are scoped to business, not user.
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
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    await db.transaction((txn) async {
      // Security Check: Verify role belongs to business (not user-scoped)
      final role = await txn.query('roles',
        where: 'id = ? AND business_id = ?',
        whereArgs: [roleId, bid]);
      if (role.isEmpty) return;

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
    final res = await db.rawQuery('''
      SELECT rp.permission_id 
      FROM role_permissions rp
      JOIN roles r ON rp.role_id = r.id
      WHERE rp.role_id = ? ${getBusinessFilter().replaceAll('business_id', 'r.business_id').replaceAll('user_id', 'r.user_id')}
    ''', [roleId, ...getBusinessArgs()]);
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
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    // [FIX] Only filter by employee_id + business_id. Filtering by user_id was fragile
    // and caused zero results if userId was null or mismatched after login.
    final List<Map<String, dynamic>> res = await db.rawQuery('''
      SELECT DISTINCT p.name 
      FROM employee_roles er
      JOIN role_permissions rp ON er.role_id = rp.role_id
      JOIN permissions p ON rp.permission_id = p.id
      JOIN employees e ON er.employee_id = e.id
      WHERE er.employee_id = ? AND e.business_id = ?
    ''', [employeeId, bid]);
    
    return res.map((r) => r['name'].toString()).toList();
  }

  Future<List<int>> getEmployeeRoleIds(dynamic employeeId) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    // [FIX] Only filter by employee_id + business_id for consistency.
    final res = await db.rawQuery('''
      SELECT er.role_id 
      FROM employee_roles er
      JOIN employees e ON er.employee_id = e.id
      WHERE er.employee_id = ? AND e.business_id = ?
    ''', [employeeId, bid]);
    return res.map((r) => int.tryParse(r['role_id'].toString()) ?? 0).where((id) => id > 0).toList();
  }

  Future<void> updateEmployeeRoles(dynamic employeeId, List<int> roleIds) async {
    final db = await database;
    await db.transaction((txn) async {
      // Security Check: Verify employee belongs to business
      final employee = await txn.query('employees', where: 'id = ?${getBusinessFilter()}', whereArgs: [employeeId, ...getBusinessArgs()]);
      if (employee.isEmpty) return;

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
