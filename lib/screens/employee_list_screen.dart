import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/add_employee_screen.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final theme = ThemeProvider.instance;
  List<Employee> _employees = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final data = await DatabaseHelper.instance.getEmployees();
      final roles = await DatabaseHelper.instance.getRoles();
      final roleMap = {for (var r in roles) r['id'].toString(): r};
      
      final List<Employee> tempEmployees = [];
      final currentAdminId = BusinessConfig.instance.adminId;

      for (var e in data) {
        if (e['id'] == currentAdminId) continue;

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
        final roleId = e['role_id']?.toString();
        if (roleId != null && roleMap.containsKey(roleId)) {
          final rolePermissions = await DatabaseHelper.instance.getRolePermissions(roleId);
          perms.addAll(rolePermissions);
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

      if (mounted) {
        setState(() {
          _employees = tempEmployees;
          // Sort: active employees first, then inactive
          _employees.sort((a, b) => b.isActive ? 1 : -1);
        });
      }
    } catch (e) {
      print('Error loading employees: $e');
    }
  }

  Future<Map<String, dynamic>?> _getRole(String roleId) async {
    return await DatabaseHelper.instance.getRoleById(roleId);
  }

  void _openAddEmployeeScreen([Employee? employee]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEmployeeScreen(employee: employee),
      ),
    );

    if (result == true) {
      _loadEmployees();
    }
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
                child: Row(
                  children: [
                    _buildQuickStat('Total', _employees.length.toString(), Icons.people_rounded),
                    const SizedBox(width: 12),
                    _buildQuickStat('Active', _employees.where((e) => e.isActive).length.toString(), Icons.check_circle_rounded),
                  ],
                ),
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
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _openAddEmployeeScreen(emp),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  decoration: theme.glassDecoration,
                                  child: Opacity(
                                    opacity: emp.isActive ? 1.0 : 0.6,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 52,
                                                height: 52,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [roleColor, roleColor.withOpacity(0.7)],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  borderRadius: BorderRadius.circular(16),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: roleColor.withOpacity(0.3),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    emp.name[0].toUpperCase(), 
                                                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      emp.name,
                                                      style: TextStyle(
                                                        color: theme.textPrimary,
                                                        fontSize: 17,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: roleColor.withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: roleColor.withOpacity(0.3)),
                                                      ),
                                                      child: Text(
                                                        emp.role.toUpperCase(), 
                                                        style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                                      ),
                                                    ),
                                                    if (emp.roleId != null) ...[
                                                      const SizedBox(height: 4),
                                                      FutureBuilder<Map<String, dynamic>?>(
                                                        future: _getRole(emp.roleId!),
                                                        builder: (ctx, snap) {
                                                          if (snap.hasData && snap.data != null) {
                                                            return Text(
                                                              snap.data!['name']?.toString().toUpperCase() ?? '',
                                                              style: TextStyle(color: theme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                                                            );
                                                          }
                                                          return const SizedBox.shrink();
                                                        },
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              Switch(
                                                value: emp.isActive,
                                                activeColor: ThemeProvider.success,
                                                activeTrackColor: ThemeProvider.success.withOpacity(0.3),
                                                inactiveThumbColor: theme.textHint,
                                                inactiveTrackColor: theme.textHint.withOpacity(0.2),
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
                                            ],
                                          ),
                                          if (emp.email != null || emp.phone != null) ...[
                                            const SizedBox(height: 16),
                                            Divider(color: theme.textHint.withOpacity(0.1), height: 1),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                if (emp.email != null) ...[
                                                  Icon(Icons.alternate_email_rounded, size: 14, color: theme.iconColor),
                                                  const SizedBox(width: 6),
                                                  Expanded(child: Text(emp.email!, style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500))),
                                                ],
                                                if (emp.phone != null) ...[
                                                  const SizedBox(width: 12),
                                                  Icon(Icons.phone_iphone_rounded, size: 14, color: theme.iconColor),
                                                  const SizedBox(width: 6),
                                                  Text(emp.phone!, style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                                                ],
                                              ],
                                            ),
                                          ],
                                          if (emp.permissions.isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                 ...emp.permissions.take(4).map((p) => Container(
                                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                   decoration: BoxDecoration(
                                                     color: theme.surface.withOpacity(0.4),
                                                     borderRadius: BorderRadius.circular(6),
                                                     border: Border.all(color: theme.textHint.withOpacity(0.1)),
                                                   ),
                                                   child: Text(
                                                     AppPermissions.getLabel(p).toUpperCase(), 
                                                     style: TextStyle(color: theme.textSecondary, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                                                   ),
                                                 )),
                                                 if (emp.permissions.length > 4)
                                                   Container(
                                                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                     child: Text('+${emp.permissions.length - 4}', style: TextStyle(color: theme.highlight, fontSize: 9, fontWeight: FontWeight.bold)),
                                                   ),
                                               ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
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
    return Expanded(
      child: Container(
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
              children: [
                Text(value, style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 9, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
