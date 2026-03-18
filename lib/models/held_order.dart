import 'customer.dart';

class HeldOrder {
  final int? id;
  final String name;
  final List<Map<String, dynamic>> items;
  final double total;
  final Customer? customer;
  final DateTime createdAt;
  final int? customerId;

  HeldOrder({
    this.id,
    required this.name,
    required this.items,
    required this.total,
    this.customer,
    required this.createdAt,
    this.customerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'total': total,
      'customer_id': customerId ?? customer?.id,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory HeldOrder.fromMap(Map<String, dynamic> map, {List<Map<String, dynamic>>? childItems, Customer? customer}) {
    return HeldOrder(
      id: map['id'],
      name: map['name'],
      total: (map['total'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at']),
      items: childItems ?? [],
      customer: customer,
      customerId: map['customer_id'],
    );
  }
}
