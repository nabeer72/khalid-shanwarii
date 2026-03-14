class BankAccount {
  final String id;
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
    required this.id,
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
      id: map['id'],
      bankName: map['bank_name'],
      accountType: map['account_type'],
      accountTitle: map['account_title'],
      accountNumber: map['account_number'],
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      transactionType: map['transaction_type'],
      remarks: map['remarks'],
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
      status: map['status'] ?? 1,
      isSynced: map['is_synced'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
