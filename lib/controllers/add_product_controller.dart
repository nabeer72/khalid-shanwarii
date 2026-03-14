import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/models/product.dart';
import 'package:uuid/uuid.dart';
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
  late TextEditingController image;

  // State
  String? selectedCategory;
  List<ProductCategory> categories = [];
  bool isFavorite = false;
  int status = 1;
  bool _isLoading = true;
  List<Branch> branches = [];
  String? selectedBranchId;

  String? _errorMessage;

  AddProductController({this.initialProduct}) {
    name = TextEditingController(text: initialProduct?.name ?? '');
    barcode = TextEditingController(text: initialProduct?.barcode ?? '');
    price = TextEditingController(text: initialProduct?.price.toString() ?? '');
    purchasePrice = TextEditingController(text: initialProduct?.purchasePrice.toString() ?? '');
    wholesalePrice = TextEditingController(text: initialProduct?.wholesalePrice.toString() ?? '');
    stock = TextEditingController(text: initialProduct?.stockQuantity.toString() ?? '');
    stockLimit = TextEditingController(text: (initialProduct?.stockLimit ?? 5).toString());
    discountLimit = TextEditingController(text: initialProduct?.discountLimit?.toString() ?? '');
    description = TextEditingController(text: initialProduct?.description ?? '');
    image = TextEditingController(text: initialProduct?.image ?? '');

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
      categories = raw.map((map) => ProductCategory.fromMap(map)).toList();

      // Auto-select logic (same as original)
      if (selectedCategory == null && categories.isNotEmpty) {
        selectedCategory = categories.first.id;
      }
    } catch (e) {
      _errorMessage = 'Failed to load categories: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadBranches() async {
    try {
      final raw = await DatabaseHelper.instance.getBranches();
      branches = raw.map((map) => Branch.fromMap(map)).toList();
      
      // Ensure we have a selection if none exists
      if (selectedBranchId == null && branches.isNotEmpty) {
        selectedBranchId = branches.first.id;
      }
    } catch (e) {
      print('Error loading branches in controller: $e');
    }
  }

  Future<bool> addCategory(String name) async {
    try {
      final newCat = ProductCategory(
        id: const Uuid().v4(),
        businessId: BusinessConfig.instance.businessId!,
        name: name,
        status: 1,
      );

      await DatabaseHelper.instance.insertCategory({
        'id': newCat.id,
        'business_id': newCat.businessId,
        'name': newCat.name,
        'status': newCat.status,
        'updated_at': DateTime.now().toIso8601String(),
      });

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

  void setCategory(String? value) {
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

  void setBranch(String? value) {
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

    final productId = isEditMode ? initialProduct!.id : const Uuid().v4();

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
      'image': image.text.trim(),
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
    image.dispose();
    super.dispose();
  }
}