import 'stock.dart';
import 'package:mobile_app/db/mock_data.dart';

class Product {
  final dynamic id;
  final dynamic businessId;
  final dynamic userId;
  final dynamic branchId;
  final dynamic category_id; 
  final dynamic categoryId;
  final dynamic subCategoryId;
  final dynamic brandId;
  final String name;
  final String? stockType;
  final String? image;
  final String? description;
  final int status;
  bool isFavorite;
  final String? barcode;
  final int stockLimit;
  final double? discountLimit;
  final String? updatedAt;
  final String? deletedAt;
  
  // Denormalized fields for immediate UI visibility
  final double price;
  final double purchasePrice;
  final double wholesalePrice;
  final double stockQuantity;

  // Weights (if applicable)
  final bool isPricePerWeight;
  final String? weightUnit;

  // Batches/Stocks
  final List<Stock> stocks;

  Product({
    this.id,
    required this.businessId,
    this.userId,
    this.branchId,
    this.categoryId,
    this.category_id,
    this.subCategoryId,
    this.brandId,
    required this.name,
    this.stockType,
    this.image,
    this.description,
    this.status = 1,
    this.isFavorite = false,
    this.barcode,
    this.stockLimit = 5,
    this.discountLimit,
    this.updatedAt,
    this.deletedAt,
    this.isPricePerWeight = false,
    this.weightUnit,
    this.price = 0,
    this.purchasePrice = 0,
    this.wholesalePrice = 0,
    this.stockQuantity = 0,
    this.stocks = const [],
  });

  factory Product.fromMap(Map<String, dynamic> map, {List<Stock> stocks = const []}) {
    return Product(
      id: map['id'],
      businessId: map['business_id'],
      userId: map['user_id'],
      branchId: map['branch_id'],
      categoryId: map['category_id'],
      category_id: map['category_id'],
      subCategoryId: map['sub_category_id'],
      brandId: map['brand_id'],
      name: map['name'] ?? '',
      stockType: map['stock_type'],
      image: map['image'],
      description: map['description'],
      status: map['status'] ?? 1,
      isFavorite: (map['is_favorite'] ?? 0) == 1,
      isPricePerWeight: (map['is_price_per_weight'] ?? 0) == 1,
      weightUnit: map['weight_unit'],
      barcode: map['barcode'],
      stockLimit: map['stock_limit'] ?? 5,
      discountLimit: (map['discount_limit'] as num?)?.toDouble(),
      updatedAt: map['updated_at'],
      deletedAt: map['deleted_at'],
      price: (map['price'] ?? 0).toDouble(),
      purchasePrice: (map['purchase_price'] ?? 0).toDouble(),
      wholesalePrice: (map['wholesale_price'] ?? 0).toDouble(),
      stockQuantity: (map['stock_quantity'] ?? 0).toDouble(),
      stocks: stocks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'user_id': userId,
      'branch_id': branchId,
      'category_id': categoryId,
      'sub_category_id': subCategoryId,
      'brand_id': brandId,
      'name': name,
      'stock_type': stockType,
      'image': image,
      'description': description,
      'status': status,
      'is_favorite': isFavorite ? 1 : 0,
      'is_price_per_weight': isPricePerWeight ? 1 : 0,
      'weight_unit': weightUnit,
      'barcode': barcode,
      'stock_limit': stockLimit,
      'discount_limit': discountLimit,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
      'price': price,
      'purchase_price': purchasePrice,
      'wholesale_price': wholesalePrice,
      'stock_quantity': stockQuantity,
    };
  }

  // Computed properties for UI convenience
  double get totalStock => stocks.isNotEmpty ? stocks.fold(0.0, (sum, s) => sum + s.quantity) : stockQuantity;
  
  double get minPrice => stocks.isEmpty ? price : stocks.map((s) => s.salePrice).reduce((a, b) => a < b ? a : b);
  double get maxPrice => stocks.isEmpty ? price : stocks.map((s) => s.salePrice).reduce((a, b) => a > b ? a : b);
  
  String get priceRange {
    if (stocks.isEmpty) return 'N/A';
    final config = BusinessConfig.instance;
    if (minPrice == maxPrice) return config.formatAmount(minPrice);
    return '${config.formatAmount(minPrice)} - ${config.formatAmount(maxPrice)}';
  }

  // Getters for legacy/controller compatibility (prefer denormalized fields)
  double get latestPrice => price != 0 ? price : (latestStock?.salePrice ?? 0.0);
  double get latestPurchasePrice => purchasePrice != 0 ? purchasePrice : (latestStock?.costPrice ?? 0.0);
  double get latestWholesalePrice => wholesalePrice != 0 ? wholesalePrice : (latestStock?.wholesalePrice ?? 0.0);
  double get latestStockQuantity => stockQuantity != 0 ? stockQuantity : totalStock;

  // Get the "primary" or "latest" stock (e.g. for default selection)
  Stock? get latestStock => stocks.isNotEmpty ? stocks.last : null;
}

class ProductCategory {
  final dynamic id;
  final dynamic businessId;
  final String name;
  final String? icon;
  final dynamic parentId;
  final int status;
  final int isSynced;

  ProductCategory({
    this.id,
    required this.businessId,
    required this.name,
    this.icon,
    this.parentId,
    this.status = 1,
    this.isSynced = 1,
  });

  factory ProductCategory.fromMap(Map<String, dynamic> map) {
    return ProductCategory(
      id: map['id'],
      businessId: map['business_id'],
      name: map['name'] ?? '',
      icon: map['icon'],
      parentId: map['parent_id'],
      status: map['status'] ?? 1,
      isSynced: map['is_synced'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'icon': icon,
      'parent_id': parentId,
      'status': status,
      'is_synced': isSynced,
    };
  }
}
