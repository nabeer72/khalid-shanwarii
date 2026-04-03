import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';

class AddPurchaseController with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ── Loaded data ────────────────────────────────────────────────────────────
  List<Supplier> suppliers = [];
  List<Map<String, dynamic>> products = [];

  // ── Form state ─────────────────────────────────────────────────────────────
  int? selectedSupplierId;
  Supplier? selectedSupplier;
  DateTime purchaseDate = DateTime.now();
  final invoiceCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final paidAmountCtrl = TextEditingController();
  String paymentType = 'Cash';
  final List<String> paymentTypes = ['Cash', 'Bank Transfer', 'Cheque', 'Credit Card', 'Credit'];

  // Conditional payment controllers
  final chequeNoCtrl = TextEditingController();
  final bankNameCtrl = TextEditingController();
  final transRefCtrl = TextEditingController();
  final cardAuthCtrl = TextEditingController();
  DateTime? creditDueDate;

  // ── Items ──────────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> items = [];

  // ── UI state & feedback ────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _errorMessage;
  String? _successMessage;
  bool _shouldShowAddItemDialog = false;
  // ignore: unused_field
  Map<String, dynamic>? _lastAddedItem; // for potential undo or logging

  AddPurchaseController() {
    _loadData();
  }


  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get showAddItemDialog => _shouldShowAddItemDialog;
  double get totalAmount => items.fold(0.0, (sum, item) => sum + (item['subtotal'] as double));
  double get paidAmount {
    if (paymentType == 'Credit') {
      return double.tryParse(paidAmountCtrl.text) ?? 0.0;
    }
    return totalAmount;
  }
  double get creditAmount => (totalAmount - paidAmount).clamp(0.0, double.infinity);
  double get newBalance => (selectedSupplier?.creditBalance ?? 0.0) + creditAmount;

  String get formattedTotal => '${BusinessConfig.instance.currency}. ${totalAmount.toStringAsFixed(2)}';
  String get formattedPreviousCredit => selectedSupplier != null 
    ? '${BusinessConfig.instance.currency}. ${selectedSupplier!.creditBalance.toStringAsFixed(2)}'
    : 'N/A';

  String get formattedTotalWithPrevious {
    final prev = selectedSupplier?.creditBalance ?? 0.0;
    final total = totalAmount;
    final newTotal = prev + total;
    return '${BusinessConfig.instance.currency}. ${newTotal.toStringAsFixed(2)}';
  }

  bool get canSave => selectedSupplierId != null && items.isNotEmpty;

  String? get supplierValidationMessage =>
      selectedSupplierId == null ? 'Please select a supplier' : null;

  String? get itemsValidationMessage =>
      items.isEmpty ? 'Please add at least one item' : null;

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final supData = await _db.getSuppliers();
      final prodData = await _db.getProducts();

      suppliers = supData.map((e) => Supplier.fromMap(e)).toList();
      products = prodData;
    } catch (e) {
      _errorMessage = 'Failed to load data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSupplier(int? id) {
    if (id == null) {
      selectedSupplierId = null;
      selectedSupplier = null;
    } else {
      selectedSupplierId = id;
      selectedSupplier = suppliers.cast<Supplier?>().firstWhere((s) => s?.id == id, orElse: () => null);
    }
    clearFeedback();
    notifyListeners();
  }

  Future<void> reloadSuppliers() async {
    try {
      final supData = await _db.getSuppliers();
      suppliers = supData.map((e) => Supplier.fromMap(e)).toList();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to reload suppliers: $e';
      notifyListeners();
    }
  }

  Future<void> reloadProducts() async {
    try {
      final prodData = await _db.getProducts();
      products = prodData;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to reload products: $e';
      notifyListeners();
    }
  }

  void setPurchaseDate(DateTime date) {
    purchaseDate = date;
    notifyListeners();
  }

  void setPaymentType(String type) {
    paymentType = type;
    // Reset conditional fields when type changes
    chequeNoCtrl.clear();
    bankNameCtrl.clear();
    transRefCtrl.clear();
    cardAuthCtrl.clear();
    
    _updatePaidAmountOnTotalChange();
    
    creditDueDate = null;
  }

  void _updatePaidAmountOnTotalChange() {
    if (paymentType != 'Credit') {
      paidAmountCtrl.text = totalAmount.toStringAsFixed(2);
    } else {
      // If switching to credit from a full payment, default to 0
      if (double.tryParse(paidAmountCtrl.text) == totalAmount) {
        paidAmountCtrl.text = '0.00';
      }
    }
    notifyListeners();
  }

  void setCreditDueDate(DateTime? date) {
    creditDueDate = date;
    notifyListeners();
  }

  void requestAddItemDialog() {
    _shouldShowAddItemDialog = true;
    notifyListeners();
  }

  void closeAddItemDialog() {
    _shouldShowAddItemDialog = false;
    notifyListeners();
  }

  void addItem({
    required int productId,
    required String productName,
    required String? barcode,
    required double existingStock,
    required double quantity,
    required double purchasePrice,
    required double wholesalePrice,
    required double sellingPrice,
  }) {
    if (quantity <= 0) return;

    final subtotal = quantity * purchasePrice;

    items.add({
      'id': null,
    'product_id': productId,
      'product_name': productName,
      'barcode': barcode,
      'existing_stock': existingStock,
      'quantity': quantity,
      'purchase_price': purchasePrice,
      'wholesale_price': wholesalePrice,
      'selling_price': sellingPrice,
      'subtotal': subtotal,
    });

    clearFeedback();
    _updatePaidAmountOnTotalChange();
  }

  void removeItem(int index) {
    if (index >= 0 && index < items.length) {
      items.removeAt(index);
      clearFeedback();
      _updatePaidAmountOnTotalChange();
    }
  }

  Future<void> savePurchase() async {
    clearFeedback();

    final supplierMsg = supplierValidationMessage;
    final itemsMsg = itemsValidationMessage;

    if (supplierMsg != null || itemsMsg != null) {
      _errorMessage = supplierMsg ?? itemsMsg;
      notifyListeners();
      return;
    }

    String paymentRef = '';
    switch (paymentType) {
      case 'Cheque':
        paymentRef = 'Cheque No: ${chequeNoCtrl.text.trim()}';
        break;
      case 'Bank Transfer':
        paymentRef = 'Bank: ${bankNameCtrl.text.trim()}, Ref: ${transRefCtrl.text.trim()}';
        break;
      case 'Credit Card':
        paymentRef = 'Auth Code: ${cardAuthCtrl.text.trim()}';
        break;
      case 'Credit':
        paymentRef = 'Due Date: ${creditDueDate != null ? DateFormat('yyyy-MM-dd').format(creditDueDate!) : 'N/A'}';
        break;
    }


    final purchase = {
      'id': null,
      'branch_id': BusinessConfig.instance.branchId,
      'supplier_id': selectedSupplierId,
      'invoice_number': invoiceCtrl.text.trim(),
      'purchase_date': purchaseDate.toIso8601String(),
      'notes': notesCtrl.text.trim(),
      'payment_type': paymentType,
      'payment_reference': paymentRef,
      'total_amount': totalAmount,
      'status': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final purchaseId = await _db.insertPurchase(purchase, items);

      // Handle Supplier Credit/Payback logic
      final credit = creditAmount;
      if (credit > 0 && selectedSupplierId != null) {
        await _db.insertSupplierCreditPurchase({
          'id': null,
          'supplier_id': selectedSupplierId,
          'purchase_id': purchaseId,
          'branch_id': BusinessConfig.instance.branchId, // Ensures reconcileSupplierBalances finds this record under the correct branch filter
          'amount': totalAmount,
          'remaining_balance': credit,
          'is_synced': 0,
          'status': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        
        await _db.updateSupplierCreditBalance(selectedSupplierId!, credit);
      }

      _successMessage = 'Purchase saved & Inventory updated!';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error saving purchase: $e';
      notifyListeners();
    }
  }

  void clearFeedback() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    invoiceCtrl.dispose();
    notesCtrl.dispose();
    chequeNoCtrl.dispose();
    bankNameCtrl.dispose();
    transRefCtrl.dispose();
    cardAuthCtrl.dispose();
    paidAmountCtrl.dispose();
    super.dispose();
  }
}
