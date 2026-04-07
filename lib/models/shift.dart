import 'dart:convert';

class Shift {
  final int? id;
  final int businessId;
  final int userId;
  final int staffId;
  final String startTime;
  final String? endTime;
  final double openingCash;
  final String openingDenominations; // JSON string
  final double closingCash;
  final String? closingDenominations; // JSON string
  final double totalSales;
  final double totalCashReceived;
  final double totalOnlineReceived;
  final double totalCreditReceived;
  final int status; // 1 = Active, 0 = Closed
  final String createdAt;
  final String updatedAt;

  Shift({
    this.id,
    required this.businessId,
    required this.userId,
    required this.staffId,
    required this.startTime,
    this.endTime,
    required this.openingCash,
    required this.openingDenominations,
    this.closingCash = 0,
    this.closingDenominations,
    this.totalSales = 0,
    this.totalCashReceived = 0,
    this.totalOnlineReceived = 0,
    this.totalCreditReceived = 0,
    this.status = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'user_id': userId,
      'staff_id': staffId,
      'start_time': startTime,
      'end_time': endTime,
      'opening_cash': openingCash,
      'opening_denominations': openingDenominations,
      'closing_cash': closingCash,
      'closing_denominations': closingDenominations,
      'total_sales': totalSales,
      'total_cash_received': totalCashReceived,
      'total_online_received': totalOnlineReceived,
      'total_credit_received': totalCreditReceived,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Shift.fromMap(Map<String, dynamic> map) {
    return Shift(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      businessId: map['business_id'] is int ? map['business_id'] : int.tryParse(map['business_id']?.toString() ?? '') ?? 0,
      userId: map['user_id'] is int ? map['user_id'] : int.tryParse(map['user_id']?.toString() ?? '') ?? 0,
      staffId: map['staff_id'] is int ? map['staff_id'] : int.tryParse(map['staff_id']?.toString() ?? '') ?? 0,
      startTime: map['start_time']?.toString() ?? '',
      endTime: map['end_time']?.toString(),
      openingCash: (map['opening_cash'] as num? ?? 0).toDouble(),
      openingDenominations: map['opening_denominations']?.toString() ?? '{}',
      closingCash: (map['closing_cash'] as num? ?? 0).toDouble(),
      closingDenominations: map['closing_denominations']?.toString(),
      totalSales: (map['total_sales'] as num? ?? 0).toDouble(),
      totalCashReceived: (map['total_cash_received'] as num? ?? 0).toDouble(),
      totalOnlineReceived: (map['total_online_received'] as num? ?? 0).toDouble(),
      totalCreditReceived: (map['total_credit_received'] as num? ?? 0).toDouble(),
      status: map['status'] ?? 0,
      createdAt: map['created_at']?.toString() ?? '',
      updatedAt: map['updated_at']?.toString() ?? '',
    );
  }

  Map<String, int> get openingDenomsMap {
    try {
      return Map<String, int>.from(jsonDecode(openingDenominations));
    } catch (_) {
      return {};
    }
  }

  Map<String, int>? get closingDenomsMap {
    if (closingDenominations == null) return null;
    try {
      return Map<String, int>.from(jsonDecode(closingDenominations!));
    } catch (_) {
      return null;
    }
  }
}
