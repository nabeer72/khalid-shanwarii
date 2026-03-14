import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:uuid/uuid.dart';

class CustomerFormHelper {
  static Future<Map<String, dynamic>?> prepareAndSaveCustomer({
    required Customer? existingCustomer,
    required String name,
    required String phone,
    required String email,
    required String notes,
    required String discountText,
    String? branchId,
    required BuildContext context,
  }) async {
    // Very basic validation (you can expand later)
    if (name.trim().isEmpty) {
      return {'success': false, 'message': 'Name is required'};
    }

    final discount = double.tryParse(discountText) ?? 0.0;
    if (discount < 0) {
      return {'success': false, 'message': 'Discount cannot be negative'};
    }

    final isEdit = existingCustomer != null;

    final customer = Customer(
      id: isEdit ? existingCustomer.id : const Uuid().v4(),
      businessId: BusinessConfig.instance.businessId!,
      name: name.trim(),
      phone: phone.trim().isNotEmpty ? phone.trim() : null,
      email: email.trim().isNotEmpty ? email.trim() : null,
      notes: notes.trim().isNotEmpty ? notes.trim() : null,
      discount: discount,
      totalSpent: isEdit ? existingCustomer.totalSpent : 0,
      visitCount: isEdit ? existingCustomer.visitCount : 0,
      status: 1,
      isSynced: 0,
      branchId: branchId ?? BusinessConfig.instance.branchId,
    );

    final customerMap = customer.toMap();

    try {
      if (isEdit) {
        await DatabaseHelper.instance.updateCustomer(customer.id, customerMap);
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