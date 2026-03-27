import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/controllers/add_purchase_controller.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/scanner_screen.dart';
import 'package:mobile_app/screens/add_supplier_screen.dart';
import 'package:mobile_app/screens/add_product_screen.dart';
import 'package:mobile_app/db/mock_data.dart';

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  late AddPurchaseController _controller;
  final theme = ThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _controller = AddPurchaseController();
    _controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: theme.highlight)),
      );
    }

    // Show feedback messages from controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_controller.errorMessage!),
            backgroundColor: ThemeProvider.error,
          ),
        );
        _controller.clearFeedback();
      }
      if (_controller.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_controller.successMessage!),
            backgroundColor: ThemeProvider.success,
          ),
        );
        _controller.clearFeedback();
        Navigator.pop(context);
      }
    });

    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'New Purchase',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
      ),
      floatingActionButton: isDesktop
          ? FloatingActionButton.extended(
              onPressed: _controller.canSave ? _controller.savePurchase : null,
              backgroundColor: _controller.canSave ? theme.highlight : theme.highlight.withOpacity(0.3),
              foregroundColor: Colors.white,
              elevation: _controller.canSave ? 8 : 0,
              icon: const Icon(Icons.save_rounded),
              label: const Text('SAVE PURCHASE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
            )
          : null,
      body: theme.glassBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total display
                      _TotalCard(total: _controller.formattedTotal, theme: theme),

                      const SizedBox(height: 24),

                      // Purchase info
                      _PurchaseInfoCard(
                        controller: _controller,
                        theme: theme,
                        onDateTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _controller.purchaseDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) _controller.setPurchaseDate(picked);
                        },
                        onCreditDueTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) _controller.setCreditDueDate(picked);
                        },
                        onAddSupplier: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddSupplierScreen()),
                          );
                          await _controller.reloadSuppliers();
                        },
                      ),

                      const SizedBox(height: 32),

                      // Items header + button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Items',
                            style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [theme.highlight, theme.highlight.withOpacity(0.85)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.highlight.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _showAddItemDialog,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'ADD ITEM', 
                                        style: TextStyle(
                                          color: Colors.white, 
                                          fontWeight: FontWeight.w900, 
                                          fontSize: 12, 
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Items list or empty state
                      if (_controller.items.isEmpty)
                        _EmptyItemsState(theme: theme)
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _controller.items.length,
                          itemBuilder: (context, index) {
                            final item = _controller.items[index];
                            return _ItemTile(
                              item: item,
                              theme: theme,
                              currency: BusinessConfig.instance.currency,
                              onRemove: () => _controller.removeItem(index),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // Bottom save bar (mobile only)
              if (!isDesktop)
                _SaveButton(
                  theme: theme,
                  total: _controller.formattedTotal,
                  previous: _controller.formattedPreviousCredit,
                  onPressed: _controller.canSave ? _controller.savePurchase : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    int? selectedProductId;
    final qtyCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final wholesaleCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    int stock = 0;
    double currCost = 0;
    double currWholesale = 0;
    double currPrice = 0;

    InputDecoration _dialogInputDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        prefixIcon: Icon(icon, color: const Color(0xFF4B5563)),
        filled: true,
        fillColor: Colors.black.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
          borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              content: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                ),
                width: 400, // Constrain width instead of double.maxFinite
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Purchase Item',
                        style: TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 18, 
                          fontWeight: FontWeight.w900, 
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Product selector + scanner
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedProductId,
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600),
                              decoration: _dialogInputDecoration('Select Product', Icons.inventory_rounded),
                              items: _controller.products.map((p) => DropdownMenuItem(
                                value: p['id'] as int,
                                child: Text(p['name'] as String, overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setDialogState(() {
                                  selectedProductId = v;
                                  final p = _controller.products.firstWhere((x) => x['id'] == v);
                                  
                                  // Look for the latest stock batch to get current prices
                                  final stocks = p['stocks'] as List<dynamic>? ?? [];
                                  if (stocks.isNotEmpty) {
                                    final latestStock = stocks.last; 
                                    currCost = (latestStock['cost_price'] as num? ?? 0).toDouble();
                                    currWholesale = (latestStock['wholesale_price'] as num? ?? 0).toDouble();
                                    currPrice = (latestStock['sale_price'] as num? ?? 0).toDouble();
                                    stock = (latestStock['quantity'] as num? ?? 0).toInt();
                                  } else {
                                    currCost = 0;
                                    currWholesale = 0;
                                    currPrice = 0;
                                    stock = 0;
                                  }

                                  costCtrl.text = currCost.toStringAsFixed(2);
                                  wholesaleCtrl.text = currWholesale.toStringAsFixed(2);
                                  priceCtrl.text = currPrice.toStringAsFixed(2);
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          _ScannerButton(
                            theme: theme,
                            onScan: (code) async {
                              final p = _controller.products.firstWhere(
                                (x) => x['barcode'] == code,
                                orElse: () => {},
                              );
                              if (p.isNotEmpty) {
                                setDialogState(() {
                                  selectedProductId = p['id'] as int;
                                  
                                  // Look for the latest stock batch to get current prices
                                  final stocks = p['stocks'] as List<dynamic>? ?? [];
                                  if (stocks.isNotEmpty) {
                                    final latestStock = stocks.last;
                                    currCost = (latestStock['cost_price'] as num? ?? 0).toDouble();
                                    currWholesale = (latestStock['wholesale_price'] as num? ?? 0).toDouble();
                                    currPrice = (latestStock['sale_price'] as num? ?? 0).toDouble();
                                    stock = (latestStock['quantity'] as num? ?? 0).toInt();
                                  } else {
                                    currCost = 0;
                                    currWholesale = 0;
                                    currPrice = 0;
                                    stock = 0;
                                  }

                                  costCtrl.text = currCost.toStringAsFixed(2);
                                  wholesaleCtrl.text = currWholesale.toStringAsFixed(2);
                                  priceCtrl.text = currPrice.toStringAsFixed(2);
                                });
                              } else {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Product with barcode $code not found')),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          // Add New Product button
                          Container(
                            decoration: BoxDecoration(
                              color: theme.highlight.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.add_circle_outline_rounded, color: theme.highlight, size: 22),
                              tooltip: 'Add New Product',
                              onPressed: () async {
                                Navigator.pop(ctx); // Close the dialog first
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AddProductScreen()),
                                );
                                // Reload products after adding a new one
                                await _controller.reloadProducts();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (selectedProductId != null)
                        _ProductStats(
                          stock: stock,
                          cost: currCost,
                          currency: BusinessConfig.instance.currency,
                          theme: theme,
                          isDialog: true,
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: qtyCtrl, 
                        keyboardType: TextInputType.number, 
                        onChanged: (v) => setDialogState(() {}),
                        decoration: _dialogInputDecoration('Quantity', Icons.numbers_rounded), 
                        style: const TextStyle(color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: costCtrl, 
                        keyboardType: TextInputType.number, 
                        onChanged: (v) => setDialogState(() {}),
                        decoration: _dialogInputDecoration('Unit Cost', Icons.attach_money_rounded), 
                        style: const TextStyle(color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: wholesaleCtrl, 
                        keyboardType: TextInputType.number, 
                        decoration: _dialogInputDecoration('Wholesale Price', Icons.business_center_rounded), 
                        style: const TextStyle(color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceCtrl, 
                        keyboardType: TextInputType.number, 
                        decoration: _dialogInputDecoration('Selling Price', Icons.price_change_rounded), 
                        style: const TextStyle(color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx), 
                              child: const Text('CANCEL', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w900)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [theme.highlight, theme.highlight.withOpacity(0.85)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.highlight.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                                    if (selectedProductId == null || qty <= 0) return;
     
                                    final p = _controller.products.firstWhere((x) => x['id'] == selectedProductId);
                                      _controller.addItem(
                                        productId: selectedProductId!,
                                      productName: p['name'] as String,
                                      barcode: p['barcode'] as String?,
                                      existingStock: stock.toDouble(),
                                      quantity: qty,
                                      purchasePrice: double.tryParse(costCtrl.text.trim()) ?? 0,
                                      wholesalePrice: double.tryParse(wholesaleCtrl.text.trim()) ?? 0,
                                      sellingPrice: double.tryParse(priceCtrl.text.trim()) ?? 0,
                                    );
                                    Navigator.pop(ctx);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    alignment: Alignment.center,
                                    height: 44,
                                    child: const Text(
                                      'ADD ITEM', 
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900, 
                                        fontSize: 13,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String total;
  final ThemeProvider theme;
  const _TotalCard({required this.total, required this.theme});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: theme.glassDecoration.copyWith(
        gradient: LinearGradient(
          colors: [theme.highlight.withOpacity(0.2), theme.highlight.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TOTAL PURCHASE', style: TextStyle(color: theme.highlight, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(total, style: TextStyle(color: theme.textPrimary, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.highlight, shape: BoxShape.circle),
            child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

class _PurchaseInfoCard extends StatelessWidget {
  final AddPurchaseController controller;
  final ThemeProvider theme;
  final VoidCallback onDateTap;
  final VoidCallback onCreditDueTap;
  final VoidCallback onAddSupplier;

  const _PurchaseInfoCard({
    required this.controller,
    required this.theme,
    required this.onDateTap,
    required this.onCreditDueTap,
    required this.onAddSupplier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: theme.glassDecoration,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: controller.selectedSupplierId,
                  dropdownColor: theme.surface,
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
                  decoration: theme.glassInputDecoration('Supplier', Icons.business_rounded),
                  items: controller.suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: controller.setSupplier,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: theme.highlight.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                ),
                child: IconButton(
                  icon: Icon(Icons.add_rounded, color: theme.highlight, size: 22),
                  tooltip: 'Add New Supplier',
                  onPressed: onAddSupplier,
                ),
              ),
            ],
          ),
          if (controller.selectedSupplier != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ThemeProvider.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                  border: Border.all(color: ThemeProvider.error.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, color: ThemeProvider.error, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'Prev. Credit: ${controller.formattedPreviousCredit}',
                      style: TextStyle(
                        color: ThemeProvider.error, 
                        fontSize: 13, 
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onDateTap,
                  child: InputDecorator(
                    decoration: theme.glassInputDecoration('Date', Icons.calendar_today_rounded),
                    child: Text(DateFormat('yyyy-MM-dd').format(controller.purchaseDate), style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller.invoiceCtrl,
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
                  decoration: theme.glassInputDecoration('Invoice #', Icons.receipt_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: controller.paymentType,
            dropdownColor: theme.surface,
            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
            decoration: theme.glassInputDecoration('Payment Type', Icons.payment_rounded),
            items: controller.paymentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => v != null ? controller.setPaymentType(v) : null,
          ),
          if (controller.paymentType == 'Cheque') ...[
            const SizedBox(height: 16),
            TextField(controller: controller.chequeNoCtrl, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600), decoration: theme.glassInputDecoration('Cheque Number', Icons.confirmation_number_rounded)),
          ] else if (controller.paymentType == 'Bank Transfer') ...[
            const SizedBox(height: 16),
            TextField(controller: controller.bankNameCtrl, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600), decoration: theme.glassInputDecoration('Bank Name', Icons.account_balance_rounded)),
            const SizedBox(height: 16),
            TextField(controller: controller.transRefCtrl, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600), decoration: theme.glassInputDecoration('Transaction Reference', Icons.receipt_long_rounded)),
          ] else if (controller.paymentType == 'Credit') ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: onCreditDueTap,
              child: InputDecorator(
                decoration: theme.glassInputDecoration('Payment Due Date', Icons.event_available_rounded),
                child: Text(
                  controller.creditDueDate != null ? DateFormat('yyyy-MM-dd').format(controller.creditDueDate!) : 'Select Due Date',
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Payment Section (Prominent)
          TextField(
            controller: controller.paidAmountCtrl,
            enabled: controller.paymentType == 'Credit',
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: controller.paymentType == 'Credit' ? theme.textPrimary : theme.textSecondary, 
              fontWeight: FontWeight.w600
            ),
            onChanged: (v) => controller.notifyListeners(),
            decoration: theme.glassInputDecoration('Paid Amount', Icons.payments_rounded),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.whiteAlpha(0.05),
              borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
              border: Border.all(color: theme.whiteAlpha(0.1)),
            ),
            child: Column(
              children: [
                _SummaryRow(label: 'Net Total', value: controller.formattedTotal, theme: theme, isBold: true),
                const SizedBox(height: 8),
                _SummaryRow(label: 'Paid', value: '${BusinessConfig.instance.currency}. ${controller.paidAmount.toStringAsFixed(2)}', theme: theme),
                const Divider(height: 24, color: Colors.white10),
                _SummaryRow(
                  label: 'To Balance', 
                  value: '${BusinessConfig.instance.currency}. ${controller.creditAmount.toStringAsFixed(2)}', 
                  theme: theme, 
                  valueColor: controller.creditAmount > 0 ? ThemeProvider.error : ThemeProvider.success,
                  isBold: true,
                ),
                const SizedBox(height: 4),
                _SummaryRow(
                  label: 'New Balance', 
                  value: '${BusinessConfig.instance.currency}. ${controller.newBalance.toStringAsFixed(2)}', 
                  theme: theme,
                  isItalic: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: controller.notesCtrl, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600), maxLines: 2, decoration: theme.glassInputDecoration('Notes', Icons.note_rounded)),
        ],
      ),
    );
  }
}

class _EmptyItemsState extends StatelessWidget {
  final ThemeProvider theme;
  const _EmptyItemsState({required this.theme});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      alignment: Alignment.center,
      decoration: theme.glassDecoration,
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, color: theme.iconColor, size: 48),
          const SizedBox(height: 16),
          Text('No items added yet', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Tap "Add Item" to start.', style: TextStyle(color: theme.textHint, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeProvider theme;
  final bool isBold;
  final bool isItalic;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.theme,
    this.isBold = false,
    this.isItalic = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            fontStyle: isItalic ? FontStyle.italic : null,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? theme.textPrimary,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            fontStyle: isItalic ? FontStyle.italic : null,
          ),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final ThemeProvider theme;
  final String currency;
  final VoidCallback onRemove;

  const _ItemTile({required this.item, required this.theme, required this.currency, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: theme.glassDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(item['product_name'] ?? 'Unknown', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Qty: ${item['quantity']} x $currency. ${item['purchase_price']}',
            style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$currency. ${(item['subtotal'] as double).toStringAsFixed(2)}',
              style: TextStyle(color: theme.highlight, fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.remove_circle_outline_rounded, color: ThemeProvider.error, size: 20), onPressed: onRemove),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final ThemeProvider theme;
  final VoidCallback? onPressed;
  final String? total;
  final String? previous;
  const _SaveButton({required this.theme, this.onPressed, this.total, this.previous});
  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: theme.glassDecoration.copyWith(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(ThemeProvider.radiusCard)),
        // Ensure visibility in light mode by adding a subtle border or background adjustment
        color: theme.isDark ? null : Colors.white.withOpacity(0.9),
        border: theme.isDark ? null : Border(top: BorderSide(color: Colors.black.withOpacity(0.05), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 200,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.highlight, 
                foregroundColor: Colors.white, 
                disabledBackgroundColor: theme.highlight.withOpacity(0.3),
                disabledForegroundColor: Colors.white.withOpacity(0.7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
                elevation: isDisabled ? 0 : 8, 
                shadowColor: theme.highlight.withOpacity(0.5),
              ),
              onPressed: onPressed,
              child: Text(
                'SAVE PURCHASE',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ),
          ),
          if (isDisabled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Add supplier and items to save',
                style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerButton extends StatelessWidget {
  final ThemeProvider theme;
  final Function(String) onScan;
  const _ScannerButton({required this.theme, required this.onScan});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: theme.highlight.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: IconButton(
        icon: Icon(Icons.qr_code_scanner_rounded, color: theme.highlight),
        onPressed: () async {
          final String? code = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
          if (code != null) onScan(code);
        },
      ),
    );
  }
}

class _ProductStats extends StatelessWidget {
  final int stock;
  final double cost;
  final String currency;
  final ThemeProvider theme;
  final bool isDialog;
  const _ProductStats({required this.stock, required this.cost, required this.currency, required this.theme, this.isDialog = false});
  @override
  Widget build(BuildContext context) {
    final bgColor = isDialog 
        ? Colors.black.withOpacity(0.05) 
        : (theme.isDark ? Colors.white10 : Colors.black12);
    final textColor = isDialog 
        ? const Color(0xFF1F2937) 
        : theme.textPrimary;
    final labelColor = isDialog
        ? const Color(0xFF6B7280)
        : theme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildMiniStat('In Stock', '$stock units', labelColor, textColor),
          const Divider(height: 16),
          _buildMiniStat('Current Cost', '$currency. ${cost.toStringAsFixed(2)}', labelColor, textColor),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color labelColor, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
