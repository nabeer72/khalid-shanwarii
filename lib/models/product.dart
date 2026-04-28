import 'stock.dart';
import 'package:mobile_app/db/mock_data.dart';

class Product {
  final dynamic id;
  final dynamic businessId;
  final dynamic userId;
  final dynamic branchId;
  final dynamic categoryId;
  final dynamic subCategoryId;
  final dynamic brandId;
  final String name;
  final String? image;
  final String? description;
  final int status;
  bool isFavorite;
  final int stockLimit;
  final double discountLimit;
  final String discountLimitType;
  final String? updatedAt;
  final String? deletedAt;
  final dynamic unitId;
  
  // Batches/Stocks
  final List<Stock> stocks;

  Product({
    this.id,
    required this.businessId,
    this.userId,
    this.branchId,
    this.categoryId,
    this.subCategoryId,
    this.brandId,
    required this.name,
    this.image,
    this.description,
    this.status = 1,
    this.isFavorite = false,
    this.stockLimit = 5,
    this.discountLimit = 0,
    this.discountLimitType = 'percentage',
    this.updatedAt,
    this.deletedAt,
    this.unitId,
    this.stocks = const [],
  });

  factory Product.fromMap(Map<String, dynamic> map, {List<Stock> stocks = const []}) {
    return Product(
      id: map['id'],
      businessId: map['business_id'],
      userId: map['user_id'],
      branchId: map['branch_id'],
      categoryId: map['category_id'] ?? map['categoryId'],
      subCategoryId: map['sub_category_id'],
      brandId: map['brand_id'],
      name: map['name'] ?? '',
      image: map['image'],
      description: map['description'],
      status: map['status'] ?? 1,
      isFavorite: (map['is_favorite'] ?? 0) == 1,
      stockLimit: map['stock_limit'] ?? 5,
      discountLimit: (map['discount_limit'] ?? 0).toDouble(),
      discountLimitType: map['discount_limit_type'] ?? 'percentage',
      updatedAt: map['updated_at'],
      deletedAt: map['deleted_at'],
      unitId: map['unit_id'],
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
      'image': image,
      'description': description,
      'status': status,
      'is_favorite': isFavorite ? 1 : 0,
      'stock_limit': stockLimit,
      'discount_limit': discountLimit,
      'discount_limit_type': discountLimitType,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
      'unit_id': unitId,
    };
  }

  // Computed properties for UI convenience
  double get totalStock => stocks.fold(0.0, (sum, s) => sum + s.quantity);
  
  double get minPrice => stocks.isEmpty ? 0.0 : stocks.map((s) => s.salePrice).reduce((a, b) => a < b ? a : b);
  double get maxPrice => stocks.isEmpty ? 0.0 : stocks.map((s) => s.salePrice).reduce((a, b) => a > b ? a : b);
  
  String get priceRange {
    final config = BusinessConfig.instance;
    if (stocks.isEmpty) return config.formatAmount(0);
    if (minPrice == maxPrice) return config.formatAmount(minPrice);
    return '${config.formatAmount(minPrice)} - ${config.formatAmount(maxPrice)}';
  }

  String? get latestBarcode => (stocks.isNotEmpty) ? (latestStock?.barcode) : null;

  double get latestPrice => (stocks.isNotEmpty) ? (latestStock?.salePrice ?? 0.0) : 0.0;
  double get latestPurchasePrice => (stocks.isNotEmpty) ? (latestStock?.costPrice ?? 0.0) : 0.0;
  double get latestWholesalePrice => (stocks.isNotEmpty) ? (latestStock?.wholesalePrice ?? 0.0) : 0.0;
  double get latestStockQuantity => totalStock;

  // Get the "primary" or "latest" stock (e.g. for default selection)
  Stock? get latestStock => stocks.isNotEmpty ? stocks.last : null;
}

class ProductCategory {
  final dynamic id;
  final dynamic businessId;
  final dynamic userId;
  final String name;
  final String? icon;
  final dynamic parentId;
  final int status;
  final int isSynced;

  ProductCategory({
    this.id,
    required this.businessId,
    this.userId,
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
      userId: map['user_id'],
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
      'user_id': userId,
      'name': name,
      'icon': icon,
      'parent_id': parentId,
      'status': status,
      'is_synced': isSynced,
    };
  }
}
