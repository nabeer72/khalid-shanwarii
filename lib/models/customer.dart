class Customer {
  final int? id;
  final int businessId;
  final int? userId;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final double discount;
  final double? creditBalance;
  final double creditLimit;
  final int status;
  final int isSynced;


  Customer({
    this.id,
    required this.businessId,
    this.userId,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    this.discount = 0.0,
    this.creditBalance = 0.0,
    this.creditLimit = 0.0,
    this.status = 1,
    this.isSynced = 0,

  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      businessId: map['business_id'] is int ? map['business_id'] : int.tryParse(map['business_id']?.toString() ?? '') ?? 0,
      userId: map['user_id'] is int ? map['user_id'] : int.tryParse(map['user_id']?.toString() ?? ''),
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      notes: map['notes']?.toString(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      creditBalance: (map['credit_balance'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0.0,
      status: (map['status'] as num?)?.toInt() ?? 1,
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 0,

    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'user_id': userId,
      'name': name,
      'phone': phone,
      'email': email,
      'notes': notes,
      'discount': discount,
      'credit_balance': creditBalance,
      'credit_limit': creditLimit,
      'status': status,
      'is_synced': isSynced,

    };
  }

  // Computed convenience getters (placeholder until real tracking is wired)
  int get visitCount => 0;
  double get totalSpent => 0.0;
}
