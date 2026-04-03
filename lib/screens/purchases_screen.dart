import 'package:flutter/material.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/controllers/add_purchase_controller.dart';
import 'package:mobile_app/services/sync_service.dart';
import 'package:mobile_app/screens/add_supplier_screen.dart';
import 'package:intl/intl.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final theme = ThemeProvider.instance;
  List<Purchase> _purchases = [];
  bool _isLoading = true;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final SyncService _syncService = SyncService();
  bool _isOnlineSearch = false;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);
    try {
      final localData = await DatabaseHelper.instance.getPurchases();
      List<Map<String, dynamic>> finalData = localData;

      if (_query.isNotEmpty && !_isOnlineSearch) {
        final q = _query.toLowerCase();
        final localFiltered = localData.where((p) {
          final supplier = (p['supplier_name'] ?? '').toString().toLowerCase();
          final id = p['id'].toString();
          final date = (p['purchase_date'] ?? '').toString().toLowerCase();
          return supplier.contains(q) || id.contains(q) || date.contains(q);
        }).toList();

        if (localFiltered.isEmpty) {
          final onlineData = await _syncService.searchOnline(_query, 'purchases');
          if (onlineData.isNotEmpty) {
            finalData = onlineData;
            _isOnlineSearch = true;
          }
        }
      } else if (_isOnlineSearch) {
        finalData = await _syncService.searchOnline(_query, 'purchases');
      }

      if (mounted) {
        setState(() {
          _purchases = finalData.map((e) => Purchase.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading purchases: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmDelete(Purchase purchase) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(24),
          decoration: theme.glassDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: ThemeProvider.error, size: 48),
              const SizedBox(height: 16),
              Text('Delete Purchase?', style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Are you sure you want to delete this purchase memory?', 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('CANCEL', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeProvider.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                      ),
                      onPressed: () async {
                        await DatabaseHelper.instance.deletePurchase(purchase.id ?? 0);
                        await _loadPurchases();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Purchase record deleted'), backgroundColor: ThemeProvider.error),
                          );
                        }
                      },
                      child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _openAddPurchaseScreen([Purchase? purchase]) {
    _showPurchaseFormDialog(purchase);
  }

  void _showPurchaseFormDialog([Purchase? purchase]) {
    final controller = AddPurchaseController();
    // In this simplified version, we only support NEW purchases as the original screen seemed focused on that.
    // If edit is needed, the controller would need adjustment for Purchase model vs Map.
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          controller.addListener(() {
            if (ctx.mounted) setDialogState(() {});
          });

          if (controller.isLoading) {
            return AlertDialog(
              backgroundColor: theme.surface,
              content: const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
            );
          }

          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Purchase',
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: Icon(Icons.close_rounded, color: theme.textSecondary, size: 20),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogSectionHeader('Supplier & Date'),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: controller.selectedSupplierId,
                            dropdownColor: theme.surface,
                            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                            decoration: theme.glassInputDecoration('Supplier', Icons.business_rounded).copyWith(isDense: true),
                            items: controller.suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (v) {
                              controller.setSupplier(v);
                              setDialogState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline_rounded, color: theme.highlight, size: 24),
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSupplierScreen()));
                            await controller.reloadSuppliers();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: controller.purchaseDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) controller.setPurchaseDate(picked);
                            },
                            child: InputDecorator(
                              decoration: theme.glassInputDecoration('Date', Icons.calendar_today_rounded).copyWith(isDense: true),
                              child: Text(DateFormat('yyyy-MM-dd').format(controller.purchaseDate), style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: controller.invoiceCtrl,
                            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                            decoration: theme.glassInputDecoration('Invoice #', Icons.receipt_rounded).copyWith(isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildDialogSectionHeader('Items'),
                    if (controller.items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.background.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.textHint.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined, color: theme.textHint, size: 30),
                            const SizedBox(height: 8),
                            Text('No items added', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      )
                    else
                      ...controller.items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: theme.glassDecoration.copyWith(color: theme.whiteAlpha(0.05)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['product_name'], style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
                                    Text('${item['quantity']} @ ${BusinessConfig.instance.currency}${item['purchase_price']}', style: TextStyle(color: theme.textSecondary, fontSize: 10)),
                                  ],
                                ),
                              ),
                              Text('${BusinessConfig.instance.currency}${item['subtotal'].toStringAsFixed(2)}', style: TextStyle(color: theme.highlight, fontWeight: FontWeight.w900, fontSize: 12)),
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline_rounded, color: ThemeProvider.error.withOpacity(0.7), size: 18),
                                onPressed: () => controller.removeItem(idx),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _showAddItemDialog(ctx, controller),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('ADD PURCHASE ITEM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                        style: TextButton.styleFrom(foregroundColor: theme.highlight),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDialogSectionHeader('Payment Details'),
                    DropdownButtonFormField<String>(
                      value: controller.paymentType,
                      dropdownColor: theme.surface,
                      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                      decoration: theme.glassInputDecoration('Payment Type', Icons.payment_rounded).copyWith(isDense: true),
                      items: controller.paymentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) => v != null ? controller.setPaymentType(v) : null,
                    ),
                    if (controller.paymentType == 'Cheque') ...[
                      const SizedBox(height: 12),
                      _buildDialogTextField(controller: controller.chequeNoCtrl, label: 'Cheque Number', icon: Icons.confirmation_number_rounded),
                    ] else if (controller.paymentType == 'Bank Transfer') ...[
                      const SizedBox(height: 12),
                      _buildDialogTextField(controller: controller.bankNameCtrl, label: 'Bank Name', icon: Icons.account_balance_rounded),
                      const SizedBox(height: 12),
                      _buildDialogTextField(controller: controller.transRefCtrl, label: 'Transaction Reference', icon: Icons.receipt_long_rounded),
                    ] else if (controller.paymentType == 'Credit Card') ...[
                      const SizedBox(height: 12),
                      _buildDialogTextField(controller: controller.cardAuthCtrl, label: 'Auth Code', icon: Icons.security_rounded),
                    ] else if (controller.paymentType == 'Credit') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller.paidAmountCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setDialogState(() {}),
                        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                        decoration: theme.glassInputDecoration('Paid Amount', Icons.payments_rounded).copyWith(isDense: true),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.whiteAlpha(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.whiteAlpha(0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('NET TOTAL:', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w900, fontSize: 11)),
                          Text(controller.formattedTotal, style: TextStyle(color: theme.highlight, fontWeight: FontWeight.w900, fontSize: 18)),
                        ],
                      ),
                    ),
                  ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: controller.canSave
                    ? () async {
                        await controller.savePurchase();
                        if (controller.successMessage != null && ctx.mounted) {
                          Navigator.pop(ctx);
                          _loadPurchases();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(controller.successMessage!), backgroundColor: ThemeProvider.success),
                          );
                        } else if (controller.errorMessage != null && ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(controller.errorMessage!), backgroundColor: ThemeProvider.error),
                          );
                        }
                      }
                    : null,
                child: const Text('SAVE PURCHASE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddItemDialog(BuildContext parentCtx, AddPurchaseController controller) {
    int? selectedProductId;
    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController();
    final wholesaleCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    double cost = 0, ws = 0, sp = 0, stk = 0;

    showDialog(
      context: parentCtx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
            title: Text('Add Item', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedProductId,
                    dropdownColor: theme.surface,
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                    decoration: theme.glassInputDecoration('Select Product', Icons.inventory_rounded).copyWith(isDense: true),
                    items: controller.products.map((p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['name'] as String, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() {
                        selectedProductId = v;
                        final p = controller.products.firstWhere((x) => x['id'] == v);
                        final stocks = p['stocks'] as List<dynamic>? ?? [];
                        if (stocks.isNotEmpty) {
                          final last = stocks.last;
                          cost = (last['cost_price'] as num? ?? 0).toDouble();
                          ws = (last['wholesale_price'] as num? ?? 0).toDouble();
                          sp = (last['sale_price'] as num? ?? 0).toDouble();
                          stk = (last['quantity'] as num? ?? 0).toDouble();
                        }
                        costCtrl.text = cost.toStringAsFixed(2);
                        wholesaleCtrl.text = ws.toStringAsFixed(2);
                        priceCtrl.text = sp.toStringAsFixed(2);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildDialogTextField(controller: qtyCtrl, label: 'Qty', icon: Icons.numbers, keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildDialogTextField(controller: costCtrl, label: 'Unit Cost', icon: Icons.attach_money, keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildDialogTextField(controller: wholesaleCtrl, label: 'Wholesale', icon: Icons.business, keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildDialogTextField(controller: priceCtrl, label: 'Selling', icon: Icons.sell, keyboardType: TextInputType.number)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CANCEL', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w800, fontSize: 12))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: theme.highlight, foregroundColor: Colors.white),
                onPressed: () {
                  final qty = double.tryParse(qtyCtrl.text) ?? 0;
                  if (selectedProductId != null && qty > 0) {
                    final p = controller.products.firstWhere((x) => x['id'] == selectedProductId);
                    controller.addItem(
                      productId: selectedProductId!,
                      productName: p['name'],
                      barcode: p['barcode'],
                      existingStock: stk,
                      quantity: qty,
                      purchasePrice: double.tryParse(costCtrl.text) ?? 0,
                      wholesalePrice: double.tryParse(wholesaleCtrl.text) ?? 0,
                      sellingPrice: double.tryParse(priceCtrl.text) ?? 0,
                    );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.w900)),
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
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
      decoration: theme.glassInputDecoration(label, icon).copyWith(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
    );
  }
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Purchases History',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
        actions: [
          if (_isOnlineSearch)
            TextButton(
              onPressed: () {
                setState(() {
                  _isOnlineSearch = false;
                  _query = '';
                  _searchCtrl.clear();
                  _loadPurchases();
                });
              },
              child: const Text('LOCAL', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
        ],
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  decoration: theme.glassDecoration,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
                      _query = v;
                      if (v.isEmpty && _isOnlineSearch) {
                        setState(() => _isOnlineSearch = false);
                      }
                      _loadPurchases();
                    },
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search purchases...',
                      hintStyle: TextStyle(color: theme.textHint),
                      prefixIcon: Icon(Icons.search_rounded, color: theme.highlight),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              if (_isOnlineSearch)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_done_rounded, color: theme.highlight, size: 14),
                      const SizedBox(width: 8),
                      Text('SHOWING RESULTS FROM SERVER', 
                        style: TextStyle(color: theme.highlight, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoading
              ? Center(child: CircularProgressIndicator(color: theme.highlight))
              : _purchases.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: theme.glassCircleDecoration,
                            child: Icon(Icons.receipt_long_rounded, size: 60, color: theme.iconColor.withOpacity(0.5)),
                          ),
                          const SizedBox(height: 24),
                          Text('No purchases yet', 
                            style: TextStyle(fontSize: 18, color: theme.textPrimary, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text('Restock your inventory to see them here', 
                            style: TextStyle(fontSize: 13, color: theme.textSecondary, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _purchases.length,
                      itemBuilder: (context, index) {
                        final purchase = _purchases[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: theme.glassDecoration,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            onTap: () => _openAddPurchaseScreen(purchase),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(purchase.supplierName ?? 'Direct Purchase', 
                                      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                                ),
                                Text('ID: ${purchase.id ?? '??'}', 
                                    style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.w800)),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                DateFormat('MMM dd, yyyy | HH:mm').format(purchase.purchaseDate),
                                style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${BusinessConfig.instance.currencyDisplay} ${purchase.totalAmount.toStringAsFixed(2)}',
                                      style: TextStyle(color: theme.highlight, fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                                    if (_isOnlineSearch)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(color: theme.highlight.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                        child: Text('ONLINE', style: TextStyle(color: theme.highlight, fontSize: 7, fontWeight: FontWeight.w900)),
                                      ),
                                    Text(
                                      'PURCHASE',
                                      style: TextStyle(color: theme.textHint, fontSize: 8, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, color: ThemeProvider.error.withOpacity(0.5), size: 18),
                                  onPressed: () => _confirmDelete(purchase),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
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
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
          boxShadow: [
            BoxShadow(
              color: theme.highlight.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _openAddPurchaseScreen(),
          backgroundColor: theme.highlight,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
          icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
          label: const Text('NEW PURCHASE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
        ),
      ),
    );
  }
}
