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
  List<Map<String, dynamic>> _paybackHistory = [];
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
      _loadSuppliersWithCredit(),
      _loadPaybackHistory(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSuppliersWithCredit() async {
    try {
      final data = await DatabaseHelper.instance.getSuppliersWithCredit();
      if (mounted) {
        _suppliersWithCredit = data.map((c) => Supplier.fromMap(c)).toList();
      }
    } catch (e) {
      debugPrint('Error loading suppliers with credit: $e');
    }
  }

  Future<void> _loadPaybackHistory() async {
    try {
      final data = await DatabaseHelper.instance.getSupplierPaybacksWithSupplier();
      if (mounted) {
        _paybackHistory = data;
      }
    } catch (e) {
      debugPrint('Error loading payback history: $e');
    }
  }

  List<dynamic> get _filteredItems {
    if (_isHistoryView) {
      if (_searchQuery.isEmpty) return _paybackHistory;
      return _paybackHistory.where((p) =>
        (p['supplier_name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (p['notes']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    } else {
      if (_searchQuery.isEmpty) return _suppliersWithCredit;
      return _suppliersWithCredit.where((c) =>
        c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (c.phone?.contains(_searchQuery) ?? false)
      ).toList();
    }
  }

  Future<void> _showPaybackForm({Supplier? supplier, Map<String, dynamic>? editingPayback}) async {
    final bool isEdit = editingPayback != null;
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController(text: isEdit ? editingPayback['amount'].toString() : '');
    final noteCtrl = TextEditingController(text: isEdit ? editingPayback['notes'] ?? '' : '');
    
    DateTime selectedDate = isEdit 
        ? DateTime.parse(editingPayback['payment_date']) 
        : DateTime.now();
        
    Supplier? selectedSupplier = supplier;
    String? selectedStaff;
    List<Map<String, dynamic>> employees = [];
    double balance = 0;
    bool isLoadingData = true;
    bool isSaving = false;

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (isLoadingData) {
            // Load data once inside the dialog
            Future.microtask(() async {
              try {
                final dbEmployees = await DatabaseHelper.instance.getEmployees();
                employees = List<Map<String, dynamic>>.from(dbEmployees);
                
                int? effectiveSupplierId = isEdit ? editingPayback['supplier_id'] : selectedSupplier?.id;
                if (effectiveSupplierId != null) {
                  balance = await DatabaseHelper.instance.getSupplierCreditBalance(effectiveSupplierId);
                  if (isEdit) balance += (editingPayback['amount'] as num).toDouble();
                }

                String currentStaff = BusinessConfig.instance.staffName;
                if (currentStaff.isEmpty && BusinessConfig.instance.userId != null) {
                  final user = await DatabaseHelper.instance.getUser(BusinessConfig.instance.userId);
                  if (user != null) currentStaff = user['name'] ?? '';
                }

                final staffNames = employees.map((e) => e['name'].toString()).toList();
                if (currentStaff.isNotEmpty && !staffNames.contains(currentStaff)) {
                  employees.insert(0, {'name': currentStaff});
                }

                selectedStaff = isEdit 
                    ? editingPayback['paid_by'] 
                    : (currentStaff.isNotEmpty ? currentStaff : (employees.isNotEmpty ? employees.first['name'] : null));

                if (isEdit && selectedSupplier == null) {
                  try {
                    selectedSupplier = _suppliersWithCredit.firstWhere((s) => s.id == effectiveSupplierId);
                  } catch (_) {
                    selectedSupplier = Supplier(id: effectiveSupplierId, name: editingPayback['supplier_name'] ?? 'Unknown', creditBalance: balance);
                  }
                }
                
                if (ctx.mounted) setDialogState(() => isLoadingData = false);
              } catch (e) {
                debugPrint('Error loading payback data: $e');
                if (ctx.mounted) setDialogState(() => isLoadingData = false);
              }
            });

            return AlertDialog(
              backgroundColor: theme.surface,
              content: const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
            );
          }

          double paidAmount = double.tryParse(amountCtrl.text) ?? 0.0;
          double currentBalance = balance;
          double remainingBalance = currentBalance - paidAmount;


          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEdit ? 'Edit Payback' : 'Record Payback',
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
                      if (selectedSupplier != null) ...[
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: theme.highlight.withOpacity(0.1),
                              child: Text(selectedSupplier!.name[0].toUpperCase(), style: TextStyle(color: theme.highlight, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(selectedSupplier!.name, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800)),
                                  Text('ID: ${selectedSupplier!.id}', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('DEBT', style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.bold)),
                                Text('${BusinessConfig.instance.currencyDisplay} ${currentBalance.toStringAsFixed(2)}', style: const TextStyle(color: ThemeProvider.warning, fontWeight: FontWeight.bold)),
                              ],
                            )
                          ],
                        ),
                      ] else ...[
                        Text('SELECT SUPPLIER', style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        _SearchableSupplierDropdown(
                          suppliers: _suppliersWithCredit,
                          onSelected: (s) async {
                            final b = await DatabaseHelper.instance.getSupplierCreditBalance(s.id ?? 0);
                            setDialogState(() {
                              selectedSupplier = s;
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

                      Text('PAID AMOUNT', style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                        decoration: theme.glassInputDecoration('Amount', Icons.payments_rounded).copyWith(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                        onChanged: (v) => setDialogState(() {}),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter amount';
                          final val = double.tryParse(v) ?? 0;
                          if (val <= 0) return 'Enter positive amount';
                          if (val > currentBalance + 0.01) return 'Cannot exceed debt';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      if (paidAmount > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('REMAINING DEBT', style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w800)),
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
                onPressed: (isSaving || selectedSupplier == null) ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  if (selectedStaff == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a staff member'), backgroundColor: ThemeProvider.error));
                    return;
                  }

                  setDialogState(() => isSaving = true);

                  try {
                    final payback = {
                      'supplier_id': selectedSupplier!.id ?? 0,
                      'amount': paidAmount,
                      'paid_by': selectedStaff,
                      'payment_date': selectedDate.toIso8601String(),
                      'notes': noteCtrl.text.trim(),
                    };

                    if (isEdit) {
                      await DatabaseHelper.instance.updateSupplierPayback(editingPayback['id'], payback);
                    } else {
                      payback['created_at'] = DateTime.now().toIso8601String();
                      payback['updated_at'] = DateTime.now().toIso8601String();
                      await DatabaseHelper.instance.insertSupplierPayback(payback);
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
                    : Text(isEdit ? 'UPDATE PAYBACK' : 'RECORD PAYBACK', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEdit ? 'Payback updated successfully' : 'Payback recorded successfully'), 
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
          'Supplier Payback',
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
                            hintText: _isHistoryView ? 'Search history...' : 'Search supplier...',
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
                            return _PaybackHistoryCard(
                              payback: _filteredItems[i],
                              onEdit: () => _showPaybackForm(editingPayback: _filteredItems[i]),
                            );
                          } else {
                            final supplier = _filteredItems[i] as Supplier;
                            return _SupplierCreditCard(
                              supplier: supplier,
                              onTap: () => _showPaybackForm(supplier: supplier),
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
            child: Text(_isHistoryView ? '📋' : '🤝', style: const TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty 
              ? (_isHistoryView ? 'No payback history' : 'No outstanding debt') 
              : 'No results found',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            _searchQuery.isEmpty 
              ? (_isHistoryView ? 'Records of supplier paybacks will appear here' : 'All suppliers have been cleared') 
              : 'Try a different search term',
            style: TextStyle(color: theme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SupplierCreditCard extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onTap;

  const _SupplierCreditCard({required this.supplier, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final creditBalance = supplier.creditBalance;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: theme.glassDecoration,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: onTap,
        leading: _buildAvatar(theme, supplier.name),
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
          child: Text('Remaining balance to be paid back',
                  style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${BusinessConfig.instance.currencyDisplay} ${creditBalance.toStringAsFixed(2)}',
              style: TextStyle(color: theme.isDark ? ThemeProvider.warning : ThemeProvider.error, fontWeight: FontWeight.w900, fontSize: 13)),
            Text('DEBT', style: TextStyle(color: theme.textHint, fontSize: 8, fontWeight: FontWeight.w800)),
          ],
        ),
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

class _PaybackHistoryCard extends StatelessWidget {
  final Map<String, dynamic> payback;
  final VoidCallback onEdit;

  const _PaybackHistoryCard({required this.payback, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final date = DateTime.parse(payback['payment_date']);
    final amount = (payback['amount'] as num).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: theme.glassDecoration,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
        child: ListTile(
          onTap: onEdit,
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
              child: Text(payback['supplier_name'] ?? 'Unknown',
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
                Text('By: ${payback['paid_by'] ?? 'System'}', 
                    style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
            if (payback['notes'] != null && payback['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(payback['notes'], style: TextStyle(color: theme.textHint, fontSize: 11, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.edit_note_rounded, color: theme.highlight, size: 24),
          onPressed: onEdit,
        ),
        ),
      ),
    );
  }
}

class _SearchableSupplierDropdown extends StatefulWidget {
  final List<Supplier> suppliers;
  final Function(Supplier) onSelected;

  const _SearchableSupplierDropdown({required this.suppliers, required this.onSelected});

  @override
  State<_SearchableSupplierDropdown> createState() => _SearchableSupplierDropdownState();
}

class _SearchableSupplierDropdownState extends State<_SearchableSupplierDropdown> {
  final TextEditingController _ctrl = TextEditingController();
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final filtered = widget.suppliers.where((s) =>
      s.name.toLowerCase().contains(_ctrl.text.toLowerCase()) ||
      (s.phone?.contains(_ctrl.text) ?? false)
    ).toList();

    return Column(
      children: [
        TextFormField(
          controller: _ctrl,
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
          decoration: theme.glassInputDecoration('Search Supplier', Icons.business_center_rounded).copyWith(
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
              ? const Padding(padding: EdgeInsets.all(16), child: Text('No suppliers found with debt', style: TextStyle(fontSize: 12)))
              : ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final s = filtered[i];
                    return ListTile(
                      dense: true,
                      title: Text(s.name, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                      subtitle: Text('Debt: ${BusinessConfig.instance.currencyDisplay} ${s.creditBalance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                      onTap: () {
                        _ctrl.text = s.name;
                        widget.onSelected(s);
                        setState(() => _isOpen = false);
                      },
                    );
                  },
                ),
          ),
      ],
    );
  }
}
