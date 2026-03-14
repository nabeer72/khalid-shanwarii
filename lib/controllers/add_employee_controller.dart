import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/providers/theme_provider.dart';

import 'package:mobile_app/models/branch.dart';

// Assuming you have these available — adjust imports if needed
// import 'package:mobile_app/models/employee.dart';           // if you have Employee model
// import 'package:mobile_app/utils/app_permissions.dart';   // for AppPermissions

class AddEmployeeController with ChangeNotifier {
  final Employee? initialEmployee;

  // Controllers
  late TextEditingController name;
  late TextEditingController password;
  late TextEditingController email;
  late TextEditingController phone;
  late TextEditingController search;

  // State
  int? selectedRoleId;
  List<Map<String, dynamic>> roles = [];
  int status = 1; // 1 = active, 0 = inactive
  int? selectedBranchId;
  List<Branch> branches = [];

  bool _isLoading = false;
  String? _errorMessage;

  AddEmployeeController({this.initialEmployee}) {
    name = TextEditingController(text: initialEmployee?.name ?? '');
    password = TextEditingController(text: initialEmployee?.pin ?? '');
    email = TextEditingController(text: initialEmployee?.email ?? '');
    phone = TextEditingController(text: initialEmployee?.phone ?? '');
    search = TextEditingController();

    final emp = initialEmployee;
    if (emp != null) {
      status = emp.isActive ? 1 : 0;
      selectedBranchId = emp.branchId;
      selectedRoleId = emp.roleId;
    }

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadBranches();
    await _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      // Load ALL roles for this business (no branch filter) so dropdowns show everything
      final db = await DatabaseHelper.instance.database;
      final rawBid = BusinessConfig.instance.businessId;
      final rawAid = BusinessConfig.instance.adminId;
      final bid = rawBid is int ? rawBid : int.tryParse(rawBid?.toString() ?? '');
      final aid = rawAid is int ? rawAid : int.tryParse(rawAid?.toString() ?? '');
      roles = await db.rawQuery(
        'SELECT * FROM roles WHERE status = 1 AND business_id = ? AND admin_id = ?',
        [bid, aid],
      );
      
      if (selectedRoleId != null) {
        // Ensure the selected role still exists in the loaded list
        if (!roles.any((r) => r['id'] == selectedRoleId)) {
          selectedRoleId = null;
        }
      } else if (initialEmployee?.roleId != null) {
          final targetId = initialEmployee!.roleId!;
          if (roles.any((r) => r['id'] == targetId)) {
            selectedRoleId = targetId;
          }
      }
      notifyListeners();
    } catch (e) {
      print('Error loading roles: $e');
    }
  }

  Future<void> _loadBranches() async {
    try {
      // Load ALL branches (no active filter) so dropdowns show everything
      final data = await DatabaseHelper.instance.getAllBranches();
      branches = data.map((b) => Branch.fromMap(b)).toList();
      
      // If employee has a branch ID that exists, keep it. Otherwise null.
      if (selectedBranchId != null) {
        if (!branches.any((b) => b.id == selectedBranchId)) {
          selectedBranchId = null;
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error loading branches: $e');
    }
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEditMode => initialEmployee != null;

  String get screenTitle => isEditMode ? 'Edit Employee' : 'Add New Employee';
  String get buttonLabel => 'SAVE EMPLOYEE';

  String get statusLabel => status == 1 ? 'Active Account' : 'Inactive Account';
  IconData get statusIcon => status == 1 ? Icons.check_circle : Icons.cancel;
  Color get statusColor => status == 1 ? ThemeProvider.success : ThemeProvider.error;

  // Removed permissions-related getters and methods as they are now handled by Roles
  // List<String> get filteredPermissions {
  //   return AppPermissions.all.where((p) {
  //     final label = AppPermissions.getLabel(p).toLowerCase();
  //     return label.contains(searchQuery);
  //   }).toList();
  // }

  // void togglePermission(String permission, bool? value) {
  //   if (value == true) {
  //     if (!selectedPermissions.contains(permission)) {
  //       selectedPermissions.add(permission);
  //     }
  //   } else {
  //     selectedPermissions.remove(permission);
  //   }
  //   notifyListeners();
  // }

  // void removeChip(String permission) {
  //   selectedPermissions.remove(permission);
  //   notifyListeners();
  // }

  void toggleStatus(bool active) {
    status = active ? 1 : 0;
    notifyListeners();
  }

  void setRole(int? newRoleId) {
    selectedRoleId = newRoleId;
    notifyListeners();
  }

  void setBranch(int? branchId) {
    selectedBranchId = branchId;
    notifyListeners();
  }

  Future<bool> save() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (name.text.trim().isEmpty || email.text.trim().isEmpty || password.text.trim().isEmpty) {
      _errorMessage = 'Name, Email and Password are mandatory';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      // Get role name for the 'role' column (backward compatibility/simplicity)
      String roleName = 'cashier';
      if (selectedRoleId != null) {
        final roleObj = roles.firstWhere((r) => r['id'] == selectedRoleId, orElse: () => {});
        if (roleObj.isNotEmpty) {
          roleName = roleObj['name']?.toString().toLowerCase() ?? 'cashier';
        }
      }

      final empMap = {
        'id': initialEmployee?.id,
        'name': name.text.trim(),
        'role': roleName, 
        'pin': password.text.trim().isEmpty ? null : password.text.trim(),
        'email': email.text.trim().toLowerCase(), 
        'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
        'status': status,
        'role_id': selectedRoleId,
        'branch_id': selectedBranchId,
        'permissions': jsonEncode(initialEmployee?.permissions ?? []), // Keep existing or empty if new
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Enforce email uniqueness locally
      final db = await DatabaseHelper.instance.database;
      final cleanEmail = email.text.trim().toLowerCase();
      final List<Map<String, dynamic>> existing = await db.query(
        'employees',
        where: 'LOWER(email) = ? AND id != ?',
        whereArgs: [cleanEmail, initialEmployee?.id ?? -1],
      );

      if (existing.isNotEmpty) {
        _errorMessage = 'An employee with this email already exists';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await DatabaseHelper.instance.insertEmployee(empMap);

      return true;
    } catch (e) {
      _errorMessage = 'Error saving employee: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) return 'Password is required';
    if (value.length < 4) {
      return 'Password must be at least 4 characters';
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return 'Enter a valid email';
    }
    return null;
  }

  @override
  void dispose() {
    name.dispose();
    password.dispose();
    email.dispose();
    phone.dispose();
    search.dispose();
    super.dispose();
  }
}
