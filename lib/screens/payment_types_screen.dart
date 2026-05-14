import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/services/sync_service.dart';
import 'package:mobile_app/services/connectivity_service.dart';

class PaymentTypesScreen extends StatefulWidget {
  const PaymentTypesScreen({super.key});

  @override
  State<PaymentTypesScreen> createState() => _PaymentTypesScreenState();
}

class _PaymentTypesScreenState extends State<PaymentTypesScreen> {
  final theme = ThemeProvider.instance;
  final db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _paymentTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentTypes();
  }

  Future<void> _loadPaymentTypes() async {
    setState(() => _isLoading = true);
    final pts = await db.getPaymentTypes();
    setState(() {
      _paymentTypes = pts;
      _isLoading = false;
    });
  }

  void _showAddEditPTDialog([Map<String, dynamic>? pt]) {
    final nameCtrl = TextEditingController(text: pt?['name'] ?? '');
    final codeCtrl = TextEditingController(text: pt?['code'] ?? '');
    bool isActive = pt?['status'] == 1 || pt == null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(pt == null ? 'Add Payment Type' : 'Edit Payment Type', 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: theme.glassInputDecoration('Type Name (e.g. Cash, Card)', Icons.payments_rounded),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                onChanged: (val) {
                  if (pt == null) {
                    codeCtrl.text = val.toLowerCase().replaceAll(' ', '_');
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                decoration: theme.glassInputDecoration('Code (e.g. cash, card)', Icons.code_rounded),
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Is Active', style: TextStyle(fontWeight: FontWeight.w600)),
                value: isActive,
                activeColor: theme.switchActiveColor,
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a name'), backgroundColor: Colors.red));
                  return;
                }

                final ptData = {
                  'name': nameCtrl.text,
                  'code': codeCtrl.text.isEmpty ? nameCtrl.text.toLowerCase().replaceAll(' ', '_') : codeCtrl.text,
                  'status': isActive ? 1 : 0,
                };

                await db.insertPaymentType(ptData);

                // Directly add to live database if internet is available
                if (await ConnectivityService.instance.getConnectionStatus() == ConnectionStatus.online) {
                  SyncService().syncPush();
                }

                Navigator.pop(ctx);
                _loadPaymentTypes();
              },
              child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePT(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment Type?'),
        content: const Text('Are you sure you want to delete this payment type?'),
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
      await db.deletePaymentType(id);
      if (await ConnectivityService.instance.getConnectionStatus() == ConnectionStatus.online) {
        SyncService().syncPush();
      }
      _loadPaymentTypes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Payment Types', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900)),
        leading: BackButton(color: theme.textPrimary),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _paymentTypes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payments_rounded, size: 64, color: theme.textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('No custom payment types', style: TextStyle(color: theme.textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditPTDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Payment Type'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _paymentTypes.length,
                  itemBuilder: (ctx, i) {
                    final pt = _paymentTypes[i];
                    final isActive = pt['status'] == 1;

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
                            child: Icon(Icons.credit_card_rounded, color: theme.highlight),
                          ),
                          title: Text(pt['name'] ?? '', 
                            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Text('Code: ${pt['code']}', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
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
                                onPressed: () => _showAddEditPTDialog(pt),
                                color: theme.textSecondary,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                onPressed: () => _deletePT(pt['id']),
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
        onPressed: () => _showAddEditPTDialog(),
        backgroundColor: theme.highlight,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}
