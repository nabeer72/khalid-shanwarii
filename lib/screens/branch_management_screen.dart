import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:mobile_app/models/branch.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  final theme = ThemeProvider.instance;
  List<Branch> _branches = [];
  bool _isLoading = true;
  List<String> _inactiveBranchIds = [];

  @override
  void initState() {
    super.initState();
    _inactiveBranchIds = List.from(BusinessConfig.instance.inactiveBranchIds);
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllBranches();
    if (mounted) {
      setState(() {
        _branches = data.map((b) => Branch.fromMap(b)).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleActiveBranch(Branch branch) async {
    const storage = FlutterSecureStorage();
    final newInactiveList = List<String>.from(_inactiveBranchIds);
    
    if (newInactiveList.contains(branch.id)) {
      newInactiveList.remove(branch.id);
    } else {
      newInactiveList.add(branch.id);
    }

    await storage.write(key: 'inactive_branches', value: newInactiveList.join(','));
    BusinessConfig.instance.inactiveBranchIds = newInactiveList;

    BusinessConfig.instance.activeBranchIds = _branches
        .where((b) => !newInactiveList.contains(b.id))
        .map((b) => b.id)
        .toList();

    setState(() => _inactiveBranchIds = newInactiveList);
    if (mounted) {
      final isActive = !newInactiveList.contains(branch.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive ? 'Branch Activated' : 'Branch Deactivated'),
          backgroundColor: isActive ? ThemeProvider.success : ThemeProvider.warning,
        ),
      );
    }
  }

  Future<void> _deactivateAllBranches() async {
    const storage = FlutterSecureStorage();
    final allIds = _branches.map((b) => b.id).toList();
    await storage.write(key: 'inactive_branches', value: allIds.join(','));
    BusinessConfig.instance.inactiveBranchIds = allIds;
    BusinessConfig.instance.activeBranchIds = [];
    setState(() => _inactiveBranchIds = allIds);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('All branches deactivated.'),
            backgroundColor: ThemeProvider.warning),
      );
    }
  }

  void _showBranchDialog([Branch? branch]) {
    final titleCtrl = TextEditingController(text: branch?.branchTitle ?? '');
    final codeCtrl = TextEditingController(text: branch?.branchCode ?? '');
    final addressCtrl = TextEditingController(text: branch?.branchAddress ?? '');
    final contactCtrl = TextEditingController(text: branch?.contactNumber?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text(branch == null ? 'Add New Branch' : 'Edit Branch',
            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(titleCtrl, 'Branch Title *', Icons.business_rounded),
              const SizedBox(height: 12),
              _buildDialogField(codeCtrl, 'Branch Code (optional)', Icons.qr_code_rounded),
              const SizedBox(height: 12),
              _buildDialogField(addressCtrl, 'Branch Address', Icons.location_on_rounded),
              const SizedBox(height: 12),
              _buildDialogField(contactCtrl, 'Contact Number', Icons.phone_rounded, isNumber: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;
              
              final newBranch = Branch(
                id: branch?.id ?? const Uuid().v4(),
                businessId: BusinessConfig.instance.businessId,
                userId: BusinessConfig.instance.adminId,
                branchTitle: titleCtrl.text,
                branchCode: codeCtrl.text.isEmpty ? null : codeCtrl.text,
                branchAddress: addressCtrl.text.isEmpty ? null : addressCtrl.text,
                contactNumber: int.tryParse(contactCtrl.text),
              );

              if (branch == null) {
                await DatabaseHelper.instance.insertBranch(newBranch.toMap());
              } else {
                await DatabaseHelper.instance.updateBranch(newBranch.id, newBranch.toMap());
              }

              if (ctx.mounted) Navigator.pop(ctx);
              _loadBranches();
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.highlight),
            child: Text(branch == null ? 'ADD BRANCH' : 'UPDATE', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: theme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.textSecondary),
        prefixIcon: Icon(icon, color: theme.iconColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Branch Management',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
        actions: [
          if (_branches.length > _inactiveBranchIds.length)
            TextButton.icon(
              onPressed: _deactivateAllBranches,
              icon: const Icon(Icons.clear_all, color: Colors.orangeAccent, size: 18),
              label: const Text('Deactivate All', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
            ),
        ],
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: Column(
            children: [
              Builder(
                builder: (context) {
                  final activeCount = _branches.length - _inactiveBranchIds.length;
                  if (activeCount > 0) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16).copyWith(bottom: 0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: ThemeProvider.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ThemeProvider.success.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: ThemeProvider.success, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Active ($activeCount): ${_branches.where((b) => !_inactiveBranchIds.contains(b.id)).map((b) => b.branchTitle).join(", ")}',
                              style: const TextStyle(color: ThemeProvider.success, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }
              ),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: theme.highlight))
                    : _branches.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.business_center_rounded, size: 80, color: theme.iconColor.withValues(alpha: 0.5)),
                                const SizedBox(height: 16),
                                Text('No branches found',
                                    style: TextStyle(fontSize: 18, color: theme.textPrimary, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('Add your first branch to get started',
                                    style: TextStyle(color: theme.textSecondary)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _branches.length,
                            itemBuilder: (ctx, i) {
                              final b = _branches[i];
                              final isActive = !_inactiveBranchIds.contains(b.id);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: theme.glassDecoration.copyWith(
                                  border: isActive
                                      ? Border.all(color: ThemeProvider.success, width: 2)
                                      : null,
                                ),
                                child: ListTile(
                                  onTap: () => _toggleActiveBranch(b),
                                  leading: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? ThemeProvider.success.withValues(alpha: 0.15)
                                          : theme.highlight.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isActive ? Icons.check_circle_rounded : Icons.storefront_rounded,
                                      color: isActive ? ThemeProvider.success : theme.highlight,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(b.branchTitle,
                                            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
                                      ),
                                      if (isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: ThemeProvider.success.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Text('ACTIVE',
                                              style: TextStyle(color: ThemeProvider.success, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${b.branchCode ?? "No Code"} • ${b.branchAddress ?? "No Address"}',
                                    style: TextStyle(color: theme.textSecondary, fontSize: 12),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined, color: theme.iconColor),
                                        onPressed: () => _showBranchDialog(b),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                        tooltip: 'Delete',
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              backgroundColor: theme.surface,
                                              title: Text('Delete Branch?', style: TextStyle(color: theme.textPrimary)),
                                              content: Text('Are you sure you want to delete ${b.branchTitle}?',
                                                  style: TextStyle(color: theme.textSecondary)),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(ctx, false),
                                                    child: Text('CANCEL', style: TextStyle(color: theme.textSecondary))),
                                                TextButton(onPressed: () => Navigator.pop(ctx, true),
                                                    child: const Text('DELETE', style: TextStyle(color: Colors.redAccent))),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            if (isActive) await _toggleActiveBranch(b);
                                            await DatabaseHelper.instance.deleteBranch(b.id);
                                            _loadBranches();
                                          }
                                        },
                                      ),
                                    ],
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
        onPressed: () => _showBranchDialog(),
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('ADD BRANCH'),
        backgroundColor: theme.highlight,
      ),
    );
  }
}
