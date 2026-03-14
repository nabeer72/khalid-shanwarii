class Customer {
  final String id;
  final String businessId;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final double discount;
  final double totalSpent;
  final int visitCount;
  final double? creditBalance;
  final int status;
  final int isSynced;
  final String? branchId;

  Customer({
    required this.id,
    required this.businessId,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    this.discount = 0.0,
    this.totalSpent = 0.0,
    this.visitCount = 0,
    this.creditBalance = 0.0,
    this.status = 1,
    this.isSynced = 0,
    this.branchId,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id']?.toString() ?? '',
      businessId: map['business_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      notes: map['notes']?.toString(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0.0,
      visitCount: (map['visit_count'] as num?)?.toInt() ?? 0,
      creditBalance: (map['credit_balance'] as num?)?.toDouble() ?? 0.0,
      status: (map['status'] as num?)?.toInt() ?? 1,
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 0,
      branchId: map['branch_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'phone': phone,
      'email': email,
      'notes': notes,
      'discount': discount,
      'total_spent': totalSpent,
      'visit_count': visitCount,
      'credit_balance': creditBalance,
      'status': status,
      'is_synced': isSynced,
      'branch_id': branchId,
    };
  }
}
