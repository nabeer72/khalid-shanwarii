import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/models/branch.dart';

class AddSupplierController with ChangeNotifier {
  final Supplier? initialSupplier;

  late TextEditingController nameCtrl;
  late TextEditingController contactCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController addressCtrl;
  late TextEditingController balanceCtrl;

  bool _isLoading = false;
  String? _errorMessage;
  List<Branch> branches = [];
  int? selectedBranchId;

  AddSupplierController({this.initialSupplier}) {
    nameCtrl = TextEditingController(text: initialSupplier?.name ?? '');
    contactCtrl = TextEditingController(text: initialSupplier?.contactPerson ?? '');
    phoneCtrl = TextEditingController(text: initialSupplier?.phone ?? '');
    emailCtrl = TextEditingController(text: initialSupplier?.email ?? '');
    addressCtrl = TextEditingController(text: initialSupplier?.address ?? '');
    balanceCtrl = TextEditingController(text: initialSupplier?.openingAmount.toString() ?? '0');
    selectedBranchId = initialSupplier?.branchId ?? BusinessConfig.instance.branchId;
  }



  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEdit => initialSupplier != null;

  String get screenTitle => isEdit ? 'Edit Supplier' : 'Add Supplier';
  String get saveButtonLabel => isEdit ? 'SAVE CHANGES' : 'ADD SUPPLIER';

  Future<void> saveSupplier(BuildContext context) async {
    if (nameCtrl.text.trim().isEmpty) {
      _errorMessage = 'Supplier name is required';
      notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final openingAmount = double.tryParse(balanceCtrl.text.trim()) ?? 0.0;
    final supplierData = {
      'id': initialSupplier?.id,
      'branch_id': selectedBranchId ?? BusinessConfig.instance.branchId,
      'name': nameCtrl.text.trim(),
      'contact_person': contactCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'email': emailCtrl.text.trim(),
      'address': addressCtrl.text.trim(),
      'opening_amount': openingAmount,
      // Set credit_balance = opening_amount so the supplier list shows it immediately
      'credit_balance': openingAmount,
      'status': 1,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (!isEdit) {
      supplierData['created_at'] = DateTime.now().toIso8601String();
    }

    try {
      await DatabaseHelper.instance.insertSupplier(supplierData);

      if (context.mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _errorMessage = 'Error saving supplier: $e';
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: ThemeProvider.error,
          ),
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSupplier(BuildContext context) async {
    if (!isEdit) return;

    _isLoading = true;
    notifyListeners();

    try {
      await DatabaseHelper.instance.deleteSupplier(initialSupplier!.id!);

      if (context.mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _errorMessage = 'Error deleting supplier: $e';
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: ThemeProvider.error,
          ),
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    contactCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    addressCtrl.dispose();
    balanceCtrl.dispose();
    super.dispose();
  }
}
