import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app/controllers/pos_controller.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/stock.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/customer_list_screen.dart';
import 'package:mobile_app/screens/payment_screen.dart';
import 'package:mobile_app/models/held_order.dart';
import 'package:mobile_app/screens/held_orders_screen.dart';
import 'package:mobile_app/widgets/shift_dialogs.dart';
import 'package:mobile_app/screens/sales_history_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Modular Widgets
import 'package:mobile_app/widgets/pos/pos_category_selector.dart';
import 'package:mobile_app/widgets/pos/pos_product_grid.dart';
import 'package:mobile_app/widgets/pos/pos_cart_section.dart';
import 'package:mobile_app/widgets/pos/pos_quick_add_panel.dart';

class POSScreen extends StatefulWidget {
  final HeldOrder? resumeOrder;
  static bool isActive = false;
  const POSScreen({super.key, this.resumeOrder});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> with SingleTickerProviderStateMixin {
  final _controller = POSController();
  final theme = ThemeProvider.instance;
  
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isScannerOpen = false;
  MobileScannerController? _scannerController;
  DateTime? _lastScanTime;
  
  bool _showQuickAddProduct = false;
  late AnimationController _quickAddController;
  late Animation<Offset> _quickAddSlideAnimation;

  @override
  void initState() {
    super.initState();
    POSScreen.isActive = true;
    _controller.addListener(_onControllerChange);
    
    if (widget.resumeOrder != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _controller.resumeOrder(widget.resumeOrder!));
    }
    
    _quickAddController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _quickAddSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _quickAddController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    POSScreen.isActive = false;
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _scannerController?.dispose();
    _quickAddController.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  void _toggleQuickAddProduct() {
    setState(() => _showQuickAddProduct = !_showQuickAddProduct);
    if (_showQuickAddProduct) {
      _quickAddController.forward();
    } else {
      _quickAddController.reverse();
    }
  }

  void _onProductQuickAdded() {
    _toggleQuickAddProduct();
    _controller.loadData();
  }

  Future<void> _showShiftHistory() async {
    final shift = await DatabaseHelper.instance.getActiveShift();
    if (shift == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No active shift found. Please start a shift first.'),
            backgroundColor: ThemeProvider.warning,
          ),
        );
      }
      return;
    }
    
    final startTime = shift['start_time'];
    final now = DateTime.now().toIso8601String();
    
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => SalesHistoryScreen(
        shiftId: shift['id'] is int ? shift['id'] : int.tryParse(shift['id'].toString()),
        isShiftHistory: true,
      )));
    }
  }

  void _showAllHistory() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesHistoryScreen()));
  }

  void _showOutOfStockAlert(Product product, Stock stock) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: ThemeProvider.error),
            const SizedBox(width: 8),
            Text('Out of Stock', style: TextStyle(color: theme.textPrimary)),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Text(
            'The product "${product.name}" (Batch: ${stock.barcode ?? 'Default'}) is out of stock and cannot be added to the cart.',
            style: TextStyle(color: theme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: theme.highlight)),
          ),
        ],
      ),
    );
  }

  void _showStockBatchDialog(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: theme.surface,
        title: Text('Select Batch for ${product.name}', style: TextStyle(color: theme.textPrimary)),
        content: SizedBox(
          width: 350,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: product.stocks.length,
            itemBuilder: (ctx, i) {
              final stock = product.stocks[i];
              return ListTile(
                title: Text('${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(stock.salePrice)}', 
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
                subtitle: Text('Stock: ${stock.quantity} | Barcode: ${stock.barcode ?? 'N/A'}',
                    style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                trailing: Icon(Icons.add_shopping_cart, color: theme.highlight),
                onTap: () {
                  Navigator.pop(ctx);
                  if (product.isPricePerWeight) {
                    _showWeightDialog(product, stock);
                  } else {
                    final success = _controller.addToCart(product, stock);
                    if (!success) _showOutOfStockAlert(product, stock);
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showWeightDialog(Product product, Stock stock) {
    final weightCtrl = TextEditingController(text: '1.00');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Row(children: [
          Text(product.image ?? '🏷️', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
              child: Text('${product.name} (${stock.barcode ?? 'Batch'})',
                  style: TextStyle(color: theme.textPrimary, fontSize: 16)))
        ]),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                      suffixText: BusinessConfig.instance.weightUnit,
                      suffixStyle:
                          TextStyle(color: theme.textSecondary, fontSize: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 12),
              Wrap(
                  spacing: 8,
                  children: ['0.5', '1.0', '2.0']
                      .map((w) => ActionChip(
                          label: Text('$w kg'),
                          onPressed: () => weightCtrl.text = w))
                      .toList()),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: TextStyle(color: theme.textSecondary))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeProvider.success),
              onPressed: () {
                final weight = double.tryParse(weightCtrl.text);
                if (weight != null && weight > 0) {
                  _controller.addToCart(product, stock, qty: weight, isWeight: true);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add')),
        ],
      ),
    );
  }

  Future<void> _promptClearCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: theme.surface,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: ThemeProvider.error),
            const SizedBox(width: 8),
            Text('Clear Cart', style: TextStyle(color: theme.textPrimary)),
          ],
        ),
        content: Text('Are you sure you want to clear all items from the cart?',
            style: TextStyle(color: theme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThemeProvider.error),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _controller.clearCart();
    }
  }

  Future<void> _handleParkCart() async {
    if (_controller.cart.isEmpty) return;
    
    final existingOrders = await DatabaseHelper.instance.getHeldOrders();
    final defaultName = _controller.selectedCustomer?.name ??
        'Order #${existingOrders.length + 1}';
        
    final nameCtrl = TextEditingController(text: defaultName);
    
    if (!mounted) return;
    
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
        title: Text('Hold Order', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: TextStyle(color: theme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Reference Name',
            labelStyle: TextStyle(color: theme.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeProvider.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('HOLD ORDER', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await _controller.parkCurrentCart(name);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Order held successfully!')));
      }
    }
  }

  void _showHeldOrdersDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.getHeldOrders(),
            builder: (context, snapshot) {
              final ordersData = snapshot.data ?? [];
              final loading = snapshot.connectionState == ConnectionState.waiting;

              return AlertDialog(
                backgroundColor: theme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
                titlePadding: EdgeInsets.zero,
                contentPadding: EdgeInsets.zero,
                content: SizedBox(
                  width: 450,
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Column(
                    children: [
                      // Title & Close
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('HELD ORDERS',
                                style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900)),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(ctx),
                              color: theme.iconColor,
                            ),
                          ],
                        ),
                      ),
                      const Divider(),

                      // List of Held Orders
                      Expanded(
                        child: loading 
                          ? Center(child: CircularProgressIndicator(color: theme.highlight))
                          : ordersData.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 48, color: theme.iconColor.withOpacity(0.5)),
                                    const SizedBox(height: 12),
                                    Text('No parked orders', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: ordersData.length,
                                itemBuilder: (context, index) {
                                  final data = ordersData[index];
                                  final createdAt = DateTime.parse(data['created_at']);
                                  final elapsed = DateTime.now().difference(createdAt);
                                  final elapsedStr = elapsed.inMinutes < 60 
                                      ? '${elapsed.inMinutes}m ago'
                                      : '${elapsed.inHours}h ${elapsed.inMinutes % 60}m ago';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: theme.glassDecoration,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: ThemeProvider.warning.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                                        ),
                                        child: const Icon(Icons.pause_rounded, color: ThemeProvider.warning, size: 20),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(data['name'] ?? 'Order', 
                                                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                                          ),
                                          Text(elapsedStr, 
                                              style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.w800)),
                                        ],
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Total: ${BusinessConfig.instance.currencyDisplay} ${(data['total'] as num).toStringAsFixed(2)}',
                                          style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: ThemeProvider.error, size: 18),
                                            onPressed: () async {
                                              await DatabaseHelper.instance.deleteHeldOrder(data['id']);
                                              setModalState(() {});
                                            },
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(Icons.play_arrow_rounded, color: ThemeProvider.success, size: 18),
                                            style: IconButton.styleFrom(
                                              backgroundColor: ThemeProvider.success.withOpacity(0.1),
                                              padding: const EdgeInsets.all(8),
                                            ),
                                            onPressed: () async {
                                              final items = await DatabaseHelper.instance.getHeldOrderItems(data['id']);
                                              Customer? customer;
                                              if (data['customer_id'] != null) {
                                                final cData = await DatabaseHelper.instance.getCustomer(data['customer_id']);
                                                if (cData != null) customer = Customer.fromMap(cData);
                                              }
                                              final order = HeldOrder.fromMap(data, childItems: items, customer: customer);
                                              await DatabaseHelper.instance.deleteHeldOrder(data['id']);
                                              _controller.resumeOrder(order);
                                              if (ctx.mounted) Navigator.pop(ctx);
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
              );
            }
          );
        },
      ),
    );
  }

  void _showDiscountDialog() {
    final discountCtrl =
        TextEditingController(text: _controller.discount > 0 ? _controller.discount.toString() : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title:
            Text('Apply Discount', style: TextStyle(color: theme.textPrimary)),
        content: SizedBox(
          width: 300,
          child: TextField(
              controller: discountCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(color: theme.textPrimary, fontSize: 24),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                  prefixText: '\$ ', border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: TextStyle(color: theme.textSecondary))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme.highlight),
              onPressed: () {
                _controller.setDiscount(double.tryParse(discountCtrl.text) ?? 0);
                Navigator.pop(ctx);
              },
              child: const Text('Apply')),
        ],
      ),
    );
  }

  void _goToPayment() async {
    if (_controller.cart.isEmpty) return;

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            cart: _controller.cart.map((item) => item.toMap()).toList(),
            subtotal: _controller.subtotal,
            tax: _controller.tax,
            discount: _controller.totalDiscount,
            total: _controller.total,
            isReturn: _controller.isReturn,
            customer: _controller.selectedCustomer,
          ),
        ),
      ).then((_) {
        _controller.clearCart();
        setState(() {});
      });
    }
  }

  Future<Customer?> _showCustomerSelectionDialog() async {
    final customersData = await DatabaseHelper.instance.getCustomers();
    final List<Customer> allCustomers =
        customersData.map<Customer>((c) => Customer.fromMap(c)).toList();

    if (!mounted) return null;

    return await showDialog<Customer?>(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = allCustomers
                .where((c) =>
                    c.name.toLowerCase().contains(query.toLowerCase()) ||
                    (c.phone?.contains(query) ?? false))
                .toList();

            return AlertDialog(
              backgroundColor: theme.surface,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select Customer',
                      style: TextStyle(color: theme.textPrimary)),
                  IconButton(
                    icon: Icon(Icons.person_add, color: theme.highlight),
                    onPressed: () async {
                      // Navigate to Add Customer Screen or show Add Dialog
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CustomerListScreen()));
                      // Refresh the list after returning
                      final updatedData =
                          await DatabaseHelper.instance.getCustomers();
                      setDialogState(() {
                        allCustomers.clear();
                        allCustomers.addAll(
                            updatedData.map((c) => Customer.fromMap(c)));
                      });
                    },
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6),
                child: SizedBox(
                  width: 350,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          autofocus: true,
                          style: TextStyle(color: theme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search customer...',
                            hintStyle: TextStyle(color: theme.textHint),
                            prefixIcon:
                                Icon(Icons.search, color: theme.iconColor),
                            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                          ),
                          onChanged: (v) => setDialogState(() => query = v),
                        ),
                        const SizedBox(height: 12),
                          if (!BusinessConfig.instance.requireCustomer) ...[
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: theme.highlight.withAlpha(40),
                                child: Icon(Icons.person_outline,
                                    color: theme.highlight, size: 20),
                              ),
                              title: Text('Walk-in Guest',
                                  style: TextStyle(
                                      color: theme.textPrimary,
                                      fontWeight: FontWeight.bold)),
                              onTap: () => Navigator.pop(ctx, null),
                            ),
                            const Divider(),
                          ],
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('No customers found',
                                style: TextStyle(color: theme.textSecondary)),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(), // Let parent scroll
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) {
                              final c = filtered[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: theme.card,
                                  child: Text(c.name[0].toUpperCase(),
                                      style: TextStyle(
                                          color: theme.textPrimary,
                                          fontSize: 13)),
                                ),
                                title: Text(c.name,
                                    style: TextStyle(color: theme.textPrimary)),
                                subtitle: Text(c.phone ?? 'No phone',
                                    style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 13)),
                                onTap: () => Navigator.pop(ctx, c),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style: TextStyle(color: theme.textSecondary))),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleFavorite(Product product) async {
    // Update Database first (persistence)
    await DatabaseHelper.instance
        .toggleProductFavorite(product.id, product.isFavorite);

    if (mounted) {
      _controller.loadData();
    }
  }

  // Inline camera barcode scanner
  void _openBarcodeScanner() {
    if (kIsWeb) {
      // Web fallback - manual entry
      _showManualBarcodeEntry();
      return;
    }

    setState(() {
      if (!_isScannerOpen) {
        _isScannerOpen = true;
        _scannerController = MobileScannerController();
      } else {
        _closeBarcodeScanner();
      }
    });
  }

  void _closeBarcodeScanner() {
    setState(() {
      _isScannerOpen = false;
      _scannerController?.dispose();
      _scannerController = null;
    });
  }

  void _onDetectBarcode(BarcodeCapture capture) {
    if (!_isScannerOpen) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        if (_lastScanTime == null || DateTime.now().difference(_lastScanTime!).inMilliseconds > 1500) {
          _lastScanTime = DateTime.now();
          _processBarcode(code);
        }
      }
    }
  }

  Widget _buildInlineScanner() {
    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.highlight, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            if (_scannerController != null)
              MobileScanner(
                controller: _scannerController!,
                onDetect: _onDetectBarcode,
              ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: _closeBarcodeScanner,
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.flash_on, color: Colors.white),
                onPressed: () => _scannerController?.toggleTorch(),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text('Scan Barcode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showManualBarcodeEntry() {
    final barcodeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Row(children: [
          const Icon(Icons.qr_code, color: ThemeProvider.info),
          const SizedBox(width: 8),
          Text('Enter Barcode', style: TextStyle(color: theme.textPrimary))
        ]),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: barcodeCtrl,
                  autofocus: true,
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                      hintText: 'Scan or type barcode...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  onSubmitted: (v) {
                    Navigator.pop(ctx);
                    _processBarcode(v);
                  }),
              const SizedBox(height: 12),
              Text('Quick test barcodes:',
                  style: TextStyle(color: theme.textHint, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                  spacing: 6,
                  children: _controller.products
                      .take(3)
                      .map((Product p) => ActionChip(
                          label: Text(p.barcode ?? 'N/A',
                              style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _processBarcode(p.barcode ?? '');
                          }))
                      .toList()),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: TextStyle(color: theme.textSecondary))),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _processBarcode(barcodeCtrl.text);
              },
              child: const Text('Add')),
        ],
      ),
    );
  }

  void _processBarcode(String barcode) {
    // 1. Find all products that have this barcode at product level OR in any of their stocks
    final matches = _controller.products.where((p) {
      final productMatch = p.barcode == barcode;
      final stockMatch = p.stocks.any((s) => s.barcode == barcode);
      return productMatch || stockMatch;
    }).toList();

    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Product not found: $barcode'),
          backgroundColor: ThemeProvider.error));
      return;
    }

    if (matches.length == 1) {
      final product = matches.first;
      // 2. Find the specific stock batch matching the barcode
      Stock? stock;
      try {
        stock = product.stocks.firstWhere((s) => s.barcode == barcode);
      } catch (_) {
        // If not found in stocks, it might be the product-level legacy barcode
        stock = product.stocks.isNotEmpty ? product.stocks.first : null;
      }

      if (stock == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No stock batches found for this product'),
            backgroundColor: ThemeProvider.error));
        return;
      }

      if (product.isPricePerWeight) {
        _showWeightDialog(product, stock);
      } else {
        final success = _controller.addToCart(product, stock);
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${product.name} is out of stock!'),
            backgroundColor: ThemeProvider.error,
          ));
        }
      }
    } else {
      // Multiple products share this barcode
      _showPriceVariantDialog(matches, barcode);
    }
  }

  void _showPriceVariantDialog(List<Product> variants, String barcode) {
    final currency = BusinessConfig.instance.currency;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.textHint.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Multiple Products Found',
                style: TextStyle(
                  color: ThemeProvider.error,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select the product for barcode: $barcode',
                style: TextStyle(color: theme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...variants.map((v) {
                // Find matching stock for this specific variant
                Stock? stock;
                try {
                  stock = v.stocks.firstWhere((s) => s.barcode == barcode);
                } catch (_) {
                  stock = v.stocks.isNotEmpty ? v.stocks.first : null;
                }
                
                if (stock == null) return const SizedBox.shrink();
                final inStock = stock.quantity > 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: theme.isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.highlight.withOpacity(0.2),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      v.name,
                      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Price: ${BusinessConfig.instance.currencyDisplay} ${stock.salePrice.toStringAsFixed(2)}  ·  Stock: ${stock.quantity}',
                      style: TextStyle(color: theme.textSecondary, fontSize: 13),
                    ),
                    trailing: inStock
                        ? Icon(Icons.add_circle_rounded, color: theme.highlight)
                        : const Text(
                            'Out of Stock',
                            style: TextStyle(
                              color: ThemeProvider.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                    onTap: inStock
                        ? () {
                            Navigator.pop(ctx);
                            if (v.isPricePerWeight) {
                              _showWeightDialog(v, stock!);
                            } else {
                              final success = _controller.addToCart(v, stock!);
                              if (!success) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('${v.name} is out of stock!'),
                                  backgroundColor: ThemeProvider.error,
                                ));
                              }
                            }
                          }
                        : null,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showBackConfirmDialog(context);
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: theme.glassBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth > 800;
                return Stack(
                  children: [
                    Focus(
                      autofocus: true,
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                          if (_searchCtrl.text.isNotEmpty) {
                            _processBarcode(_searchCtrl.text);
                            _searchCtrl.clear();
                            _controller.setSearchQuery('');
                            return KeyEventResult.handled;
                          }
                        }
                        if (event is KeyDownEvent && 
                            event.character != null && 
                            event.character!.isNotEmpty && 
                            !_searchFocusNode.hasFocus) {
                          _searchFocusNode.requestFocus();
                          _searchCtrl.text += event.character!;
                          _searchCtrl.selection = TextSelection.collapsed(offset: _searchCtrl.text.length);
                          _controller.setSearchQuery(_searchCtrl.text);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                Expanded(child: _buildProductPanel()),
                                if (!isTablet)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    child: _buildMobileCartBar(),
                                  ),
                              ],
                            ),
                          ),
                          if (isTablet) SizedBox(width: 380, child: _buildCartPanel())
                        ],
                      ),
                    ),
                    
                    // Quick Add Product Overlay
                    if (_showQuickAddProduct)
                      GestureDetector(
                        onTap: _toggleQuickAddProduct,
                        child: Container(color: Colors.black26),
                      ),
                    
                    if (_showQuickAddProduct)
                      SlideTransition(
                        position: _quickAddSlideAnimation,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 350,
                            child: POSQuickAddPanel(
                              onClose: _toggleQuickAddProduct,
                              onSuccess: _onProductQuickAdded,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.cardBorder, width: 1)),
          ),
          child: _buildPOSHeader(),
        ),
        if (_isScannerOpen) _buildInlineScanner(),
        if (!_isScannerOpen) 
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.cardBorder, width: 1)),
            ),
            child: POSCategorySelector(controller: _controller),
          ),
        Expanded(
          child: POSProductGrid(
            controller: _controller,
            onProductTap: (product) {
              if (product.stocks.length > 1) {
                _showStockBatchDialog(product);
              } else {
                final stock = product.stocks.first;
                if (product.isPricePerWeight) {
                  _showWeightDialog(product, stock);
                } else {
                  final success = _controller.addToCart(product, stock);
                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${product.name} is out of stock!'),
                      backgroundColor: ThemeProvider.error,
                    ));
                  }
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCartPanel() {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(left: BorderSide(color: theme.whiteAlpha(0.1))),
      ),
      child: POSCartSection(
        controller: _controller,
        onPay: _goToPayment,
        onHold: _handleParkCart,
        onClear: _promptClearCart,
        onSelectCustomer: () async {
          final customer = await _showCustomerSelectionDialog();
          if (customer != null) _controller.setSelectedCustomer(customer);
        },
        onShowHeldOrders: _showHeldOrdersDialog,
        onToggleQuickAdd: _toggleQuickAddProduct,
        onApplyDiscount: _showDiscountDialog,
      ),
    );
  }

  Widget _buildPOSHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            decoration: theme.glassCircleDecoration,
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: theme.iconColor, size: 20),
              onPressed: () async {
                final shouldPop = await _showBackConfirmDialog(context);
                if (shouldPop == true && context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: theme.glassCircleDecoration,
            child: IconButton(
              icon: Icon(Icons.logout_rounded,
                  color: ThemeProvider.error, size: 20),
              tooltip: 'Clock Out',
              onPressed: () async {
                final activeShift = await DatabaseHelper.instance.getActiveShift();
                if (activeShift != null && mounted) {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: theme.surface,
                      title: const Text('Clock Out'),
                      content: const Text('Are you sure you want to clock out? This will end your current shift.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: ThemeProvider.error),
                          onPressed: () => Navigator.pop(ctx, true), 
                          child: const Text('Yes, Clock Out')
                        ),
                      ],
                    ),
                  );

                  if (confirm != true || !mounted) return;

                  final closingData = await showDialog<Map<String, dynamic>>(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const ClockOutDenominationsDialog(),
                  );

                  if (closingData == null || !mounted) return;

                  final clockedOut = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => ClockOutDialog(
                      activeShift: activeShift,
                      closingCash: closingData['total'],
                      closingDenominations: closingData['denominations'],
                    ),
                  );

                  if (clockedOut == true && mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 12),
       
          Container(
            decoration: theme.glassCircleDecoration,
            child: IconButton(
              icon: Icon(theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: theme.isDark ? Colors.white : Colors.black, size: 20),
              tooltip: theme.isDark ? 'Light Mode' : 'Dark Mode',
              onPressed: () => setState(() => theme.toggleTheme()),
            ),
          ),
          const SizedBox(width: 12),
          _buildHeaderActionButton(
            icon: Icons.history_rounded,
            label: 'Shift History',
            color: theme.highlight,
            onTap: _showShiftHistory,
          ),
          const SizedBox(width: 8),
          _buildHeaderActionButton(
            icon: Icons.receipt_long_rounded,
            label: 'All History',
            onTap: _showAllHistory,
          ),
          const SizedBox(width: 12),
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              decoration: theme.glassDecoration.copyWith(
                borderRadius: BorderRadius.circular(8),
                color: theme.isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.2),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                onChanged: (v) => _controller.setSearchQuery(v),
                onSubmitted: (v) {
                  if (v.isNotEmpty) {
                    _processBarcode(v);
                    _searchCtrl.clear();
                    _controller.setSearchQuery('');
                  }
                },
                style: TextStyle(
                    color: theme.textPrimary, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Search product or scan barcode...',
                  hintStyle: TextStyle(
                      color: theme.textHint, fontWeight: FontWeight.w400),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: theme.iconColor),
                  suffixIcon: _controller.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 18, color: theme.iconColor),
                          onPressed: () {
                            _searchCtrl.clear();
                            _controller.setSearchQuery('');
                          })
                      : IconButton(
                          icon: Icon(Icons.qr_code_scanner_rounded,
                              color: theme.iconColor),
                          onPressed: _openBarcodeScanner),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCartBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: theme.glassDecoration.copyWith(
        color: theme.highlight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) => Container(
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: _buildCartPanel(),
              ),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_controller.cart.length} ITEMS',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'VIEW CART',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1),
              ),
            ),
            Text(
              '${BusinessConfig.instance.currencyDisplay} ${_controller.total.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showBackConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Exit POS?', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to go back? Your current cart will be lost.', style: TextStyle(color: theme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Stay', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.highlight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: theme.glassDecoration.copyWith(
          color: color?.withOpacity(0.1) ?? theme.whiteAlpha(0.05),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color ?? theme.textPrimary),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: color ?? theme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
