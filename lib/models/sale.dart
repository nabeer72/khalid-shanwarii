class Sale {
  final String id;
  final String businessId;
  final String userId;
  final double grandTotal;
  final int status;
  final int isSynced;

  Sale({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.grandTotal,
    this.status = 1,
    this.isSynced = 0,
  });

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
  final String id;
  final String saleId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double subTotal;

  SaleDetail({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.subTotal,
  });

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
