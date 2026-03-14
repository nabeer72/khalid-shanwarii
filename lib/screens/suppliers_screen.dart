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
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: theme.glassDecoration,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _handleAddEdit(supplier),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: theme.highlight.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: theme.highlight.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          supplier.name[0].toUpperCase(),
                                          style: TextStyle(
                                            color: theme.highlight,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            supplier.name,
                                            style: TextStyle(
                                              color: theme.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                          if (supplier.contactPerson?.isNotEmpty ?? false) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.person_outline_rounded, size: 14, color: theme.textHint),
                                                const SizedBox(width: 4),
                                                Text(
                                                  supplier.contactPerson!,
                                                  style: TextStyle(
                                                    color: theme.textSecondary,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (supplier.phone?.isNotEmpty ?? false) ...[
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(Icons.phone_outlined, size: 14, color: theme.textHint),
                                                const SizedBox(width: 4),
                                                Text(
                                                  supplier.phone!,
                                                  style: TextStyle(
                                                    color: theme.textHint,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (supplier.creditBalance > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: ThemeProvider.error.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${BusinessConfig.instance.currency}. ${supplier.creditBalance.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                color: ThemeProvider.error,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 14,
                                          color: theme.iconColor.withOpacity(0.3),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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