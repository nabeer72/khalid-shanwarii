import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/customer.dart';

class CustomerFormHelper {
  static Future<Map<String, dynamic>?> prepareAndSaveCustomer({
    required Customer? existingCustomer,
    required String name,
    required String phone,
    String? email,
    required String notes,
    required String discountText,
    required String creditLimitText,
    int? branchId,
    required BuildContext context,
  }) async {
    // Enhanced Validation
    if (name.trim().isEmpty) {
      return {'success': false, 'message': 'Name is required'};
    }

    if (email != null && email.trim().isNotEmpty) {
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim())) {
        return {'success': false, 'message': 'Invalid email format'};
      }
    }

    final discount = double.tryParse(discountText) ?? 0.0;
    if (discount < 0 || discount > 100) {
      return {'success': false, 'message': 'Discount must be between 0 and 100'};
    }

    final creditLimit = double.tryParse(creditLimitText) ?? 0.0;

    final isEdit = existingCustomer != null;

    final customer = Customer(
      id: isEdit ? existingCustomer.id : null,
      businessId: BusinessConfig.instance.businessId!,
      userId: BusinessConfig.instance.userId,
      name: name.trim(),
      phone: phone.trim().isNotEmpty ? phone.trim() : null,
      email: email != null && email.trim().isNotEmpty ? email.trim() : null,
      notes: notes.trim().isNotEmpty ? notes.trim() : null,
      discount: discount,
      creditLimit: creditLimit,
      status: 1,
      isSynced: 0,
      branchId: branchId ?? BusinessConfig.instance.branchId,
    );

    final customerMap = customer.toMap();

    try {
      if (isEdit) {
        await DatabaseHelper.instance.updateCustomer(customer.id!, customerMap);
      } else {
        await DatabaseHelper.instance.insertCustomer(customerMap);
      }

      return {
        'success': true,
        'message': '${customer.name} ${isEdit ? 'updated' : 'added'}!',
        'customerName': customer.name,
        'isEdit': isEdit,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
