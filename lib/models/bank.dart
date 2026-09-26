class Bank {
  final int? id;
  final int? businessId;
  final int? userId;
  final String name;
  final int status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Bank({
    this.id,
    this.businessId,
    this.userId,
    required this.name,
    this.status = 1,
    this.createdAt,
    this.updatedAt,
  });

  factory Bank.fromMap(Map<String, dynamic> map) {
    return Bank(
      id: map['id'],
      businessId: map['business_id'],
      userId: map['user_id'],
      name: map['name'],
      status: map['status'] ?? 1,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'user_id': userId,
      'name': name,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
