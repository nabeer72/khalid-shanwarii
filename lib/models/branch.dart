class Branch {
  final dynamic id;
  final dynamic businessId;
  final dynamic userId;
  final String branchTitle;
  final String? branchCode;
  final String? branchAddress;
  final int? contactNumber;
  final int status;
  final int isSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Branch({
    this.id,
    this.businessId,
    this.userId,
    required this.branchTitle,
    this.branchCode,
    this.branchAddress,
    this.contactNumber,
    this.status = 1,
    this.isSynced = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Branch.fromMap(Map<String, dynamic> map) {
    return Branch(
      id: map['id'],
      businessId: map['business_id'],
      userId: map['user_id'],
      branchTitle: (map['branch_title'] ?? map['name'])?.toString() ?? '',
      branchCode: map['branch_code']?.toString(),
      branchAddress: map['branch_address']?.toString(),
      contactNumber: map['contact_number'] is int ? map['contact_number'] : int.tryParse(map['contact_number']?.toString() ?? ''),
      status: map['status'] ?? 1,
      isSynced: map['is_synced'] ?? 0,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'user_id': userId,
      'branch_title': branchTitle,
      'branch_code': branchCode,
      'branch_address': branchAddress,
      'contact_number': contactNumber,
      'status': status,
      'is_synced': isSynced,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
