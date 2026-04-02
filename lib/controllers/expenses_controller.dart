import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/services/sync_service.dart';

class ExpensesController with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<ExpenseHead> expenseHeads = [];
  List<Expense> expenses = [];

  bool _isLoading = true;
  String? _errorMessage;
  final SyncService _syncService = SyncService();
  bool isOnlineSearch = false;
  String query = '';

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
      final heads = headsData.map((h) => ExpenseHead.fromMap(h)).toList();
      final headMap = {for (var h in heads) h.id: h.name};
      expenseHeads = heads;

      if (query.isNotEmpty && !isOnlineSearch) {
        // Local Filter
        final localData = await _db.getExpenses();
        final q = query.toLowerCase();
        final localFiltered = localData.where((e) {
          final desc = (e['description'] ?? '').toString().toLowerCase();
          final headName = (headMap[e['expense_head_id']] ?? '').toLowerCase();
          final date = (e['date'] ?? '').toString().toLowerCase();
          return desc.contains(q) || headName.contains(q) || date.contains(q);
        }).toList();

        if (localFiltered.isEmpty) {
          final onlineData = await _syncService.searchOnline(query, 'expenses');
          if (onlineData.isNotEmpty) {
            expenses = onlineData.map((e) => Expense.fromMap(e, headName: headMap[e['expense_head_id']])).toList();
            isOnlineSearch = true;
          } else {
            expenses = [];
          }
        } else {
          expenses = localFiltered.map((e) => Expense.fromMap(e, headName: headMap[e['expense_head_id']])).toList();
        }
      } else if (isOnlineSearch) {
        final onlineData = await _syncService.searchOnline(query, 'expenses');
        expenses = onlineData.map((e) => Expense.fromMap(e, headName: headMap[e['expense_head_id']])).toList();
      } else {
        final expensesData = await _db.getExpenses();
        expenses = expensesData.map((e) => Expense.fromMap(e, headName: headMap[e['expense_head_id']])).toList();
      }
    } catch (e) {
      _errorMessage = 'Error loading expenses: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearch(String q) {
    query = q;
    if (q.isEmpty) isOnlineSearch = false;
    loadData();
  }

  void clearOnlineSearch() {
    isOnlineSearch = false;
    query = '';
    loadData();
  }

  Future<void> addExpenseHead(String name) async {
    if (name.trim().isEmpty) return;

    final head = {
      'name': name.trim(),
      'status': 1,
      'is_synced': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _db.insertExpenseHead(head);
    await loadData();
  }

  Future<void> deleteExpenseHead(int id) async {
    await _db.deleteExpenseHead(id);
    await loadData();
  }

  Future<void> addExpense({
    required int headId,
    required double amount,
    String? description,
    required DateTime date,
  }) async {
    final expense = {
      'expense_head_id': headId,
      'amount': amount,
      'description': description?.trim().isNotEmpty == true ? description!.trim() : null,
      'date': date.toIso8601String(),
      'status': 1,
      'is_synced': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _db.insertExpense(expense);
    await loadData();
  }

  Future<void> deleteExpense(int id) async {
    await _db.deleteExpense(id);
    await loadData();
  }
}
