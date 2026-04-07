class CreditSale {
  final int? id;
  final int businessId;
  final int branchId;
  final int? userId;
  final int customerId;
  final int saleId;
  final double amount;
  final double remainingBalance;
  final int status;
  final int isSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CreditSale({
    this.id,
    required this.businessId,
    required this.branchId,
    this.userId,
    required this.customerId,
    required this.saleId,
    required this.amount,
    required this.remainingBalance,
    this.status = 1,
    this.isSynced = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory CreditSale.fromMap(Map<String, dynamic> map) {
    return CreditSale(
      id: map['id'],
      businessId: map['business_id'] ?? 0,
      branchId: map['branch_id'] ?? 0,
      userId: map['user_id'],
      customerId: map['customer_id'] ?? 0,
      saleId: map['sale_id'] ?? 0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      remainingBalance: (map['remaining_balance'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 1,
      isSynced: map['is_synced'] ?? 0,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'business_id': businessId,
      'branch_id': branchId,
      'user_id': userId,
      'customer_id': customerId,
      'sale_id': saleId,
      'amount': amount,
      'remaining_balance': remainingBalance,
      'status': status,
      'is_synced': isSynced,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
