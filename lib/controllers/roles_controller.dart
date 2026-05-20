import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/models/role.dart';

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
      // Load roles using the centralized method to ensure branch isolation
      final rolesData = await DatabaseHelper.instance.getRoles();
      allPermissions = await DatabaseHelper.instance.getPermissions();
      
      roles = [];
      for (var r in rolesData) {
        final id = r['id'] is int ? r['id'] as int : int.tryParse(r['id']?.toString() ?? '') ?? 0;
        final perms = await _getRolePermissions(id);
        roles.add(Role.fromMap(r, permissions: perms));
      }

      print('🔍 [Roles] Found ${roles.length} role(s)');

      final data = await DatabaseHelper.instance.getBranches();
      branches = data.where((b) => b['status'] == 1).toList();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<int>> _getRolePermissions(int roleId) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('role_permissions', where: 'role_id = ?', whereArgs: [roleId]);
    return res.map((p) => p['permission_id'] is int ? p['permission_id'] as int : int.tryParse(p['permission_id']?.toString() ?? '') ?? 0).toList();
  }

  Future<bool> saveRole(Role role) async {
    try {
      print('💾 [SaveRole] Saving role: ${role.name}, id: ${role.id}, branchId: ${role.branchId}, businessId: ${role.businessId}');
      print('💾 [SaveRole] toMap: ${role.toMap()}');
      print('💾 [SaveRole] permissionIds: ${role.permissionIds}');
      final roleId = await DatabaseHelper.instance.insertRole(role.toMap());
      print('💾 [SaveRole] Inserted with roleId: $roleId');
      await DatabaseHelper.instance.insertRolePermissions(role.id ?? roleId, role.permissionIds);
      print('💾 [SaveRole] Permissions saved for roleId: ${role.id ?? roleId}');
      await loadData();
      print('💾 [SaveRole] Data reloaded. Total roles: ${roles.length}');
      return true;
    } catch (e, stackTrace) {
      print('❌ [SaveRole] ERROR: $e');
      print('❌ [SaveRole] STACK: $stackTrace');
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
