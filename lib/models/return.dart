import 'customer.dart';
import 'sale.dart';

class Return {
  final int? id;
  final int? businessId;
  final int? branchId;
  final int? adminId;
  final int? saleId;
  final int? customerId;
  final int? userId;
  final double totalAmount;
  final String? reason;
  final int status;
  final int isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ReturnItem> items;
  final Customer? customer;
  final Sale? sale;

  Return({
    this.id,
    this.businessId,
    this.branchId,
    this.adminId,
    this.saleId,
    this.customerId,
    this.userId,
    required this.totalAmount,
    this.reason,
    this.status = 1,
    this.isSynced = 0,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.customer,
    this.sale,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'branch_id': branchId,
      'admin_id': adminId,
      'sale_id': saleId,
      'customer_id': customerId ?? customer?.id,
      'user_id': userId,
      'total_amount': totalAmount,
      'reason': reason,
      'status': status,
      'is_synced': isSynced,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Return.fromMap(Map<String, dynamic> map, {List<ReturnItem> items = const [], Customer? customer, Sale? sale}) {
    return Return(
      id: map['id'],
      businessId: map['business_id'],
      branchId: map['branch_id'],
      adminId: map['admin_id'],
      saleId: map['sale_id'],
      customerId: map['customer_id'],
      userId: map['user_id'],
      totalAmount: (map['total_amount'] as num).toDouble(),
      reason: map['reason'],
      status: map['status'] ?? 1,
      isSynced: map['is_synced'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      items: items,
      customer: customer,
      sale: sale,
    );
  }
}

class ReturnItem {
  final int? id;
  final int? returnId;
  final int? saleItemId;
  final int? productId;
  final int? stockId;
  final double quantity;
  final double price;
  final double subtotal;

  ReturnItem({
    this.id,
    this.returnId,
    this.saleItemId,
    this.productId,
    this.stockId,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'return_id': returnId,
      'sale_item_id': saleItemId,
      'product_id': productId,
      'stock_id': stockId,
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal,
    };
  }

  factory ReturnItem.fromMap(Map<String, dynamic> map) {
    return ReturnItem(
      id: map['id'],
      returnId: map['return_id'],
      saleItemId: map['sale_item_id'],
      productId: map['product_id'],
      stockId: map['stock_id'],
      quantity: (map['quantity'] as num).toDouble(),
      price: (map['price'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
    );
  }
}
