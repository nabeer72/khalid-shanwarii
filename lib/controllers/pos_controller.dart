import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/stock.dart';
import 'package:mobile_app/models/pos_cart_item.dart';
import 'package:mobile_app/models/held_order.dart';

class POSController with ChangeNotifier {
  List<ProductCategory> _categories = [];
  List<ProductCategory> _subCategories = [];
  List<Product> _products = [];
  List<POSCartItem> _cart = [];
  
  String _selectedCategory = 'all';
  dynamic _selectedSubCategoryId;
  bool _isLoading = true;
  
  double _subtotal = 0;
  double _tax = 0;
  double _discount = 0;
  double _total = 0;
  bool _isReturn = false;
  int? _originalSaleId;
  Customer? _selectedCustomer;
  String _searchQuery = '';
  bool _isManualDiscount = false;

  // Getters
  List<ProductCategory> get categories => _categories;
  List<ProductCategory> get subCategories => _subCategories;
  List<Product> get products => _products;
  List<POSCartItem> get cart => _cart;
  String get selectedCategory => _selectedCategory;
  dynamic get selectedSubCategoryId => _selectedSubCategoryId;
  bool get isLoading => _isLoading;
  double get subtotal => _subtotal;
  double get tax => _tax;
  double get discount => _discount;
  double get totalDiscount => _cart.fold(0.0, (sum, item) => sum + item.discount) + _discount;
  double get total => _total;
  bool get isReturn => _isReturn;
  int? get originalSaleId => _originalSaleId;
  Customer? get selectedCustomer => _selectedCustomer;
  String get searchQuery => _searchQuery;

  POSController() {
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final productsData = await DatabaseHelper.instance.getProducts();
      final categoriesData = await DatabaseHelper.instance.getCategories();
      final subCategoriesData = await DatabaseHelper.instance.getSubCategories();
      
      _products = productsData.map((p) {
        final stocksData = (p['stocks'] as List<Map<String, dynamic>>? ?? []);
        return Product.fromMap(p, stocks: stocksData.map((s) => Stock.fromMap(s)).toList());
      }).toList();
      _categories = categoriesData.map((c) => ProductCategory.fromMap(c)).toList();
      
      // Load and map subcategories
      final List<ProductCategory> subCats = subCategoriesData.map((c) => ProductCategory.fromMap({
        ...c,
        'parent_id': c['category_id'],
      })).toList();
      
      // We can also store them in a separate list if we want to show a subcategory selector
      _subCategories = subCats;
      
    } catch (e) {
      debugPrint('Error loading POS data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Product> get filteredProducts {
    List<Product> filtered;
    if (_searchQuery.isNotEmpty) {
      filtered = _products
          .where((p) =>
              p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (p.stocks.any((s) => s.barcode?.contains(_searchQuery) ?? false)))
          .toList();
    } else if (_selectedCategory == 'favorites') {
      filtered = _products.where((p) => p.isFavorite).toList();
    } else if (_selectedCategory == 'recent') {
      final recentIds = MockDataStore.instance.recentProductIds;
      filtered = _products.where((p) => recentIds.contains(p.id)).toList();
    } else if (_selectedCategory == 'all') {
      filtered = _products;
    } else {
      if (_selectedSubCategoryId != null) {
        filtered = _products.where((p) => p.subCategoryId?.toString() == _selectedSubCategoryId.toString()).toList();
      } else {
        filtered = _products.where((p) {
          final pcid = p.categoryId?.toString();
          final pscid = p.subCategoryId?.toString();
          
          if (pscid != null) {
            final subCat = _subCategories.where((sc) => sc.id.toString() == pscid).firstOrNull;
            if (subCat != null && subCat.parentId?.toString() == _selectedCategory) {
              final count = _products.where((p2) => p2.subCategoryId?.toString() == pscid).length;
              if (count <= 1) return true; // Show directly if 1 or 0 items
            }
          } else if (pcid == _selectedCategory) {
            return true; // Direct category match with no subcategory
          }
          return false;
        }).toList();
      }
    }
    
    // UNIQUE BY NAME: Ensure each product name only appears once in the POS grid.
    // This handles cases where price changes created multiple product entries.
    final Map<String, Product> uniqueByName = {};
    for (var p in filtered) {
       uniqueByName[p.name.toLowerCase()] = p; // Last one wins (usually the newest)
    }
    
    return uniqueByName.values.toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String categoryId) {
    _selectedCategory = categoryId;
    _selectedSubCategoryId = null;
    _searchQuery = '';
    notifyListeners();
  }

  void setSubCategory(dynamic subCategoryId) {
    _selectedSubCategoryId = subCategoryId;
    _searchQuery = '';
    notifyListeners();
  }

  /// Finds all products (and their stocks) that share the same name.
  /// Used for the "Batch Selection" popup in the POS.
  List<Product> getVariantsByName(String name) {
    return _products.where((p) => p.name.toLowerCase() == name.toLowerCase()).toList();
  }

  // Cart Management
  bool addToCart(Product product, Stock stock, {double qty = 1, bool isWeight = false}) {
    final cartItemId = '${product.id}_${stock.id}';
    final existingIndex = _cart.indexWhere((item) => item.cartItemId == cartItemId);
    
    final double currentCartQty = existingIndex >= 0 ? _cart[existingIndex].quantity : 0;
    if (currentCartQty + qty > stock.quantity) return false;

    MockDataStore.instance.addToRecent(product.id);

    if (existingIndex >= 0 && !isWeight) {
      _cart[existingIndex].quantity += qty;
      _cart[existingIndex].updateSubtotal();
    } else {
      _cart.add(POSCartItem(
        cartItemId: cartItemId,
        product: product,
        stock: stock,
        quantity: qty,
        price: stock.salePrice,
        isWeight: isWeight,
      ));
    }
    calculateTotals();
    return true;
  }

  void removeFromCart(int index) {
    if (index < 0 || index >= _cart.length) return;
    _cart.removeAt(index);
    calculateTotals();
  }

  void updateQuantity(int index, double delta) {
    if (index < 0 || index >= _cart.length) return;
    
    final item = _cart[index];
    final double step = item.isWeight ? 0.25 : 1.0;
    final double nextQty = item.quantity + (delta * step);
    
    if (nextQty <= 0) {
      _cart.removeAt(index);
    } else {
      if (nextQty > item.stock.quantity) return;
      item.setQuantity(nextQty);
    }
    calculateTotals();
  }

  void setQuantity(int index, double value) {
    if (index < 0 || index >= _cart.length) return;
    
    if (value <= 0) {
      _cart.removeAt(index);
    } else {
      final item = _cart[index];
      if (value > item.stock.quantity) return;
      item.setQuantity(value);
    }
    calculateTotals();
  }

  void calculateTotals() {
    _subtotal = _cart.fold(0, (sum, item) => sum + item.subtotal);
    _tax = _subtotal * (BusinessConfig.instance.taxRate / 100);

    // Auto-calculate discount if a customer is selected AND NO MANUAL DISCOUNT entered
    if (!_isManualDiscount && _selectedCustomer != null && _selectedCustomer!.discount > 0) {
       double autoDiscount = 0;
       for (var item in _cart) {
         double limitPercent = item.stock.discountLimit;
         double applyPercent = _selectedCustomer!.discount;
         if (limitPercent >= 0 && applyPercent > limitPercent) {
             applyPercent = limitPercent; // Cap customer discount at product's limit
         }
         autoDiscount += (item.price * item.quantity) * (applyPercent / 100);
       }
       _discount = autoDiscount;
    }

    _total = _subtotal + _tax - _discount;
    if (_total < 0) _total = 0;
    notifyListeners();
  }

  double getProductQuantityInCart(dynamic productId) {
    return _cart
        .where((item) => item.product.id == productId)
        .fold(0.0, (sum, item) => sum + item.quantity);
  }

  void setDiscount(double value) {
    _discount = value;
    _isManualDiscount = true;
    calculateTotals();
  }

  void clearCart() {
    _cart.clear();
    _discount = 0;
    _isManualDiscount = false;
    _isReturn = false;
    _originalSaleId = null;
    _selectedCustomer = null;
    calculateTotals();
  }

  void clearSaleData() {
    _subtotal = 0;
    _selectedCustomer = null;
    _isReturn = false;
    _originalSaleId = null;
    notifyListeners();
  }

  void setSelectedCustomer(Customer? customer) {
    _selectedCustomer = customer;
    _isManualDiscount = false;
    if (customer == null) {
      _discount = 0;
    }
    calculateTotals();
  }

  void toggleReturn(bool value) {
    _isReturn = value;
    notifyListeners();
  }

  void resumeOrder(HeldOrder order) {
    _cart = order.items.map((itemMap) {
      final productId = itemMap['product_id'] ?? itemMap['id'];
      final product = _products.firstWhere((p) => p.id == productId, orElse: () => _products.first);
      final stock = product.stocks.firstWhere((s) => s.id == itemMap['stock_id'], orElse: () => product.stocks.first);
      
      return POSCartItem(
        cartItemId: '${product.id}_${stock.id}',
        product: product,
        stock: stock,
        quantity: (itemMap['quantity'] as num).toDouble(),
        price: (itemMap['price'] as num).toDouble(),
        discount: (itemMap['discount'] as num).toDouble(),
        isWeight: itemMap['isWeight'] ?? false,
      );
    }).toList();
    
    _selectedCustomer = order.customer;
    calculateTotals();
  }

  Future<void> parkCurrentCart(String name) async {
    if (_cart.isEmpty) return;
    
    final cartList = _cart.map((item) => item.toMap()).toList();
    await DatabaseHelper.instance.insertHeldOrder({
      'name': name,
      'total': _total,
      'customer_id': _selectedCustomer?.id,
    }, cartList);
    
    clearCart();
  }

  Future<void> loadReturnSale(Map<String, dynamic> sale) async {
    debugPrint('START loadReturnSale: sale_id=${sale['id']}');
    _originalSaleId = sale['id'];
    if (_products.isEmpty) {
      debugPrint('Products empty, waiting for loadData...');
      await loadData();
      debugPrint('Products loaded. Count: ${_products.length}');
    }
    
    final items = await DatabaseHelper.instance.getSaleItems(sale['id']);
    debugPrint('Fetched sale items: ${items.length}');
    _cart.clear();
    
    for (var itemMap in items) {
      final productId = itemMap['product_id'];
      final stockId = itemMap['stock_id'];
      debugPrint('Processing item: product_id=$productId, stock_id=$stockId');
      
      try {
        final product = _products.firstWhere((p) => p.id == productId);
        // Use matching stock if stockId is present, otherwise fall back to first stock
        Stock? stock;
        if (stockId != null) {
          stock = product.stocks.where((s) => s.id == stockId).firstOrNull;
        }
        stock ??= product.stocks.isNotEmpty ? product.stocks.first : null;
        
        if (stock == null) {
          debugPrint('No stocks found for product $productId, skipping');
          continue;
        }
        
        _cart.add(POSCartItem(
          cartItemId: '${product.id}_${stock.id}',
          saleItemId: itemMap['id'], // ID from sale_items table
          product: product,
          stock: stock,
          quantity: (itemMap['quantity'] as num).toDouble(),
          price: (itemMap['price'] as num).toDouble(),
          discount: (itemMap['discount'] as num? ?? 0).toDouble(),
          isWeight: itemMap['isWeight'] == 1,
        ));
      } catch (e) {
        debugPrint('Product or stock not found for return item: $e');
      }
    }
    
    if (sale['customer_id'] != null) {
      try {
         final customers = await DatabaseHelper.instance.getCustomers();
         final customerMap = customers.firstWhere((c) => c['id'] == sale['customer_id']);
         _selectedCustomer = Customer.fromMap(customerMap);
      } catch (e) {
         _selectedCustomer = null; 
      }
    } else {
      _selectedCustomer = null;
    }
    
    _isReturn = true;
    _discount = 0; // We reset global discount for the return process
    debugPrint('loadReturnSale complete. Cart size: ${_cart.length}');
    calculateTotals();
  }
}
