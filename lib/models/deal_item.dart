class DealItem {
  final int id;
  final int dealId;
  final int productId;
  final double quantity;
  final double unitPrice; // the normal selling price of the product when added to deal
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // UI Convenience fields (joined from products table)
  final String? productName;
  final double? productPrice;
  final String? barcode;
  final double? currentStock;

  DealItem({
    required this.id,
    required this.dealId,
    required this.productId,
    this.quantity = 1,
    this.unitPrice = 0.0,
    this.createdAt,
    this.updatedAt,
    this.productName,
    this.productPrice,
    this.barcode,
    this.currentStock,
  });

  factory DealItem.fromMap(Map<String, dynamic> map) {
    return DealItem(
      id: (map['id'] as num?)?.toInt() ?? 0,
      dealId: (map['deal_id'] as num?)?.toInt() ?? 0,
      productId: (map['product_id'] as num?)?.toInt() ?? 0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
      productName: (map['product_name'] as String?)?.trim().isNotEmpty == true
          ? map['product_name'] as String
          : 'Product #${(map['product_id'] as num?)?.toInt() ?? 0}',
      productPrice: (map['product_price'] as num?)?.toDouble(),
      barcode: (map['barcode'] as String?),
      currentStock: (map['current_stock'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id == 0 ? null : id,
      'deal_id': dealId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
