import 'package:flutter/material.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:mobile_app/models/bank_account.dart';
import 'package:intl/intl.dart';

class BankManagementScreen extends StatefulWidget {
  const BankManagementScreen({super.key});

  @override
  State<BankManagementScreen> createState() => _BankManagementScreenState();
}

class _BankManagementScreenState extends State<BankManagementScreen> {
  final theme = ThemeProvider.instance;
  List<BankAccount> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getBankTransactions();
    if (mounted) {
      setState(() {
        _transactions = data.map((t) => BankAccount.fromMap(t)).toList();
        _isLoading = false;
      });
    }
  }

  void _showTransactionDialog([BankAccount? transaction]) {
    final bankCtrl = TextEditingController(text: transaction?.bankName ?? '');
    final typeCtrl = TextEditingController(text: transaction?.accountType ?? '');
    final titleCtrl = TextEditingController(text: transaction?.accountTitle ?? '');
    final numberCtrl = TextEditingController(text: transaction?.accountNumber ?? '');
    final amountCtrl = TextEditingController(text: transaction?.amount.toString() ?? '');
    final remarksCtrl = TextEditingController(text: transaction?.remarks ?? '');
    String transType = transaction?.transactionType ?? 'Deposit';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.surface,
          title: Text(transaction == null ? 'Add Bank Entry' : 'Edit Entry',
              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(bankCtrl, 'Bank Name', Icons.account_balance_rounded),
                const SizedBox(height: 12),
                _buildDialogField(titleCtrl, 'Account Title', Icons.person_rounded),
                const SizedBox(height: 12),
                _buildDialogField(typeCtrl, 'Account Type', Icons.category_rounded),
                const SizedBox(height: 12),
                _buildDialogField(numberCtrl, 'Account Number', Icons.numbers_rounded),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: transType,
                  dropdownColor: theme.surface,
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Transaction Type',
                    labelStyle: TextStyle(color: theme.textSecondary),
                    prefixIcon: Icon(Icons.swap_horiz_rounded, color: theme.iconColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: ['Deposit', 'Withdrawal', 'Transfer']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => transType = v!),
                ),
                const SizedBox(height: 12),
                _buildDialogField(amountCtrl, 'Amount', Icons.attach_money_rounded, isNumber: true),
                const SizedBox(height: 12),
                _buildDialogField(remarksCtrl, 'Remarks', Icons.notes_rounded),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL', style: TextStyle(color: theme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (bankCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                
                final newEntry = BankAccount(
                  id: transaction?.id ?? const Uuid().v4(),
                  bankName: bankCtrl.text,
                  accountType: typeCtrl.text,
                  accountTitle: titleCtrl.text,
                  accountNumber: numberCtrl.text,
                  amount: double.tryParse(amountCtrl.text) ?? 0.0,
                  transactionType: transType,
                  remarks: remarksCtrl.text,
                  date: transaction?.date ?? DateTime.now(),
                );

                await DatabaseHelper.instance.insertBankTransaction(newEntry.toMap());
                Navigator.pop(ctx);
                _loadTransactions();
              },
              style: ElevatedButton.styleFrom(backgroundColor: theme.highlight),
              child: Text(transaction == null ? 'SAVE ENTRY' : 'UPDATE', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: TextStyle(color: theme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.textSecondary),
        prefixIcon: Icon(icon, color: theme.iconColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Bank Account Management',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: theme.highlight))
              : _transactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_rounded, size: 80, color: theme.iconColor.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text('No bank entries found', 
                              style: TextStyle(fontSize: 18, color: theme.textPrimary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Record your bank transactions here', 
                              style: TextStyle(color: theme.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _transactions.length,
                      itemBuilder: (ctx, i) {
                        final t = _transactions[i];
                        final isWithdrawal = t.transactionType == 'Withdrawal';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: theme.glassDecoration,
                          child: ListTile(
                            onTap: () => _showTransactionDialog(t),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (isWithdrawal ? Colors.redAccent : Colors.greenAccent).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isWithdrawal ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                color: isWithdrawal ? Colors.redAccent : Colors.greenAccent,
                              ),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(t.bankName, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
                                Text(
                                  '${isWithdrawal ? "-" : "+"}${BusinessConfig.instance.currency}. ${t.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: isWithdrawal ? Colors.redAccent : Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${t.accountTitle} • ${t.accountNumber ?? ""}',
                                    style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded, size: 10, color: theme.iconColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      t.date != null ? DateFormat('MMM dd, yyyy').format(t.date!) : "No date",
                                      style: TextStyle(color: theme.textSecondary, fontSize: 10),
                                    ),
                                    const Spacer(),
                                    if (t.remarks != null && t.remarks!.isNotEmpty)
                                      Icon(Icons.info_outline_rounded, size: 12, color: theme.highlight),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Entry?'),
                                    content: const Text('Are you sure you want to delete this bank entry?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.redAccent))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await DatabaseHelper.instance.deleteBankTransaction(t.id);
                                  _loadTransactions();
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTransactionDialog(),
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('ADD ENTRY'),
        backgroundColor: theme.highlight,
      ),
    );
  }
}
