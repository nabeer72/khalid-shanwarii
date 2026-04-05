import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/services/sync_service.dart';
import 'package:mobile_app/services/connectivity_service.dart';

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  final theme = ThemeProvider.instance;
  final db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _units = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    setState(() => _isLoading = true);
    final units = await db.getUnits();
    setState(() {
      _units = units;
      _isLoading = false;
    });
  }

  void _showAddEditUnitDialog([Map<String, dynamic>? unit]) {
    final nameCtrl = TextEditingController(text: unit?['name'] ?? '');
    bool isActive = unit?['status'] == 1 || unit == null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(unit == null ? 'Add Unit' : 'Edit Unit', 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: theme.glassInputDecoration('Unit Name (e.g. Kg, Pcs)', Icons.scale_rounded),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Is Active', style: TextStyle(fontWeight: FontWeight.w600)),
                value: isActive,
                activeColor: ThemeProvider.success,
                onChanged: (val) => setDialogState(() => isActive = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.highlight,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (nameCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a unit name'), backgroundColor: Colors.red));
                  return;
                }

                final unitData = {
                  'name': nameCtrl.text,
                  'status': isActive ? 1 : 0,
                };

                await db.insertUnit(unitData);

                // Directly add to live database if internet is available
                if (await ConnectivityService.instance.getConnectionStatus() == ConnectionStatus.online) {
                  SyncService().syncPush();
                }

                Navigator.pop(ctx);
                _loadUnits();
              },
              child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteUnit(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Unit?'),
        content: const Text('Are you sure you want to delete this unit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await db.deleteUnit(id);
      if (await ConnectivityService.instance.getConnectionStatus() == ConnectionStatus.online) {
        SyncService().syncPush();
      }
      _loadUnits();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Manage Units', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900)),
        leading: BackButton(color: theme.textPrimary),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _units.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.scale_rounded, size: 64, color: theme.textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('No units defined', style: TextStyle(color: theme.textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditUnitDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Unit'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _units.length,
                  itemBuilder: (ctx, i) {
                    final unit = _units[i];
                    final isActive = unit['status'] == 1;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: theme.glassDecoration,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.whiteAlpha(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.straighten_rounded, color: theme.highlight),
                          ),
                          title: Text(unit['name'] ?? '', 
                            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('INACTIVE', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 20),
                                onPressed: () => _showAddEditUnitDialog(unit),
                                color: theme.textSecondary,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                onPressed: () => _deleteUnit(unit['id']),
                                color: Colors.redAccent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditUnitDialog(),
        backgroundColor: theme.highlight,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}
