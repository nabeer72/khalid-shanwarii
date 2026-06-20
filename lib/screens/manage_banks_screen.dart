import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/models/bank.dart';
import 'package:mobile_app/models/bank_detail.dart';

class ManageBanksScreen extends StatefulWidget {
  const ManageBanksScreen({super.key});

  @override
  State<ManageBanksScreen> createState() => _ManageBanksScreenState();
}

class _ManageBanksScreenState extends State<ManageBanksScreen> {
  final theme = ThemeProvider.instance;
  List<Bank> _banks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getBanks();
    if (mounted) {
      setState(() {
        _banks = data.map((b) => Bank.fromMap(b)).toList();
        _isLoading = false;
      });
    }
  }

  void _showBankDialog([Bank? bank]) {
    final nameCtrl = TextEditingController(text: bank?.name ?? '');

    // Active controllers for the currently being edited account
    final activeTitleCtrl = TextEditingController();
    final activeNumberCtrl = TextEditingController();
    final activeTypeCtrl = TextEditingController();

    // List of "Pushed" accounts
    List<Map<String, String>> stagedAccounts = [];

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.surface,
          title: Text(bank == null ? 'Add Bank' : 'Edit Bank',
              style: TextStyle(color: theme.textPrimary)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      style: TextStyle(color: theme.textPrimary),
                      decoration: theme.glassInputDecoration(
                          'Bank Name', Icons.account_balance_rounded),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    if (bank == null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: theme.highlight.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.add_circle_outline_rounded,
                                    size: 20, color: theme.highlight),
                                const SizedBox(width: 8),
                                Text('Add Account Details',
                                    style: TextStyle(
                                        color: theme.highlight,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: activeTitleCtrl,
                              style: TextStyle(color: theme.textPrimary),
                              decoration: theme.glassInputDecoration(
                                  'Account Title', Icons.person_rounded),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: activeNumberCtrl,
                              style: TextStyle(color: theme.textPrimary),
                              decoration: theme.glassInputDecoration(
                                  'Account Number', Icons.numbers_rounded),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: activeTypeCtrl,
                              style: TextStyle(color: theme.textPrimary),
                              decoration: theme.glassInputDecoration(
                                  'Account Type (e.g. Savings)',
                                  Icons.category_rounded),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (activeTitleCtrl.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Account Title is required to add.')));
                                    return;
                                  }
                                  setDialogState(() {
                                    stagedAccounts.add({
                                      'title': activeTitleCtrl.text.trim(),
                                      'number': activeNumberCtrl.text.trim(),
                                      'type': activeTypeCtrl.text.trim(),
                                    });
                                    activeTitleCtrl.clear();
                                    activeNumberCtrl.clear();
                                    activeTypeCtrl.clear();
                                  });
                                },
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add Account to List'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.highlight,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (stagedAccounts.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(Icons.list_alt_rounded,
                                size: 16, color: theme.textSecondary),
                            const SizedBox(width: 8),
                            Text('Added Accounts (${stagedAccounts.length})',
                                style: TextStyle(
                                    color: theme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ],
                        ),
                        const Divider(),
                        ...stagedAccounts.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final acc = entry.value;
                          return Card(
                            color: theme.surface.withOpacity(0.5),
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              dense: true,
                              title: Text(acc['title']!,
                                  style: TextStyle(
                                      color: theme.textPrimary,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  '${acc['number']} - ${acc['type']}',
                                  style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 11)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 18, color: Colors.redAccent),
                                onPressed: () => setDialogState(
                                    () => stagedAccounts.removeAt(idx)),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL',
                  style: TextStyle(
                      color: theme.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.highlight,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // Include current active account if it has a title
                  if (activeTitleCtrl.text.trim().isNotEmpty) {
                    stagedAccounts.add({
                      'title': activeTitleCtrl.text.trim(),
                      'number': activeNumberCtrl.text.trim(),
                      'type': activeTypeCtrl.text.trim(),
                    });
                  }

                  if (stagedAccounts.isEmpty && bank == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('At least one account is required.')));
                    return;
                  }

                  final data = {
                    if (bank != null) 'id': bank.id,
                    'name': nameCtrl.text.trim(),
                  };
                  final bankId = await DatabaseHelper.instance.insertBank(data);

                  // Save all staged accounts
                  if (bank == null) {
                    for (var acc in stagedAccounts) {
                      await DatabaseHelper.instance.insertBankDetail({
                        'bank_id': bankId,
                        'account_title': acc['title'],
                        'account_number': acc['number'],
                        'account_type': acc['type'],
                      });
                    }
                  }

                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadBanks();
                  }
                }
              },
              child: Text(
                bank == null ? 'SAVE ALL RECORDS' : 'UPDATE BANK',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountsDialog(Bank bank) {
    showDialog(
      context: context,
      builder: (ctx) => _AccountsListDialog(bank: bank),
    ).then((_) => _loadBanks());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Manage Banks',
                    style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: theme.textPrimary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: theme.highlight))
                  : _banks.isEmpty
                      ? Center(
                          child: Text('No banks added yet',
                              style: TextStyle(color: theme.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _banks.length,
                          itemBuilder: (context, index) {
                            final bank = _banks[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: theme.glassListDecoration,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      theme.highlight.withOpacity(0.1),
                                  child: Icon(Icons.account_balance_rounded,
                                      color: theme.highlight),
                                ),
                                title: Text(bank.name,
                                    style: TextStyle(
                                        color: theme.textPrimary,
                                        fontWeight: FontWeight.w800)),
                                subtitle: Text('Manage accounts',
                                    style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 12)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_rounded,
                                          color: theme.textSecondary, size: 20),
                                      onPressed: () => _showBankDialog(bank),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                          size: 20),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: theme.surface,
                                            title: Text('Delete Bank?',
                                                style: TextStyle(
                                                    color: theme.textPrimary,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            content: Text(
                                                'This will delete all associated accounts.',
                                                style: TextStyle(
                                                    color:
                                                        theme.textSecondary)),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: Text('Cancel',
                                                      style: TextStyle(
                                                          color: theme
                                                              .textSecondary))),
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('Delete',
                                                      style: TextStyle(
                                                          color: Colors.red))),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await DatabaseHelper.instance
                                              .deleteBank(bank.id!);
                                          _loadBanks();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () => _showAccountsDialog(bank),
                              ),
                            );
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.highlight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showBankDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'ADD NEW BANK',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsListDialog extends StatefulWidget {
  final Bank bank;
  const _AccountsListDialog({required this.bank});

  @override
  State<_AccountsListDialog> createState() => _AccountsListDialogState();
}

class _AccountsListDialogState extends State<_AccountsListDialog> {
  final theme = ThemeProvider.instance;
  List<BankDetail> _details = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    final data =
        await DatabaseHelper.instance.getBankDetails(bankId: widget.bank.id);
    if (mounted) {
      setState(() {
        _details = data.map((d) => BankDetail.fromMap(d)).toList();
        _isLoading = false;
      });
    }
  }

  void _showAccountDialog([BankDetail? detail]) {
    final titleCtrl = TextEditingController(text: detail?.accountTitle ?? '');
    final numberCtrl = TextEditingController(text: detail?.accountNumber ?? '');
    final typeCtrl = TextEditingController(text: detail?.accountType ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text(detail == null ? 'Add Account' : 'Edit Account',
            style: TextStyle(color: theme.textPrimary)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleCtrl,
                style: TextStyle(color: theme.textPrimary),
                decoration: theme.glassInputDecoration(
                    'Account Title', Icons.person_rounded),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: numberCtrl,
                style: TextStyle(color: theme.textPrimary),
                decoration: theme.glassInputDecoration(
                    'Account Number', Icons.numbers_rounded),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: typeCtrl,
                style: TextStyle(color: theme.textPrimary),
                decoration: theme.glassInputDecoration(
                    'Account Type (SB, Current, etc.)', Icons.category_rounded),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: TextStyle(
                    color: theme.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.highlight,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final data = {
                  if (detail != null) 'id': detail.id,
                  'bank_id': widget.bank.id,
                  'account_title': titleCtrl.text.trim(),
                  'account_number': numberCtrl.text.trim(),
                  'account_type': typeCtrl.text.trim(),
                };
                await DatabaseHelper.instance.insertBankDetail(data);
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadDetails();
                }
              }
            },
            child: Text(
              detail == null ? 'SAVE ACCOUNT' : 'UPDATE ACCOUNT',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: theme.surface,
      title: Text('Accounts: ${widget.bank.name}',
          style: TextStyle(color: theme.textPrimary)),
      content: SizedBox(
        width: 400,
        height: 500,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: theme.highlight))
            : Column(
                children: [
                  Expanded(
                    child: _details.isEmpty
                        ? Center(
                            child: Text('No accounts added',
                                style: TextStyle(color: theme.textSecondary)))
                        : ListView.builder(
                            itemCount: _details.length,
                            itemBuilder: (context, index) {
                              final d = _details[index];
                              return ListTile(
                                title: Text(d.accountTitle,
                                    style: TextStyle(color: theme.textPrimary)),
                                subtitle: Text(d.accountNumber ?? 'No Number',
                                    style:
                                        TextStyle(color: theme.textSecondary)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_rounded,
                                          color: theme.textSecondary, size: 18),
                                      onPressed: () => _showAccountDialog(d),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                          size: 18),
                                      onPressed: () async {
                                        await DatabaseHelper.instance
                                            .deleteBankDetail(d.id!);
                                        _loadDetails();
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.highlight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showAccountDialog(),
                      icon: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 18),
                      label: const Text(
                        'ADD NEW ACCOUNT',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }
}
