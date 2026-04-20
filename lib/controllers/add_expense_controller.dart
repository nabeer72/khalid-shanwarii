import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/models/branch.dart';
import 'package:mobile_app/models/bank.dart';
import 'package:mobile_app/models/bank_detail.dart';

class AddExpenseController with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  final Expense? initialExpense;
  
  // Form Controllers
  final amountCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  
  int? selectedHeadId;
  DateTime selectedDate = DateTime.now();
  
  List<ExpenseHead> expenseHeads = [];
  List<Branch> branches = [];
  int? selectedBranchId;
  bool isLoading = false;

  // [NEW] Payment selection
  String paymentMethod = 'Cash'; // 'Cash' or 'Bank'
  List<Bank> banks = [];
  List<BankDetail> bankDetails = [];
  Bank? selectedBank;
  BankDetail? selectedBankDetail;

  AddExpenseController({this.initialExpense}) {
    if (initialExpense != null) {
      amountCtrl.text = initialExpense!.amount.toString();
      descCtrl.text = initialExpense!.description ?? '';
      selectedHeadId = initialExpense!.expenseHeadId;
      selectedDate = initialExpense!.date;
      selectedBranchId = initialExpense!.branchId;
    } else {
      selectedBranchId = BusinessConfig.instance.branchId;
    }
    loadData();
  }

  Future<void> loadData() async {
    await loadHeads();
    await loadBanks();
  }

  Future<void> loadBanks() async {
    final data = await _db.getBanks();
    banks = data.map((b) => Bank.fromMap(b)).toList();
    notifyListeners();
  }

  Future<void> loadBankDetails(int bankId) async {
    final data = await _db.getBankDetails(bankId: bankId);
    bankDetails = data.map((d) => BankDetail.fromMap(d)).toList();
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    paymentMethod = method;
    notifyListeners();
  }

  void setBank(Bank? bank) async {
    selectedBank = bank;
    selectedBankDetail = null;
    bankDetails = [];
    if (bank != null) {
      final data = await _db.getBankDetails(bankId: bank.id!);
      bankDetails = data.map((d) => BankDetail.fromMap(d)).toList();
      if (bankDetails.length == 1) {
        selectedBankDetail = bankDetails.first;
      }
    }
    notifyListeners();
  }

  void setBankDetail(BankDetail? detail) {
    selectedBankDetail = detail;
    notifyListeners();
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


  void setCategory(int? id) {
    selectedHeadId = id;
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
      String finalDescription = descCtrl.text.trim();
      if (paymentMethod == 'Bank' && selectedBankDetail != null) {
        final bankInfo = '[Bank: ${selectedBank?.name}, Account: ${selectedBankDetail?.accountTitle}]';
        finalDescription = finalDescription.isEmpty ? bankInfo : '$bankInfo $finalDescription';
      }

      final data = {
        'id': initialExpense?.id,
        'expense_head_id': selectedHeadId,
        'amount': amount,
        'description': finalDescription.isNotEmpty ? finalDescription : null,
        'date': selectedDate.toIso8601String(),
        'branch_id': selectedBranchId ?? BusinessConfig.instance.branchId,
        'status': 1,
      };

      if (isEdit) {
        await _db.updateExpense(initialExpense!.id!, data);
      } else {
        await _db.insertExpense(data);
        
        // If paid via bank, record it in bank transactions too
        if (paymentMethod == 'Bank' && selectedBankDetail != null) {
          await _db.insertBankTransaction({
            'bank_id': selectedBank?.id,
            'account_title': selectedBankDetail?.accountTitle ?? '',
            'account_type': selectedBankDetail?.accountType ?? '',
            'account_number': selectedBankDetail?.accountNumber ?? '',
            'amount': amount,
            'transaction_type': 'Withdrawal',
            'remarks': 'Expense: ${descCtrl.text.trim()}',
            'date': selectedDate.toIso8601String(),
            'branch_id': selectedBranchId ?? BusinessConfig.instance.branchId,
            'status': 1,
          });
        }
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
