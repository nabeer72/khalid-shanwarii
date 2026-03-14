class Branch {
  final String id;
  final String? businessId;
  final String? userId;
  final String branchTitle;
  final String? branchCode;
  final String? branchAddress;
  final int? contactNumber;
  final int status;
  final int isSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Branch({
    required this.id,
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
      branchTitle: map['branch_title'],
      branchCode: map['branch_code'],
      branchAddress: map['branch_address'],
      contactNumber: map['contact_number'],
      status: map['status'] ?? 1,
      isSynced: map['is_synced'] ?? 0,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
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
