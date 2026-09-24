class Deal {
  final int id;
  final int? businessId;
  final String name;
  final String? description;
  final double dealPrice;
  final DateTime? startDate;
  final DateTime? endDate;
  final int status; // 1 = active, 0 = inactive
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Deal({
    required this.id,
    this.businessId,
    required this.name,
    this.description,
    this.dealPrice = 0.0,
    this.startDate,
    this.endDate,
    this.status = 1,
    this.createdAt,
    this.updatedAt,
  });

  factory Deal.fromMap(Map<String, dynamic> map) {
    return Deal(
      id: (map['id'] as num?)?.toInt() ?? 0,
      businessId: (map['business_id'] as num?)?.toInt(),
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : 'Deal #${(map['id'] as num?)?.toInt() ?? 0}',
      description: map['description'] as String?,
      dealPrice: (map['deal_price'] as num?)?.toDouble() ?? 0.0,
      startDate: map['start_date'] != null ? DateTime.tryParse(map['start_date'].toString()) : null,
      endDate: map['end_date'] != null ? DateTime.tryParse(map['end_date'].toString()) : null,
      status: (map['status'] as num?)?.toInt() ?? 1,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id == 0 ? null : id,
      'business_id': businessId,
      'name': name,
      'description': description,
      'deal_price': dealPrice,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
