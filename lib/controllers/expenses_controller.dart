import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:uuid/uuid.dart';

class ExpensesController with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  List<ExpenseHead> expenseHeads = [];
  List<Expense> expenses = [];

  bool _isLoading = true;
  String? _errorMessage;

  ExpensesController() {
    loadData();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get totalExpenses => expenses.fold(0.0, (sum, e) => sum + e.amount);

  String get formattedTotal => 
      '${BusinessConfig.instance.currency}. ${totalExpenses.toStringAsFixed(2)}';

  int get expenseCount => expenses.length;

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final headsData = await _db.getExpenseHeads();
      final expensesData = await _db.getExpenses();

      final heads = headsData.map((h) => ExpenseHead.fromMap(h)).toList();
      final headMap = {for (var h in heads) h.id: h.name};

      expenseHeads = heads;
      expenses = expensesData.map((e) => Expense.fromMap(e, headName: headMap[e['expense_head_id']])).toList();

    } catch (e) {
      _errorMessage = 'Error loading expenses: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addExpenseHead(String name) async {
    if (name.trim().isEmpty) return;

    final head = {
      'id': _uuid.v4(),
      'name': name.trim(),
      'status': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _db.insertExpenseHead(head);
    await loadData();
  }

  Future<void> deleteExpenseHead(String id) async {
    await _db.deleteExpenseHead(id);
    await loadData();
  }

  Future<void> addExpense({
    required String headId,
    required double amount,
    String? description,
    required DateTime date,
  }) async {
    final expense = {
      'id': _uuid.v4(),
      'expense_head_id': headId,
      'amount': amount,
      'description': description?.trim().isNotEmpty == true ? description!.trim() : null,
      'date': date.toIso8601String(),
      'status': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _db.insertExpense(expense);
    await loadData();
  }

  Future<void> deleteExpense(String id) async {
    await _db.deleteExpense(id);
    await loadData();
  }
}