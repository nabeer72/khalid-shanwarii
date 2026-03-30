import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/controllers/add_employee_controller.dart';
import 'dart:convert';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final theme = ThemeProvider.instance;
  List<Employee> _employees = [];
  Map<dynamic, String> _permissionLabels = {};
  Map<dynamic, String> _branchNames = {};

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final data = await DatabaseHelper.instance.getAllEmployees();
      // Load roles using the centralized method to ensure branch isolation
      final roles = await DatabaseHelper.instance.getRoles();
      final roleMap = <int, Map<String, dynamic>>{};
      for (var r in roles) {
        final id = r['id'] is int ? r['id'] as int : int.tryParse(r['id']?.toString() ?? '');
        if (id != null) roleMap[id] = r;
      }
      
      final List<Employee> tempEmployees = [];
      final currentAdminId = BusinessConfig.instance.adminId;

      for (var e in data) {
        // Removed: if (e['id'] == currentAdminId) continue;
        // The admin is in the 'users' table, while staff are in the 'employees' table.
        // Comparing their primary keys is incorrect as they can overlap.

        Set<String> perms = {};
        // 1. Direct permissions
        if (e['permissions'] != null && e['permissions'].toString().isNotEmpty) {
          try {
            final decoded = e['permissions'] is String ? jsonDecode(e['permissions']) : e['permissions'];
            if (decoded is List) {
              perms.addAll(List<String>.from(decoded));
            }
          } catch (err) {
            print('Error decoding permissions for ${e['name']}: $err');
          }
        }
        
        // 2. Role-based permissions
        final roleIdInt = e['role_id'] is int ? e['role_id'] as int : int.tryParse(e['role_id']?.toString() ?? '');
        if (roleIdInt != null) {
          final rolePermissions = await DatabaseHelper.instance.getRolePermissions(roleIdInt);
          perms.addAll(rolePermissions.map((p) => p.toString()));
        }

        // DEBUG: Log merged permissions
        if (kDebugMode) {
          print('🔑 [DEBUG] Merged permissions for ${e['name']}: $perms');
        }
        
        tempEmployees.add(Employee(
          id: e['id'],
          name: e['name'],
          role: e['role'] ?? 'cashier',
          pin: e['pin'],
          email: e['email'],
          phone: e['phone'],
          isActive: e['status'] == 1,
          permissions: perms.toList(),
          branchId: e['branch_id'],
          roleId: e['role_id'],
        ));
      }

      // Load Permission Labels
      final permsList = await DatabaseHelper.instance.getPermissions();
      final Map<dynamic, String> labels = {};
      for (var p in permsList) {
        labels[p['id'] ?? p['name']] = p['label'] ?? p['name'];
      }

      // Load Branch Names
      final branchesList = await DatabaseHelper.instance.getAllBranches();
      final Map<dynamic, String> bNames = {};
      for (var b in branchesList) {
        bNames[b['id']] = b['branch_title'] ?? 'Branch';
      }

      if (mounted) {
        setState(() {
          _permissionLabels = labels;
          _branchNames = bNames;
          _employees = tempEmployees;
          // Sort: active employees first, then inactive
          _employees.sort((a, b) => b.isActive ? 1 : -1);
        });
      }
    } catch (e) {
      print('Error loading employees: $e');
    }
  }

  Future<Map<String, dynamic>?> _getRole(int? roleId) async {
    if (roleId == null) return null;
    return await DatabaseHelper.instance.getRoleById(roleId);
  }

  void _openAddEmployeeScreen([Employee? employee]) async {
    _showEmployeeFormDialog(employee);
  }

  void _showEmployeeFormDialog([Employee? employee]) {
    final controller = AddEmployeeController(initialEmployee: employee);
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          controller.addListener(() {
            if (ctx.mounted) setDialogState(() {});
          });

          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  controller.isEditMode ? 'Edit Staff' : 'Add Staff',
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: Icon(Icons.close_rounded, color: theme.textSecondary, size: 20),
                ),
              ],
            ),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDialogSectionHeader('Account Information'),
                      _buildDialogTextField(
                        controller: controller.name,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        validator: controller.validateName,
                      ),
                      const SizedBox(height: 12),
                      _buildDialogTextField(
                        controller: controller.email,
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: controller.validateEmail,
                      ),
                      const SizedBox(height: 12),
                      _buildDialogTextField(
                        controller: controller.phone,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Phone is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildDialogTextField(
                        controller: controller.password,
                        label: 'Password / PIN',
                        icon: Icons.lock_outline,
                        keyboardType: TextInputType.visiblePassword,
                        validator: controller.validatePassword,
                      ),
                      const SizedBox(height: 20),
                      _buildDialogSectionHeader('Role & Access'),
                      DropdownButtonFormField<int?>(
                        value: controller.roles.any((r) => r['id'] == controller.selectedRoleId)
                            ? controller.selectedRoleId
                            : null,
                        dropdownColor: theme.surface,
                        style: TextStyle(color: theme.textPrimary, fontSize: 13),
                        decoration: theme.glassInputDecoration('Access Role', Icons.badge_outlined).copyWith(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                        items: controller.roles
                            .map((r) => DropdownMenuItem<int?>(
                                  value: r['id'] is int ? r['id'] : int.tryParse(r['id']?.toString() ?? ''),
                                  child: Text(r['name']?.toString() ?? 'Unknown'),
                                ))
                            .toList(),
                        onChanged: (val) {
                          controller.setRole(val);
                          setDialogState(() {});
                        },
                      ),
                      if (controller.selectedRoleId != null && controller.selectedRolePermissions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: controller.selectedRolePermissions.map((p) {
                            final label = _permissionLabels[p] ?? _permissionLabels[int.tryParse(p)] ?? p;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.highlight.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: theme.highlight.withOpacity(0.15)),
                              ),
                              child: Text(
                                label.toUpperCase(),
                                style: TextStyle(color: theme.highlight, fontSize: 8, fontWeight: FontWeight.w900),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (controller.branches.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int?>(
                          value: (controller.selectedBranchId == null || controller.branches.any((b) => b.id == controller.selectedBranchId))
                              ? controller.selectedBranchId
                              : null,
                          dropdownColor: theme.surface,
                          style: TextStyle(color: theme.textPrimary, fontSize: 13),
                          decoration: theme.glassInputDecoration('Assign to Branch', Icons.storefront_outlined).copyWith(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All Branches (Global)'),
                            ),
                            ...controller.branches.map((b) => DropdownMenuItem<int?>(
                                  value: b.id,
                                  child: Text(b.branchTitle),
                                )),
                          ],
                          onChanged: (val) {
                            controller.setBranch(val);
                            setDialogState(() {});
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.background.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.textHint.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              controller.statusLabel,
                              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            Transform.scale(
                              scale: 0.7,
                              child: Switch.adaptive(
                                value: controller.status == 1,
                                activeColor: ThemeProvider.success,
                                onChanged: (val) {
                                  controller.toggleStatus(val);
                                  setDialogState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('CANCEL', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.highlight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: controller.isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        final success = await controller.save();
                        if (success && ctx.mounted) {
                          Navigator.pop(ctx);
                          _loadEmployees();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(controller.isEditMode ? 'Staff updated successfully!' : 'Staff member registered!'),
                              backgroundColor: ThemeProvider.success,
                            ),
                          );
                        } else if (controller.errorMessage != null && ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(controller.errorMessage!), backgroundColor: ThemeProvider.error),
                          );
                        }
                      },
                child: controller.isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        controller.isEditMode ? 'UPDATE' : 'REGISTER',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
      validator: validator,
      decoration: theme.glassInputDecoration(label, icon).copyWith(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: theme.textSecondary),
      prefixIcon: Icon(icon, color: theme.iconColor),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.isDark ? theme.textHint : Colors.black.withOpacity(0.3))),
      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.isDark ? theme.highlight : Colors.black.withOpacity(0.6))),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return ThemeProvider.error;
      case 'manager': return ThemeProvider.warning;
      default: return ThemeProvider.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Staff Management',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
        actions: [
          IconButton(
            icon: Icon(theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: theme.iconColor),
            onPressed: () => setState(() => theme.toggleTheme()),
          ),
        ],
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Summary Stats (Optional but looks good)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: LayoutBuilder(builder: (context, constraints) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final isTablet = screenWidth > 600;
                  
                  if (isTablet) {
                    return GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 240,
                        mainAxisExtent: 140,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      children: [
                        _buildQuickStat('Total Staff', _employees.length.toString(), Icons.people_rounded),
                        _buildQuickStat('Active Staff', _employees.where((e) => e.isActive).length.toString(), Icons.check_circle_rounded),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: _buildQuickStat('Total', _employees.length.toString(), Icons.people_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickStat('Active', _employees.where((e) => e.isActive).length.toString(), Icons.check_circle_rounded)),
                    ],
                  );
                }),
              ),
              
              Expanded(
                child: _employees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: theme.glassCircleDecoration,
                              child: Icon(Icons.people_alt_outlined, size: 60, color: theme.iconColor),
                            ),
                            const SizedBox(height: 16),
                            Text('No staff members', 
                              style: TextStyle(fontSize: 18, color: theme.textPrimary, fontWeight: FontWeight.w800)),
                            Text('Invite your team to get started', 
                              style: TextStyle(fontSize: 14, color: theme.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: _employees.length,
                        itemBuilder: (context, index) {
                          final emp = _employees[index];
                          final roleColor = _getRoleColor(emp.role);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: theme.glassDecoration,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              onTap: () => _openAddEmployeeScreen(emp),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(emp.name, 
                                        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(emp.role).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: _getRoleColor(emp.role).withOpacity(0.2)),
                                    ),
                                    child: Text(emp.role.toUpperCase(), 
                                        style: TextStyle(color: _getRoleColor(emp.role), fontSize: 7, fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '${emp.phone ?? 'No Phone'} | Branch: ${_branchNames[emp.branchId] ?? 'Global'}',
                                      style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  if (emp.permissions.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: emp.permissions.take(4).map((p) {
                                        final label = _permissionLabels[p] ?? _permissionLabels[int.tryParse(p.toString())] ?? p.toString();
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.highlight.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: theme.highlight.withOpacity(0.15)),
                                          ),
                                          child: Text(
                                            label.toUpperCase(),
                                            style: TextStyle(color: theme.highlight, fontSize: 8, fontWeight: FontWeight.w800),
                                          ),
                                        );
                                      }).toList()..addAll([
                                        if (emp.permissions.length > 4)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: theme.whiteAlpha(0.05),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '+${emp.permissions.length - 4} MORE',
                                              style: TextStyle(color: theme.textSecondary, fontSize: 8, fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                      ]),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Transform.scale(
                                scale: 0.7,
                                child: Switch(
                                  value: emp.isActive,
                                  activeColor: ThemeProvider.success,
                                  onChanged: (v) async {
                                    final empMap = {
                                      'id': emp.id,
                                      'name': emp.name,
                                      'role': emp.role,
                                      'pin': emp.pin,
                                      'permissions': emp.permissions,
                                      'status': v ? 1 : 0,
                                      'updated_at': DateTime.now().toIso8601String(),
                                    };
                                    await DatabaseHelper.instance.insertEmployee(empMap);
                                    _loadEmployees();
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEmployeeScreen(),
        backgroundColor: theme.highlight,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: const Text('ADD STAFF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        elevation: 8,
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: theme.glassDecoration.copyWith(
        color: theme.isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.2),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.highlight, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
              Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}
