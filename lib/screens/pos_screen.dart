import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
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
import 'package:mobile_app/widgets/shift_dialogs.dart';
import 'package:mobile_app/screens/sales_history_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';

// Modular Widgets
import 'package:mobile_app/widgets/pos/pos_category_selector.dart';
import 'package:mobile_app/widgets/pos/pos_product_grid.dart';
import 'package:mobile_app/widgets/pos/pos_cart_section.dart';
import 'package:mobile_app/widgets/pos/pos_quick_add_panel.dart';
import 'package:mobile_app/widgets/add_customer_dialog.dart';
import 'package:mobile_app/utils/keyboard_shortcuts.dart';

class POSScreen extends StatefulWidget {
  final HeldOrder? resumeOrder;
  final Map<String, dynamic>? returnSale;
  final String? initialCategory;
  static bool isActive = false;
  const POSScreen({super.key, this.resumeOrder, this.returnSale, this.initialCategory});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> with SingleTickerProviderStateMixin {
  final _controller = POSController();
  final theme = ThemeProvider.instance;
  
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();
  final GlobalKey<POSCartSectionState> _cartKey = GlobalKey<POSCartSectionState>();
  bool _isScannerOpen = false;
  MobileScannerController? _scannerController;
  DateTime? _lastScanTime;
  AudioPlayer? _audioPlayer;
  
  bool _showQuickAddProduct = false;
  late AnimationController _quickAddController;
  late Animation<Offset> _quickAddSlideAnimation;
  
  double _searchBoxWidth = 300;

  @override
  void initState() {
    super.initState();
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        _audioPlayer = AudioPlayer();
      }
    } catch (_) {}
    POSScreen.isActive = true;
    _controller.addListener(_onControllerChange);
    
    if (widget.resumeOrder != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _controller.resumeOrder(widget.resumeOrder!));
    } else if (widget.returnSale != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _controller.loadReturnSale(widget.returnSale!));
    }

    if (widget.initialCategory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _controller.setCategory(widget.initialCategory!));
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
    _audioPlayer?.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _keyboardFocusNode.dispose();
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
    // Force switch to 'all' items so the new product is visible immediately
    _controller.setCategory('all');
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
    
    // ignore: unused_local_variable
    final startTime = shift['start_time'];
    // ignore: unused_local_variable
    final now = DateTime.now().toIso8601String();
    
    if (mounted) {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => SalesHistoryScreen(
        shiftId: shift['id'] is int ? shift['id'] : int.tryParse(shift['id'].toString()),
        isShiftHistory: true,
      )));
      if (result != null && result is Map && mounted) {
        _controller.loadReturnSale(Map<String, dynamic>.from(result));
      }
    }
  }

  void _showAllHistory() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesHistoryScreen()));
    if (result != null && result is Map && mounted) {
      _controller.loadReturnSale(Map<String, dynamic>.from(result));
    }
  }

  void _showStockNotFoundDialog(Product product, Stock stock) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: theme.surface,
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: ThemeProvider.error),
            const SizedBox(width: 12),
            Text('Stock Not Found', 
              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Out of Stock Alert', 
              style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Text(
              'The product "${product.name}" (Batch: ${stock.barcode ?? 'Default'}) has zero stock and cannot be sold.',
              style: TextStyle(color: theme.textSecondary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.highlight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showStockBatchDialog(List<Product> variants) {
    if (variants.isEmpty) return;
    final product = variants.first;
    
    // Group all stocks from all variants by their salePrice to avoid duplicates with the same price.
    final Map<double, Map<String, dynamic>> groupedStocks = {};
    for (var v in variants) {
      for (var s in v.stocks) {
        final price = s.salePrice;
        if (groupedStocks.containsKey(price)) {
          // SAME PRICE -> Update existing entry with combined quantity
          final existingStock = groupedStocks[price]!['stock'] as Stock;
          groupedStocks[price]!['stock'] = existingStock.copyWith(
            quantity: existingStock.quantity + s.quantity,
          );
        } else {
          // NEW PRICE -> Create new entry (using a clone to avoid side effects)
          groupedStocks[price] = {
            'product': v, 
            'stock': Stock.fromMap(s.toMap()),
          };
        }
      }
    }
    final allStocks = groupedStocks.values.toList();
    // Sort by price descending (newest/highest usually preferred)
    allStocks.sort((a, b) => b['stock'].salePrice.compareTo(a['stock'].salePrice));
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(20),
          decoration: theme.glassDecoration.copyWith(
            borderRadius: BorderRadius.circular(16),
            color: theme.surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select Stock Batch'.toUpperCase(),
                            style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text(product.name,
                            style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.textHint.withOpacity(0.1),
                        ),
                        child: Icon(Icons.close, color: theme.textSecondary, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: allStocks.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final item = allStocks[i];
                    final p = item['product'] as Product;
                    final s = item['stock'] as Stock;
                    final bool isLowStock = s.quantity <= p.stockLimit;
                    
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          if (s.quantity <= 0) {
                            _showStockNotFoundDialog(p, s);
                          } else {
                            final success = _controller.addToCart(p, s);
                            if (!success) _showStockNotFoundDialog(p, s);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.cardBorder),
                            color: theme.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.highlight.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.inventory_2_outlined, color: theme.highlight, size: 22),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(s.salePrice)}',
                                        style: TextStyle(
                                            color: theme.textPrimary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('Barcode: ${s.barcode ?? p.latestBarcode ?? 'Default'}',
                                        style: TextStyle(
                                            color: theme.textSecondary,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isLowStock ? ThemeProvider.error.withOpacity(0.1) : ThemeProvider.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${s.quantity} Unit',
                                  style: TextStyle(
                                    color: isLowStock ? ThemeProvider.error : ThemeProvider.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
    );
  }

  void _showWeightDialog(Product product, Stock stock) {
    final weightCtrl = TextEditingController(text: '1.00');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(20),
          decoration: theme.glassDecoration.copyWith(
            borderRadius: BorderRadius.circular(16),
            color: theme.surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enter Weight'.toUpperCase(),
                            style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text(product.name,
                            style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.highlight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(stock.salePrice)} / ${BusinessConfig.instance.weightUnit}',
                      style: TextStyle(color: theme.highlight, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              TextField(
                controller: weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: theme.textHint.withOpacity(0.2)),
                  suffixText: BusinessConfig.instance.weightUnit,
                  suffixStyle: TextStyle(color: theme.textSecondary, fontSize: 18, fontWeight: FontWeight.bold),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['0.5', '1.0', '2.0', '5.0'].map((w) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      label: Text('$w ${BusinessConfig.instance.weightUnit}', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      backgroundColor: theme.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      side: BorderSide(color: theme.cardBorder),
                      onPressed: () => weightCtrl.text = w,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: theme.cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final weight = double.tryParse(weightCtrl.text);
                        if (weight != null && weight > 0) {
                          _controller.addToCart(product, stock, qty: weight, isWeight: true);
                          Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.highlight,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('ADD TO CART', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
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

  Future<void> _promptClearCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter) {
              Navigator.pop(ctx, true);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AlertDialog(
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
      },
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
    String dType = 'fixed';
    String? dialogError;
    final discountCtrl = TextEditingController(text: _controller.discount > 0 ? _controller.discount.toString() : '');
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.transparent,
          child: Container(
            width: 350,
            padding: const EdgeInsets.all(20),
            decoration: theme.glassDecoration.copyWith(
              borderRadius: BorderRadius.circular(16),
              color: theme.surface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cart Discount'.toUpperCase(),
                            style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text('Apply Discount',
                            style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          dType = dType == 'percentage' ? 'fixed' : 'percentage';
                          dialogError = null;
                        });
                      },
                      child: Text(
                        dType == 'percentage' ? '%' : BusinessConfig.instance.currencyDisplay,
                        style: TextStyle(color: theme.highlight, fontWeight: FontWeight.bold, fontSize: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Container(
                  decoration: BoxDecoration(
                    color: theme.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: dialogError != null ? ThemeProvider.error : theme.cardBorder),
                  ),
                  child: TextField(
                    controller: discountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: TextStyle(color: theme.textPrimary, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      prefixText: dType == 'percentage' ? '' : '${BusinessConfig.instance.currencyDisplay} ',
                      suffixText: dType == 'percentage' ? '%' : '',
                      prefixStyle: TextStyle(color: theme.textSecondary, fontSize: 20, fontWeight: FontWeight.bold),
                      suffixStyle: TextStyle(color: theme.textSecondary, fontSize: 20, fontWeight: FontWeight.bold),
                      hintText: '0.00',
                      hintStyle: TextStyle(color: theme.textHint.withOpacity(0.2)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    ),
                    onChanged: (v) => setDialogState(() {
                      dialogError = null;
                    }),
                    onSubmitted: (v) {
                      final val = double.tryParse(v) ?? 0;
                      final max = _controller.getMaxAllowedGlobalDiscount(dType);
                      
                      if (val > max && max != double.infinity) {
                        setDialogState(() {
                          dialogError = 'Exceeds max allowed (${max.toStringAsFixed(2)})';
                        });
                        return;
                      }
                      
                      _controller.setDiscount(val, type: dType);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                if (dialogError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      dialogError!,
                      style: const TextStyle(color: ThemeProvider.error, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: theme.cardBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Cancel', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final val = double.tryParse(discountCtrl.text) ?? 0;
                          final max = _controller.getMaxAllowedGlobalDiscount(dType);
                          
                          if (val > max && max != double.infinity) {
                            setDialogState(() {
                              dialogError = 'Exceeds max allowed (${max.toStringAsFixed(2)})';
                            });
                            return;
                          }
                          
                          _controller.setDiscount(val, type: dType);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.highlight,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('APPLY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goToPayment() async {
    if (_controller.cart.isEmpty) return;

    if (BusinessConfig.instance.enableGlobalDiscount &&
        _controller.isDiscountRestricted) {
      await _showDiscountExceededDialog();
      return;
    }

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
            originalSaleId: _controller.originalSaleId,
            customer: _controller.selectedCustomer,
          ),
        ),
      ).then((_) {
        _controller.clearCart();
        _controller.loadData();
        setState(() {});
      });
    }
  }

  Future<void> _showDiscountExceededDialog() async {
    final config = BusinessConfig.instance;
    final limitText = config.globalDiscountLimitType == 'percentage'
        ? '${config.globalDiscountLimit}%'
        : '${config.currencyDisplay} ${config.formatAmount(config.globalDiscountLimit)}';

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: theme.surface,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: ThemeProvider.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Discount Exceeded',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Your entered discount exceeds the maximum allowed limit of $limitText. Please adjust the discount before proceeding to payment.',
                style: TextStyle(color: theme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.highlight,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  child: const Text('OK', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                      // Directly open Add Customer form dialog
                      await AddCustomerDialog.show(context);
                      // Refresh the list and stay in the popup
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
                                trailing: IconButton(
                                  icon: Icon(Icons.edit_outlined,
                                      size: 18, color: theme.textSecondary),
                                  onPressed: () async {
                                    // Open edit form, stay in popup
                                    await AddCustomerDialog.show(context,
                                        existing: c);
                                    final updatedData = await DatabaseHelper
                                        .instance
                                        .getCustomers();
                                    setDialogState(() {
                                      allCustomers.clear();
                                      allCustomers.addAll(updatedData
                                          .map((x) => Customer.fromMap(x)));
                                    });
                                  },
                                ),
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

  // ignore: unused_element
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
          _audioPlayer?.play(AssetSource('beep.mpeg'));
          _processBarcode(code);
        }
      }
    }
  }

  Widget _buildInlineScanner() {
    return Align(
      alignment: Alignment.center,
      child: Container(
        height: 120,
        width: 400,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.highlight.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              if (_scannerController != null && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS))
                MobileScanner(
                  controller: _scannerController!,
                  onDetect: _onDetectBarcode,
                )
              else
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_enhance_outlined, color: theme.textSecondary.withOpacity(0.5), size: 24),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Camera not available', 
                              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () {
                              _closeBarcodeScanner();
                              _showManualBarcodeEntry();
                            },
                            child: Text('Click for Manual Entry', 
                                style: TextStyle(color: theme.highlight, fontSize: 11, decoration: TextDecoration.underline)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: Icon(Icons.close_rounded, color: theme.textPrimary, size: 18),
                  onPressed: _closeBarcodeScanner,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(backgroundColor: theme.surface.withOpacity(0.5)),
                ),
              ),
              if (_scannerController != null && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS))
                Positioned(
                  top: 4,
                  left: 4,
                  child: IconButton(
                    icon: const Icon(Icons.flash_on, color: Colors.white, size: 18),
                    onPressed: () => _scannerController?.toggleTorch(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualBarcodeEntry() {
    final barcodeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(20),
          decoration: theme.glassDecoration.copyWith(
            borderRadius: BorderRadius.circular(16),
            color: theme.surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Barcode Entry'.toUpperCase(),
                          style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 4),
                      Text('Manual Scan',
                          style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ThemeProvider.info.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: ThemeProvider.info, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: theme.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.cardBorder),
                ),
                child: TextField(
                  controller: barcodeCtrl,
                  autofocus: true,
                  style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                  decoration: InputDecoration(
                    hintText: 'Enter barcode...',
                    hintStyle: TextStyle(color: theme.textHint.withOpacity(0.5), fontSize: 16),
                    prefixIcon: Icon(Icons.keyboard_outlined, color: theme.textSecondary, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  onSubmitted: (v) {
                    Navigator.pop(ctx);
                    if (v.isNotEmpty) _processBarcode(v);
                  },
                ),
              ),
              const SizedBox(height: 20),
              if (_controller.products.isNotEmpty) ...[
                Text('Quick Selection',
                    style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _controller.products
                      .where((p) => p.latestBarcode != null && p.latestBarcode!.isNotEmpty)
                      .take(3)
                      .map((p) => Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                _processBarcode(p.latestBarcode!);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: theme.cardBorder),
                                  color: theme.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                                ),
                                child: Text(p.latestBarcode!, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: theme.cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (barcodeCtrl.text.isNotEmpty) _processBarcode(barcodeCtrl.text);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.highlight,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('ADD PRODUCT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
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

  void _processBarcode(String barcode) {
    // 1. Find all active stocks matching this barcode across all products
    final List<MapEntry<Product, Stock>> matchingStocks = [];
    for (var p in _controller.products) {
      for (var s in p.stocks) {
        if (s.status == 1 && s.barcode == barcode) {
          matchingStocks.add(MapEntry(p, s));
        }
      }
      // Fallback: Check if product name matches or product has no barcode but we have matches
      // (This is primarily for specific barcode scans, so we focus on s.barcode == barcode)
    }

    if (matchingStocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Product not found: $barcode'),
          backgroundColor: ThemeProvider.error));
      return;
    }

    if (matchingStocks.length == 1) {
      final entry = matchingStocks.first;
      final product = entry.key;
      final stock = entry.value;

      if (stock.quantity <= 0) {
        _showStockNotFoundDialog(product, stock);
      } else {
        final success = _controller.addToCart(product, stock);
        if (!success) {
          _showStockNotFoundDialog(product, stock);
        }
      }
    } else {
      // Multiple stocks share this barcode (variants)
      _showStockBatchDialog(matchingStocks.map((e) => e.key).toSet().toList());
    }
  }

  void _showPriceVariantDialog(List<Product> variants, String barcode) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(20),
          decoration: theme.glassDecoration.copyWith(
            borderRadius: BorderRadius.circular(16),
            color: theme.surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Multiple Products Found'.toUpperCase(),
                            style: TextStyle(
                                color: ThemeProvider.error,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text('Select Product for $barcode',
                            style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.textHint.withOpacity(0.1),
                        ),
                        child: Icon(Icons.close, color: theme.textSecondary, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: variants.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final v = variants[i];
                    Stock? stock;
                    try {
                      stock = v.stocks.firstWhere((s) => s.barcode == barcode);
                    } catch (_) {
                      stock = v.stocks.isNotEmpty ? v.stocks.first : null;
                    }
                    
                    if (stock == null) return const SizedBox.shrink();
                    final inStock = stock.quantity > 0;
                    final bool isLowStock = stock.quantity <= v.stockLimit;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                                if (!inStock) {
                                  _showStockNotFoundDialog(v, stock!);
                                  return;
                                }
                                Navigator.pop(ctx);
                                final success = _controller.addToCart(v, stock!);
                                if (!success) {
                                  // ignore: unnecessary_non_null_assertion
                                  _showStockNotFoundDialog(v, stock!);
                                }
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: inStock ? theme.cardBorder : theme.cardBorder.withOpacity(0.5)),
                            color: theme.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                          ),
                          child: Opacity(
                            opacity: inStock ? 1.0 : 0.6,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (inStock ? theme.highlight : theme.textHint).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.inventory_2_outlined,
                                      color: inStock ? theme.highlight : theme.textHint, size: 22),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(v.name,
                                          style: TextStyle(
                                              color: theme.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(
                                          '${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(stock.salePrice)}',
                                          style: TextStyle(
                                              color: theme.highlight,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: !inStock
                                        ? ThemeProvider.error.withOpacity(0.1)
                                        : isLowStock
                                            ? ThemeProvider.warning.withOpacity(0.1)
                                            : ThemeProvider.success.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    !inStock
                                        ? 'Out of Stock'
                                        : '${stock.quantity} Unit',
                                    style: TextStyle(
                                      color: !inStock
                                          ? ThemeProvider.error
                                          : isLowStock
                                              ? ThemeProvider.warning
                                              : ThemeProvider.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog({void Function(int newId)? onSuccess}) {
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController(text: '📦');
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: theme.glassDecoration.copyWith(
            borderRadius: BorderRadius.circular(16),
            color: theme.surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('QUICK ADD'.toUpperCase(),
                  style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text('New Category',
                  style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: TextStyle(color: theme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  labelStyle: TextStyle(color: theme.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: iconCtrl,
                style: TextStyle(color: theme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Icon / Emoji',
                  labelStyle: TextStyle(color: theme.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: theme.cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty) return;
                        final newId = await DatabaseHelper.instance.insertCategory({
                          'name': nameCtrl.text,
                          'icon': iconCtrl.text,
                          'status': 1,
                        });
                        if (mounted) {
                          await _controller.loadData();
                          _controller.setCategory(newId.toString());
                          if (onSuccess != null) onSuccess(newId);
                          Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.highlight,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _showAddSubCategoryDialog({void Function(int newId)? onSuccess, String? categoryId}) {
    final String effectiveCategoryId = categoryId ?? _controller.selectedCategory;
    final bool isRealCategory = int.tryParse(effectiveCategoryId) != null;
    
    if (!isRealCategory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a main category first'), backgroundColor: ThemeProvider.error)
      );
      return;
    }

    final nameCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: theme.glassDecoration.copyWith(
            borderRadius: BorderRadius.circular(16),
            color: theme.surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('QUICK ADD'.toUpperCase(),
                  style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text('New Sub-Category',
                  style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: TextStyle(color: theme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Sub-Category Name',
                  labelStyle: TextStyle(color: theme.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: theme.cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty) return;
                        final newId = await DatabaseHelper.instance.insertSubCategory({
                          'name': nameCtrl.text,
                          'category_id': int.parse(effectiveCategoryId),
                          'status': 1,
                        });
                        if (mounted) {
                          await _controller.loadData();
                          _controller.setSubCategory(newId.toString());
                          if (onSuccess != null) onSuccess(newId);
                          Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.highlight,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: POSKeyboardShortcuts.getPosBindings(
        onEscape: () async {
          final shouldPop = await _showBackConfirmDialog(context);
          if (shouldPop == true && context.mounted) {
            Navigator.pop(context);
          }
        },
        onF1: _promptClearCart,
        onF2: () => _cartKey.currentState?.toggleCustomerDropdown(),
        onF3: () => _controller.toggleReturn(!_controller.isReturn),
        onF4: _toggleQuickAddProduct,
        onF5: () => _cartKey.currentState?.openDiscountEditor(),
        onF6: _showAllHistory,
        onF7: () => setState(() => theme.toggleTheme()),
      ),
      child: PopScope(
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
                      focusNode: _keyboardFocusNode,
                      autofocus: true,
                      canRequestFocus: true,
                      descendantsAreFocusable: true,
                      onKeyEvent: (node, event) {
                        final result = POSKeyboardShortcuts.handleKeyEvent(
                          keyboardFocusNode: _keyboardFocusNode,
                          searchFocusNode: _searchFocusNode,
                          searchCtrl: _searchCtrl,
                          event: event,
                          onExit: () async {
                            final shouldPop = await _showBackConfirmDialog(context);
                            if (shouldPop == true && mounted) {
                              Navigator.pop(context);
                            }
                          },
                          onPay: _goToPayment,
                          onHold: _handleParkCart,
                          onUnhold: _showHeldOrdersDialog,
                          onClearCart: _promptClearCart,
                          onAddCustomer: () async {
                            final customer = await _showCustomerSelectionDialog();
                            if (customer != null) _controller.setSelectedCustomer(customer);
                          },
                          onSwitchReturnMode: () => _controller.toggleReturn(!_controller.isReturn),
                          onQuickAdd: _toggleQuickAddProduct,
                          onAddDiscount: _showDiscountDialog,
                          onHistory: _showAllHistory,
                          onSwitchTheme: () => setState(() => theme.toggleTheme()),
                          onSearchSubmit: (text) {
                            _processBarcode(text);
                            _searchCtrl.clear();
                            _controller.setSearchQuery('');
                          },
                          onSearchUpdate: (text) {
                            _controller.setSearchQuery(text);
                          },
                        );

                        if (result == KeyEventResult.ignored &&
                            event is KeyDownEvent &&
                            _cartKey.currentState?.isCustomerDropdownOpen != true) {
                          final key = event.logicalKey;
                          
                          if (key == LogicalKeyboardKey.enter) {
                            if (_searchCtrl.text.isNotEmpty) {
                              _processBarcode(_searchCtrl.text);
                              _searchCtrl.clear();
                              _controller.setSearchQuery('');
                            } else {
                              _goToPayment();
                            }
                            return KeyEventResult.handled;
                          }
                          
                          if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowRight) {
                            if (_controller.cart.isNotEmpty) {
                              _controller.updateQuantity(_controller.cart.length - 1, 1);
                            }
                            return KeyEventResult.handled;
                          }
                          
                          if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowLeft) {
                            if (_controller.cart.isNotEmpty) {
                              _controller.updateQuantity(_controller.cart.length - 1, -1);
                            }
                            return KeyEventResult.handled;
                          }
                        }
                        
                        return result;
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
                              onAddCategory: (void Function(int newId) refresh) => _showAddCategoryDialog(onSuccess: refresh),
                              onAddSubCategory: (void Function(int newId) refresh, catId) => _showAddSubCategoryDialog(onSuccess: refresh, categoryId: catId),
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
    ));
  }

  void _handleProductTap(Product product) {
    final variants = _controller.getVariantsByName(product.name);
    final bool hasMultipleBatches = variants.expand((v) => v.stocks).length > 1;

    if (hasMultipleBatches) {
      _showStockBatchDialog(variants);
    } else {
      final targetV = variants.isNotEmpty ? variants.first : product;
      if (targetV.stocks.isEmpty) return;
      
      final stock = targetV.stocks.first;
      if (stock.quantity <= 0) {
        _showStockNotFoundDialog(targetV, stock);
      } else {
        final success = _controller.addToCart(targetV, stock);
        if (!success) {
          _showStockNotFoundDialog(targetV, stock);
        }
      }
    }
  }

  Widget _buildProductPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isScannerOpen) _buildInlineScanner(),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.cardBorder, width: 1)),
          ),
          child: _buildPOSHeader(),
        ),
        if (!_isScannerOpen) 
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.cardBorder, width: 1)),
            ),
            child: POSCategorySelector(
              controller: _controller,
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              POSProductGrid(
                controller: _controller,
                onProductTap: _handleProductTap,
              ),
              if (_searchCtrl.text.isNotEmpty && _searchFocusNode.hasFocus)
                Positioned(
                  top: 0,
                  right: 16,
                  width: _searchBoxWidth,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: Material(
                      elevation: 12,
                      color: Colors.transparent,
                      child: Container(
                        decoration: theme.glassDecoration.copyWith(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          border: Border.all(color: theme.cardBorder),
                          color: theme.surface,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(4),
                          itemCount: _controller.filteredProducts.length,
                          separatorBuilder: (ctx, i) => Divider(height: 1, color: theme.cardBorder),
                          itemBuilder: (ctx, i) {
                            final product = _controller.filteredProducts[i];
                            final isInCart = _controller.cart.any((item) => item.product.id == product.id);
                            
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              leading: Checkbox(
                                value: isInCart,
                                onChanged: (bool? checked) {
                                  if (checked == true) {
                                    _handleProductTap(product);
                                  } else {
                                    final indices = <int>[];
                                    for(int j = 0; j < _controller.cart.length; j++) {
                                      if (_controller.cart[j].product.id == product.id) {
                                        indices.add(j);
                                      }
                                    }
                                    for(final idx in indices.reversed) {
                                      _controller.removeFromCart(idx);
                                    }
                                  }
                                  _searchFocusNode.requestFocus();
                                },
                                activeColor: theme.highlight,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              title: Text(product.name, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('Stock: ${product.latestStockQuantity}', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                              trailing: Text(BusinessConfig.instance.formatAmount(product.latestPrice), style: TextStyle(color: theme.highlight, fontWeight: FontWeight.w900)),
                              onTap: () {
                                if (!isInCart) {
                                  _handleProductTap(product);
                                } else {
                                  final indices = <int>[];
                                  for(int j = 0; j < _controller.cart.length; j++) {
                                    if (_controller.cart[j].product.id == product.id) {
                                      indices.add(j);
                                    }
                                  }
                                  for(final idx in indices.reversed) {
                                    _controller.removeFromCart(idx);
                                  }
                                }
                                _searchFocusNode.requestFocus();
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
        key: _cartKey,
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
        onOpenCashDrawer: () => debugPrint('Opening Cash Drawer...'),
      ),
    );
  }

  Widget _buildPOSHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool showLabel = constraints.maxWidth > 600;

        final buttons = [
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
              if (BusinessConfig.instance.enableShiftManagement) ...[
                const SizedBox(width: 8),
                Container(
                  decoration: theme.glassCircleDecoration,
                  child: IconButton(
                    icon: Icon(Icons.logout_rounded,
                        color: ThemeProvider.error, size: 20),
                    tooltip: 'Clock Out',
                    onPressed: () async {
                      final activeShift =
                          await DatabaseHelper.instance.getActiveShift();
                      if (activeShift != null && mounted) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: theme.surface,
                            title: const Text('Clock Out'),
                            content: const Text(
                                'Are you sure you want to clock out? This will end your current shift.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('No')),
                              ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: ThemeProvider.error),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Yes, Clock Out')),
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
              ],
              const SizedBox(width: 12),
              Container(
                decoration: theme.glassCircleDecoration,
                child: IconButton(
                  icon: Icon(
                      theme.isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: theme.isDark ? Colors.white : Colors.black,
                      size: 20),
                  tooltip: theme.isDark ? 'Light Mode' : 'Dark Mode',
                  onPressed: () => setState(() => theme.toggleTheme()),
                ),
              ),
              if (BusinessConfig.instance.enableShiftManagement) ...[
                const SizedBox(width: 12),
                _buildHeaderActionButton(
                  icon: Icons.history_rounded,
                  label: 'Shift History',
                  showLabel: showLabel,
                  color: theme.highlight,
                  onTap: _showShiftHistory,
                ),
              ],
              const SizedBox(width: 8),
              _buildHeaderActionButton(
                icon: Icons.receipt_long_rounded,
                label: 'All History',
                showLabel: showLabel,
                onTap: _showAllHistory,
              ),
        ];

        final searchWidget = LayoutBuilder(
          builder: (context, fieldConstraints) {
            if (_searchBoxWidth != fieldConstraints.maxWidth) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _searchBoxWidth = fieldConstraints.maxWidth);
              });
            }
            return Container(
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
              hintText: showLabel
                  ? 'Search product or scan barcode...'
                  : 'Search...',
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
                      icon: Icon(Icons.barcode_reader,
                          color: theme.iconColor),
                      onPressed: _openBarcodeScanner),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
        );
      },
    );

    if (showLabel) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                ...buttons,
                const SizedBox(width: 12),
                Expanded(child: searchWidget),

              ],
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: buttons),
                ),
                const SizedBox(height: 12),
                searchWidget,
              ],
            ),
          );
        }
      },
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
      builder: (ctx) => Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter) {
              Navigator.pop(ctx, true);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.pop(ctx, false);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: AlertDialog(
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
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool showLabel = true,
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
            if (showLabel) ...[
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
          ],
        ),
      ),
    );
  }
}
