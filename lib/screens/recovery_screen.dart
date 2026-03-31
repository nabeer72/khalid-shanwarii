import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:intl/intl.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final theme = ThemeProvider.instance;
  List<Customer> _customersWithCredit = [];
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomersWithCredit();
  }

  Future<void> _loadCustomersWithCredit() async {
    setState(() => _loading = true);
    try {
      final data = await DatabaseHelper.instance.getCustomersWithCredit();
      if (mounted) {
        setState(() {
          _customersWithCredit = data.map((c) => Customer.fromMap(c)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading customers with credit: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Customer> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customersWithCredit;
    return _customersWithCredit.where((c) =>
      c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (c.phone?.contains(_searchQuery) ?? false)
    ).toList();
  }

  Future<void> _showRecoveryForm(Customer customer) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final balance = await DatabaseHelper.instance.getCustomerCreditBalance(customer.id ?? 0);
    final employees = await DatabaseHelper.instance.getEmployees();
    
    if (mounted) Navigator.pop(context); // close loading

    String? selectedStaff = employees.isNotEmpty ? employees.first['name'] : null;
    DateTime selectedDate = DateTime.now();
    final receivedAmountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          double receivedAmount = double.tryParse(receivedAmountCtrl.text) ?? 0.0;
          double remainingBalance = balance - receivedAmount;

          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Record Payment',
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
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: theme.highlight.withOpacity(0.1),
                            child: Text(customer.name[0].toUpperCase(), style: TextStyle(color: theme.highlight, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(customer.name, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800)),
                                Text('ID: ${customer.id}', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('CREDIT', style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text('${BusinessConfig.instance.currencyDisplay} ${balance.toStringAsFixed(2)}', style: const TextStyle(color: ThemeProvider.warning, fontWeight: FontWeight.bold)),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: theme.whiteAlpha(0.1)),
                      const SizedBox(height: 16),

                      Text('PAYMENT DATE', style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setDialogState(() => selectedDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: theme.glassDecoration,
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, color: theme.highlight, size: 20),
                              const SizedBox(width: 12),
                              Text(DateFormat('MMM dd, yyyy').format(selectedDate), style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Text('RECEIVED BY', style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedStaff,
                        dropdownColor: theme.surface,
                        style: TextStyle(color: theme.textPrimary, fontSize: 13),
                        decoration: theme.glassInputDecoration('Select Staff', Icons.person_rounded).copyWith(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                        items: employees.map((staff) => DropdownMenuItem<String>(value: staff['name'], child: Text(staff['name']))).toList(),
                        onChanged: (v) => setDialogState(() => selectedStaff = v),
                      ),
                      const SizedBox(height: 16),

                      Text('RECEIVED AMOUNT', style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: receivedAmountCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                        decoration: theme.glassInputDecoration('Amount', Icons.payments_rounded).copyWith(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                        onChanged: (v) => setDialogState(() {}),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      if (receivedAmount > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('REMAINING BALANCE', style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w800)),
                            Text('${BusinessConfig.instance.currencyDisplay} ${remainingBalance.toStringAsFixed(2)}', 
                              style: TextStyle(color: remainingBalance > 0 ? ThemeProvider.warning : ThemeProvider.success, fontWeight: FontWeight.w900, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      Text('NOTE (OPTIONAL)', style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: noteCtrl,
                        maxLines: 2,
                        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                        decoration: theme.glassInputDecoration('Add a note', Icons.note_rounded).copyWith(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
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
                  backgroundColor: ThemeProvider.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSaving ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  if (selectedStaff == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a staff member'), backgroundColor: ThemeProvider.error));
                    return;
                  }
                  if (receivedAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid payment amount'), backgroundColor: ThemeProvider.error));
                    return;
                  }
                  if (receivedAmount > balance) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment amount cannot exceed credit balance'), backgroundColor: ThemeProvider.error));
                    return;
                  }

                  setDialogState(() => isSaving = true);

                  final payment = {
                    'customer_id': customer.id ?? 0,
                    'amount': receivedAmount,
                    'received_by': selectedStaff,
                    'payment_date': selectedDate.toIso8601String(),
                    'notes': noteCtrl.text.trim(),
                    'created_at': DateTime.now().toIso8601String(),
                  };

                  try {
                    await DatabaseHelper.instance.insertCreditPayment(payment);
                    if (ctx.mounted) {
                      Navigator.pop(ctx, true);
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      setDialogState(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: ThemeProvider.error));
                    }
                  }
                },
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('RECORD PAYMENT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully'), backgroundColor: ThemeProvider.success));
      _loadCustomersWithCredit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Credit Recovery',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        leading: BackButton(color: theme.textPrimary),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: theme.glassDecoration.copyWith(
                    borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                    color: theme.isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.2),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Search customer by name or phone...',
                      hintStyle: TextStyle(color: theme.textHint, fontWeight: FontWeight.w400),
                      prefixIcon: Icon(Icons.search_rounded, color: theme.iconColor),
                      suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded, size: 18, color: theme.iconColor),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),

              // Customer List
              Expanded(
                child: _loading
                  ? Center(child: CircularProgressIndicator(color: theme.highlight))
                  : _filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: theme.glassCircleDecoration,
                              child: const Text('💰', style: TextStyle(fontSize: 48)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? 'No outstanding credit' : 'No customers found',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _searchQuery.isEmpty ? 'All customers have cleared their credit' : 'Try a different search term',
                              style: TextStyle(color: theme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (ctx, i) {
                          final customer = _filteredCustomers[i];
                          return _CustomerCreditCard(
                            customer: customer,
                            onTap: () => _showRecoveryForm(customer),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerCreditCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const _CustomerCreditCard({
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final creditBalance = customer.creditBalance ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: theme.glassDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.highlight.withOpacity(0.3), theme.highlight.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
          ),
          child: Center(
            child: Text(
              customer.name[0].toUpperCase(),
              style: TextStyle(color: theme.highlight, fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(customer.name, 
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            if (customer.phone != null)
              Text(customer.phone!, 
                  style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'Remaining balance to be recovered',
            style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${BusinessConfig.instance.currencyDisplay} ${creditBalance.toStringAsFixed(2)}',
              style: const TextStyle(color: ThemeProvider.warning, fontWeight: FontWeight.w900, fontSize: 13),
            ),
            Text(
              'CREDIT',
              style: TextStyle(color: theme.textHint, fontSize: 8, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

