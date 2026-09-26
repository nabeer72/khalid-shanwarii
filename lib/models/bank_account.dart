class BankAccount {
  final int? id;
  final int? businessId;
  final int? userId;
  final int? bankId;
  final String? accountType;
  final String? accountTitle;
  final String? accountNumber;
  final double amount;
  final String? transactionType;
  final String? remarks;
  final String? personName;
  final String? receiptImage;
  final DateTime? date;
  final int status;

  BankAccount({
    this.id,
    this.businessId,
    this.userId,
    this.bankId,
    this.accountType,
    this.accountTitle,
    this.accountNumber,
    this.amount = 0.0,
    this.transactionType,
    this.remarks,
    this.personName,
    this.receiptImage,
    this.date,
    this.status = 1,
  });

  factory BankAccount.fromMap(Map<String, dynamic> map) {
    return BankAccount(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      businessId: map['business_id'] is int ? map['business_id'] : int.tryParse(map['business_id']?.toString() ?? ''),
      userId: map['user_id'] is int ? map['user_id'] : int.tryParse(map['user_id']?.toString() ?? ''),
      bankId: map['bank_id'] is int ? map['bank_id'] : int.tryParse(map['bank_id']?.toString() ?? ''),
      accountType: map['account_type']?.toString(),
      accountTitle: map['account_title']?.toString(),
      accountNumber: map['account_number']?.toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      transactionType: map['transaction_type']?.toString(),
      remarks: map['remarks']?.toString(),
      personName: map['person_name']?.toString(),
      receiptImage: map['receipt_image']?.toString(),
      date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) : null,
      status: map['status'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'user_id': userId,
      'bank_id': bankId,
      'account_type': accountType,
      'account_title': accountTitle,
      'account_number': accountNumber,
      'amount': amount,
      'transaction_type': transactionType,
      'remarks': remarks,
      'person_name': personName,
      'receipt_image': receiptImage,
      'date': date?.toIso8601String(),
      'status': status,
    };
  }
}
