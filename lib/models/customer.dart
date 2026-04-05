class Customer {
  final int? id;
  final int businessId;
  final int? adminId;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final double discount;
  final double totalSpent;
  final int visitCount;
  final double? creditBalance;
  final double creditLimit;
  final int status;
  final int isSynced;
  final int? branchId;

  Customer({
    this.id,
    required this.businessId,
    this.adminId,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    this.discount = 0.0,
    this.totalSpent = 0.0,
    this.visitCount = 0,
    this.creditBalance = 0.0,
    this.creditLimit = 0.0,
    this.status = 1,
    this.isSynced = 0,
    this.branchId,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      businessId: map['business_id'] is int ? map['business_id'] : int.tryParse(map['business_id']?.toString() ?? '') ?? 0,
      adminId: map['admin_id'] is int ? map['admin_id'] : int.tryParse(map['admin_id']?.toString() ?? ''),
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      notes: map['notes']?.toString(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0.0,
      visitCount: (map['visit_count'] as num?)?.toInt() ?? 0,
      creditBalance: (map['credit_balance'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0.0,
      status: (map['status'] as num?)?.toInt() ?? 1,
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 0,
      branchId: map['branch_id'] is int ? map['branch_id'] : int.tryParse(map['branch_id']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'admin_id': adminId,
      'name': name,
      'phone': phone,
      'email': email,
      'notes': notes,
      'discount': discount,
      'total_spent': totalSpent,
      'visit_count': visitCount,
      'credit_balance': creditBalance,
      'credit_limit': creditLimit,
      'status': status,
      'is_synced': isSynced,
      'branch_id': branchId,
    };
  }
}
