// lib/controllers/suppliers_controller.dart
import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart'; // assuming Supplier model is here
import 'package:mobile_app/screens/add_supplier_screen.dart';

class SuppliersController extends ChangeNotifier {
  List<Supplier> _suppliers = [];
  bool _isLoading = true;

  List<Supplier> get suppliers => _suppliers;
  bool get isLoading => _isLoading;

  SuppliersController() {
    loadSuppliers();
  }

  Future<void> loadSuppliers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await DatabaseHelper.instance.getSuppliers();
      _suppliers = data.map((e) => Supplier.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error loading suppliers: $e');
      // Optionally: you could add error state here
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Call this after add/edit/delete operations
  Future<void> refreshSuppliers() => loadSuppliers();

  // Optional: if you want to handle navigation & result in controller too
  Future<bool> showAddEditDialog(
    BuildContext context, [
    Supplier? supplier,
  ]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddSupplierScreen(supplier: supplier),
      ),
    );

    if (result == true) {
      await refreshSuppliers();
    }

    return result == true;
  }

  // If you plan to add delete functionality later:
  Future<void> deleteSupplier(String id) async {
    try {
      await DatabaseHelper.instance.deleteSupplier(id);
      await refreshSuppliers();
    } catch (e) {
      debugPrint('Error deleting supplier: $e');
    }
  }
}