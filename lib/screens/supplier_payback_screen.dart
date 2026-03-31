import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:intl/intl.dart';

class SupplierPaybackScreen extends StatefulWidget {
  const SupplierPaybackScreen({super.key});

  @override
  State<SupplierPaybackScreen> createState() => _SupplierPaybackScreenState();
}

class _SupplierPaybackScreenState extends State<SupplierPaybackScreen> {
  final theme = ThemeProvider.instance;
  List<Supplier> _suppliersWithCredit = [];
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSuppliersWithCredit();
  }

  Future<void> _loadSuppliersWithCredit() async {
    setState(() => _loading = true);
    try {
      final data = await DatabaseHelper.instance.getSuppliersWithCredit();
      if (mounted) {
        setState(() {
          _suppliersWithCredit = data.map((c) => Supplier.fromMap(c)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading suppliers with credit: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Supplier> get _filteredSuppliers {
    if (_searchQuery.isEmpty) return _suppliersWithCredit;
    return _suppliersWithCredit.where((c) =>
      c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (c.phone?.contains(_searchQuery) ?? false)
    ).toList();
  }

  Future<void> _showPaybackForm(Supplier supplier) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final balance = await DatabaseHelper.instance.getSupplierCreditBalance(supplier.id ?? 0);
    final employees = await DatabaseHelper.instance.getEmployees();
    
    if (mounted) Navigator.pop(context); // close loading

    String? selectedStaff = employees.isNotEmpty ? employees.first['name'] : null;
    DateTime selectedDate = DateTime.now();
    final paidAmountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          double paidAmount = double.tryParse(paidAmountCtrl.text) ?? 0.0;
          double remainingBalance = balance - paidAmount;

          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Record Payback',
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
                            child: Text(supplier.name[0].toUpperCase(), style: TextStyle(color: theme.highlight, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(supplier.name, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800)),
                                Text('ID: ${supplier.id}', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
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

                      Text('PAYBACK DATE', style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
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
                      
                      Text('PAID BY (STAFF)', style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
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

                      Text('AMOUNT PAID', style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: paidAmountCtrl,
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
                      
                      if (paidAmount > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('NEW BALANCE', style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w800)),
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
                  backgroundColor: theme.highlight,
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
                  if (paidAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid payment amount'), backgroundColor: ThemeProvider.error));
                    return;
                  }
                  if (paidAmount > balance + 0.01) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment amount cannot exceed owed balance'), backgroundColor: ThemeProvider.error));
                    return;
                  }

                  setDialogState(() => isSaving = true);

                  final payback = {
                    'supplier_id': supplier.id ?? 0,
                    'amount': paidAmount,
                    'paid_by': selectedStaff,
                    'payment_date': selectedDate.toIso8601String(),
                    'notes': noteCtrl.text.trim(),
                    'created_at': DateTime.now().toIso8601String(),
                  };

                  try {
                    await DatabaseHelper.instance.insertSupplierPayback(payback);
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
                    : const Text('RECORD PAYBACK', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payback recorded successfully'), backgroundColor: ThemeProvider.success));
      _loadSuppliersWithCredit();
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
          'Supplier Payback',
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
                      hintText: 'Search supplier by name or phone...',
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

              // Supplier List
              Expanded(
                child: _loading
                  ? Center(child: CircularProgressIndicator(color: theme.highlight))
                  : _filteredSuppliers.isEmpty
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
                              _searchQuery.isEmpty ? 'No outstanding debt' : 'No suppliers found',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _searchQuery.isEmpty ? 'All suppliers have been paid' : 'Try a different search term',
                              style: TextStyle(color: theme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _filteredSuppliers.length,
                        itemBuilder: (ctx, i) {
                          final supplier = _filteredSuppliers[i];
                          return _SupplierCreditCard(
                            supplier: supplier,
                            onTap: () => _showPaybackForm(supplier),
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

class _SupplierCreditCard extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onTap;

  const _SupplierCreditCard({
    required this.supplier,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final creditBalance = supplier.creditBalance;

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
              supplier.name[0].toUpperCase(),
              style: TextStyle(color: theme.highlight, fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(supplier.name, 
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            if (supplier.phone != null)
              Text(supplier.phone!, 
                  style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'Remaining balance to be paid back',
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
