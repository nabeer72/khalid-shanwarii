class BankDetail {
  final int? id;
  final int bankId;
  final int? businessId;
  final int? userId;
  final String accountTitle;
  final String? accountNumber;
  final String? accountType;
  final int status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BankDetail({
    this.id,
    required this.bankId,
    this.businessId,
    this.userId,
    required this.accountTitle,
    this.accountNumber,
    this.accountType,
    this.status = 1,
    this.createdAt,
    this.updatedAt,
  });

  factory BankDetail.fromMap(Map<String, dynamic> map) {
    return BankDetail(
      id: map['id'],
      bankId: map['bank_id'],
      businessId: map['business_id'],
      userId: map['user_id'],
      accountTitle: map['account_title'],
      accountNumber: map['account_number'],
      accountType: map['account_type'],
      status: map['status'] ?? 1,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bank_id': bankId,
      'business_id': businessId,
      'user_id': userId,
      'account_title': accountTitle,
      'account_number': accountNumber,
      'account_type': accountType,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
