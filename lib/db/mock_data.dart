import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/customer.dart';

/// Business configuration store
class BusinessConfig {
  static final BusinessConfig instance = BusinessConfig._();
  BusinessConfig._();

  String businessType = 'general'; // general, garments, produce, restaurant
  String businessName = 'My Business';
  String businessAddress = '';
  String businessPhone = '';
   dynamic businessId;
   dynamic userId;
   dynamic staffId;
  String staffName = '';
  String receiptFooter = 'Thank you!';
  double taxRate = 0.0;
  bool enableTax = false;
  bool enableGlobalDiscount = true;
  double globalDiscountLimit = 0;
  String globalDiscountLimitType = 'percentage'; // 'fixed' or 'percentage'
  bool requireCustomer = false;
  bool autoReceipt = true;
  bool openCashDrawer = true;
  bool soundEnabled = true;
  bool hasSeenOnboarding = false;


  
  // App-wide cached data
  List<dynamic> businessTypes = [];


  
  final ValueNotifier<String> currencyNotifier = ValueNotifier<String>('Rs');
  String get currency => currencyNotifier.value;
  set currency(String value) {
    currencyNotifier.value = value;
  }
  String get currencyDisplay {
    return currency;
  }
  
  String formatAmount(double amount) {
    final c = currency.toLowerCase();
    final absAmount = amount.abs();
    // Include various Rupee symbols: Rs, ₹ (INR), ₨ (PKR), etc.
    if (c.startsWith('rs') || c.startsWith('rupee') || c == '₹' || c == '₨' || c.contains('rs')) {
      return absAmount.toStringAsFixed(2);
    } else {
      return absAmount.toStringAsFixed(0);
    }
  }

  IconData get currencyIcon {
    switch (currency) {
      case '\$': return Icons.attach_money;
      case '€': return Icons.euro;
      case '£': return Icons.currency_pound;
      case '¥': return Icons.currency_yen;
      case '₹': return Icons.currency_rupee;
      default: return Icons.monetization_on;
    }
  }

  bool weightMode = false;
  String weightUnit = 'kg'; // kg, lb

  void reset({bool keepContext = false}) {
    if (!keepContext) {
       businessId = null;
       userId = null;
       staffId = null;
      staffName = '';
    }
    businessType = 'general';
    businessName = 'My Business';
    businessAddress = '';
    businessPhone = '';
    receiptFooter = 'Thank you!';
    currency = 'Rs';
    taxRate = 0.0;
    enableTax = false;
    enableGlobalDiscount = true;
    globalDiscountLimit = 0;
    globalDiscountLimitType = 'percentage';
    requireCustomer = false;
    autoReceipt = true;
    openCashDrawer = true;
    soundEnabled = true;
    weightMode = false;
    weightUnit = 'kg';
    hasSeenOnboarding = false;

  }


  /// Sets the complete business and branch context
   void setContext({
     required dynamic bid,
     required dynamic uid,
     String? bName,
     String? bType,
   }) {
     businessId = bid;
     userId = uid;
    if (bName != null) businessName = bName;
    if (bType != null) businessType = bType;

    if (bid != null) {
      // Logic to load subscription info from DB will be in loadSettings
    }
  }








}

/// Mock data store for web testing (in-memory)
class MockDataStore {
  static final MockDataStore instance = MockDataStore._();
  MockDataStore._();

  final List<ProductCategory> categories = [];
  final List<Product> products = [];
  final List<Map<String, dynamic>> sales = [];
  final List<Customer> customers = [];
  final List<PaymentMethod> paymentMethods = [
    PaymentMethod(id: 1, name: 'Cash', icon: 'payments'),
    PaymentMethod(id: 2, name: 'Card', icon: 'credit_card'),
    PaymentMethod(id: 3, name: 'Mobile', icon: 'phone_android'),
    PaymentMethod(id: 4, name: 'Credit', icon: 'account_balance_wallet'),
  ];
  final List<Employee> employees = [];
  final List<QuickKey> quickKeys = [];
  List<int> recentProductIds = [];

  void addToRecent(int id) {
    if (!recentProductIds.contains(id)) {
      recentProductIds.insert(0, id);
      if (recentProductIds.length > 20) recentProductIds.removeLast();
    }
  }

  void clear() {
    sales.clear();
    recentProductIds.clear();
  }

  List<Product> get recentProducts => recentProductIds.map((id) => products.firstWhere((p) => p.id == id, orElse: () => products.first)).toList();
  List<Product> get favoriteProducts => products.where((p) => p.isFavorite).toList();
}

// Customer Model


// Payment Method Model
class PaymentMethod {
  final int id;
  final String name;
  final String icon;

  PaymentMethod({required this.id, required this.name, required this.icon});
}

// Employee Model
class Employee {
  final int? id;
  final String name;
  final String role;
  final String? pin;
  final String? email;
  final String? phone;
  final bool isActive;

  Employee({
    this.id,
    required this.name,
    required this.role,
    this.pin,
    this.email,
    this.phone,
    required this.isActive,
  });
}


// ... (QuickKey, ExpenseHead, Expense models overlap) ...

// Supplier Model
class Supplier {
  final int? id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final double creditBalance;
  final double openingAmount;


  Supplier({
    this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.creditBalance = 0,
    this.openingAmount = 0,

  });

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      name: map['name']?.toString() ?? '',
      contactPerson: map['contact_person']?.toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      address: map['address']?.toString(),
      creditBalance: (map['credit_balance'] as num?)?.toDouble() ?? 0,
      openingAmount: (map['opening_amount'] as num?)?.toDouble() ?? 0,

    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'credit_balance': creditBalance,
      'opening_amount': openingAmount,

    };
  }
}

// Purchase Model
class Purchase {
  final int? id;
  final int supplierId;
  final String? supplierName;
  final String? invoiceNumber;
  final DateTime purchaseDate;
  final String? notes;
  final String? paymentType;
  final double totalAmount;


  Purchase({
    this.id,
    required this.supplierId,
    this.supplierName,
    this.invoiceNumber,
    required this.purchaseDate,
    this.notes,
    this.paymentType,
    required this.totalAmount,

  });

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      supplierId: map['supplier_id'] is int ? map['supplier_id'] : int.tryParse(map['supplier_id']?.toString() ?? '') ?? 0,
      supplierName: map['supplier_name']?.toString(),
      invoiceNumber: map['invoice_number']?.toString(),
      purchaseDate: DateTime.tryParse(map['purchase_date']?.toString() ?? '') ?? DateTime.now(),
      notes: map['notes']?.toString(),
      paymentType: map['payment_type']?.toString(),
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,

    );
  }
}

// Purchase Item Model
class PurchaseItem {
  final int? id;
  final int purchaseId;
  final int productId;
  final String? productName;
  final double quantity;
  final double purchasePrice;
  final double sellingPrice;
  final double subtotal;

  PurchaseItem({
    this.id,
    required this.purchaseId,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.subtotal,
  });

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      purchaseId: map['purchase_id'] is int ? map['purchase_id'] : int.tryParse(map['purchase_id']?.toString() ?? '') ?? 0,
      productId: map['product_id'] is int ? map['product_id'] : int.tryParse(map['product_id']?.toString() ?? '') ?? 0,
      productName: map['product_name']?.toString(),
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0,
      sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
    );
  }
}

// Quick Key Model
class QuickKey {
  final int? id;
  final int productId;
  final int quantity;
  final String label;
  final String color;

  QuickKey({this.id, required this.productId, this.quantity = 1, required this.label, this.color = 'blue'});
}

// Expense Head Model
class ExpenseHead {
  final int? id;
  final String name;

  ExpenseHead({this.id, required this.name});

  factory ExpenseHead.fromMap(Map<String, dynamic> map) {
    return ExpenseHead(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      name: map['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
  }
}

// Expense Model
class Expense {
  final int? id;
  final int expenseHeadId;
  final String? expenseHeadName;
  final double amount;
  final String? description;
  final DateTime date;


  Expense({
    this.id,
    required this.expenseHeadId,
    this.expenseHeadName,
    required this.amount,
    this.description,
    required this.date,

  });

  factory Expense.fromMap(Map<String, dynamic> map, {String? headName}) {
    return Expense(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      expenseHeadId: map['expense_head_id'] is int ? map['expense_head_id'] : int.tryParse(map['expense_head_id']?.toString() ?? '') ?? 0,
      expenseHeadName: headName ?? map['expense_head_name']?.toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      description: (map['remarks'] ?? map['remark'] ?? map['description'] ?? map['title'])?.toString(),
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),

    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expense_head_id': expenseHeadId,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),

    };
  }
}
