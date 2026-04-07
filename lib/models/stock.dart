class Stock {
  final dynamic id;
  final dynamic businessId;
  final dynamic userId;
  final dynamic productId;
  final String? barcode;
  final String? manufactureDate;
  final String? expireDate;
  final double quantity;
  final String? packing;
  final String? piecesPerPack;
  final double costPrice;
  final double salePrice;
  final double wholesalePrice;
  final double alertQuantity;
  final String? alertStatus;
  final double discount;
  final double discountLimit;
  final double tax;
  final String? tradeOff;
  final double carryExpense;
  final int status;
  final int isSynced;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  Stock({
    this.id,
    this.businessId,
    this.userId,
    required this.productId,
    this.barcode,
    this.manufactureDate,
    this.expireDate,
    this.quantity = 0,
    this.packing,
    this.piecesPerPack,
    this.costPrice = 0,
    this.salePrice = 0,
    this.wholesalePrice = 0,
    this.alertQuantity = 0,
    this.alertStatus,
    this.discount = 0,
    this.discountLimit = 0,
    this.tax = 0,
    this.tradeOff,
    this.carryExpense = 0,
    this.status = 1,
    this.isSynced = 0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory Stock.fromMap(Map<String, dynamic> map) {
    return Stock(
      id: map['id'],
      businessId: map['business_id'],
      userId: map['user_id'],
      productId: map['product_id'],
      barcode: map['barcode'],
      manufactureDate: map['manufacture_date'],
      expireDate: map['expire_date'],
      quantity: (map['quantity'] ?? 0).toDouble(),
      packing: map['packing'],
      piecesPerPack: map['pieces_per_pack'],
      costPrice: (map['cost_price'] ?? 0).toDouble(),
      salePrice: (map['sale_price'] ?? 0).toDouble(),
      wholesalePrice: (map['wholesale_price'] ?? map['whole_sale_price'] ?? 0).toDouble(),
      alertQuantity: (map['alert_quantity'] ?? 0).toDouble(),
      alertStatus: map['alert_status'],
      discount: (map['discount'] ?? 0).toDouble(),
      discountLimit: (map['discount_limit'] ?? 0).toDouble(),
      tax: (map['tax'] ?? 0).toDouble(),
      tradeOff: map['trade_off'],
      carryExpense: (map['carry_expense'] ?? 0).toDouble(),
      status: map['status'] ?? 1,
      isSynced: map['is_synced'] ?? 0,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      deletedAt: map['deleted_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'user_id': userId,
      'product_id': productId,
      'barcode': barcode,
      'manufacture_date': manufactureDate,
      'expire_date': expireDate,
      'quantity': quantity,
      'packing': packing,
      'pieces_per_pack': piecesPerPack,
      'cost_price': costPrice,
      'sale_price': salePrice,
      'wholesale_price': wholesalePrice,
      'alert_quantity': alertQuantity,
      'alert_status': alertStatus,
      'discount': discount,
      'discount_limit': discountLimit,
      'tax': tax,
      'trade_off': tradeOff,
      'carry_expense': carryExpense,
      'status': status,
      'is_synced': isSynced,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  Stock copyWith({
    double? quantity,
  }) {
    return Stock(
      id: id,
      businessId: businessId,
      userId: userId,
      productId: productId,
      barcode: barcode,
      manufactureDate: manufactureDate,
      expireDate: expireDate,
      quantity: quantity ?? this.quantity,
      packing: packing,
      piecesPerPack: piecesPerPack,
      costPrice: costPrice,
      salePrice: salePrice,
      wholesalePrice: wholesalePrice,
      alertQuantity: alertQuantity,
      alertStatus: alertStatus,
      discount: discount,
      discountLimit: discountLimit,
      tax: tax,
      tradeOff: tradeOff,
      carryExpense: carryExpense,
      status: status,
      isSynced: isSynced,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }
}
