import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/controllers/expenses_controller.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/screens/add_expense_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late ExpensesController _controller;
  final theme = ThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _controller = ExpensesController();
    _controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    super.dispose();
  }

  Future<void> _showAddExpenseHeadDialog() async {
    final nameCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Expense Category',
                style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  labelStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.label_rounded, color: theme.highlight),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('CANCEL', style: TextStyle(color: Colors.black.withOpacity(0.6), fontWeight: FontWeight.w900)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeProvider.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await _controller.addExpenseHead(nameCtrl.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('SAVE CATEGORY', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddExpenseDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
    );
    if (result == true) {
      await _controller.loadData();
    }
  }

  Future<void> _confirmDeleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Delete Expense?', style: TextStyle(color: theme.textPrimary)),
        content: Text('Are you sure you want to delete this expense?', style: TextStyle(color: theme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThemeProvider.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (expense.id != null) await _controller.deleteExpense(expense.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted'), backgroundColor: ThemeProvider.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: theme.highlight)),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Business Expenses',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.category_rounded, color: theme.iconColor),
            onPressed: _showAddExpenseHeadDialog,
            tooltip: 'Manage Expense Heads',
          ),
          IconButton(
            icon: Icon(theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: theme.iconColor),
            onPressed: () => setState(() => theme.toggleTheme()),
          ),
        ],
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Summary Card
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: theme.glassDecoration.copyWith(
                    gradient: const LinearGradient(
                      colors: ThemeProvider.gradientDanger,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL CASH FLOW OUT',
                              style: TextStyle(color: (theme.isDark ? Colors.white : Colors.black).withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _controller.formattedTotal,
                              style: TextStyle(color: theme.isDark ? Colors.white : Colors.black, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: (theme.isDark ? Colors.white : Colors.black).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          '${_controller.expenseCount} entries',
                          style: TextStyle(color: theme.isDark ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Expenses List
              Expanded(
                child: _controller.expenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: theme.glassCircleDecoration,
                              child: Icon(Icons.receipt_long_rounded, size: 60, color: theme.iconColor),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No expenses listed',
                              style: TextStyle(fontSize: 18, color: theme.textPrimary, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Keep track of your overhead costs here',
                              style: TextStyle(fontSize: 14, color: theme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: _controller.expenses.length,
                        itemBuilder: (context, index) {
                          final expense = _controller.expenses[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              decoration: theme.glassDecoration,
                            child: InkWell(
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AddExpenseScreen(expense: expense)),
                                );
                                if (result == true) {
                                  await _controller.loadData();
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: ThemeProvider.error.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.money_off_rounded, color: ThemeProvider.error),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            expense.expenseHeadName ?? 'Uncategorized',
                                            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                                          ),
                                          if (expense.description != null && expense.description!.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              expense.description!,
                                              style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.event_note_rounded, size: 10, color: theme.iconColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                                                style: TextStyle(color: theme.textHint, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${BusinessConfig.instance.currency}. ${expense.amount.toStringAsFixed(2)}',
                                          style: const TextStyle(color: ThemeProvider.error, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
                                        ),
                                        const SizedBox(height: 4),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline_rounded, color: ThemeProvider.error.withOpacity(0.5), size: 20),
                                          onPressed: () => _confirmDeleteExpense(expense),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        backgroundColor: theme.highlight,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('ADD EXPENSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }
}
