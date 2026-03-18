import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/stock.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/customer_list_screen.dart';
import 'package:mobile_app/screens/payment_screen.dart';
import 'package:mobile_app/screens/held_orders_screen.dart';
import 'package:mobile_app/screens/scanner_screen.dart';
import 'package:mobile_app/widgets/shift_dialogs.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_app/controllers/add_product_controller.dart';

class POSScreen extends StatefulWidget {
  final HeldOrder? resumeOrder;
  static bool isActive = false;
  const POSScreen({super.key, this.resumeOrder});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> with SingleTickerProviderStateMixin {
  final theme = ThemeProvider.instance;
  List<ProductCategory> _categories = [];
  List<Product> _products = [];
  List<Map<String, dynamic>> _cart = [];
  String _selectedCategory = 'favorites';
  dynamic _selectedSubCategoryId;
  bool _loading = true;
  double _subtotal = 0;
  double _tax = 0;
  double _discount = 0;
  double _total = 0;
  bool _isReturn = false;
  Customer? _selectedCustomer;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  
  int? _expandedIndex;
  bool _isScannerOpen = false;
  MobileScannerController? _scannerController;
  DateTime? _lastScanTime;
  
  // Quick Add Product Panel State
  bool _showQuickAddProduct = false;
  late AnimationController _quickAddController;
  late Animation<Offset> _quickAddSlideAnimation;

  @override
  void initState() {
    super.initState();
    POSScreen.isActive = true;
    _loadData();
    if (widget.resumeOrder != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resumeOrder());
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
    _searchCtrl.dispose();
    _scannerController?.dispose();
    _quickAddController.dispose();
    super.dispose();
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
    _loadData();
  }

  void _resumeOrder() {
    final order = widget.resumeOrder!;
    setState(() {
      _cart = List.from(order.items);
      _selectedCustomer = order.customer;
      _calculateTotals();
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final productsData = await DatabaseHelper.instance.getProducts();
      final categoriesData = await DatabaseHelper.instance.getCategories();
      if (mounted) {
        setState(() {
          _products = productsData.map((p) {
            final stocksData = (p['stocks'] as List<Map<String, dynamic>>? ?? []);
            return Product.fromMap(p, stocks: stocksData.map((s) => Stock.fromMap(s)).toList());
          }).toList();
          _categories = categoriesData.map((c) => ProductCategory.fromMap(c)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading POS data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Product> get _filteredProducts {
    List<Product> products;
    if (_searchQuery.isNotEmpty) {
      products = _products
          .where((p) =>
              p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (p.stocks.any((s) => s.barcode?.contains(_searchQuery) ?? false)))
          .toList();
    } else if (_selectedCategory == 'favorites') {
      products = _products.where((p) => p.isFavorite).toList();
    } else if (_selectedCategory == 'recent') {
      final recentIds = MockDataStore.instance.recentProductIds;
      products = _products.where((p) => recentIds.contains(p.id)).toList();
    } else if (_selectedCategory == 'all') {
      products = _products;
    } else {
      products = _products.where((p) => p.categoryId?.toString() == _selectedCategory).toList();
      
      if (_selectedSubCategoryId != null) {
        products = products.where((p) => p.subCategoryId?.toString() == _selectedSubCategoryId.toString()).toList();
      } else {
        // Show only products directly in this parent category (no subcategory assigned)
        products = products.where((p) => p.subCategoryId == null || p.subCategoryId == 0 || p.subCategoryId == '').toList();
      }
    }
    
    return products.where((p) => p.stocks.any((s) => s.quantity > 0)).toList();
  }

  /// Shows an out of stock alert dialog.
  void _showOutOfStockAlert(Product product, Stock stock) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: ThemeProvider.error),
            const SizedBox(width: 8),
            Text('Out of Stock', style: TextStyle(color: theme.textPrimary)),
          ],
        ),
        content: Text(
          'The product "${product.name}" (Batch: ${stock.barcode ?? 'Default'}) is out of stock and cannot be added to the cart.',
          style: TextStyle(color: theme.textSecondary),
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

  void _addToCart(Product product, Stock stock, {double qty = 1, bool isWeight = false}) async {
    final cartItemId = '${product.id}_${stock.id}';
    final existingIndex = _cart.indexWhere((item) => item['cart_item_id'] == cartItemId);
    final double currentCartQty = existingIndex >= 0
        ? (_cart[existingIndex]['quantity'] as num).toDouble()
        : 0;
    final double newTotalQty = currentCartQty + qty;

    // Hard block: product batch is out of stock
    if (stock.quantity <= 0) {
      _showOutOfStockAlert(product, stock);
      return;
    }

    // Hard cap: requested qty exceeds available stock
    if (newTotalQty > stock.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Cannot add more. Only ${stock.quantity} in this batch.'),
        backgroundColor: ThemeProvider.error,
      ));
      return;
    }


    MockDataStore.instance.addToRecent(product.id);
    setState(() {
      if (existingIndex >= 0 && !isWeight) {
        _cart[existingIndex]['quantity'] += qty;
        final currentDiscount = (_cart[existingIndex]['discount'] ?? 0.0) as double;
        _cart[existingIndex]['subtotal'] =
            (_cart[existingIndex]['quantity'] * _cart[existingIndex]['price']) - currentDiscount;
      } else {
        _cart.add({
          'cart_item_id': cartItemId, // Unique ID for product+batch
          'id': product.id,
          'stock_id': stock.id ?? 0,
          'name': product.name,
          'price': stock.salePrice,
          'quantity': qty,
          'subtotal': stock.salePrice * qty,
          'isWeight': isWeight,
          'emoji': product.image,
          'barcode': stock.barcode,
          'discount': 0.0,
        });
      }
      _calculateTotals();
    });
  }

  void _showStockBatchDialog(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Select Batch for ${product.name}', style: TextStyle(color: theme.textPrimary)),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: product.stocks.length,
            itemBuilder: (ctx, i) {
              final stock = product.stocks[i];
              return ListTile(
                title: Text('${BusinessConfig.instance.currency}. ${stock.salePrice.toStringAsFixed(2)}', 
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
                subtitle: Text('Stock: ${stock.quantity} | Barcode: ${stock.barcode ?? 'N/A'}',
                    style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                trailing: Icon(Icons.add_shopping_cart, color: theme.highlight),
                onTap: () {
                  Navigator.pop(ctx);
                  if (product.isPricePerWeight) {
                    _showWeightDialog(product, stock);
                  } else {
                    _addToCart(product, stock);
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
        content: Column(
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
                        borderRadius: BorderRadius.circular(12)))),
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
                  _addToCart(product, stock, qty: weight, isWeight: true);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add')),
        ],
      ),
    );
  }

  void _removeFromCart(int index) => setState(() {
        _cart.removeAt(index);
        _calculateTotals();
      });

  void _updateQuantity(int index, int delta) async {
    if (delta > 0) {
      final item = _cart[index];
      final product = _products.firstWhere(
        (p) => p.id == (item['id'] ?? item['productId']),
        orElse: () => Product(id: 0, businessId: 0, name: ''),
      );
      final stock = product.stocks.firstWhere(
        (s) => s.id == item['stock_id'],
        orElse: () => Stock(
          id: 0,
          businessId: 0,
          productId: 0,
          quantity: 0,
          salePrice: 0,
          costPrice: 0,
        ),
      );

      if (product.id != 0 && (stock.id ?? 0) != 0) {
        final double nextQty = (item['quantity'] as num).toDouble() +
            (item['isWeight'] == true ? delta * 0.25 : delta);

        if (nextQty > stock.quantity) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Cannot increase. Only ${stock.quantity.toStringAsFixed(2)} in stock for this batch.'),
            backgroundColor: ThemeProvider.error,
          ));
          return;
        }

      }
    }

    setState(() {
      final item = _cart[index];
      if (item['isWeight'] == true) {
        _cart[index]['quantity'] =
            (_cart[index]['quantity'] as double) + (delta * 0.25);
      } else {
        _cart[index]['quantity'] += delta;
      }
      if (_cart[index]['quantity'] <= 0) {
        _cart.removeAt(index);
      } else {
        final currentDiscount = (_cart[index]['discount'] ?? 0.0) as double;
        _cart[index]['subtotal'] =
            (_cart[index]['quantity'] * _cart[index]['price']) - currentDiscount;
      }
      _calculateTotals();
    });
  }

  void _setQuantity(int index, double value) {
    if (value > 0) {
      final item = _cart[index];
      final product = _products.firstWhere(
        (p) => p.id == (item['id'] ?? item['productId']),
        orElse: () => Product(id: 0, businessId: 0, name: ''),
      );
      final stock = product.stocks.firstWhere(
        (s) => s.id == item['stock_id'],
        orElse: () => Stock(
          id: 0,
          businessId: 0,
          productId: 0,
          quantity: 0,
          salePrice: 0,
          costPrice: 0,
        ),
      );

      if (product.id != 0 && (stock.id ?? 0) != 0) {
        if (value > stock.quantity) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Cannot set to ${value.toStringAsFixed(2)}. Only ${stock.quantity.toStringAsFixed(2)} in stock.'),
            backgroundColor: ThemeProvider.error,
          ));
          return;
        }
      }
    }

    setState(() {
      _cart[index]['quantity'] = value;
      if (_cart[index]['quantity'] <= 0) {
        _cart.removeAt(index);
        _expandedIndex = null;
      } else {
        final currentDiscount = (_cart[index]['discount'] ?? 0.0) as double;
        _cart[index]['subtotal'] =
            (_cart[index]['quantity'] * _cart[index]['price']) - currentDiscount;
      }
      _calculateTotals();
    });
  }

  void _calculateTotals() {
    _subtotal =
        _cart.fold(0, (sum, item) => sum + (item['subtotal'] as double));
    _tax = _subtotal * (BusinessConfig.instance.taxRate / 100);
    _total = _subtotal + _tax - _discount;
    if (_total < 0) _total = 0;
  }

  void _clearCart() => setState(() {
        _cart.clear();
        _discount = 0;
        _isReturn = false;
        _selectedCustomer = null;
        _calculateTotals();
      });

  Future<bool?> _showBackConfirmDialog(BuildContext context) {
    final theme = ThemeProvider.instance;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.help_outline_rounded, color: theme.highlight),
            const SizedBox(width: 12),
            Text('Go Back?', style: TextStyle(color: theme.textPrimary)),
          ],
        ),
        content: Text(
          'Are you sure you want to exit the POS? Any unsaved cart progress might be lost.',
          style: TextStyle(color: theme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Stay', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.highlight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Go Back', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _promptClearCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
      _clearCart();
    }
  }

  void _parkCurrentCart() {
    if (_cart.isEmpty) return;
    
    // Auto-generate name based on customer or order number
    final defaultName = _selectedCustomer?.name ??
        'Order #${HeldOrdersStore.instance.orders.length + 1}';
        
    holdOrder(defaultName, _cart, _total, _selectedCustomer);
    _clearCart();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Order held successfully!')));
  }

  void _showHeldOrdersModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final orders = HeldOrdersStore.instance.orders;
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(ThemeProvider.radiusCard)),
            ),
            child: Column(
              children: [
                // Modal Handle
                Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: theme.isDark
                            ? Colors.white.withOpacity(0.2)
                            : theme.textHint.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2))),
                
                // Title & Close
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(' ORDERS',
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

                // Park Current Cart Button (only if cart is not empty)
                if (_cart.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: InkWell(
                      onTap: () {
                        _parkCurrentCart();
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ThemeProvider.warning.withOpacity(0.1),
                          border: Border.all(color: ThemeProvider.warning.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.pause_circle_filled_rounded, color: ThemeProvider.warning),
                            const SizedBox(width: 8),
                            Text('Park Current Cart', 
                                style: TextStyle(
                                  color: ThemeProvider.warning, 
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // List of Held Orders
                Expanded(
                  child: orders.isEmpty
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            final elapsed = DateTime.now().difference(order.createdAt);
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
                                      child: Text(order.name, 
                                          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                                    ),
                                    Text(elapsedStr, 
                                        style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '${order.items.length} items • ${BusinessConfig.instance.currency}. ${order.total.toStringAsFixed(2)}',
                                    style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: ThemeProvider.error, size: 18),
                                      onPressed: () {
                                        setModalState(() => orders.remove(order));
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.play_arrow_rounded, color: ThemeProvider.success, size: 18),
                                      style: IconButton.styleFrom(
                                        backgroundColor: ThemeProvider.success.withOpacity(0.1),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                      onPressed: () {
                                        orders.remove(order);
                                        setState(() {
                                          _cart = List.from(order.items);
                                          _selectedCustomer = order.customer;
                                          _calculateTotals();
                                        });
                                        Navigator.pop(ctx);
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
          );
        },
      ),
    );
  }

  void _showDiscountDialog() {
    final discountCtrl =
        TextEditingController(text: _discount > 0 ? _discount.toString() : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title:
            Text('Apply Discount', style: TextStyle(color: theme.textPrimary)),
        content: TextField(
            controller: discountCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: TextStyle(color: theme.textPrimary, fontSize: 24),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
                prefixText: '\$ ', border: const OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: TextStyle(color: theme.textSecondary))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme.highlight),
              onPressed: () {
                setState(() {
                  _discount = double.tryParse(discountCtrl.text) ?? 0;
                  _calculateTotals();
                });
                Navigator.pop(ctx);
              },
              child: const Text('Apply')),
        ],
      ),
    );
  }

  void _goToPayment() async {
    if (_cart.isEmpty) return;

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            cart: _cart,
            subtotal: _subtotal,
            tax: _tax,
            discount: _discount,
            total: _total,
            isReturn: _isReturn,
            customer: _selectedCustomer,
          ),
        ),
      ).then((_) {
        _clearCart();
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
                  width: 400,
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
                            border: const OutlineInputBorder(),
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
      setState(() {
        // Update in the main list
        final pIdx = _products.indexWhere((p) => p.id == product.id);
        if (pIdx >= 0) {
          _products[pIdx].isFavorite = !_products[pIdx].isFavorite;
        }

        // Also update in MockDataStore for consistency if still used
        final idx = MockDataStore.instance.products
            .indexWhere((p) => p.id == product.id);
        if (idx >= 0) {
          MockDataStore.instance.products[idx].isFavorite =
              !MockDataStore.instance.products[idx].isFavorite;
        }
      });
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.highlight, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: barcodeCtrl,
                autofocus: true,
                style: TextStyle(color: theme.textPrimary),
                decoration: InputDecoration(
                    hintText: 'Scan or type barcode...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
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
                children: _products
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
    final matches = _products.where((p) {
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
        _addToCart(product, stock);
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      'Price: $currency. ${stock.salePrice.toStringAsFixed(2)}  ·  Stock: ${stock.quantity}',
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
                              _addToCart(v, stock!);
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
                return Row(
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductPanel() {
    final screenWidth = MediaQuery.of(context).size.width;
    final gridColumns = screenWidth > 1400
        ? 7
        : (screenWidth > 1100
            ? 6
            : (screenWidth > 800 ? 5 : (screenWidth > 500 ? 3 : 2)));

    return Column(
      children: [
        // Premium Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                      // 1. Confirmation Dialog
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

                      // 2. Denominations Dialog
                      final closingData = await showDialog<Map<String, dynamic>>(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => const ClockOutDenominationsDialog(),
                      );

                      if (closingData == null || !mounted) return;

                      // 3. Summary & Finalize Dialog
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
                        Navigator.pop(context); // Go back to HomeScreen
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: theme.glassDecoration.copyWith(
                    borderRadius: BorderRadius.circular(8),
                    color: theme.isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white.withOpacity(0.2),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(
                        color: theme.textPrimary, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Search product or scan barcode...',
                      hintStyle: TextStyle(
                          color: theme.textHint, fontWeight: FontWeight.w400),
                      prefixIcon:
                          Icon(Icons.search_rounded, color: theme.iconColor),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded,
                                  size: 18, color: theme.iconColor),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
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
        ),

        // Inline Scanner (if open)
        if (_isScannerOpen) _buildInlineScanner(),

        // Horizontal Categories
        if (!_isScannerOpen) _buildCategoryTabs(),

        // Products
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: theme.highlight))
              : _getGridItemCount() == 0
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: theme.glassCircleDecoration,
                              child: Text(
                                  _selectedCategory == 'favorites' ? '⭐' : '📦',
                                  style: const TextStyle(fontSize: 48)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                                _selectedCategory == 'favorites'
                                    ? 'No favorites yet'
                                    : 'No products found',
                                style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                            Text('Try a different category or search',
                                style: TextStyle(
                                    color: theme.textSecondary, fontSize: 13)),
                          ]),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridColumns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: _getGridItemCount(),
                      itemBuilder: (ctx, i) {
                        return _buildGridItem(i);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCategoryTabs() {
    final categories = [
      ProductCategory(
          id: -1, name: 'Favorites', icon: '⭐', businessId: 0),
      ProductCategory(id: -2, name: 'Recent', icon: '🕐', businessId: 0),
      ProductCategory(id: 0, name: 'All Items', icon: '📝', businessId: 0),
      ..._categories.where((c) => c.parentId == null),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat.id.toString();
          
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() {
                if (cat.id == -1) {
                  _selectedCategory = 'favorites';
                } else if (cat.id == -2) {
                  _selectedCategory = 'recent';
                } else if (cat.id == 0) {
                  _selectedCategory = 'all';
                } else {
                  _selectedCategory = cat.id.toString();
                }
                _selectedSubCategoryId = null;
                _searchCtrl.clear();
                _searchQuery = '';
              }),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: theme.glassDecoration.copyWith(
                  color: isSelected
                      ? theme.highlight
                      : (theme.isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withOpacity(0.4)),
                  border: Border.all(
                      color: isSelected
                          ? theme.highlight
                          : theme.whiteAlpha(0.1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        cat.id == -1 || cat.id == -2 || cat.id == 0
                            ? cat.icon!
                            : _getCategoryEmoji(cat.icon),
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Text(
                      cat.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : theme.textPrimary,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getCategoryEmoji(String? icon) {
    switch (icon) {
      case 'devices':
        return '📱';
      case 'headphones':
        return '🎧';
      case 'cable':
        return '🔌';
      default:
        return '📦';
    }
  }

  int _getGridItemCount() {
    int count = _filteredProducts.length;
    if (_selectedSubCategoryId != null) {
      count += 1; // Back button
    } else if (_selectedCategory != 'favorites' && _selectedCategory != 'recent' && _selectedCategory != 'all') {
      final subCats = _categories.where((c) => c.parentId?.toString() == _selectedCategory).toList();
      count += subCats.length;
    }
    return count;
  }

  Widget _buildGridItem(int index) {
    // 1. Check for Back button
    if (_selectedSubCategoryId != null) {
      if (index == 0) {
        return _buildBackTile();
      }
      index -= 1;
    }

    // 2. Check for Subcategories
    if (_selectedSubCategoryId == null && _selectedCategory != 'favorites' && _selectedCategory != 'recent' && _selectedCategory != 'all') {
      final subCats = _categories.where((c) => c.parentId?.toString() == _selectedCategory).toList();
      if (index < subCats.length) {
        return _buildSubCategoryTile(subCats[index]);
      }
      index -= subCats.length;
    }

    // 3. Product Tile
    final p = _filteredProducts[index];
    return _ProductGridTile(
      product: p,
      onTap: () {
        if (p.stocks.length > 1) {
          _showStockBatchDialog(p);
        } else if (p.stocks.length == 1) {
          if (p.isPricePerWeight) {
            _showWeightDialog(p, p.stocks.first);
          } else {
            _addToCart(p, p.stocks.first);
          }
        }
      },
      onLongPress: () => _toggleFavorite(p),
      onWeightTap: null, 
    );
  }

  Widget _buildBackTile() {
    return InkWell(
      onTap: () => setState(() => _selectedSubCategoryId = null),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: theme.glassDecoration.copyWith(
          color: theme.highlight.withOpacity(0.05),
          border: Border.all(color: theme.highlight.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.highlight.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back_rounded, color: theme.highlight, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              'BACK', 
              style: TextStyle(
                color: theme.highlight, 
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.5,
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategoryTile(ProductCategory cat) {
    return InkWell(
      onTap: () => setState(() => _selectedSubCategoryId = cat.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: theme.glassDecoration.copyWith(
          color: theme.isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(cat.icon ?? '📁', style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 12),
            Text(
              cat.name.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'SUB-CATEGORY',
              style: TextStyle(
                color: theme.textSecondary.withOpacity(0.5),
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallHeight = constraints.maxHeight < 500;

        // Common content
        final header = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.whiteAlpha(0.1))),
          ),
          child: Row(
            children: [
              // Customer Status / Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CUSTOMER',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedCustomer?.name ?? 'Walk-in Guest',
                      style: TextStyle(
                        color: _selectedCustomer != null ? theme.highlight : theme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons Row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Select Customer Button
                  _buildHeaderButton(
                    icon: _selectedCustomer != null ? Icons.person_rounded : Icons.person_add_rounded,
                    color: _selectedCustomer != null ? theme.highlight : theme.textSecondary,
                    onTap: () async {
                      final result = await Navigator.push<Customer>(
                        context,
                        MaterialPageRoute(builder: (_) => const CustomerListScreen(selectMode: true)),
                      );
                      if (result != null && mounted) {
                        setState(() => _selectedCustomer = result);
                      }
                    },
                    tooltip: 'Select Customer',
                  ),
                  const SizedBox(width: 8),

                  // Held Orders Button
                  _buildHeaderButton(
                    icon: Icons.receipt_long_rounded,
                    color: ThemeProvider.warning,
                    onTap: _showHeldOrdersModal,
                    tooltip: ' Orders',
                  ),
                  const SizedBox(width: 8),

                  // Quick Add Product Button
                  _buildHeaderButton(
                    icon: Icons.add_business_rounded,
                    color: theme.highlight,
                    onTap: _toggleQuickAddProduct,
                    tooltip: 'Quick Add Product',
                  ),
                ],
              ),
            ],
          ),
        );

        final tableHeader = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.whiteAlpha(0.03),
            border: Border(bottom: BorderSide(color: theme.whiteAlpha(0.1))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('PRODUCTS',
                    style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: Text('QTY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: Text('RATE',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 75,
                child: Text('TOTAL',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
              ),
            ],
          ),
        );

        final listContent = _cart.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_shopping_cart_rounded,
                          size: 48, color: theme.iconColor.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text('Cart is empty',
                          style: TextStyle(
                              color: theme.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: isSmallHeight, // Shrink wrap if scrolling parent
                physics: isSmallHeight
                    ? const NeverScrollableScrollPhysics()
                    : null, // Disable own scroll if parent scrolls
                itemCount: _cart.length,
                padding: EdgeInsets.zero,
                itemBuilder: (ctx, i) => _CartItemTile(
                  item: _cart[i],
                  isExpanded: _expandedIndex == i,
                  onToggleExpand: () => setState(() {
                    _expandedIndex = (_expandedIndex == i) ? null : i;
                  }),
                  onIncrement: () => _updateQuantity(i, 1),
                  onDecrement: () => _updateQuantity(i, -1),
                  onQuantityChanged: (newQty) => _setQuantity(i, newQty),
                  onRemove: () => _removeFromCart(i),
                  onPriceChanged: (newPrice) => setState(() {
                    _cart[i]['price'] = newPrice;
                    _cart[i]['subtotal'] = _cart[i]['quantity'] * newPrice;
                    _calculateTotals();
                  }),
                  onDiscountChanged: (newDiscount) => setState(() {
                    _cart[i]['discount'] = newDiscount;
                    // Subtotal includes discount
                    _cart[i]['subtotal'] = (_cart[i]['quantity'] * _cart[i]['price']) - newDiscount;
                    _calculateTotals();
                  }),
                ),
              );

        final totals = _buildTotals();

        Widget content;
        if (isSmallHeight) {
          // Scrollable layout for small screens
          content = SingleChildScrollView(
            child: Column(
              children: [
                header,
                if (_cart.isNotEmpty) tableHeader,
                listContent,
                totals,
              ],
            ),
          );
        } else {
          // Fixed layout for normal screens
          content = Column(
            children: [
              header,
              if (_cart.isNotEmpty) tableHeader,
              Expanded(child: listContent),
              totals,
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.whiteAlpha(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                content,
                SlideTransition(
                  position: _quickAddSlideAnimation,
                  child: _QuickAddProductPanel(
                    onClose: _toggleQuickAddProduct,
                    onSuccess: _onProductQuickAdded,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildCartAction(
      {required IconData icon,
      required String label,
      required Color color,
      VoidCallback? onTap,
      bool expanded = true}) {
    final theme = ThemeProvider.instance;
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          children: [
            Icon(icon,
                color: onTap == null ? theme.iconColor.withOpacity(0.5) : color,
                size: 20),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label.toUpperCase(),
                  style: TextStyle(
                    color: onTap == null
                        ? theme.textSecondary.withOpacity(0.5)
                        : color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  )),
            ),
          ],
        ),
      ),
    );
    return expanded ? Expanded(child: content) : content;
  }

  Widget _buildMobileCartBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: theme.glassDecoration.copyWith(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: _showMobileCartSheet,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: _isReturn
                              ? ThemeProvider.gradientDanger
                              : ThemeProvider.gradientSuccess),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (_isReturn
                                  ? ThemeProvider.error
                                  : ThemeProvider.success)
                              .withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.shopping_basket_rounded,
                        color: Colors.white),
                  ),
                  if (_cart.isNotEmpty)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: ThemeProvider.error, shape: BoxShape.circle),
                        child: Text('${_cart.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      _cart.isEmpty ? 'CART IS EMPTY' : '${_cart.length} ITEMS',
                      style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5)),
                  Text(
                      '${BusinessConfig.instance.currency}. ${_total.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _cart.isEmpty ? null : _goToPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isReturn ? ThemeProvider.error : ThemeProvider.success,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(_isReturn ? 'REFUND' : 'PAYMENT',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: theme.isDark
                          ? Colors.white.withOpacity(0.2)
                          : theme.textHint.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('YOUR ORDER',
                        style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    if (_cart.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('CLEAR'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _promptClearCart();
                        },
                        style: TextButton.styleFrom(
                            foregroundColor: ThemeProvider.error),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _cart.isEmpty
                    ? Center(
                        child: Text('Add items to get started',
                            style: TextStyle(color: theme.textSecondary)))
                    : ListView.builder(
                        itemCount: _cart.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (ctx, i) => _CartItemTile(
                            item: _cart[i],
                            isExpanded: _expandedIndex == i,
                            onToggleExpand: () => setSheetState(() {
                              _expandedIndex = (_expandedIndex == i) ? null : i;
                            }),
                            onIncrement: () {
                              _updateQuantity(i, 1);
                              setSheetState(() {});
                            },
                            onDecrement: () {
                              _updateQuantity(i, -1);
                              if (_cart.isEmpty) {
                                Navigator.pop(ctx);
                              } else {
                                setSheetState(() {});
                              }
                            },
                            onQuantityChanged: (newQty) {
                              _setQuantity(i, newQty);
                              setSheetState(() {});
                            },
                            onRemove: () {
                              _removeFromCart(i);
                              if (_cart.isEmpty) {
                                Navigator.pop(ctx);
                              } else {
                                setSheetState(() {});
                              }
                            },
                            onPriceChanged: (newPrice) => setSheetState(() {
                              _cart[i]['price'] = newPrice;
                              _cart[i]['subtotal'] = _cart[i]['quantity'] * newPrice;
                              _calculateTotals();
                            }),
                            onDiscountChanged: (newDiscount) => setSheetState(() {
                              _cart[i]['discount'] = newDiscount;
                              _cart[i]['subtotal'] = (_cart[i]['quantity'] * _cart[i]['price']) - newDiscount;
                              _calculateTotals();
                            }),
                        ),
                      ),
              ),
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildTotalsCompact()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotals() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.whiteAlpha(0.1))),
      ),
      child: Column(
        children: [
          _totalRow('Subtotal', _subtotal),
          const SizedBox(height: 6),
          _totalRow('Tax (8%)', _tax),
          if (_discount > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _showDiscountDialog,
                  child: Row(children: [
                    Text('Discount',
                        style: TextStyle(
                            color: theme.highlight,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_rounded, size: 12, color: theme.highlight)
                  ]),
                ),
                Text(
                    '-${BusinessConfig.instance.currency}. ${_discount.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: theme.highlight,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ],
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL AMOUNT',
                  style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
              Text(
                  '${BusinessConfig.instance.currency}. ${_total.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: theme.highlight,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildCartAction(
                    icon: Icons.discount_rounded,
                    label: 'Discount',
                    color: theme.highlight,
                    onTap: _showDiscountDialog,
                    expanded: false,
                  ),
                  const SizedBox(width: 4),
                  _buildCartAction(
                    icon: _isReturn
                        ? Icons.shopping_cart_checkout_rounded
                        : Icons.assignment_return_rounded,
                    label: _isReturn ? 'Sale Mode' : 'Return Mode',
                    color: _isReturn ? ThemeProvider.success : ThemeProvider.error,
                    onTap: () => setState(() => _isReturn = !_isReturn),
                    expanded: false,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _cart.isEmpty ? null : _promptClearCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeProvider.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('CLEAR',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _cart.isEmpty ? null : _parkCurrentCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeProvider.warning,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('HOLD',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _cart.isEmpty ? null : _goToPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isReturn ? ThemeProvider.error : ThemeProvider.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(_isReturn ? 'REFUND' : 'PAY',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: theme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        Text('${BusinessConfig.instance.currency}. ${value.toStringAsFixed(2)}',
            style: TextStyle(
                color: theme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildTotalsCompact() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('TOTAL AMOUNT',
                style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
            Text(
                '${BusinessConfig.instance.currency}. ${_total.toStringAsFixed(2)}',
                style: TextStyle(
                    color: theme.highlight,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1)),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _cart.isEmpty
                ? null
                : () {
                    Navigator.pop(context);
                    _goToPayment();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isReturn ? ThemeProvider.error : ThemeProvider.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              _isReturn
                  ? 'PROCESS REFUND'
                  : 'PAYMENT ${BusinessConfig.instance.currency}. ${_total.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTab(
      {required this.emoji,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.highlight : theme.whiteAlpha(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? theme.highlight : theme.whiteAlpha(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : theme.textPrimary,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ProductGridTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onWeightTap;

  const _ProductGridTile(
      {required this.product,
      required this.onTap,
      required this.onLongPress,
      this.onWeightTap});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onWeightTap ?? onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: product.isFavorite
                  ? ThemeProvider.warning.withOpacity(0.5)
                  : theme.whiteAlpha(theme.isDark ? 0.05 : 0.2),
              width: product.isFavorite ? 1.2 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(theme.isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Emoji and Stock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.highlight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        product.image ?? '📦',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  if (product.isFavorite)
                    Icon(Icons.star_rounded,
                        color: ThemeProvider.warning, size: 14)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.highlight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${product.totalStock}',
                        style: TextStyle(
                            color: theme.highlight,
                            fontSize: 12,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              // Bottom Row: Details
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text(
                      product.priceRange,
                      style: TextStyle(
                          color: theme.highlight,
                          fontSize: 13,
                          fontWeight: FontWeight.w900),
                    ),
                    if (product.stocks.length > 1) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${product.stocks.length} batches',
                        style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (product.isPricePerWeight) ...[
                      const SizedBox(width: 4),
                      Text(
                        '/ ${BusinessConfig.instance.weightUnit}',
                        style:
                            TextStyle(color: theme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final Function(double) onPriceChanged;
  final Function(double) onDiscountChanged;

  const _CartItemTile({
    required this.item,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onIncrement,
    required this.onDecrement,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onPriceChanged,
    required this.onDiscountChanged,
  });

  final Function(double) onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final isWeight = item['isWeight'] == true;
    final qty = isWeight
        ? (item['quantity'] as double).toStringAsFixed(2)
        : '${item['quantity']}';
    final discount = (item['discount'] ?? 0.0) as double;

    return Column(
      children: [
        InkWell(
          onTap: onToggleExpand,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.whiteAlpha(0.05)))),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item['name'],
                    style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                // QTY (Display Only)
                SizedBox(
                  width: 90,
                  child: Text(
                    qty,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),

                // RATE (Unit Price)
                SizedBox(
                  width: 60,
                  child: Text(
                    (item['price'] as double).toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: theme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),

                // TOTAL (Subtotal)
                SizedBox(
                  width: 75,
                  child: Text(
                    (item['subtotal'] as double).toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: -0.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        if (isExpanded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: theme.whiteAlpha(0.02),
              border: Border(bottom: BorderSide(color: theme.whiteAlpha(0.05))),
            ),
            child: Row(
              children: [
                // PRICE (Icon Only)
                _ActionButton(
                  icon: Icons.edit_rounded,
                  label: '',
                  onTap: () => _showEditValueDialog(
                    context,
                    title: 'Edit Price',
                    initialValue: (item['price'] as double),
                    onChanged: onPriceChanged,
                  ),
                ),
                const SizedBox(width: 8),

                // DISCOUNT (Icon + Label)
                _ActionButton(
                  icon: Icons.discount_rounded,
                  label: 'Disc',
                  onTap: () => _showEditValueDialog(
                    context,
                    title: 'Discount',
                    initialValue: discount,
                    onChanged: onDiscountChanged,
                  ),
                ),
                
                const Spacer(),

                // QUANTITY CONTROLS (Between Discount and Remove)
                _qtyBtn(Icons.remove_rounded, onDecrement, theme.textSecondary),
                InkWell(
                  onTap: () => _showEditValueDialog(
                    context,
                    title: 'Edit Quantity',
                    initialValue: (item['quantity'] as double).toDouble(),
                    onChanged: onQuantityChanged,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      qty,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                _qtyBtn(Icons.add_rounded, onIncrement, theme.highlight),
                
                const SizedBox(width: 8),

                // REMOVE (Icon Only)
                _ActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: '',
                  color: ThemeProvider.error,
                  onTap: onRemove,
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showEditValueDialog(BuildContext context,
      {required String title,
      required double initialValue,
      required Function(double) onChanged}) {
    final theme = ThemeProvider.instance;
    final ctrl = TextEditingController(text: initialValue.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text(title, style: TextStyle(color: theme.textPrimary)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: theme.textPrimary, fontSize: 24),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            prefixText: '${BusinessConfig.instance.currency} ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: theme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.highlight),
            onPressed: () {
              final val = double.tryParse(ctrl.text) ?? initialValue;
              onChanged(val);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _largeQtyBtn(IconData icon, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 54,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final activeColor = color ?? theme.highlight;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: activeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: activeColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: activeColor, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: activeColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _QuickAddProductPanel extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onSuccess;

  const _QuickAddProductPanel({
    super.key,
    required this.onClose,
    required this.onSuccess,
  });

  @override
  State<_QuickAddProductPanel> createState() => _QuickAddProductPanelState();
}

class _QuickAddProductPanelState extends State<_QuickAddProductPanel> {
  late AddProductController _controller;
  final _formKey = GlobalKey<FormState>();
  final theme = ThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _controller = AddProductController();
    _controller.addListener(_updateUI);
    _controller.loadCategories();
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_updateUI);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showAddCategoryDialog() async {
    final catCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Add Category', style: TextStyle(color: theme.textPrimary)),
        content: TextField(
          controller: catCtrl,
          style: TextStyle(color: theme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Category Name',
            labelStyle: TextStyle(color: theme.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.isDark ? theme.textHint : Colors.black.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.isDark ? theme.highlight : Colors.black.withOpacity(0.6)),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.highlight),
            onPressed: () async {
              if (catCtrl.text.trim().isNotEmpty) {
                final success = await _controller.addCategory(catCtrl.text.trim());
                if (success && mounted) {
                  Navigator.pop(c);
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSubCategoryDialog() async {
    if (_controller.selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a main category first')),
      );
      return;
    }

    final catCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Add Sub-Category', style: TextStyle(color: theme.textPrimary)),
        content: TextField(
          controller: catCtrl,
          style: TextStyle(color: theme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Sub-Category Name',
            labelStyle: TextStyle(color: theme.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.isDark ? theme.textHint : Colors.black.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.isDark ? theme.highlight : Colors.black.withOpacity(0.6)),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.highlight),
            onPressed: () async {
              if (catCtrl.text.trim().isNotEmpty) {
                final success = await _controller.addCategory(
                  catCtrl.text.trim(),
                  parentId: _controller.selectedCategory,
                );
                if (success && mounted) {
                  Navigator.pop(c);
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final result = await _controller.saveProduct();

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: ThemeProvider.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to save product'),
          backgroundColor: ThemeProvider.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return Container(
        color: theme.surface,
        child: Center(child: CircularProgressIndicator(color: theme.highlight)),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(left: BorderSide(color: theme.whiteAlpha(0.1))),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.whiteAlpha(0.1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                    'QUICK ADD PRODUCT',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.textSecondary, size: 20),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDropdownField(),
                    const SizedBox(height: 12),
                    _buildSubCategoryDropdownField(),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _controller.name,
                      label: 'Product Name',
                      icon: Icons.inventory_2_outlined,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _controller.barcode,
                      label: 'Barcode',
                      icon: Icons.qr_code_rounded,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _controller.price,
                            label: 'Sell Price',
                            icon: Icons.monetization_on_outlined,
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(
                            controller: _controller.purchasePrice,
                            label: 'Cost Price',
                            icon: Icons.shopping_bag_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _controller.stock,
                      label: 'Current Stock',
                      icon: Icons.warehouse_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.whiteAlpha(0.1))),
              ),
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.highlight,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text('SAVE PRODUCT', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.textSecondary, fontSize: 12),
        prefixIcon: Icon(icon, color: theme.highlight.withOpacity(0.7), size: 18),
        filled: true,
        fillColor: theme.whiteAlpha(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<dynamic>(
            value: _controller.categories.any((c) => c.id == _controller.selectedCategory)
                ? _controller.selectedCategory
                : null,
            dropdownColor: theme.surface,
            isExpanded: true,
            style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: TextStyle(color: theme.textSecondary, fontSize: 12),
              prefixIcon: Icon(Icons.category_outlined, color: theme.highlight.withOpacity(0.7), size: 18),
              filled: true,
              fillColor: theme.whiteAlpha(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: _controller.categories
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: _controller.setCategory,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _showAddCategoryDialog,
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.highlight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.add_rounded, color: theme.highlight, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildSubCategoryDropdownField() {
    final theme = ThemeProvider.instance;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<dynamic>(
            value: _controller.subCategories.any((c) => c.id == _controller.selectedSubCategoryId)
                ? _controller.selectedSubCategoryId
                : null,
            dropdownColor: theme.surface,
            isExpanded: true,
            style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Sub-Category',
              labelStyle: TextStyle(color: theme.textSecondary, fontSize: 12),
              prefixIcon: Icon(Icons.account_tree_outlined, color: theme.highlight.withOpacity(0.7), size: 18),
              filled: true,
              fillColor: theme.whiteAlpha(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('No Sub-Category')),
              ..._controller.subCategories
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            ],
            onChanged: _controller.setSubCategory,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _showAddSubCategoryDialog,
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.highlight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.add_rounded, color: theme.highlight, size: 20),
          ),
        ),
      ],
    );
  }
}
