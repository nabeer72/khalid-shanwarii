import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/models/bank_account.dart';
import 'package:intl/intl.dart';
import 'manage_banks_screen.dart';
import 'package:mobile_app/models/bank.dart';
import 'package:mobile_app/models/bank_detail.dart';

class BankManagementScreen extends StatefulWidget {
  const BankManagementScreen({super.key});

  @override
  State<BankManagementScreen> createState() => _BankManagementScreenState();
}

class _BankManagementScreenState extends State<BankManagementScreen> {
  final theme = ThemeProvider.instance;
  List<BankAccount> _transactions = [];
  Map<int, String> _bankNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    
    // Load bank names mapping
    final bankData = await DatabaseHelper.instance.getBanks();
    final Map<int, String> namesMap = {};
    for (var b in bankData) {
      final id = b['id'] as int;
      namesMap[id] = b['name'] as String;
    }

    final data = await DatabaseHelper.instance.getBankTransactions();
    if (mounted) {
      setState(() {
        _bankNames = namesMap;
        _transactions = data.map((t) => BankAccount.fromMap(t)).toList();
        _isLoading = false;
      });
    }
  }

  void _showTransactionDialog([BankAccount? transaction]) async {
    final theme = ThemeProvider.instance;
    final bankCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: transaction?.accountType ?? '');
    final titleCtrl = TextEditingController(text: transaction?.accountTitle ?? '');
    final numberCtrl = TextEditingController(text: transaction?.accountNumber ?? '');
    final amountCtrl = TextEditingController(text: transaction?.amount.toString() ?? '');
    final remarksCtrl = TextEditingController(text: transaction?.remarks ?? '');
    String transType = transaction?.transactionType ?? 'Deposit';
    final formKey = GlobalKey<FormState>();

    // Master data for dropdowns
    List<Bank> banks = [];
    List<BankDetail> accounts = [];
    Bank? selectedBank;
    BankDetail? selectedAccount;

    // Load banks
    final bankData = await DatabaseHelper.instance.getBanks();
    banks = bankData.map((b) => Bank.fromMap(b)).toList();
    if (transaction != null && transaction.bankId != null) {
      try {
        selectedBank = banks.firstWhere((b) => b.id == transaction.bankId);
        bankCtrl.text = selectedBank.name;
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.surface,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                transaction == null ? 'Add Bank Entry' : 'Edit Bank Entry',
                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
              ),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: Icon(Icons.close_rounded, color: theme.textSecondary, size: 20),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (banks.isNotEmpty) ...[
                    DropdownButtonFormField<Bank>(
                      value: selectedBank,
                      dropdownColor: theme.surface,
                      style: TextStyle(color: theme.textPrimary),
                      decoration: theme.glassInputDecoration('Select Bank', Icons.account_balance_rounded),
                      items: banks.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
                      onChanged: (b) async {
                        selectedBank = b;
                        bankCtrl.text = b?.name ?? '';
                        final accData = await DatabaseHelper.instance.getBankDetails(bankId: b?.id);
                        setDialogState(() {
                          accounts = accData.map((d) => BankDetail.fromMap(d)).toList();
                          if (accounts.length == 1) {
                            selectedAccount = accounts.first;
                            titleCtrl.text = selectedAccount!.accountTitle;
                            numberCtrl.text = selectedAccount!.accountNumber ?? '';
                            typeCtrl.text = selectedAccount!.accountType ?? '';
                          } else {
                            selectedAccount = null;
                            titleCtrl.text = '';
                            numberCtrl.text = '';
                            typeCtrl.text = '';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedBank != null) ...[
                      DropdownButtonFormField<BankDetail>(
                        value: selectedAccount,
                        dropdownColor: theme.surface,
                        style: TextStyle(color: theme.textPrimary),
                        decoration: theme.glassInputDecoration('Select Account', Icons.credit_card_rounded),
                        items: accounts.map((a) => DropdownMenuItem(value: a, child: Text(a.accountTitle))).toList(),
                        onChanged: (a) {
                          setDialogState(() {
                            selectedAccount = a;
                            titleCtrl.text = a?.accountTitle ?? '';
                            numberCtrl.text = a?.accountNumber ?? '';
                            typeCtrl.text = a?.accountType ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                  _buildDialogField(
                    ctrl: bankCtrl, 
                    label: 'Bank Name', 
                    icon: Icons.account_balance_outlined,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField(
                    ctrl: titleCtrl, 
                    label: 'Account Title', 
                    icon: Icons.person_rounded,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField(ctrl: typeCtrl, label: 'Account Type', icon: Icons.category_rounded),
                  const SizedBox(height: 12),
                  _buildDialogField(ctrl: numberCtrl, label: 'Account Number', icon: Icons.numbers_rounded),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: transType,
                    dropdownColor: theme.surface,
                    style: TextStyle(color: theme.textPrimary),
                    decoration: theme.glassInputDecoration('Transaction Type', Icons.swap_horiz_rounded),
                    items: ['Deposit', 'Withdrawal', 'Transfer']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => transType = v!),
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField(
                    ctrl: amountCtrl, 
                    label: 'Amount', 
                    icon: Icons.attach_money_rounded, 
                    isNumber: true,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v.trim()) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField(ctrl: remarksCtrl, label: 'Remarks', icon: Icons.notes_rounded),
                ],
              ),
            ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL', style: TextStyle(color: theme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                
                final newEntry = BankAccount(
                  id: transaction?.id,
                  bankId: selectedBank?.id,
                  accountType: typeCtrl.text,
                  accountTitle: titleCtrl.text,
                  accountNumber: numberCtrl.text,
                  amount: double.tryParse(amountCtrl.text.trim()) ?? 0.0,
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

  Widget _buildDialogField({
    required TextEditingController ctrl, 
    required String label, 
    required IconData icon, 
    bool isNumber = false, 
    String? Function(String?)? validator
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: TextStyle(color: theme.textPrimary),
      validator: validator,
      decoration: theme.glassInputDecoration(label, icon),
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
        actions: [
          IconButton(
            icon: Icon(Icons.settings_suggest_rounded, color: theme.textPrimary),
            tooltip: 'Manage Banks & Accounts',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ManageBanksScreen()),
            ).then((_) => _loadTransactions()),
          ),
          const SizedBox(width: 8),
        ],
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
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: theme.glassDecoration,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            onTap: () => _showTransactionDialog(t),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(_bankNames[t.bankId] ?? 'Bank ID: ${t.bankId}', 
                                      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                                ),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(t.date ?? DateTime.now()),
                                  style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${t.accountTitle} | ${t.accountNumber ?? ""}',
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
                                      '${isWithdrawal ? "-" : "+"}${BusinessConfig.instance.currency}. ${t.amount}',
                                      style: TextStyle(
                                        color: isWithdrawal ? ThemeProvider.error : ThemeProvider.success,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      (t.transactionType ?? "").toUpperCase(),
                                      style: TextStyle(color: theme.textHint, fontSize: 8, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: ThemeProvider.error, size: 18),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: theme.surface,
                                        title: Text('Delete Entry?', style: TextStyle(color: theme.textPrimary)),
                                        content: Text('Are you sure you want to delete this bank entry?', style: TextStyle(color: theme.textSecondary)),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('CANCEL', style: TextStyle(color: theme.textSecondary))),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: ThemeProvider.error))),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await DatabaseHelper.instance.deleteBankTransaction(t.id ?? 0);
                                      _loadTransactions();
                                    }
                                  },
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