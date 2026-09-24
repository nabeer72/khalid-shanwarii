import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/stock.dart';
import 'package:mobile_app/models/pos_cart_item.dart';
import 'package:mobile_app/models/held_order.dart';
import 'package:mobile_app/models/deal.dart';
import 'package:mobile_app/models/deal_item.dart';

class POSController with ChangeNotifier {
  List<ProductCategory> _categories = [];
  List<ProductCategory> _subCategories = [];
  List<Product> _products = [];
  List<Deal> _deals = [];
  List<dynamic> _topSellingProductIds = [];
  List<POSCartItem> _cart = [];
  Set<dynamic> _weightUnitIds = {};
  Set<dynamic> _noStockUnitIds = {};

  String _selectedCategory = 'all';
  dynamic _selectedSubCategoryId;
  bool _isLoading = true;
  double _subtotal = 0;
  double _tax = 0;
  double _discount = 0;
  String _globalDiscountType = 'fixed'; // 'fixed' or 'percentage'
  double _globalDiscountValue = 0;
  double _total = 0;
  bool _isReturn = false;
  int? _originalSaleId;
  Customer? _selectedCustomer;
  String _searchQuery = '';
  bool get isDiscountRestricted => _isDiscountRestricted;
  bool _isManualDiscount = false;
  bool _isDiscountRestricted = false;

  // Subscription to data changes
  StreamSubscription? _dataChangeSubscription;

  // Getters
  List<ProductCategory> get categories => _categories;
  List<ProductCategory> get subCategories => _subCategories;
  List<Product> get products => _products;
  List<Deal> get deals => _deals;
  List<POSCartItem> get cart => _cart;
  String get selectedCategory => _selectedCategory;
  dynamic get selectedSubCategoryId => _selectedSubCategoryId;
  bool get isLoading => _isLoading;
  double get subtotal => _subtotal;
  double get tax => _tax;
  double get discount => _discount;
  String get globalDiscountType => _globalDiscountType;
  double get globalDiscountValue => _globalDiscountValue;
  double get totalDiscount =>
      _cart.fold(0.0, (sum, item) => sum + item.discount) + _discount;
  double get total => _total;
  bool get isReturn => _isReturn;
  int? get originalSaleId => _originalSaleId;
  Customer? get selectedCustomer => _selectedCustomer;
  String get searchQuery => _searchQuery;

  bool isWeightUnit(dynamic unitId) {
    if (unitId == null) return false;
    return _weightUnitIds.contains(unitId);
  }

  bool isWeightProduct(Product product) {
    return isWeightUnit(product.unitId);
  }

  bool isNoStockUnit(dynamic unitId) {
    if (unitId == null) return false;
    return _noStockUnitIds.contains(unitId);
  }

  bool isNoStockProduct(Product product) {
    return isNoStockUnit(product.unitId);
  }

  POSController() {
    loadData();
    _listenToDataChanges();
  }

  void _listenToDataChanges() {
    _dataChangeSubscription = DatabaseHelper.dataStream.listen((_) {
      loadData();
    });
  }

  @override
  void dispose() {
    _dataChangeSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final productsData = await DatabaseHelper.instance.getProducts();
      final categoriesData = await DatabaseHelper.instance.getCategories();
      final subCategoriesData =
          await DatabaseHelper.instance.getSubCategories();

      try {
        final unitsData = await DatabaseHelper.instance.getUnits();
        const weightShortNames = {'kg', 'g', 'L', 'l', 'm', 'ft', 'yd'};
        const weightFullNames = {
          'kilogram',
          'gram',
          'liter',
          'litre',
          'meter',
          'metre',
          'foot',
          'yard'
        };
        const noStockShortNames = {'kg', 'g', 'L', 'l', 'plt', 'nan', 'roti'};
        const noStockFullNames = {
          'kilogram',
          'gram',
          'liter',
          'litre',
          'plate',
          'nan',
          'roti'
        };
        _weightUnitIds = <dynamic>{};
        _noStockUnitIds = <dynamic>{};
        for (final u in unitsData) {
          final sn = (u['short_name'] ?? '').toString().trim().toLowerCase();
          final nm = (u['name'] ?? '').toString().trim().toLowerCase();
          if (weightShortNames.contains(sn) || weightFullNames.contains(nm)) {
            _weightUnitIds.add(u['id']);
          }
          if (noStockShortNames.contains(sn) || noStockFullNames.contains(nm)) {
            _noStockUnitIds.add(u['id']);
          }
        }
      } catch (ue) {
        debugPrint('Error loading weight/noStock units: $ue');
        _weightUnitIds = {};
        _noStockUnitIds = {};
      }

      _products = productsData.map((p) {
        final stocksData = (p['stocks'] as List<Map<String, dynamic>>? ?? []);
        return Product.fromMap(p,
            stocks: stocksData.map((s) => Stock.fromMap(s)).toList());
      }).toList();
      _categories =
          categoriesData.map((c) => ProductCategory.fromMap(c)).toList();

      // Load and map subcategories
      final List<ProductCategory> subCats = subCategoriesData
          .map((c) => ProductCategory.fromMap({
                ...c,
                'parent_id': c['category_id'],
              }))
          .toList();

      _subCategories = subCats;

      // Load active deals
      final dealsData =
          await DatabaseHelper.instance.getAllDeals(activeOnly: true);
      _deals = dealsData.map((d) => Deal.fromMap(d)).toList();

      _topSellingProductIds = [];
      try {
        final topItems =
            await DatabaseHelper.instance.getTopSellingItems(limit: 30);
        for (final item in topItems) {
          final id = item['product_id'];
          if (id != null) _topSellingProductIds.add(id);
        }
      } catch (_) {}
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
    } else if (_selectedCategory == 'top_selling') {
      filtered = _products
          .where((p) => _topSellingProductIds
              .any((id) => id.toString() == p.id.toString()))
          .toList();
      filtered.sort((a, b) {
        final ai = _topSellingProductIds
            .indexWhere((id) => id.toString() == a.id.toString());
        final bi = _topSellingProductIds
            .indexWhere((id) => id.toString() == b.id.toString());
        return ai.compareTo(bi);
      });
    } else if (_selectedCategory == 'recent') {
      final recentIds = MockDataStore.instance.recentProductIds;
      filtered = _products.where((p) => recentIds.contains(p.id)).toList();
    } else if (_selectedCategory == 'all') {
      filtered = _products;
    } else {
      if (_selectedSubCategoryId != null) {
        filtered = _products
            .where((p) =>
                p.subCategoryId?.toString() ==
                _selectedSubCategoryId.toString())
            .toList();
      } else {
        filtered = _products.where((p) {
          final pcid = p.categoryId?.toString();
          final pscid = p.subCategoryId?.toString();

          if (pscid != null) {
            final subCat = _subCategories
                .where((sc) => sc.id.toString() == pscid)
                .firstOrNull;
            if (subCat != null &&
                subCat.parentId?.toString() == _selectedCategory) {
              final count = _products
                  .where((p2) => p2.subCategoryId?.toString() == pscid)
                  .length;
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
      uniqueByName[p.name.toLowerCase()] =
          p; // Last one wins (usually the newest)
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
    return _products
        .where((p) => p.name.toLowerCase() == name.toLowerCase())
        .toList();
  }

  // Cart Management
  bool addToCart(Product product, Stock stock,
      {double qty = 1, bool isWeight = false}) {
    final cartItemId = '${product.id}_${stock.id}';
    final existingIndex =
        _cart.indexWhere((item) => item.cartItemId == cartItemId);

    final double currentCartQty =
        existingIndex >= 0 ? _cart[existingIndex].quantity : 0;
    final bool skipStock = isNoStockProduct(product);
    if (!skipStock && currentCartQty + qty > stock.quantity) return false;

    MockDataStore.instance.addToRecent(product.id);

    if (existingIndex >= 0 && !isWeight) {
      // Quantity bump on existing row — keep the green on whichever row is already marked
      _cart[existingIndex].quantity += qty;
      _cart[existingIndex].updateSubtotal();
    } else {
      // Brand new row: clear isNew on all existing items, then mark the new one
      for (final item in _cart) {
        item.isNew = false;
      }
      final newItem = POSCartItem(
        cartItemId: cartItemId,
        product: product,
        stock: stock,
        quantity: qty,
        price: stock.salePrice,
        isWeight: isWeight,
        discountType: 'fixed',
        discountValue: 0,
      );
      newItem.isNew = true;
      _cart.add(newItem);
    }
    calculateTotals();
    return true;
  }

  bool addDealToCart(Deal deal, List<DealItem> dealItems, {double qty = 1}) {
    final cartItemId = 'deal_${deal.id}';
    final existingIndex =
        _cart.indexWhere((item) => item.cartItemId == cartItemId);

    if (existingIndex >= 0) {
      _cart[existingIndex].quantity += qty;
      _cart[existingIndex].updateSubtotal();
    } else {
      for (final item in _cart) {
        item.isNew = false;
      }
      final newItem = POSCartItem(
        cartItemId: cartItemId,
        isDeal: true,
        deal: deal,
        dealItems: dealItems,
        quantity: qty,
        price: deal.dealPrice,
        isWeight: false,
        discountType: 'fixed',
        discountValue: 0,
      );
      newItem.isNew = true;
      _cart.add(newItem);
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
      if (!item.isDeal && item.stock != null && item.product != null) {
        final bool skipStock = isNoStockProduct(item.product!);
        if (!skipStock && nextQty > item.stock!.quantity) return;
      }
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
      if (!item.isDeal && item.stock != null && item.product != null) {
        final bool skipStock = isNoStockProduct(item.product!);
        if (!skipStock && value > item.stock!.quantity) return;
      }
      item.setQuantity(value);
    }
    calculateTotals();
  }

  void calculateTotals() {
    // 1. Apply Auto-discount Logic first if applicable
    if (!_isManualDiscount &&
        _selectedCustomer != null &&
        _selectedCustomer!.discount > 0) {
      for (var item in _cart) {
        if (item.isManual) continue; // Skip auto-discount for manual overrides
        if (item.isDeal) continue; // Skip auto-discount for deals

        double limitValue = item.stock?.discountLimit ?? 0;
        String limitType = item.stock?.discountLimitType ?? 'percentage';
        double customerPercent = _selectedCustomer!.discount;

        double calculatedDiscount = 0;
        if (limitType == 'percentage') {
          double applyPercent = customerPercent;
          if (limitValue > 0 && applyPercent > limitValue) {
            applyPercent = limitValue;
          }
          calculatedDiscount =
              (item.price * item.quantity) * (applyPercent / 100);
        } else {
          calculatedDiscount =
              (item.price * item.quantity) * (customerPercent / 100);
          if (limitValue > 0 && calculatedDiscount > limitValue) {
            calculatedDiscount = limitValue;
          }
        }

        item.discountType = 'fixed';
        item.discountValue = calculatedDiscount;
        item.updateSubtotal();
      }
    }

    // 2. Sum up final figures
    _subtotal = 0;
    double itemDiscounts = 0;

    for (var item in _cart) {
      // The user wants item-level discounts to be 'hidden' from the bottom discount row
      // So we make the subtotal reflect the value AFTER item discounts
      _subtotal += item.subtotal;
      itemDiscounts += item.discount;
    }

    if (BusinessConfig.instance.enableTax) {
      _tax = _subtotal * (BusinessConfig.instance.taxRate / 100);
    } else {
      _tax = 0.0;
    }

    if (_isManualDiscount && BusinessConfig.instance.enableGlobalDiscount) {
      double calculatedDiscount = 0;
      if (_globalDiscountType == 'percentage') {
        calculatedDiscount = _subtotal * (_globalDiscountValue / 100);
      } else {
        calculatedDiscount = _globalDiscountValue;
      }

      final maxAllowed = _adminMaxGlobalDiscountFixed();
      if (maxAllowed != double.infinity &&
          calculatedDiscount > maxAllowed + 0.009) {
        _discount = maxAllowed;
        _isDiscountRestricted = true;
      } else {
        _discount = calculatedDiscount;
        _isDiscountRestricted = false;
      }
    } else {
      // Bottom discount row stays 'empty' (0) for item-level discounts
      _discount = 0;
      _isDiscountRestricted = false;
    }

    _total = _subtotal + _tax - _discount;

    if (!_isReturn && _total < 0) _total = 0;
    notifyListeners();
  }

  double getProductQuantityInCart(dynamic productId) {
    return _cart
        .where((item) => item.product?.id == productId)
        .fold(0.0, (sum, item) => sum + item.quantity);
  }

  void setDiscount(double value, {String type = 'fixed'}) {
    _globalDiscountValue = value;
    _globalDiscountType = type;
    _isManualDiscount = true;
    calculateTotals();
  }

  bool isGlobalDiscountOverLimit(double value, String type) {
    if (!BusinessConfig.instance.enableGlobalDiscount) return false;
    if (BusinessConfig.instance.globalDiscountLimit <= 0) return false;

    double calculatedDiscount;
    if (type == 'percentage') {
      calculatedDiscount = _subtotal * (value / 100);
    } else {
      calculatedDiscount = value;
    }

    final maxAllowed = _adminMaxGlobalDiscountFixed();
    return maxAllowed != double.infinity &&
        calculatedDiscount > maxAllowed + 0.009;
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
      final product = _products.firstWhere((p) => p.id == productId,
          orElse: () => _products.first);
      final stock = product.stocks.firstWhere(
          (s) => s.id == itemMap['stock_id'],
          orElse: () => product.stocks.first);

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
          quantity: -((itemMap['quantity'] as num).toDouble().abs()),
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
        final customerMap =
            customers.firstWhere((c) => c['id'] == sale['customer_id']);
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

  double _adminMaxGlobalDiscountFixed() {
    if (!BusinessConfig.instance.enableGlobalDiscount) return double.infinity;

    final limit = BusinessConfig.instance.globalDiscountLimit;
    if (limit <= 0) return double.infinity;

    if (BusinessConfig.instance.globalDiscountLimitType == 'percentage') {
      return _subtotal * (limit / 100);
    }
    return limit;
  }

  double getMaxAllowedGlobalDiscount(String type) {
    final maxFixed = _adminMaxGlobalDiscountFixed();
    if (maxFixed == double.infinity) return double.infinity;

    if (type == 'percentage') {
      if (_subtotal <= 0) return 0;
      return (maxFixed / _subtotal) * 100;
    }
    return maxFixed;
  }
}
