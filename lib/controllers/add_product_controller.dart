import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/branch.dart';

class AddProductController with ChangeNotifier {
  final Product? initialProduct;

  // Controllers
  late TextEditingController name;
  late TextEditingController barcode;
  late TextEditingController price;
  late TextEditingController purchasePrice;
  late TextEditingController wholesalePrice;
  late TextEditingController stock;
  late TextEditingController stockLimit;
  late TextEditingController discountLimit;
  late TextEditingController description;

  // State
  dynamic selectedCategory;
  List<ProductCategory> categories = [];
  bool isFavorite = false;
  int status = 1;
  bool _isLoading = true;
  List<Branch> branches = [];
  dynamic selectedBranchId;

  String? _errorMessage;

  AddProductController({this.initialProduct}) {
    name = TextEditingController(text: initialProduct?.name ?? '');
    barcode = TextEditingController(text: initialProduct?.barcode ?? '');
    price = TextEditingController(text: initialProduct?.latestPrice.toString() ?? '');
    purchasePrice = TextEditingController(text: initialProduct?.latestPurchasePrice.toString() ?? '');
    wholesalePrice = TextEditingController(text: initialProduct?.latestWholesalePrice.toString() ?? '');
    stock = TextEditingController(text: initialProduct?.latestStockQuantity.toString() ?? '');
    stockLimit = TextEditingController(text: (initialProduct?.stockLimit ?? 5).toString());
    discountLimit = TextEditingController(text: initialProduct?.discountLimit?.toString() ?? '');
    description = TextEditingController(text: initialProduct?.description ?? '');

    selectedCategory = initialProduct?.categoryId;
    isFavorite = initialProduct?.isFavorite ?? false;
    status = initialProduct?.status ?? 1;
    selectedBranchId = initialProduct?.branchId ?? BusinessConfig.instance.branchId;
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEditMode => initialProduct != null;

  String get screenTitle => isEditMode ? 'Edit Product' : 'Add New Product';
  String get saveSuccessMessage => '${name.text.trim()} saved successfully!';

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      final raw = await DatabaseHelper.instance.getCategories();
      final allCats = raw.map((map) => ProductCategory.fromMap(map)).toList();
      
      // Deduplicate by ID to prevent Dropdown crash
      final seenIds = <dynamic>{};
      categories = [];
      for (var c in allCats) {
        if (c.id != null && !seenIds.contains(c.id)) {
          categories.add(c);
          seenIds.add(c.id);
        }
      }

      // Normalize selectedCategory to match type in the list
      if (selectedCategory != null) {
        final matches = categories.where((c) => c.id.toString() == selectedCategory.toString());
        if (matches.isNotEmpty) {
          selectedCategory = matches.first.id;
        } else {
          // If no match found, fallback to first category if available, otherwise null
          selectedCategory = categories.isNotEmpty ? categories.first.id : null;
        }
      } else if (categories.isNotEmpty) {
        selectedCategory = categories.first.id;
      }
    } catch (e) {
      _errorMessage = 'Failed to load categories: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<bool> addCategory(String name) async {
    try {
      final newId = await DatabaseHelper.instance.insertCategory({
        'business_id': BusinessConfig.instance.businessId!,
        'name': name,
        'status': 1,
        'updated_at': DateTime.now().toIso8601String(),
      });

      final newCat = ProductCategory(
        id: newId,
        businessId: BusinessConfig.instance.businessId!,
        name: name,
        status: 1,
      );

      categories.add(newCat);
      selectedCategory = newCat.id;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add category: $e';
      notifyListeners();
      return false;
    }
  }

  void setCategory(dynamic value) {
    selectedCategory = value;
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
    final limitVal = int.tryParse(stockLimit.text) ?? 5;
    final discountLimitVal = double.tryParse(discountLimit.text);
    final barcodeVal = barcode.text.trim().isEmpty ? null : barcode.text.trim();

    final productId = isEditMode ? initialProduct!.id : null;

    // Prepare map for DatabaseHelper.insertProduct
    // This map includes both metadata and the initial stock batch data
    final productMap = {
      'id': productId,
      'business_id': BusinessConfig.instance.businessId,
      'branch_id': selectedBranchId ?? BusinessConfig.instance.branchId,
      'category_id': selectedCategory,
      'name': nameVal,
      'barcode': barcodeVal,
      'price': priceVal,
      'purchase_price': purchaseVal,
      'wholesale_price': wholesaleVal,
      'stock_quantity': stockVal,
      'stock_limit': limitVal,
      'discount_limit': discountLimitVal,
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
    name.dispose();
    barcode.dispose();
    price.dispose();
    purchasePrice.dispose();
    wholesalePrice.dispose();
    stock.dispose();
    stockLimit.dispose();
    discountLimit.dispose();
    description.dispose();
    super.dispose();
  }
}
