class BankAccount {
  final int? id;
  final int? businessId;
  final int? userId;
  final String bankName;
  final String? accountType;
  final String? accountTitle;
  final String? accountNumber;
  final double amount;
  final String? transactionType;
  final String? remarks;
  final DateTime? date;
  final int status;
  final int isSynced;

  BankAccount({
    this.id,
    this.businessId,
    this.userId,
    required this.bankName,
    this.accountType,
    this.accountTitle,
    this.accountNumber,
    this.amount = 0.0,
    this.transactionType,
    this.remarks,
    this.date,
    this.status = 1,
    this.isSynced = 0,
  });

  factory BankAccount.fromMap(Map<String, dynamic> map) {
    return BankAccount(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      businessId: map['business_id'] is int ? map['business_id'] : int.tryParse(map['business_id']?.toString() ?? ''),
      userId: map['user_id'] is int ? map['user_id'] : int.tryParse(map['user_id']?.toString() ?? ''),
      bankName: map['bank_name']?.toString() ?? '',
      accountType: map['account_type']?.toString(),
      accountTitle: map['account_title']?.toString(),
      accountNumber: map['account_number']?.toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      transactionType: map['transaction_type']?.toString(),
      remarks: map['remarks']?.toString(),
      date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) : null,
      status: map['status'] ?? 1,
      isSynced: map['is_synced'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'user_id': userId,
      'bank_name': bankName,
      'account_type': accountType,
      'account_title': accountTitle,
      'account_number': accountNumber,
      'amount': amount,
      'transaction_type': transactionType,
      'remarks': remarks,
      'date': date?.toIso8601String(),
      'status': status,
      'is_synced': isSynced,
    };
  }
}
