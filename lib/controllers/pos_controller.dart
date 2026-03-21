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
  List<Product> _products = [];
  List<POSCartItem> _cart = [];
  
  String _selectedCategory = 'favorites';
  dynamic _selectedSubCategoryId;
  bool _isLoading = true;
  
  double _subtotal = 0;
  double _tax = 0;
  double _discount = 0;
  double _total = 0;
  bool _isReturn = false;
  Customer? _selectedCustomer;
  String _searchQuery = '';

  // Getters
  List<ProductCategory> get categories => _categories;
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
      
      _products = productsData.map((p) {
        final stocksData = (p['stocks'] as List<Map<String, dynamic>>? ?? []);
        return Product.fromMap(p, stocks: stocksData.map((s) => Stock.fromMap(s)).toList());
      }).toList();
      _categories = categoriesData.map((c) => ProductCategory.fromMap(c)).toList();
      
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
      filtered = _products.where((p) => p.categoryId?.toString() == _selectedCategory).toList();
      
      if (_selectedSubCategoryId != null) {
        filtered = filtered.where((p) => p.subCategoryId?.toString() == _selectedSubCategoryId.toString()).toList();
      } else {
        filtered = filtered.where((p) => p.subCategoryId == null || p.subCategoryId == 0 || p.subCategoryId == '').toList();
      }
    }
    
    // Only show products with stock
    return filtered.where((p) => p.stocks.any((s) => s.quantity > 0)).toList();
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
      item.quantity = nextQty;
      item.updateSubtotal();
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
      item.quantity = value;
      item.updateSubtotal();
    }
    calculateTotals();
  }

  void calculateTotals() {
    _subtotal = _cart.fold(0, (sum, item) => sum + item.subtotal);
    _tax = _subtotal * (BusinessConfig.instance.taxRate / 100);
    _total = _subtotal + _tax - _discount;
    if (_total < 0) _total = 0;
    notifyListeners();
  }

  void setDiscount(double value) {
    _discount = value;
    calculateTotals();
  }

  void clearCart() {
    _cart.clear();
    _discount = 0;
    _isReturn = false;
    _selectedCustomer = null;
    calculateTotals();
  }

  void setSelectedCustomer(Customer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
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
}
