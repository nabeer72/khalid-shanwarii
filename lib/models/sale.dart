class Sale {
  final int? id;
  final int businessId;
  final int? branchId;
  final int? userId;
  final int? customerId;
  final int staffId;
  final double subTotal;
  final double tax;
  final double discount;
  final double total;
  final String paymentMethod;
  final int isReturn;
  final double totalTip;
  final int status;
  final int isSynced;
  final int? shiftId;
  final String? createdAt;
  final String? updatedAt;

  Sale({
    this.id,
    required this.businessId,
    this.branchId,
    this.userId,
    this.customerId,
    required this.staffId,
    this.subTotal = 0.0,
    this.tax = 0.0,
    this.discount = 0.0,
    this.total = 0.0,
    this.paymentMethod = 'cash',
    this.isReturn = 0,
    this.totalTip = 0.0,
    this.status = 1,
    this.isSynced = 0,
    this.shiftId,
    this.createdAt,
    this.updatedAt,
  });

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      businessId: map['business_id'] is int ? map['business_id'] : int.tryParse(map['business_id']?.toString() ?? '') ?? 0,
      branchId: map['branch_id'] is int ? map['branch_id'] : int.tryParse(map['branch_id']?.toString() ?? ''),
      userId: map['user_id'] is int ? map['user_id'] : int.tryParse(map['user_id']?.toString() ?? ''),
      customerId: map['customer_id'] is int ? map['customer_id'] : int.tryParse(map['customer_id']?.toString() ?? ''),
      staffId: map['staff_id'] is int ? map['staff_id'] : int.tryParse(map['staff_id']?.toString() ?? '') ?? 0,
      subTotal: (map['sub_total'] as num?)?.toDouble() ?? (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? (map['grand_total'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method']?.toString() ?? 'cash',
      isReturn: (map['is_return'] as num?)?.toInt() ?? 0,
      totalTip: (map['total_tip'] as num?)?.toDouble() ?? (map['tip'] as num?)?.toDouble() ?? 0.0,
      status: (map['status'] as num?)?.toInt() ?? 1,
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 0,
      shiftId: map['shift_id'] is int ? map['shift_id'] : int.tryParse(map['shift_id']?.toString() ?? ''),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'branch_id': branchId,
      'user_id': userId,
      'customer_id': customerId,
      'staff_id': staffId,
      'sub_total': subTotal,
      'tax': tax,
      'discount': discount,
      'total': total,
      'payment_method': paymentMethod,
      'is_return': isReturn,
      'total_tip': totalTip,
      'status': status,
      'is_synced': isSynced,
      'shift_id': shiftId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class SaleDetail {
  final int? saleId;
  final int? productId;
  final int? stockId;
  final double quantity;
  final double price;
  final double subTotal;
  final double discount;
  final int? businessId;
  final int? userId;
  final int? branchId;

  SaleDetail({
    this.id,
    this.saleId,
    this.productId,
    this.stockId,
    required this.quantity,
    required this.price,
    required this.subTotal,
    this.discount = 0.0,
    this.businessId,
    this.userId,
    this.branchId,
  });

  factory SaleDetail.fromMap(Map<String, dynamic> map) {
    return SaleDetail(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      saleId: map['sale_id'] is int ? map['sale_id'] : int.tryParse(map['sale_id']?.toString() ?? '') ?? 0,
      productId: map['product_id'] is int ? map['product_id'] : int.tryParse(map['product_id']?.toString() ?? ''),
      stockId: map['stock_id'] is int ? map['stock_id'] : int.tryParse(map['stock_id']?.toString() ?? ''),
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      price: (map['price'] as num?)?.toDouble() ?? (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      subTotal: (map['sub_total'] as num?)?.toDouble() ?? (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      businessId: map['business_id'] is int ? map['business_id'] : int.tryParse(map['business_id']?.toString() ?? ''),
      userId: map['user_id'] is int ? map['user_id'] : int.tryParse(map['user_id']?.toString() ?? ''),
      branchId: map['branch_id'] is int ? map['branch_id'] : int.tryParse(map['branch_id']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'stock_id': stockId,
      'quantity': quantity,
      'price': price,
      'sub_total': subTotal,
      'discount': discount,
      'business_id': businessId,
      'user_id': userId,
      'branch_id': branchId,
    };
  }
}
