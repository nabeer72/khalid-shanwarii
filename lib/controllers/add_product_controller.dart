import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/stock.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/branch.dart';
import 'package:mobile_app/models/brand.dart';
import 'package:mobile_app/db/crud/units_crud.dart';
import 'package:mobile_app/services/sync_service.dart';

class AddProductController with ChangeNotifier {
  final Product? initialProduct;
  final Stock? initialStock;

  // Controllers
  late TextEditingController name;
  late TextEditingController barcode;
  late TextEditingController price;
  late TextEditingController purchasePrice;
  late TextEditingController wholesalePrice;
  late TextEditingController stock;
  late TextEditingController stockLimit;
  late TextEditingController discountLimit;
  String discountLimitType = 'percentage'; // 'percentage' or 'fixed'
  late TextEditingController description;
  late TextEditingController piecesPerBox;
  late TextEditingController boxPrice;
  late TextEditingController boxPurchasePrice;
  late TextEditingController boxWholesalePrice;

  // State
  dynamic selectedCategory;
  List<ProductCategory> categories = [];
  dynamic selectedSubCategoryId;
  List<ProductCategory> subCategories = [];
  bool isFavorite = false;
  int status = 1;
  bool _isLoading = true;
  List<Branch> branches = [];
  dynamic selectedBranchId;

  String? _errorMessage;
  List<Brand> brands = [];
  dynamic selectedBrandId;
  List<Map<String, dynamic>> units = [];
  dynamic selectedUnitId;
  bool isBoxUnit = false;
  Map<String, List<Map<String, dynamic>>> groupedUnits = {};
  static final Set<dynamic> _globalSelectedUnitIds = {};
  Set<dynamic> get selectedUnitIds => _globalSelectedUnitIds;
  StreamSubscription? _dbSubscription;


  // Called during logout to ensure no in-memory state leaks to the next session
  static void clearGlobalState() {
    _globalSelectedUnitIds.clear();
  }

  AddProductController({this.initialProduct, this.initialStock}) {
    name = TextEditingController(text: initialProduct?.name ?? '');
    barcode = TextEditingController(text: initialStock?.barcode ?? initialProduct?.latestBarcode ?? '');
    price = TextEditingController(text: initialStock?.salePrice.toString() ?? initialProduct?.latestPrice.toString() ?? '');
    purchasePrice = TextEditingController(text: initialStock?.costPrice.toString() ?? initialProduct?.latestPurchasePrice.toString() ?? '');
    wholesalePrice = TextEditingController(text: initialStock?.wholesalePrice.toString() ?? initialProduct?.latestWholesalePrice.toString() ?? '');
    stock = TextEditingController(text: initialStock?.quantity.toString() ?? initialProduct?.latestStockQuantity.toString() ?? '');
    stockLimit = TextEditingController(text: (initialProduct?.stockLimit ?? 5).toString());
    discountLimit = TextEditingController(text: initialStock?.discountLimit.toString() ?? initialProduct?.discountLimit.toString() ?? ''); 
    discountLimitType = initialStock?.discountLimitType ?? initialProduct?.discountLimitType ?? 'percentage';
    description = TextEditingController(text: initialProduct?.description ?? '');
    piecesPerBox = TextEditingController(text: '1');
    boxPrice = TextEditingController();
    boxPurchasePrice = TextEditingController();
    boxWholesalePrice = TextEditingController();

    selectedCategory = initialProduct?.categoryId;
    selectedSubCategoryId = initialProduct?.subCategoryId;
    isFavorite = initialProduct?.isFavorite ?? false;
    status = initialProduct?.status ?? 1;
    selectedBranchId = initialProduct?.branchId ?? BusinessConfig.instance.branchId;
    selectedBrandId = initialProduct?.brandId;
    selectedUnitId = initialProduct?.unitId;
    if (selectedUnitId != null) {
      selectedUnitIds.add(selectedUnitId);
      _checkIfBoxUnit();
    }
    
    barcode.addListener(() {
      if (_errorMessage != null && _errorMessage!.contains('barcode')) {
        _errorMessage = null;
      }
      // Trigger uniqueness check with delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (barcode.text.isNotEmpty) {
          checkBarcodeUniqueness(barcode.text);
        } else {
          barcodeValidationError = null;
          notifyListeners();
        }
      });
    });

    _dbSubscription = DatabaseHelper.dataStream.listen((_) {
      _handleDatabaseChange();
    });
  }

  Future<void> _handleDatabaseChange() async {
    if (_isLoading) return;

    // Capture current names to re-associate after ID changes (sync mappings)
    final currentCatName = _firstOrNull(categories.where((c) => c.id == selectedCategory))?.name;
    final currentSubName = _firstOrNull(subCategories.where((c) => c.id == selectedSubCategoryId))?.name;

    final oldCatId = selectedCategory;
    final oldSubId = selectedSubCategoryId;

    await _fetchCategories();
    
    // If IDs changed due to sync, re-map selection by name
    if (currentCatName != null) {
      final newCatMatch = _firstOrNull(categories.where((c) => c.name == currentCatName));
      if (newCatMatch != null) {
        selectedCategory = newCatMatch.id;
        
        // If category ID changed, we MUST reload subcategories to find the new sub ID
        if (selectedCategory != oldCatId) {
           await reloadSubCategories();
        }

        if (currentSubName != null) {
          final newSubMatch = _firstOrNull(subCategories.where((sc) => sc.name == currentSubName));
          if (newSubMatch != null) {
            selectedSubCategoryId = newSubMatch.id;
          }
        }
      }
    }
    
    if (oldCatId != selectedCategory || oldSubId != selectedSubCategoryId) {
      if (kDebugMode) print('🔄 [CONTROLLER] Re-mapped selection after DB change: Cat $oldCatId->$selectedCategory, Sub $oldSubId->$selectedSubCategoryId');
      notifyListeners();
    }
  }

  // Helper extension-like getter for safety
  T? _firstOrNull<T>(Iterable<T> iterable) => iterable.isEmpty ? null : iterable.first;


  void _checkIfBoxUnit() {
    if (selectedUnitId == null) {
      isBoxUnit = false;
      return;
    }
    final unit = units.firstWhere((u) => u['id'] == selectedUnitId, orElse: () => {});
    isBoxUnit = ['box', 'carton', 'bag'].any((w) => (unit['name'] ?? '').toString().toLowerCase().contains(w));
    notifyListeners();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEditMode => initialProduct != null;

  String get screenTitle => isEditMode ? 'Edit Product Screen' : 'Add New Product Screen';
  String get saveSuccessMessage => '${name.text.trim()} saved successfully!';

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    try {

      await Future.wait([
        _fetchCategories(),
        _fetchBrands(),
        _fetchUnits(),
      ]);
    } catch (e) {
      _errorMessage = 'Failed to load initial data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchCategories() async {
    final raw = await DatabaseHelper.instance.getCategories();
    final allCats = raw.map((map) => ProductCategory.fromMap(map)).toList();
    
    // Filter for parent categories only (parentId is null)
    categories = allCats.where((c) => c.parentId == null).toList();
    
    if (selectedCategory != null) {
      final matches = categories.where((c) => c.id.toString() == selectedCategory.toString());
      if (matches.isNotEmpty) {
        selectedCategory = matches.first.id;
      } else {
        selectedCategory = categories.isNotEmpty ? categories.first.id : null;
      }
    } else if (categories.isNotEmpty) {
      selectedCategory = categories.first.id;
    }

    // Now load subcategories for the resolved selectedCategory
    if (selectedCategory != null) {
      final rawSub = await DatabaseHelper.instance.getSubCategories(categoryId: selectedCategory);
      subCategories = rawSub.map((map) => ProductCategory.fromMap({
        ...map,
        'parent_id': map['category_id'] ?? map['parent_id'], 
      })).toList();
    } else {
      subCategories = [];
    }

    if (selectedSubCategoryId != null) {
      final matches = subCategories.where((c) => c.id.toString() == selectedSubCategoryId.toString());
      if (matches.isNotEmpty) {
        selectedSubCategoryId = matches.first.id;
      } else {
        selectedSubCategoryId = null;
      }
    }
  }

  Future<void> _fetchBrands() async {
    final raw = await DatabaseHelper.instance.getBrands();
    brands = raw.map((map) => Brand.fromMap(map)).toList();
    
    if (selectedBrandId != null) {
      final matches = brands.where((b) => b.id.toString() == selectedBrandId.toString());
      if (matches.isEmpty) selectedBrandId = null;
    }
  }

  Future<void> _fetchUnits() async {
    List<Map<String, dynamic>> allUnits = await DatabaseHelper.instance.getAllUnitsWithBusiness();
    
    // FAIL-SAFE: If database is empty, auto-seed standard units locally
    if (allUnits.isEmpty) {
      if (kDebugMode) print('📦 [UI] Local units empty, auto-seeding standard units...');
      final standardUnits = [
        {'name': 'Piece', 'short_name': 'pc'},
        {'name' : 'Pack', 'short_name': 'pk'},
        {'name' : 'Box', 'short_name' : 'bx'},
        {'name' : 'Kilogram', 'short_name': 'kg'},
        {'name' : 'Gram', 'short_name' : 'g'},
        {'name' : 'Liter', 'short_name': 'L'},
        {'name' : 'Carton', 'short_name': 'ctn'},
        {'name' : 'Dozen', 'short_name': 'doz'},
        {'name' : 'Bag', 'short_name': 'bag'},
        {'name' : 'Bottle', 'short_name': 'btl'},
      ];

      for (var unit in standardUnits) {
        await DatabaseHelper.instance.insertUnit({
          ...unit,
          'status': 1,
        });
      }
      // Refresh after seeding
      await loadCategories();
      return;
    }

    final bid = BusinessConfig.instance.businessId;

    // Standardize: Create a unique-by-name list of units to show in the UI
    final Map<String, Map<String, dynamic>> uniqueUnitsMap = {};
    
    for (var u in allUnits) {
      final name = u['name'].toString().toLowerCase();
      final isLocal = u['business_id'].toString() == bid.toString();
      
      if (!uniqueUnitsMap.containsKey(name) || isLocal) {
        uniqueUnitsMap[name] = u;
      }
    }

    units = uniqueUnitsMap.values.toList()
      ..sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

    // [FIX] Auto-select units that belong to the current business
    // This solves the issue where units added during onboarding don't show up in the product dropdown.
    for (var u in units) {
      final unitBid = u['business_id']?.toString();
      if (unitBid != null && unitBid != 'null' && unitBid == bid?.toString()) {
        selectedUnitIds.add(u['id']);
      }
    }

    if (selectedUnitId != null) {
      final matches = units.where((u) => u['id'].toString() == selectedUnitId.toString());
      if (matches.isEmpty) {
        // If the specific ID is missing from the unique list, find by name instead
        final currentUnit = allUnits.firstWhere((u) => u['id'].toString() == selectedUnitId.toString(), orElse: () => {});
        if (currentUnit.isNotEmpty) {
           final nameMatch = units.where((u) => u['name'].toString().toLowerCase() == currentUnit['name'].toString().toLowerCase());
           if (nameMatch.isNotEmpty) selectedUnitId = nameMatch.first['id'];
        }
      }
    }
  }

  String getSelectedUnitName() {
    if (selectedUnitId == null) return 'No Unit';
    final unit = units.firstWhere((u) => u['id'] == selectedUnitId, orElse: () => {});
    return unit['name']?.toString() ?? 'No Unit';
  }

  Future<bool> addBrand(String name) async {
    try {
      final newId = await DatabaseHelper.instance.insertBrand({
        'name': name,
        'status': 1,
      });
      await _fetchBrands();
      selectedBrandId = newId;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add brand: $e';
      notifyListeners();
      return false;
    }
  }

  void setBrand(dynamic value) {
    selectedBrandId = value;
    notifyListeners();
  }

  void toggleUnit(dynamic unitId) {
    if (selectedUnitIds.contains(unitId)) {
      // Don't remove if it's the primary unit, unless there are others? 
      // Actually, just toggle it.
      selectedUnitIds.remove(unitId);
      if (selectedUnitId == unitId) {
        selectedUnitId = selectedUnitIds.isNotEmpty ? selectedUnitIds.first : null;
      }
    } else {
      selectedUnitIds.add(unitId);
      if (selectedUnitId == null) selectedUnitId = unitId;
    }
    _checkIfBoxUnit();
    notifyListeners();
  }

  Future<void> setUnit(dynamic value) async {
    if (value == null) {
      selectedUnitId = null;
      _checkIfBoxUnit();
      notifyListeners();
      return;
    }

    final unit = units.firstWhere((u) => u['id'].toString() == value.toString(), orElse: () => {});
    if (unit.isEmpty) return;

    final currentBid = BusinessConfig.instance.businessId;
    
    // If the unit belongs to another business, import it into the local business units
    if (unit['business_id'] != null && unit['business_id'].toString() != currentBid.toString()) {
      final existingLocalUnits = await DatabaseHelper.instance.getUnits();
      final existingMatch = existingLocalUnits.where((u) => 
        u['name'].toString().toLowerCase() == unit['name'].toString().toLowerCase()
      );
      
      if (existingMatch.isNotEmpty) {
        selectedUnitId = existingMatch.first['id'];
      } else {
        final newId = await DatabaseHelper.instance.insertUnit({
          'name': unit['name'],
          'short_name': unit['short_name'],
          'status': 1,
        });
        await _fetchUnits(); // Refresh the list to include the newly imported unit
        selectedUnitId = newId;
      }
    } else {
      selectedUnitId = value;
    }

    if (selectedUnitId != null) {
      selectedUnitIds.add(selectedUnitId);
    }

    _checkIfBoxUnit();
    notifyListeners();
  }

  Future<String?> validateBarcodeUnique(String? val) async {
    if (val == null || val.trim().isEmpty) return null;
    final exists = await DatabaseHelper.instance.checkBarcodeExists(val.trim());
    if (exists) {
      if (isEditMode) {
        final productWithBarcode = await DatabaseHelper.instance.getProductByBarcode(val.trim());
        if (productWithBarcode != null && productWithBarcode['id'].toString() != initialProduct!.id.toString()) {
          return 'Barcode already assigned to: ${productWithBarcode['name']}';
        }
      } else {
        final productWithBarcode = await DatabaseHelper.instance.getProductByBarcode(val.trim());
        return 'Barcode already assigned to: ${productWithBarcode != null ? productWithBarcode['name'] : 'another product'}';
      }
    }
    return null;
  }

  String? barcodeValidationError;

  Future<void> checkBarcodeUniqueness(String val) async {
    if (val.trim().isEmpty) {
      barcodeValidationError = null;
      notifyListeners();
      return;
    }
    
    final exists = await DatabaseHelper.instance.checkBarcodeExists(val.trim());
    if (exists) {
      if (isEditMode) {
        final productWithBarcode = await DatabaseHelper.instance.getProductByBarcode(val.trim());
        if (productWithBarcode != null && productWithBarcode['id'].toString() != initialProduct!.id.toString()) {
          barcodeValidationError = 'Assigned to: ${productWithBarcode['name']}';
        } else {
          barcodeValidationError = null;
        }
      } else {
        final productWithBarcode = await DatabaseHelper.instance.getProductByBarcode(val.trim());
        barcodeValidationError = 'Assigned to: ${productWithBarcode != null ? productWithBarcode['name'] : 'another product'}';
      }
    } else {
      barcodeValidationError = null;
    }
    notifyListeners();
  }

  Future<void> generateUniqueBarcode() async {
    final random = Random();
    String newBarcode = '';
    bool exists = true;

    // Try up to 100 times to find a unique 13-digit barcode
    for (int i = 0; i < 100; i++) {
      newBarcode = '';
      for (int j = 0; j < 13; j++) {
        newBarcode += random.nextInt(10).toString();
      }
      
      exists = await DatabaseHelper.instance.checkBarcodeExists(newBarcode);
      if (!exists) break;
    }

    if (!exists) {
      barcode.text = newBarcode;
      barcodeValidationError = null;
      notifyListeners();
    }
  }


  Future<bool> addCategory(String name, {dynamic parentId}) async {
    if (kDebugMode) print('➕ [CONTROLLER] addCategory: name=$name, parentId=$parentId');
    try {
      int newId;
      if (parentId == null) {
        newId = await DatabaseHelper.instance.insertCategory({
          'business_id': BusinessConfig.instance.businessId!,
          'name': name,
          'status': 1,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        newId = await DatabaseHelper.instance.insertSubCategory({
          'business_id': BusinessConfig.instance.businessId!,
          'category_id': parentId,
          'name': name,
          'status': 1,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      if (kDebugMode) print('✅ [CONTROLLER] Category/Sub added with ID: $newId');

      if (parentId == null) {
        final newCat = ProductCategory(
          id: newId,
          businessId: BusinessConfig.instance.businessId!,
          name: name,
          parentId: null,
          status: 1,
        );
        categories.add(newCat);
        selectedCategory = newCat.id;
        subCategories = []; // Reset subcategories when parent changes
        selectedSubCategoryId = null;
      } else {
        if (kDebugMode) print('📂 [CONTROLLER] Reloading subcategories for new ID: $newId under parent: $parentId');
        await reloadSubCategories(selectId: newId, forCategoryId: parentId);
      }
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ [CONTROLLER] Failed to add category: $e');
      _errorMessage = 'Failed to add category: $e';
      notifyListeners();
      return false;
    }
  }

  void setCategory(dynamic value) async {
    if (kDebugMode) print('🔄 [CONTROLLER] setCategory: $value');
    selectedCategory = value;
    selectedSubCategoryId = null; // Reset subcategory when parent changes
    
    // Refresh subcategories for the new parent
    final rawSub = await DatabaseHelper.instance.getSubCategories(categoryId: value);
    if (kDebugMode) print('   - Loaded ${rawSub.length} subcategories for category $value');

    subCategories = rawSub.map((map) => ProductCategory.fromMap({
      ...map,
      'parent_id': map['category_id'] ?? map['parent_id'],
    })).toList();
    
    notifyListeners();
  }

  void setSubCategory(dynamic value) {
    selectedSubCategoryId = value;
    notifyListeners();
  }

  /// Reloads only the subcategories for the current [selectedCategory].
  /// Optionally auto-selects [selectId] after reload (e.g. the newly created subcategory).
  Future<void> reloadSubCategories({dynamic selectId, dynamic forCategoryId}) async {
    // Use the explicitly-provided category ID, falling back to the current selection.
    final catId = forCategoryId ?? selectedCategory;
    if (catId == null) return;
    final rawSub = await DatabaseHelper.instance.getSubCategories(categoryId: catId);
    subCategories = rawSub.map((map) => ProductCategory.fromMap({
      ...map,
      'parent_id': map['category_id'] ?? map['parent_id'],
    })).toList();
    if (selectId != null) {
      final match = subCategories.where((c) => c.id.toString() == selectId.toString());
      selectedSubCategoryId = match.isNotEmpty ? match.first.id : selectedSubCategoryId;
    }
    notifyListeners();
  }

  void toggleFavorite(bool value) {
    isFavorite = value;
    notifyListeners();
  }

  void toggleStatus(bool active) {
    status = active ? 1 : 0;
    notifyListeners();
  }

  void setBranch(dynamic value) {
    selectedBranchId = value;
    notifyListeners();
  }

  Future<Map<String, dynamic>> saveProduct() async {
    _errorMessage = null;
    notifyListeners();

    final nameVal = name.text.trim();
    if (nameVal.isEmpty) {
      _errorMessage = 'Product name is required';
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
    }

    final priceVal = double.tryParse(price.text) ?? 0.0;
    final purchaseVal = double.tryParse(purchasePrice.text) ?? 0.0;
    final wholesaleVal = double.tryParse(wholesalePrice.text) ?? 0.0;
    final stockVal = double.tryParse(stock.text) ?? 0.0;
    final pieces = double.tryParse(piecesPerBox.text) ?? 1.0;
    
    // If box unit, multiply stock by pieces, and handle nullable price per piece if box price is set
    double effectiveStock = isBoxUnit ? (stockVal * pieces) : stockVal;
    double effectivePrice = priceVal;
    double effectivePurchase = purchaseVal;
    
    double effectiveWholesale = wholesaleVal;
    
    if (isBoxUnit) {
      final boxPr = double.tryParse(boxPrice.text) ?? 0.0;
      final boxPur = double.tryParse(boxPurchasePrice.text) ?? 0.0;
      final boxWh = double.tryParse(boxWholesalePrice.text) ?? 0.0;
      effectivePrice = pieces > 0 ? (boxPr / pieces) : boxPr;
      effectivePurchase = pieces > 0 ? (boxPur / pieces) : boxPur;
      effectiveWholesale = pieces > 0 ? (boxWh / pieces) : boxWh;
    }

    final limitVal = int.tryParse(stockLimit.text) ?? 5;
    final discountLimitVal = double.tryParse(discountLimit.text) ?? 0.0;
    final barcodeVal = barcode.text.trim().isEmpty ? null : barcode.text.trim();

    if (barcodeVal != null) {
      final barcodeExists = await DatabaseHelper.instance.checkBarcodeExists(barcodeVal);
      if (barcodeExists) {
        // If editing, check if the barcode belongs to the current product
        if (isEditMode) {
          final productWithBarcode = await DatabaseHelper.instance.getProductByBarcode(barcodeVal);
          if (productWithBarcode != null && productWithBarcode['id'].toString() != initialProduct!.id.toString()) {
            _errorMessage = 'This barcode is already assigned to another product: ${productWithBarcode['name']}';
            notifyListeners();
            return {'success': false, 'message': _errorMessage};
          }
        } else {
          final productWithBarcode = await DatabaseHelper.instance.getProductByBarcode(barcodeVal);
          _errorMessage = 'This barcode is already assigned to another product${productWithBarcode != null ? ': ' + productWithBarcode['name'] : ''}';
          notifyListeners();
          return {'success': false, 'message': _errorMessage};
        }
      }
    }

    final productId = isEditMode ? initialProduct!.id : null;

    // [SUBSCRIPTION CHECK] Verify limits before saving new product
    if (!isEditMode) {
      final currentCount = await DatabaseHelper.instance.getProductCount();
      final canAdd = await BusinessConfig.instance.canAddProduct(currentCount);
      if (!canAdd) {
        final plan = BusinessConfig.instance.subscriptionPlanName;
        final max = BusinessConfig.instance.maxProducts;
        final status = BusinessConfig.instance.subscriptionStatus;

        if (status != 'active') {
          _errorMessage = 'Your subscription is $status. Please renew to add products.';
        } else {
          _errorMessage = 'You have reached the limit of $max products for your $plan plan. Please upgrade to add more.';
        }
        notifyListeners();
        return {'success': false, 'message': _errorMessage};
      }
    }

    final productMap = {
      'id': productId,
      'business_id': BusinessConfig.instance.businessId,
      'branch_id': selectedBranchId ?? BusinessConfig.instance.branchId,
      'category_id': selectedCategory,
      'sub_category_id': selectedSubCategoryId,
      'brand_id': selectedBrandId,
      'unit_id': selectedUnitId,
      'name': nameVal,
      'barcode': barcodeVal,
      'price': effectivePrice,
      'purchase_price': effectivePurchase,
      'wholesale_price': effectiveWholesale,
      'stock_quantity': effectiveStock,
      'stock_limit': limitVal,
      'discount_limit': discountLimitVal,
      'discount_limit_type': discountLimitType,
      'pieces_per_pack': isBoxUnit ? piecesPerBox.text : null,
      'packing': isBoxUnit ? stock.text : null,
      'description': description.text.trim(),
      'image': initialProduct?.image ?? 'box',
      'status': status,
      'is_favorite': isFavorite ? 1 : 0,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await DatabaseHelper.instance.insertProduct(productMap);

      return {
        'success': true,
        'message': saveSuccessMessage,
      };
    } catch (e) {
      _errorMessage = 'Error saving product: $e';
      notifyListeners();
      return {
        'success': false,
        'message': _errorMessage,
      };
    }
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    name.dispose();

    barcode.dispose();
    price.dispose();
    purchasePrice.dispose();
    wholesalePrice.dispose();
    stock.dispose();
    stockLimit.dispose();
    discountLimit.dispose();
    description.dispose();
    piecesPerBox.dispose();
    boxPrice.dispose();
    boxPurchasePrice.dispose();
    boxWholesalePrice.dispose();
    super.dispose();
  }
}
