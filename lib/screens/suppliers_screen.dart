// lib/screens/suppliers_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/suppliers_controller.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/add_supplier_screen.dart';

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
    await _controller.showAddEditDialog(context, supplier);
    // refresh is already handled inside controller
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
                          decoration: theme.glassDecoration,
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
