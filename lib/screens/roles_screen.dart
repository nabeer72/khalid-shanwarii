import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/roles_controller.dart';
import 'package:mobile_app/models/role.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/providers/theme_provider.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  final RolesController _controller = RolesController();
  final theme = ThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    if (!mounted) return;
    if (_controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.errorMessage!),
          backgroundColor: Colors.redAccent,
        ),
      );
      _controller.errorMessage = null; // Clear after showing
    }
    setState(() {});
  }

  void _showRoleDialog([Role? role]) {
    final nameController = TextEditingController(text: role?.name ?? '');
    final descController = TextEditingController(text: role?.description ?? '');
    int? selectedBranchId = role?.branchId ?? BusinessConfig.instance.branchId;
    
    // Ensure the selectedBranchId actually exists in the loaded branches list.
    // If not, fall back to the first available branch, or null if empty.
    bool branchExists = _controller.branches.any((b) {
      final bId = b['id'] is int ? b['id'] : int.tryParse(b['id']?.toString() ?? '');
      return bId == selectedBranchId;
    });

    if (!branchExists) {
      if (_controller.branches.isNotEmpty) {
        selectedBranchId = _controller.branches.first['id'] is int 
            ? _controller.branches.first['id'] as int 
            : int.tryParse(_controller.branches.first['id']?.toString() ?? '');
      } else {
        selectedBranchId = null;
      }
    }

    List<int> selectedPerms = List.from(role?.permissionIds ?? []);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Group permissions by module
          Map<String, List<Map<String, dynamic>>> grouped = {};
          for (var p in _controller.allPermissions) {
            String name = (p['name'] ?? '').toString().toLowerCase();
            String module = 'General';
            if (name.contains('product') || name.contains('stock')) module = 'Inventory';
            else if (name.contains('sale') || name.contains('pos') || name.contains('recovery')) module = 'Sales';
            else if (name.contains('expense')) module = 'Expenses';
            else if (name.contains('supplier') || name.contains('vendor') || name.contains('payback')) module = 'Suppliers';
            else if (name.contains('customer')) module = 'Customers';
            else if (name.contains('staff') || name.contains('role') || name.contains('employee')) module = 'Staff';
            else if (name.contains('report')) module = 'Reports';
            else if (name.contains('setting') || name.contains('branch') || name.contains('bank')) module = 'Configuration';
            
            grouped.putIfAbsent(module, () => []).add(p);
          }

          return AlertDialog(
            backgroundColor: theme.surface,
            title: Text(role == null ? 'Create Role' : 'Edit Role', style: TextStyle(color: theme.textPrimary)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: theme.textPrimary),
                      decoration: theme.glassInputDecoration('Role Name', Icons.badge_outlined),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      style: TextStyle(color: theme.textPrimary),
                      decoration: theme.glassInputDecoration('Description', Icons.description_outlined),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      value: selectedBranchId,
                      dropdownColor: theme.surface,
                      style: TextStyle(color: theme.textPrimary),
                      decoration: theme.glassInputDecoration('Assign to Branch', Icons.storefront_outlined),
                      items: [
                        ..._controller.branches.map((b) => DropdownMenuItem(
                          value: b['id'] is int ? b['id'] : int.tryParse(b['id']?.toString() ?? ''),
                          child: Text(b['branch_title'] ?? 'Branch'),
                        )),
                      ],
                      onChanged: (val) => setDialogState(() => selectedBranchId = val),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Permissions by Module', 
                            style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          icon: Icon(
                            selectedPerms.length == _controller.allPermissions.length 
                              ? Icons.deselect 
                              : Icons.select_all, 
                            size: 16, 
                            color: theme.highlight
                          ),
                          label: Text(
                            selectedPerms.length == _controller.allPermissions.length ? 'Deselect All' : 'Assign All',
                            style: TextStyle(color: theme.highlight, fontSize: 12),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              if (selectedPerms.length == _controller.allPermissions.length) {
                                selectedPerms.clear();
                              } else {
                                selectedPerms = _controller.allPermissions.map((p) => p['id'] as int).toList();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 400,
                      decoration: BoxDecoration(
                        color: theme.background.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView(
                        children: grouped.entries.map((entry) {
                          final groupPermIds = entry.value.map((p) => p['id'] as int).toList();
                          final bool isAllSelectedInGroup = groupPermIds.every((id) => selectedPerms.contains(id));
                          final bool isPartiallySelectedInGroup = groupPermIds.any((id) => selectedPerms.contains(id)) && !isAllSelectedInGroup;

                          return ExpansionTile(
                            leading: Icon(_getModuleIcon(entry.key), color: theme.highlight, size: 20),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(entry.key, style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                                ),
                                Checkbox(
                                  value: isAllSelectedInGroup ? true : (isPartiallySelectedInGroup ? null : false),
                                  tristate: true,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true || val == null) {
                                        // If empty or partial, select all in this group
                                        for (var id in groupPermIds) {
                                          if (!selectedPerms.contains(id)) selectedPerms.add(id);
                                        }
                                      } else {
                                        // Deselect all in this group
                                        selectedPerms.removeWhere((id) => groupPermIds.contains(id));
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            children: entry.value.map((p) {
                              final pid = p['id'] as int;
                              final isSelected = selectedPerms.contains(pid);
                              return CheckboxListTile(
                                title: Text(p['label'] ?? p['name'] ?? pid, style: TextStyle(color: theme.textPrimary, fontSize: 12)),
                                value: isSelected,
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selectedPerms.add(pid);
                                    } else {
                                      selectedPerms.remove(pid);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a role name')),
                    );
                    return;
                  }
                  
                  if (selectedBranchId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a branch for this role')),
                    );
                    return;
                  }

                  final newRole = Role(
                    id: role?.id,
                    businessId: BusinessConfig.instance.businessId ?? 0,
                    branchId: selectedBranchId,
                    name: nameController.text.trim(),
                    description: descController.text.trim(),
                    permissionIds: selectedPerms,
                  );
                  final success = await _controller.saveRole(newRole);
                  if (success && mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _getModuleIcon(String module) {
    switch (module) {
      case 'Inventory': return Icons.inventory_2_outlined;
      case 'Sales': return Icons.receipt_long_outlined;
      case 'Expenses': return Icons.account_balance_wallet_outlined;
      case 'Suppliers': return Icons.business_outlined;
      case 'Customers': return Icons.people_outline;
      case 'Staff': return Icons.badge_outlined;
      case 'Reports': return Icons.bar_chart_outlined;
      case 'Configuration': return Icons.settings_outlined;
      default: return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.textPrimary,
      ),
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRoleDialog(),
        backgroundColor: theme.highlight,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: theme.bgGradient)),
        child: SafeArea(
          child: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _controller.roles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge_outlined, size: 64, color: theme.textSecondary.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text('No roles found', style: TextStyle(color: theme.textSecondary, fontSize: 18)),
                          const SizedBox(height: 8),
                          Text('Add a role to get started', style: TextStyle(color: theme.textSecondary.withOpacity(0.7), fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _controller.roles.length,
                      itemBuilder: (ctx, i) {
                        final role = _controller.roles[i];
                        return Card(
                          color: theme.surface.withOpacity(0.5),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            title: Text(role.name, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
                            subtitle: Text('${role.permissionIds.length} permissions', style: TextStyle(color: theme.textSecondary)),
                            trailing: IconButton(
                              icon: Icon(Icons.edit, color: theme.highlight),
                              onPressed: () => _showRoleDialog(role),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
