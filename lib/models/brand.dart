class Brand {
  final dynamic id;
  final dynamic businessId;

  final dynamic userId;
  final String name;
  final int status;
  final int isSynced;
  final String? createdAt;
  final String? updatedAt;

  Brand({
    this.id,
    required this.businessId,

    this.userId,
    required this.name,
    this.status = 1,
    this.isSynced = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Brand.fromMap(Map<String, dynamic> map) {
    return Brand(
      id: map['id'],
      businessId: map['business_id'],

      userId: map['user_id'],
      name: map['name'] ?? '',
      status: map['status'] ?? 1,
      isSynced: map['is_synced'] ?? 0,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,

      'user_id': userId,
      'name': name,
      'status': status,
      'is_synced': isSynced,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
