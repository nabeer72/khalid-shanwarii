// lib/screens/suppliers_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/suppliers_controller.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/controllers/add_supplier_controller.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  late final SuppliersController _controller;
  final theme = ThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _controller = SuppliersController();
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    // If controller is not used anywhere else → you can dispose it too
    // _controller.dispose();   // ← only if nobody else listens
    super.dispose();
  }

  Future<void> _handleAddEdit([Supplier? supplier]) async {
    _showSupplierFormDialog(supplier);
  }

  void _showSupplierFormDialog([Supplier? supplier]) {
    final controller = AddSupplierController(initialSupplier: supplier);
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
                  controller.isEdit ? 'Edit Supplier' : 'New Supplier',
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
                      _buildSectionHeader('Business Info'),
                      _buildTextField(
                        controller: controller.nameCtrl,
                        label: 'Supplier Name',
                        icon: Icons.business_rounded,
                        isRequired: true,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: controller.contactCtrl,
                        label: 'Contact Person',
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 20),
                      _buildSectionHeader('Contact Details'),
                      _buildTextField(
                        controller: controller.phoneCtrl,
                        label: 'Phone Number',
                        icon: Icons.phone_rounded,
                        type: TextInputType.phone,
                        isRequired: true,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Phone is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: controller.emailCtrl,
                        label: 'Email Address',
                        icon: Icons.email_rounded,
                        type: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: controller.addressCtrl,
                        label: 'Address',
                        icon: Icons.location_on_rounded,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),
                      _buildSectionHeader('Account Balance'),
                      _buildTextField(
                        controller: controller.balanceCtrl,
                        label: 'Opening Balance (Owed)',
                        icon: Icons.account_balance_wallet_rounded,
                        type: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              if (controller.isEdit)
                TextButton(
                  onPressed: () async {
                    final proceed = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => AlertDialog(
                        backgroundColor: theme.surface,
                        title: Text('Delete Supplier?', style: TextStyle(color: theme.textPrimary)),
                        content: Text('This action cannot be undone.', style: TextStyle(color: theme.textSecondary)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('CANCEL', style: TextStyle(color: theme.textSecondary))),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('DELETE', style: TextStyle(color: ThemeProvider.error))),
                        ],
                      ),
                    );
                    if (proceed == true) {
                      await controller.deleteSupplier(ctx);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _controller.refreshSuppliers();
                    }
                  },
                  child: const Text('DELETE', style: TextStyle(color: ThemeProvider.error, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('CANCEL', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.highlight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: controller.isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        await controller.saveSupplier(ctx);
                        if (mounted) {
                          _controller.refreshSuppliers();
                        }
                      },
                child: controller.isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        controller.saveButtonLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    bool isRequired = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
      validator: validator,
      decoration: theme.glassInputDecoration(label, icon, isRequired: isRequired).copyWith(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        foregroundColor: theme.textPrimary,
        title: const Text('Suppliers', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: _controller.isLoading
              ? Center(child: CircularProgressIndicator(color: theme.highlight))
              : _controller.suppliers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: theme.iconColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.iconColor.withOpacity(0.2)),
                            ),
                            child: Icon(Icons.business_outlined, size: 64, color: theme.iconColor),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No suppliers yet',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the + button to add your first supplier',
                            style: TextStyle(color: theme.textHint, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _controller.suppliers.length,
                      itemBuilder: (context, index) {
                        final supplier = _controller.suppliers[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: theme.glassListDecoration,
                          child: ListTile(
                            isThreeLine: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            onTap: () => _handleAddEdit(supplier),
                            title: Text(
                              supplier.name,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${supplier.contactPerson ?? 'No Contact'} | ${supplier.phone ?? 'No Phone'}',
                                    style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'RUNNING: ${BusinessConfig.instance.currencyDisplay}${supplier.openingAmount.toStringAsFixed(2)}',
                                    style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${BusinessConfig.instance.currencyDisplay}${supplier.creditBalance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: supplier.creditBalance > 0 ? ThemeProvider.error : theme.highlight,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'CREDIT BALANCE',
                                  style: TextStyle(color: theme.textHint, fontSize: 8, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleAddEdit(),
        backgroundColor: theme.highlight,
        elevation: 8,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
