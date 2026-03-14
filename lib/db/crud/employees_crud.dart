import 'package:sqflite/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'common_crud.dart';

mixin EmployeesCrud on CommonCrud {
  // Employees
  Future<List<Map<String, dynamic>>> getEmployees() async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId?.toLowerCase();
    final aid = BusinessConfig.instance.adminId?.toLowerCase();
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [bid, aid, ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM employees WHERE LOWER(business_id) = ? AND LOWER(admin_id) = ? $branchFilter',
      args,
    );
  }

  Future<void> insertEmployee(Map<String, dynamic> employee) async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final aid = BusinessConfig.instance.adminId;
    
    final Map<String, dynamic> data = Map.from(employee);
    final bIdToUse = data['business_id'] ?? bid;
    final aIdToUse = data['admin_id'] ?? aid;

    if (data['permissions'] is List) {
      data['permissions'] = jsonEncode(data['permissions']);
    }
    
    if (data['email'] != null) {
      data['email'] = data['email'].toString().toLowerCase().trim();
    }

    // Branch ID logic: preserve provided (for Global selection), otherwise use current.
    if (!data.containsKey('branch_id')) {
      data['branch_id'] = getCurrentBranchId();
    }

    await db.insert('employees', {
      ...data,
      'business_id': bIdToUse,
      'admin_id': aIdToUse,
      'is_synced': 0
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getEmployeeByEmailAndPin(String email, String pin) async {
    final db = await database;
    final cleanEmail = email.toLowerCase().trim();
    
    final List<Map<String, dynamic>> results = await db.query(
      'employees',
      where: 'LOWER(email) = ? AND pin = ? AND status = 1',
      whereArgs: [cleanEmail, pin],
      limit: 1,
    );
    
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> deleteEmployee(String id) async {
    final db = await database;
    await db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }

  // Roles
  Future<List<Map<String, dynamic>>> getRoles() async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    return await db.rawQuery(
      'SELECT * FROM roles WHERE business_id = ? AND status = 1 $branchFilter',
      [bid, ...branchArgs]
    );
  }

  Future<Map<String, dynamic>?> getRoleById(String id) async {
    final db = await database;
    final res = await db.query('roles', where: 'id = ?', whereArgs: [id]);
    return res.firstOrNull;
  }


  Future<void> insertRole(Map<String, dynamic> role) async {
    final db = await database;
    await db.insert('roles', {
      ...role,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertRolePermissions(String roleId, List<String> permissionIds) async {
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
  }

  Future<List<String>> getRolePermissions(String roleId) async {
    final db = await database;
    final res = await db.query('role_permissions', where: 'role_id = ?', whereArgs: [roleId]);
    return res.map((r) => r['permission_id'].toString()).toList();
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
      {'id': 'pos_access', 'name': 'pos_access', 'label': 'POS Access'},
      {'id': 'new_sale', 'name': 'new_sale', 'label': 'Create New Sale'},
      {'id': 'reports_view', 'name': 'reports_view', 'label': 'View Reports'},
      {'id': 'product_manage', 'name': 'product_manage', 'label': 'Manage Products'},
      {'id': 'customer_manage', 'name': 'customer_manage', 'label': 'Manage Customers'},
      {'id': 'staff_manage', 'name': 'staff_manage', 'label': 'Manage Staff'},
      {'id': 'settings_manage', 'name': 'settings_manage', 'label': 'Manage Settings'},
      {'id': 'expenses_manage', 'name': 'expenses_manage', 'label': 'Manage Expenses'},
      {'id': 'suppliers_manage', 'name': 'suppliers_manage', 'label': 'Manage Suppliers'},
      {'id': 'purchases_manage', 'name': 'purchases_manage', 'label': 'Manage Purchases'},
      {'id': 'sales_history', 'name': 'sales_history', 'label': 'View Sales History'},
      {'id': 'recovery', 'name': 'recovery', 'label': 'Credit Recovery'},
      {'id': 'stock_view', 'name': 'stock_view', 'label': 'View Stock Reports'},
    ];

    await db.transaction((txn) async {
      for (var p in perms) {
        await txn.insert('permissions', {
          ...p,
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }
}
