import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
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
      // Load ALL roles for this business (no branch filter) so the management screen sees everything
      final db = await DatabaseHelper.instance.database;
      final rawBid = BusinessConfig.instance.businessId;
      final rawAid = BusinessConfig.instance.adminId;
      final brid = BusinessConfig.instance.branchId;
      final bid = rawBid is int ? rawBid : int.tryParse(rawBid?.toString() ?? '');
      final aid = rawAid is int ? rawAid : int.tryParse(rawAid?.toString() ?? '');

      final rolesData = await db.rawQuery(
        'SELECT * FROM roles WHERE status = 1 AND business_id = ? AND admin_id = ?',
        [bid, aid],
      );
      allPermissions = await DatabaseHelper.instance.getPermissions();
      
      roles = [];
      for (var r in rolesData) {
        final id = r['id'] is int ? r['id'] as int : int.tryParse(r['id']?.toString() ?? '') ?? 0;
        final perms = await _getRolePermissions(id);
        roles.add(Role.fromMap(r, permissions: perms));
      }

      print('🔍 [Roles] Found ${roles.length} roles for BID: $bid, AID: $aid, BRID: $brid');

      branches = await db.query('branches', 
        where: 'status = 1 AND business_id = ? AND admin_id = ?', 
        whereArgs: [bid, aid]);
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
