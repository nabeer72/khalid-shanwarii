import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:mobile_app/models/branch.dart';

class AddExpenseController with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  final Expense? initialExpense;
  
  // Form Controllers
  final amountCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  
  String? selectedHeadId;
  DateTime selectedDate = DateTime.now();
  
  List<ExpenseHead> expenseHeads = [];
  List<Branch> branches = [];
  String? selectedBranchId;
  bool isLoading = false;

  AddExpenseController({this.initialExpense}) {
    if (initialExpense != null) {
      amountCtrl.text = initialExpense!.amount.toString();
      descCtrl.text = initialExpense!.description ?? '';
      selectedHeadId = initialExpense!.expenseHeadId;
      selectedDate = initialExpense!.date;
      selectedBranchId = initialExpense!.branchId?.toLowerCase();
    } else {
      selectedBranchId = BusinessConfig.instance.branchId?.toLowerCase();
    }
    loadData();
  }

  Future<void> loadData() async {
    await loadHeads();
    await loadBranches();
  }

  bool get isEdit => initialExpense != null;
  String get screenTitle => isEdit ? 'Edit Expense' : 'Record Expense';
  String get saveButtonLabel => isEdit ? 'UPDATE EXPENSE' : 'SAVE EXPENSE';

  Future<void> loadHeads() async {
    isLoading = true;
    notifyListeners();
    try {
      final headsData = await _db.getExpenseHeads();
      expenseHeads = headsData.map((h) => ExpenseHead.fromMap(h)).toList();
      if (expenseHeads.isNotEmpty && selectedHeadId == null) {
        selectedHeadId = expenseHeads.first.id;
      }
    } catch (e) {
      debugPrint('Error loading heads: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadBranches() async {
    try {
      final data = await _db.getBranches();
      branches = data.map((b) => Branch.fromMap(b)).toList();
      if (branches.isNotEmpty && selectedBranchId == null) {
        selectedBranchId = branches.first.id.toLowerCase();
      }
    } catch (e) {
      debugPrint('Error loading branches: $e');
    } finally {
      notifyListeners();
    }
  }

  void setCategory(String? id) {
    selectedHeadId = id;
    notifyListeners();
  }

  void setBranch(String? id) {
    selectedBranchId = id;
    notifyListeners();
  }

  void setDate(DateTime date) {
    selectedDate = date;
    notifyListeners();
  }

  Future<bool> save(BuildContext context) async {
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      _showError(context, 'Please enter a valid amount');
      return false;
    }
    if (selectedHeadId == null) {
      _showError(context, 'Please select a category');
      return false;
    }

    isLoading = true;
    notifyListeners();

    try {
      final data = {
        'id': isEdit ? initialExpense!.id : _uuid.v4(),
        'expense_head_id': selectedHeadId,
        'amount': amount,
        'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
        'date': selectedDate.toIso8601String(),
        'branch_id': selectedBranchId ?? BusinessConfig.instance.branchId,
        'status': 1,
      };

      if (isEdit) {
        await _db.updateExpense(initialExpense!.id, data);
      } else {
        await _db.insertExpense(data);
      }
      return true;
    } catch (e) {
      _showError(context, 'Error saving expense: $e');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: ThemeProvider.error),
    );
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }
}
