class Sale {
  final int? id;
  final int businessId;
  final int userId;
  final double grandTotal;
  final int status;
  final int isSynced;

  Sale({
    this.id,
    required this.businessId,
    required this.userId,
    required this.grandTotal,
    this.status = 1,
    this.isSynced = 0,
  });

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      businessId: map['business_id'] is int ? map['business_id'] : int.tryParse(map['business_id']?.toString() ?? '') ?? 0,
      userId: map['user_id'] is int ? map['user_id'] : int.tryParse(map['user_id']?.toString() ?? '') ?? 0,
      grandTotal: (map['grand_total'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 1,
      isSynced: map['is_synced'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'user_id': userId,
      'grand_total': grandTotal,
      'status': status,
      'is_synced': isSynced,
    };
  }
}

class SaleDetail {
  final int? id;
  final int saleId;
  final int productId;
  final int quantity;
  final double unitPrice;
  final double subTotal;

  SaleDetail({
    this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.subTotal,
  });

  factory SaleDetail.fromMap(Map<String, dynamic> map) {
    return SaleDetail(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      saleId: map['sale_id'] is int ? map['sale_id'] : int.tryParse(map['sale_id']?.toString() ?? '') ?? 0,
      productId: map['product_id'] is int ? map['product_id'] : int.tryParse(map['product_id']?.toString() ?? '') ?? 0,
      quantity: (map['quantity'] ?? 0).toInt(),
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      subTotal: (map['sub_total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'sub_total': subTotal,
    };
  }
}
