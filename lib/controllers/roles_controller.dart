import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/models/role.dart';
import 'package:uuid/uuid.dart';

class RolesController with ChangeNotifier {
  List<Role> roles = [];
  List<Map<String, dynamic>> allPermissions = [];
  List<Map<String, dynamic>> branches = [];
  bool isLoading = false;
  String? errorMessage;

  RolesController() {
    loadData();
  }

  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();
    try {
      final rolesData = await DatabaseHelper.instance.getRoles();
      allPermissions = await DatabaseHelper.instance.getPermissions();
      
      roles = [];
      for (var r in rolesData) {
        final perms = await _getRolePermissions(r['id']);
        roles.add(Role.fromMap(r, permissions: perms));
      }
      
      final db = await DatabaseHelper.instance.database;
      branches = await db.query('branches', where: 'status = 1');
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<String>> _getRolePermissions(String roleId) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('role_permissions', where: 'role_id = ?', whereArgs: [roleId]);
    return res.map((p) => p['permission_id'].toString()).toList();
  }

  Future<bool> saveRole(Role role) async {
    try {
      await DatabaseHelper.instance.insertRole(role.toMap());
      await DatabaseHelper.instance.insertRolePermissions(role.id, role.permissionIds);
      await loadData();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
