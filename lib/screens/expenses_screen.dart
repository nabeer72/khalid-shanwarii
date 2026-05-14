import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/expenses_controller.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/controllers/add_expense_controller.dart';
import 'package:mobile_app/models/bank.dart';
import 'package:mobile_app/models/bank_detail.dart';

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
            borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
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
                decoration: _buildDecoration('Category Name', isRequired: true),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
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

  Future<void> _showAddExpenseDialog([Expense? expense]) async {
    _showExpenseFormDialog(expense);
  }

  void _showExpenseFormDialog([Expense? expense]) {
    final controller = AddExpenseController(initialExpense: expense);
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          controller.addListener(() {
            if (ctx.mounted) setDialogState(() {});
          });

          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  controller.isEdit ? 'Edit Expense' : 'Record Expense',
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
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDialogSectionHeader('Transaction Details'),
                      _buildDialogTextField(
                        controller: controller.amountCtrl,
                        label: 'Amount (Cash Out)',
                        icon: Icons.money_off_rounded,
                        keyboardType: TextInputType.number,
                        isRequired: true,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Amount is required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              value: controller.expenseHeads.any((h) => h.id == controller.selectedHeadId)
                                  ? controller.selectedHeadId
                                  : null,
                              dropdownColor: theme.surface,
                              style: TextStyle(color: theme.textPrimary, fontSize: 13),
                              decoration: theme.glassInputDecoration('Expense Category', Icons.category_rounded, isRequired: true).copyWith(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                              items: controller.expenseHeads
                                  .map((h) => DropdownMenuItem<int?>(
                                        value: h.id,
                                        child: Text(h.name),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                controller.setCategory(val);
                                setDialogState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: theme.highlight.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              onPressed: () async {
                                await _showAddExpenseHeadDialog();
                                await controller.loadHeads();
                                setDialogState(() {});
                              },
                              icon: Icon(Icons.add_rounded, color: theme.highlight),
                              tooltip: 'Add Category',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: controller.selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: theme.highlight,
                                    onPrimary: Colors.white,
                                    surface: theme.surface,
                                    onSurface: theme.textPrimary,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null) {
                            controller.setDate(date);
                            setDialogState(() {});
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.background.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.textHint.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 18, color: theme.highlight),
                              const SizedBox(width: 12),
                              Text(
                                '${controller.selectedDate.day}/${controller.selectedDate.month}/${controller.selectedDate.year}',
                                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const Spacer(),
                              Text('CHANGE', style: TextStyle(color: theme.highlight, fontWeight: FontWeight.w900, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildDialogSectionHeader('Optional Description'),
                      _buildDialogTextField(
                        controller: controller.descCtrl,
                        label: 'Expense Description...',
                        icon: Icons.description_outlined,
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
                onPressed: controller.isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        final success = await controller.save(ctx);
                        if (success && ctx.mounted) {
                          Navigator.pop(ctx);
                          await _controller.loadData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(controller.isEdit ? 'Expense updated!' : 'Expense recorded!'),
                              backgroundColor: ThemeProvider.success,
                            ),
                          );
                        }
                      },
                child: controller.isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        controller.saveButtonLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogSectionHeader(String title) {
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

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
      validator: validator,
      decoration: theme.glassInputDecoration(label, icon, isRequired: isRequired).copyWith(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
    );
  }

  InputDecoration _buildDecoration(String label, {bool isRequired = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
      label: isRequired 
        ? RichText(
            text: TextSpan(
              text: label,
              style: TextStyle(color: Colors.black.withOpacity(0.6)),
              children: const [
                TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        : null,
      prefixIcon: Icon(Icons.label_rounded, color: theme.highlight),
      filled: true,
      fillColor: Colors.black.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList), borderSide: BorderSide.none),
    );
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
          if (_controller.isOnlineSearch)
            TextButton(
              onPressed: () => _controller.clearOnlineSearch(),
              child: const Text('LOCAL', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
        ],
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: theme.glassDecoration,
                  child: TextField(
                    onChanged: (v) => _controller.setSearch(v),
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search expenses...',
                      hintStyle: TextStyle(color: theme.textHint),
                      prefixIcon: Icon(Icons.search_rounded, color: theme.highlight),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              if (_controller.isOnlineSearch)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_done_rounded, color: theme.highlight, size: 14),
                      const SizedBox(width: 8),
                      Text('SHOWING RESULTS FROM SERVER', 
                        style: TextStyle(color: theme.highlight, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ],
                  ),
                ),
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
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL CASH FLOW OUT',
                              style: TextStyle(color: (theme.isDark ? Colors.white : Colors.black).withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
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
                        decoration: BoxDecoration(color: (theme.isDark ? Colors.white : Colors.black).withOpacity(0.1), borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                        child: Text(
                          '${_controller.expenseCount} entries',
                          style: TextStyle(color: theme.isDark ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.w800),
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
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: theme.glassDecoration,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                onTap: () => _showAddExpenseDialog(expense),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(expense.expenseHeadName ?? 'Uncategorized', 
                                        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                                  ),
                                  Text('${expense.date.day}/${expense.date.month}/${expense.date.year}',
                                      style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.w800)),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  expense.description?.isNotEmpty == true ? expense.description! : 'No description',
                                  style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${BusinessConfig.instance.currency}. ${expense.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(color: ThemeProvider.error, fontWeight: FontWeight.w900, fontSize: 13),
                                      ),
                                      if (_controller.isOnlineSearch)
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(color: theme.highlight.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                          child: Text('ONLINE', style: TextStyle(color: theme.highlight, fontSize: 7, fontWeight: FontWeight.w900)),
                                        ),
                                      Text(
                                        'EXPENSE',
                                        style: TextStyle(color: theme.textHint, fontSize: 8, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: ThemeProvider.error.withOpacity(0.5), size: 18),
                                    onPressed: () => _confirmDeleteExpense(expense),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
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
