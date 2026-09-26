import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/widgets/empty_state_icon.dart';
import 'package:mobile_app/models/bank_account.dart';
import 'package:intl/intl.dart';
import 'manage_banks_screen.dart';
import 'package:mobile_app/models/bank.dart';
import 'package:mobile_app/models/bank_detail.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:mobile_app/services/api_service.dart';
import 'dart:convert';

class BankManagementScreen extends StatefulWidget {
  const BankManagementScreen({super.key});

  @override
  State<BankManagementScreen> createState() => _BankManagementScreenState();
}

class _BankManagementScreenState extends State<BankManagementScreen> {
  final theme = ThemeProvider.instance;
  final _api = ApiService();
  List<BankAccount> _transactions = [];
  Map<int, String> _bankNames = {};
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String? _imagePath;

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
    final typeCtrl =
        TextEditingController(text: transaction?.accountType ?? '');
    final titleCtrl =
        TextEditingController(text: transaction?.accountTitle ?? '');
    final numberCtrl =
        TextEditingController(text: transaction?.accountNumber ?? '');
    final amountCtrl =
        TextEditingController(text: transaction?.amount.toString() ?? '');
    final remarksCtrl = TextEditingController(text: transaction?.remarks ?? '');
    final personCtrl =
        TextEditingController(text: transaction?.personName ?? '');
    String transType = transaction?.transactionType ?? 'Deposit';
    _selectedDate = transaction?.date ?? DateTime.now();
    _imagePath = transaction?.receiptImage;
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
                style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18),
              ),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: Icon(Icons.close_rounded,
                    color: theme.textSecondary, size: 20),
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
                    // Date Selection
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: theme.highlight,
                                onPrimary: Colors.white,
                                surface: theme.surface,
                                onSurface: theme.textPrimary,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setDialogState(() => _selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 15),
                        decoration: BoxDecoration(
                          color: theme.whiteAlpha(0.05),
                          borderRadius:
                              BorderRadius.circular(ThemeProvider.radiusInput),
                          border: Border.all(
                              color: theme.isDark
                                  ? Colors.transparent
                                  : Colors.black.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded,
                                color: theme.iconColor, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('MMM dd, yyyy').format(_selectedDate),
                              style: TextStyle(color: theme.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (banks.isNotEmpty) ...[
                      DropdownButtonFormField<Bank>(
                        value: selectedBank,
                        dropdownColor: theme.surface,
                        style: TextStyle(color: theme.textPrimary),
                        decoration: theme.glassInputDecoration(
                            'Select Bank', Icons.account_balance_rounded),
                        items: banks
                            .map((b) =>
                                DropdownMenuItem(value: b, child: Text(b.name)))
                            .toList(),
                        onChanged: (b) async {
                          selectedBank = b;
                          bankCtrl.text = b?.name ?? '';
                          final accData = await DatabaseHelper.instance
                              .getBankDetails(bankId: b?.id);
                          setDialogState(() {
                            accounts = accData
                                .map((d) => BankDetail.fromMap(d))
                                .toList();
                            if (accounts.length == 1) {
                              selectedAccount = accounts.first;
                              titleCtrl.text = selectedAccount!.accountTitle;
                              numberCtrl.text =
                                  selectedAccount!.accountNumber ?? '';
                              typeCtrl.text =
                                  selectedAccount!.accountType ?? '';
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
                          decoration: theme.glassInputDecoration(
                              'Select Account', Icons.credit_card_rounded),
                          items: accounts
                              .map((a) => DropdownMenuItem(
                                  value: a, child: Text(a.accountTitle)))
                              .toList(),
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
                      readOnly: selectedBank != null,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      isRequired: true,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      ctrl: titleCtrl,
                      label: 'Account Title',
                      icon: Icons.person_rounded,
                      readOnly: selectedAccount != null,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      isRequired: true,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                        ctrl: typeCtrl,
                        label: 'Account Type',
                        icon: Icons.category_rounded,
                        readOnly: selectedAccount != null),
                    const SizedBox(height: 12),
                    _buildDialogField(
                        ctrl: numberCtrl,
                        label: 'Account Number',
                        icon: Icons.numbers_rounded,
                        readOnly: selectedAccount != null),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: transType,
                      dropdownColor: theme.surface,
                      style: TextStyle(color: theme.textPrimary),
                      decoration: theme.glassInputDecoration(
                          'Transaction Type', Icons.swap_horiz_rounded),
                      items: ['Deposit', 'Withdrawal', 'Transfer']
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => transType = v!),
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      ctrl: personCtrl,
                      label: 'Person Name',
                      icon: Icons.person_pin_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      ctrl: amountCtrl,
                      label: 'Amount',
                      icon: Icons.attach_money_rounded,
                      isNumber: true,
                      isRequired: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.trim()) == null)
                          return 'Must be a number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                        ctrl: remarksCtrl,
                        label: 'Remarks',
                        icon: Icons.notes_rounded),
                    const SizedBox(height: 12),

                    // Image Upload
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Receipt Image (Optional)',
                          style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(
                                source: ImageSource.gallery);
                            if (pickedFile != null) {
                              setDialogState(
                                  () => _imagePath = pickedFile.path);
                            }
                          },
                          child: Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: theme.textHint.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(12),
                              color: theme.surface.withOpacity(0.5),
                            ),
                            child: _imagePath != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _imagePath!.startsWith('base64:')
                                        ? Image.memory(
                                            base64Decode(
                                                _imagePath!.substring(7)),
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, st) =>
                                                const Icon(
                                                    Icons.broken_image_rounded),
                                          )
                                        : (_imagePath!.startsWith('/') ||
                                                _imagePath!.contains(':'))
                                            ? Image.file(File(_imagePath!),
                                                fit: BoxFit.cover)
                                            : Image.network(
                                                '${ApiService.baseUrl.replaceAll('/api', '')}/storage/$_imagePath',
                                                fit: BoxFit.cover,
                                                errorBuilder: (ctx, err, st) =>
                                                    Container(
                                                  color: theme.surface,
                                                  child: const Center(
                                                      child: Icon(Icons
                                                          .broken_image_rounded)),
                                                ),
                                              ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo_rounded,
                                          color: theme.textHint),
                                      const SizedBox(height: 4),
                                      Text(
                                        transType == 'Transfer'
                                            ? 'Upload Transfer Receipt'
                                            : (transType == 'Withdrawal'
                                                ? 'Upload Cheque Image'
                                                : 'Upload Slip Image'),
                                        style: TextStyle(
                                            color: theme.textHint,
                                            fontSize: 10),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        if (_imagePath != null)
                          TextButton.icon(
                            onPressed: () =>
                                setDialogState(() => _imagePath = null),
                            icon: const Icon(Icons.delete_outline,
                                color: ThemeProvider.error, size: 16),
                            label: const Text('Remove Image',
                                style: TextStyle(
                                    color: ThemeProvider.error, fontSize: 11)),
                          ),
                      ],
                    ),
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
                  personName: personCtrl.text,
                  receiptImage: _imagePath,
                  date: _selectedDate,
                );

                // 1. Save/update locally
                // If transaction is not null, it's an update, so we keep the ID
                await DatabaseHelper.instance
                    .insertBankTransaction(newEntry.toMap());

                // 2. If editing an existing record, push update to live server immediately
                if (transaction?.id != null) {
                  final payload = {
                    'bank_id': newEntry.bankId,
                    'account_type': newEntry.accountType,
                    'account_title': newEntry.accountTitle,
                    'account_number': newEntry.accountNumber,
                    'amount': newEntry.amount,
                    'transaction_type': newEntry.transactionType,
                    'remarks': newEntry.remarks,
                    'person_name': newEntry.personName,
                    'receipt_image': newEntry.receiptImage,
                    'date': newEntry.date?.toIso8601String(),
                    'status': 1,
                  };
                  final success =
                      await _api.updateBankAccount(transaction!.id!, payload);

                  if (success) {
                    // Mark as synced locally if server update worked
                    await DatabaseHelper.instance.database.then((db) =>
                        db.update('bank_accounts', {'is_synced': 1},
                            where: 'id = ?', whereArgs: [transaction!.id]));
                  }
                }

                if (ctx.mounted) Navigator.pop(ctx);
                _loadTransactions();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.highlight,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                transaction == null ? 'SAVE ENTRY' : 'UPDATE',
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

  Widget _buildDialogField(
      {required TextEditingController ctrl,
      required String label,
      required IconData icon,
      bool isNumber = false,
      bool readOnly = false,
      bool isRequired = false,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      readOnly: readOnly,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters:
          isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: TextStyle(color: readOnly ? theme.textHint : theme.textPrimary),
      validator: validator,
      decoration: theme
          .glassInputDecoration(label, icon, isRequired: isRequired)
          .copyWith(
            fillColor: readOnly ? theme.surface.withOpacity(0.3) : null,
            filled: readOnly,
          ),
    );
  }

  void _showTransactionDetailsDialog(BankAccount t) {
    final bankName = _bankNames[t.bankId] ?? 'Unknown Bank';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Transaction Details',
                        style: TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.red),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Table(
                  border: TableBorder.all(
                      color: Colors.black12,
                      width: 1,
                      borderRadius: BorderRadius.circular(8)),
                  columnWidths: const {
                    0: FlexColumnWidth(1.2),
                    1: FlexColumnWidth(2.0),
                  },
                  children: [
                    _buildTableRow('Bank', bankName),
                    _buildTableRow('Account Title', t.accountTitle ?? 'N/A'),
                    _buildTableRow('Account Number', t.accountNumber ?? 'N/A'),
                    _buildTableRow('Person Name', t.personName ?? 'N/A'),
                    _buildTableRow('Type', t.transactionType ?? 'N/A'),
                    _buildTableRow('Amount',
                        '${BusinessConfig.instance.currency}. ${t.amount}'),
                    _buildTableRow(
                        'Date',
                        DateFormat('MMM dd, yyyy')
                            .format(t.date ?? DateTime.now())),
                    _buildTableRow('Remarks', t.remarks ?? 'N/A'),
                  ],
                ),
                if (t.receiptImage != null && t.receiptImage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Receipt Image:',
                      style: TextStyle(
                          color: Colors.black54, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: t.receiptImage!.startsWith('base64:')
                        ? Image.memory(
                            base64Decode(t.receiptImage!.substring(7)),
                            fit: BoxFit.contain)
                        : (t.receiptImage!.startsWith('/') ||
                                t.receiptImage!.contains(':'))
                            ? Image.file(File(t.receiptImage!),
                                fit: BoxFit.contain)
                            : Image.network(
                                '${ApiService.baseUrl.replaceAll('/api', '')}/storage/${t.receiptImage}',
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, err, st) => const Icon(
                                    Icons.broken_image_rounded,
                                    color: Colors.black54),
                              ),
                  ),
                ],
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text(
                      'EDIT TRANSACTION',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showTransactionDialog(t);
                    },
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
        ),
      ),
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(value,
              style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ),
      ],
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
          style: TextStyle(
              color: theme.textPrimary,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
        actions: [
          IconButton(
            icon:
                Icon(Icons.settings_suggest_rounded, color: theme.textPrimary),
            tooltip: 'Manage Banks & Accounts',
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => const ManageBanksScreen(),
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
                            const EmptyStateIcon(icon: Icons.account_balance_rounded),
                          const SizedBox(height: 16),
                          Text('No bank entries found',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: theme.textPrimary,
                                  fontWeight: FontWeight.bold)),
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
                          decoration: theme.glassListDecoration,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            onTap: () => _showTransactionDetailsDialog(t),
                            title: Text(
                              t.accountTitle ?? 'Unknown Account',
                              style: TextStyle(
                                  color: theme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${t.personName != null && t.personName!.isNotEmpty ? t.personName : ""} ${t.personName != null && t.personName!.isNotEmpty && t.accountNumber != null && t.accountNumber!.isNotEmpty ? "|" : ""} ${t.accountNumber ?? ""}'
                                    .trim(),
                                style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
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
                                        color: isWithdrawal
                                            ? ThemeProvider.error
                                            : ThemeProvider.success,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      (t.transactionType ?? "").toUpperCase(),
                                      style: TextStyle(
                                          color: theme.textHint,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: ThemeProvider.error, size: 18),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: theme.surface,
                                        title: Text('Delete Entry?',
                                            style: TextStyle(
                                                color: theme.textPrimary)),
                                        content: Text(
                                            'Are you sure you want to delete this bank entry?',
                                            style: TextStyle(
                                                color: theme.textSecondary)),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: Text('CANCEL',
                                                  style: TextStyle(
                                                      color: theme
                                                          .textSecondary))),
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('DELETE',
                                                  style: TextStyle(
                                                      color: ThemeProvider
                                                          .error))),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      bool serverDeleted = false;
                                      bool recordMissingOnServer = false;
                                      // 1. Delete on live server immediately
                                      if (t.id != null) {
                                        try {
                                          serverDeleted = await _api
                                              .deleteBankAccount(t.id!);
                                        } catch (e) {
                                          // If server returns 404, it means the record is already gone or never existed there
                                          recordMissingOnServer = true;
                                        }

                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                            content: Text(serverDeleted
                                                ? ' Deleted Sucessfully'
                                                : (recordMissingOnServer
                                                    ? ' Record already removed from server'
                                                    : '⚠️ Server delete failed – check logs')),
                                            backgroundColor: serverDeleted
                                                ? Colors.green
                                                : (recordMissingOnServer
                                                    ? Colors.blue
                                                    : Colors.red),
                                            duration:
                                                const Duration(seconds: 3),
                                          ));
                                        }
                                      }
                                      // 2. Delete locally
                                      // If server delete was successful OR if it was already missing on the server, hard delete it locally
                                      await DatabaseHelper.instance
                                          .deleteBankTransaction(t.id ?? 0,
                                              hardDelete: serverDeleted ||
                                                  recordMissingOnServer);
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
        label: const Text('ADD ENTRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: theme.highlight,
        foregroundColor: Colors.white,
      ),
    );
  }
}
