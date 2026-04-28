import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/controllers/add_customer_controller.dart';

class AddCustomerDialog {
  static Future<Customer?> show(BuildContext context, {Customer? existing}) async {
    final theme = ThemeProvider.instance;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final discountController = TextEditingController(text: (existing?.discount ?? 0).toString());
    final creditLimitController = TextEditingController(text: (existing?.creditLimit ?? 0).toString());
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    return await showDialog<Customer?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  existing == null ? 'New Customer' : 'Edit Customer',
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: Icon(Icons.close_rounded, color: theme.textSecondary, size: 20),
                ),
              ],
            ),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(theme, 'Basic Details'),
                      _buildTextField(
                        theme: theme,
                        controller: nameController,
                        label: 'Customer Name',
                        icon: Icons.person_outline,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        theme: theme,
                        controller: phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            if (!RegExp(r'^[0-9+ ]+$').hasMatch(v.trim())) {
                              return 'Invalid phone number';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        theme: theme,
                        controller: emailController,
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                              return 'Invalid email format';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildSectionHeader(theme, 'Loyalty & Preferences'),
                      _buildTextField(
                        theme: theme,
                        controller: discountController,
                        label: 'Standard Discount (%)',
                        icon: Icons.percent_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final d = double.tryParse(v);
                          if (d == null) return 'Must be a number';
                          if (d < 0 || d > 100) return 'Must be 0-100%';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        theme: theme,
                        controller: creditLimitController,
                        label: 'Credit Limit (Amount)',
                        icon: Icons.money_off_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final d = double.tryParse(v);
                          if (d == null) return 'Must be a number';
                          if (d < 0) return 'Cannot be negative';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        theme: theme,
                        controller: notesController,
                        label: 'Additional Notes',
                        icon: Icons.notes_rounded,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('CANCEL', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.highlight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        
                        setDialogState(() => isLoading = true);
                        final result = await CustomerFormHelper.prepareAndSaveCustomer(
                          existingCustomer: existing,
                          name: nameController.text,
                          phone: phoneController.text,
                          email: emailController.text,
                          notes: notesController.text,
                          discountText: discountController.text,
                          creditLimitText: creditLimitController.text,
                          context: context,
                        );
                        
                        if (result != null && result['success'] == true) {
                          // Try to fetch the newly created customer
                          final customers = await DatabaseHelper.instance.getCustomers();
                          Customer? newCust;
                          try {
                            // Find the customer we just saved (usually the last one added or by name)
                            final lastData = customers.last;
                            newCust = Customer.fromMap(lastData);
                          } catch (_) {}

                          if (ctx.mounted) {
                            Navigator.pop(ctx, newCust);
                          }
                        } else {
                          if (ctx.mounted) {
                            setDialogState(() => isLoading = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(result?['message'] ?? 'Save failed'), backgroundColor: ThemeProvider.error),
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        existing == null ? 'SAVE CUSTOMER' : 'UPDATE CHANGES',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _buildSectionHeader(ThemeProvider theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }

  static Widget _buildTextField({
    required ThemeProvider theme,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
      validator: validator,
      decoration: theme.glassInputDecoration(label, icon).copyWith(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
    );
  }
}
