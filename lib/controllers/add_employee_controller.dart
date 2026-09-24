import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/providers/theme_provider.dart';



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
  List<int> selectedRoleIds = [];
  List<Map<String, dynamic>> roles = [];
  int status = 1; // 1 = active, 0 = inactive

  List<String> selectedRolePermissions = [];

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
    }

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {

    await _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      roles = await DatabaseHelper.instance.getRoles();
      
      if (isEditMode && initialEmployee?.id != null) {
        selectedRoleIds = await DatabaseHelper.instance.getEmployeeRoleIds(initialEmployee!.id!);
      }

      await _updateRolePermissions();
      notifyListeners();
    } catch (e) {
      print('Error loading roles: $e');
    }
  }

  Future<void> _updateRolePermissions() async {
    final Set<String> allPerms = {};
    for (var rid in selectedRoleIds) {
      final perms = await DatabaseHelper.instance.getRolePermissions(rid);
      allPerms.addAll(perms.map((p) => p.toString()));
    }
    selectedRolePermissions = allPerms.toList();
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

  void toggleRole(int? roleId) async {
    if (roleId == null) return;
    if (selectedRoleIds.contains(roleId)) {
      selectedRoleIds.remove(roleId);
    } else {
      selectedRoleIds.add(roleId);
    }
    await _updateRolePermissions();
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
      // Backward compatibility: use the first selected role name
      String roleName = 'cashier';
      if (selectedRoleIds.isNotEmpty) {
        final firstRoleId = selectedRoleIds.first;
        final roleObj = roles.firstWhere((r) => r['id'] == firstRoleId || r['id'].toString() == firstRoleId.toString(), orElse: () => {});
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
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Enforce email uniqueness locally
      final db = await DatabaseHelper.instance.database;
      final cleanEmail = email.text.trim().toLowerCase();
      final bid = BusinessConfig.instance.businessId;
      final uid = BusinessConfig.instance.userId;
      final List<Map<String, dynamic>> existing = await db.query(
        'employees',
        where: 'LOWER(email) = ? AND id != ? AND business_id = ? AND user_id = ?',
        whereArgs: [cleanEmail, initialEmployee?.id ?? -1, bid, uid],
      );

      if (existing.isNotEmpty) {
        _errorMessage = 'An employee with this email already exists';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final insertedId = await DatabaseHelper.instance.insertEmployee(empMap);
      
      // Update employee_roles pivot table
      final idToUse = initialEmployee?.id ?? insertedId;
      // ignore: unnecessary_null_comparison
      if (idToUse != null) {
        await DatabaseHelper.instance.updateEmployeeRoles(idToUse, selectedRoleIds);
      }

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
    if (value == null || value.trim().isEmpty) return 'PIN is required';
    if (value.length != 4) {
      return 'PIN must be exactly 4 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'PIN must be numeric';
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
