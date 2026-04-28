import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:intl/intl.dart';
import 'customer_credit_sales_screen.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final theme = ThemeProvider.instance;
  List<Customer> _customersWithCredit = [];
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _loading = true;
  bool _isHistoryView = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadCustomersWithCredit(),
      _loadPaymentHistory(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCustomersWithCredit() async {
    try {
      final data = await DatabaseHelper.instance.getCustomersWithCredit();
      if (mounted) {
        _customersWithCredit = data.map((c) => Customer.fromMap(c)).toList();
      }
    } catch (e) {
      debugPrint('Error loading customers with credit: $e');
    }
  }

  Future<void> _loadPaymentHistory() async {
    try {
      final data = await DatabaseHelper.instance.getCreditPaymentsWithCustomer();
      if (mounted) {
        _paymentHistory = data;
      }
    } catch (e) {
      debugPrint('Error loading payment history: $e');
    }
  }

  List<dynamic> get _filteredItems {
    if (_isHistoryView) {
      if (_searchQuery.isEmpty) return _paymentHistory;
      return _paymentHistory.where((p) =>
        (p['customer_name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (p['notes']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    } else {
      if (_searchQuery.isEmpty) return _customersWithCredit;
      return _customersWithCredit.where((c) =>
        c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (c.phone?.contains(_searchQuery) ?? false)
      ).toList();
    }
  }

  Future<void> _showRecoveryForm({Customer? customer, Map<String, dynamic>? editingPayment}) async {
    final bool isEdit = editingPayment != null;
    
    // 1. Fetch data first to avoid dialog race conditions
    List<Map<String, dynamic>> employees = [];
    double balance = 0;
    int? effectiveCustomerId = isEdit ? editingPayment['customer_id'] : customer?.id;
    
    try {
      final dbEmployees = await DatabaseHelper.instance.getEmployees();
      employees = List<Map<String, dynamic>>.from(dbEmployees); // Convert to modifiable list
      
      if (effectiveCustomerId != null) {
        balance = await DatabaseHelper.instance.getCustomerCreditBalance(effectiveCustomerId);
        if (isEdit) balance += (editingPayment['amount'] as num).toDouble();
      }
    } catch (e) {
      debugPrint('Error fetching data for recovery form: $e');
    }

    final staffNames = employees.map((e) => e['name'].toString()).toList();
    String currentStaff = BusinessConfig.instance.staffName;

    // If staffName is empty (e.g. Admin logged in), try to fetch from users table
    if (currentStaff.isEmpty && BusinessConfig.instance.userId != null) {
      final user = await DatabaseHelper.instance.getUser(BusinessConfig.instance.userId);
      if (user != null && user['name'] != null) {
        currentStaff = user['name'];
      }
    }

    if (currentStaff.isNotEmpty && !staffNames.contains(currentStaff)) {
      employees.insert(0, {'name': currentStaff});
    }

    String? selectedStaff = isEdit 
        ? editingPayment['received_by'] 
        : (currentStaff.isNotEmpty ? currentStaff : (employees.isNotEmpty ? employees.first['name'] : null));
    
    DateTime selectedDate = isEdit 
        ? DateTime.parse(editingPayment['payment_date']) 
        : DateTime.now();
    
    final receivedAmountCtrl = TextEditingController(text: isEdit ? editingPayment['amount'].toString() : '');
    final noteCtrl = TextEditingController(text: isEdit ? editingPayment['notes'] ?? '' : '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    
    Customer? selectedCustomer = customer;
    if (isEdit && selectedCustomer == null) {
      // Find customer in our list for display info
      try {
        selectedCustomer = _customersWithCredit.firstWhere((c) => c.id == effectiveCustomerId);
      } catch (_) {
        // If not in list (balance 0), create a dummy for display
        selectedCustomer = Customer(
          id: effectiveCustomerId, 
          name: editingPayment['customer_name'] ?? 'Unknown',
          businessId: 0
        );
      }
    }

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          double receivedAmount = double.tryParse(receivedAmountCtrl.text) ?? 0.0;
          double currentBalance = (selectedCustomer != null) ? balance : 0.0;
          double remainingBalance = currentBalance - receivedAmount;

          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEdit ? 'Edit Payment' : 'Record Payment',
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
                      if (selectedCustomer != null) ...[
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: theme.highlight.withOpacity(0.1),
                              child: Text(selectedCustomer!.name[0].toUpperCase(), style: TextStyle(color: theme.highlight, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(selectedCustomer!.name, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800)),
                                  Text('ID: ${selectedCustomer!.id}', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('CREDIT', style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.bold)),
                                Text('${BusinessConfig.instance.currencyDisplay} ${currentBalance.toStringAsFixed(2)}', style: const TextStyle(color: ThemeProvider.warning, fontWeight: FontWeight.bold)),
                              ],
                            )
                          ],
                        ),
                      ] else ...[
                        Text('SELECT CUSTOMER', style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        _SearchableCustomerDropdown(
                          customers: _customersWithCredit,
                          onSelected: (c) async {
                            final b = await DatabaseHelper.instance.getCustomerCreditBalance(c.id ?? 0);
                            setDialogState(() {
                              selectedCustomer = c;
                              balance = b;
                            });
                          },
                        ),
                      ],
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
                          final val = double.tryParse(v) ?? 0;
                          if (val <= 0) return 'Enter positive amount';
                          if (val > currentBalance) return 'Cannot exceed balance';
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
                onPressed: (isSaving || selectedCustomer == null) ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  if (selectedStaff == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a staff member'), backgroundColor: ThemeProvider.error));
                    return;
                  }

                  setDialogState(() => isSaving = true);

                  try {
                    final payment = {
                      'customer_id': selectedCustomer!.id ?? 0,
                      'amount': receivedAmount,
                      'received_by': selectedStaff,
                      'payment_date': selectedDate.toIso8601String(),
                      'notes': noteCtrl.text.trim(),
                    };

                    if (isEdit) {
                      await DatabaseHelper.instance.updateCreditPayment(editingPayment['id'], payment);
                    } else {
                      payment['created_at'] = DateTime.now().toIso8601String();
                      payment['updated_at'] = DateTime.now().toIso8601String();
                      await DatabaseHelper.instance.insertCreditPayment(payment);
                    }
                    
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
                    : Text(isEdit ? 'UPDATE PAYMENT' : 'RECORD PAYMENT', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEdit ? 'Payment updated successfully' : 'Payment recorded successfully'), 
        backgroundColor: ThemeProvider.success
      ));
      _refreshData();
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
        actions: [
          IconButton(
            icon: Icon(_isHistoryView ? Icons.group_rounded : Icons.history_rounded, color: theme.textPrimary),
            tooltip: _isHistoryView ? 'View Outstanding' : 'View History',
            onPressed: () => setState(() => _isHistoryView = !_isHistoryView),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRecoveryForm(),
        backgroundColor: theme.highlight,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Search & Tab Toggle Row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
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
                            hintText: _isHistoryView ? 'Search history...' : 'Search customer...',
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
                    const SizedBox(width: 12),
                    Container(
                      height: 40,
                      width: 200,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.whiteAlpha(0.05),
                        borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                        border: Border.all(color: theme.whiteAlpha(0.1)),
                      ),
                      child: Row(
                        children: [
                          _buildTabButton('Outstanding', !_isHistoryView),
                          _buildTabButton('History', _isHistoryView),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // List
              Expanded(
                child: _loading
                  ? Center(child: CircularProgressIndicator(color: theme.highlight))
                  : _filteredItems.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: _filteredItems.length,
                        itemBuilder: (ctx, i) {
                          if (_isHistoryView) {
                            return _PaymentHistoryCard(
                              payment: _filteredItems[i],
                              onEdit: () => _showRecoveryForm(editingPayment: _filteredItems[i]),
                            );
                          } else {
                            final customer = _filteredItems[i] as Customer;
                            return _CustomerCreditCard(
                              customer: customer,
                              onTap: () {}, // Tap disabled as per user request
                            );
                          }
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isHistoryView = (label == 'History')),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? theme.highlight : Colors.transparent,
            borderRadius: BorderRadius.circular(ThemeProvider.radiusList - 2),
            boxShadow: active ? [
              BoxShadow(
                color: theme.highlight.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
          child: Center(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: active ? Colors.white : theme.textSecondary,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: theme.glassCircleDecoration,
            child: Text(_isHistoryView ? '📋' : '💰', style: const TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty 
              ? (_isHistoryView ? 'No payment history' : 'No outstanding credit') 
              : 'No results found',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            _searchQuery.isEmpty 
              ? (_isHistoryView ? 'Records of credit recovery will appear here' : 'All customers have cleared their credit') 
              : 'Try a different search term',
            style: TextStyle(color: theme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CustomerCreditCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const _CustomerCreditCard({required this.customer, required this.onTap});

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
        leading: _buildAvatar(theme, customer.name),
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
          child: Row(
            children: [
              Expanded(
                child: Text('Remaining balance',
                  style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerCreditSalesScreen(customer: customer)));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.highlight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: theme.highlight.withOpacity(0.3)),
                  ),
                  child: Text('VIEW SALES', style: TextStyle(color: theme.highlight, fontSize: 9, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${BusinessConfig.instance.currencyDisplay} ${creditBalance.toStringAsFixed(2)}',
              style: const TextStyle(color: ThemeProvider.warning, fontWeight: FontWeight.w900, fontSize: 13)),
            Text('CREDIT', style: TextStyle(color: theme.textHint, fontSize: 8, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeProvider theme, String name) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.highlight.withOpacity(0.3), theme.highlight.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(name[0].toUpperCase(),
          style: TextStyle(color: theme.highlight, fontSize: 18, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onEdit;

  const _PaymentHistoryCard({required this.payment, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final date = DateTime.parse(payment['payment_date']);
    final amount = (payment['amount'] as num).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: theme.glassDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ThemeProvider.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.payment_rounded, color: ThemeProvider.success, size: 20),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(payment['customer_name'] ?? 'Unknown',
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            Text('${BusinessConfig.instance.currencyDisplay} ${amount.toStringAsFixed(2)}',
                style: const TextStyle(color: ThemeProvider.success, fontWeight: FontWeight.w900, fontSize: 15)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: theme.textHint, size: 12),
                const SizedBox(width: 4),
                Text(DateFormat('MMM dd, yyyy').format(date), 
                    style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Icon(Icons.person_outline_rounded, color: theme.textHint, size: 12),
                const SizedBox(width: 4),
                Text('By: ${payment['received_by'] ?? 'System'}', 
                    style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
            if (payment['notes'] != null && payment['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(payment['notes'], style: TextStyle(color: theme.textHint, fontSize: 11, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.edit_note_rounded, color: theme.highlight, size: 24),
          onPressed: onEdit,
        ),
      ),
    );
  }
}

class _SearchableCustomerDropdown extends StatefulWidget {
  final List<Customer> customers;
  final Function(Customer) onSelected;

  const _SearchableCustomerDropdown({required this.customers, required this.onSelected});

  @override
  State<_SearchableCustomerDropdown> createState() => _SearchableCustomerDropdownState();
}

class _SearchableCustomerDropdownState extends State<_SearchableCustomerDropdown> {
  final TextEditingController _ctrl = TextEditingController();
  bool _isOpen = false;
  final LayerLink _layerLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final filtered = widget.customers.where((c) =>
      c.name.toLowerCase().contains(_ctrl.text.toLowerCase()) ||
      (c.phone?.contains(_ctrl.text) ?? false)
    ).toList();

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        children: [
          TextFormField(
            controller: _ctrl,
            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
            decoration: theme.glassInputDecoration('Search Customer', Icons.person_search_rounded).copyWith(
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(_isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
                onPressed: () => setState(() => _isOpen = !_isOpen),
              ),
            ),
            onChanged: (v) => setState(() => _isOpen = true),
            onTap: () => setState(() => _isOpen = true),
          ),
          if (_isOpen)
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                border: Border.all(color: theme.whiteAlpha(0.1)),
              ),
              child: filtered.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: Text('No customers found with credit', style: TextStyle(fontSize: 12)))
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final c = filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text(c.name, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                        subtitle: Text('Bal: ${BusinessConfig.instance.currencyDisplay} ${c.creditBalance?.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                        onTap: () {
                          _ctrl.text = c.name;
                          widget.onSelected(c);
                          setState(() => _isOpen = false);
                        },
                      );
                    },
                  ),
            ),
        ],
      ),
    );
  }
}
