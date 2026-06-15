import 'package:flutter/material.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/controllers/add_customer_controller.dart';

class CustomerListScreen extends StatefulWidget {
  final bool selectMode;
  const CustomerListScreen({super.key, this.selectMode = false});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final theme = ThemeProvider.instance;
  List<Customer> _customers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final data = await DatabaseHelper.instance.getCustomers();
    if (mounted) {
      setState(() {
        _customers = data.map((c) => Customer.fromMap(c)).toList();
      });
    }
  }

  List<Customer> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((c) =>
      c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (c.phone?.contains(_searchQuery) ?? false) ||
      (c.email?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
    ).toList();
  }

  Future<void> _navigateToAddCustomer([Customer? existing]) async {
    _showCustomerFormDialog(existing);
  }

  void _showCustomerFormDialog([Customer? existing]) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final discountController = TextEditingController(text: (existing?.discount ?? 0).toString());
    final creditLimitController = TextEditingController(text: (existing?.creditLimit ?? 0).toString());
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final _formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  existing == null ? 'New Customer' : 'Edit Customer',
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
                      _buildDialogSectionHeader('Basic Details'),
                      _buildDialogTextField(
                        controller: nameController,
                        label: 'Customer Name',
                        icon: Icons.person_outline,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                        isRequired: true,
                      ),
                      const SizedBox(height: 12),
                      _buildDialogTextField(
                        controller: phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        isRequired: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Phone is required';
                          if (!RegExp(r'^[0-9+ ]+$').hasMatch(v.trim())) {
                            return 'Invalid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDialogTextField(
                        controller: emailController,
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        isRequired: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                            return 'Invalid email format';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildDialogSectionHeader('Loyalty & Preferences'),
                      _buildDialogTextField(
                        controller: discountController,
                        label: 'Standard Discount (%)',
                        icon: Icons.percent_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final d = double.tryParse(v);
                          if (d == null) return 'Must be a number';
                          if (d < 0 || d > 100) return 'Must be 0-100%';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDialogTextField(
                        controller: creditLimitController,
                        label: 'Credit Limit (Amount)',
                        icon: Icons.money_off_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final d = double.tryParse(v);
                          if (d == null) return 'Must be a number';
                          if (d < 0) return 'Cannot be negative';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDialogTextField(
                        controller: notesController,
                        label: 'Additional Notes',
                        icon: Icons.notes_rounded,
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
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        
                        setDialogState(() => isLoading = true);
                        final result = await CustomerFormHelper.prepareAndSaveCustomer(
                          existingCustomer: existing,
                          name: nameController.text,
                          phone: phoneController.text,
                          email: emailController.text,
                          notes: notesController.text,
                          discountText: discountController.text,
                          creditLimitText: creditLimitController.text,
                          context: context,
                        );
                        
                        if (result != null && result['success'] == true) {
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _loadCustomers();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result['message']), backgroundColor: ThemeProvider.success),
                            );
                          }
                        } else {
                          if (ctx.mounted) {
                            setDialogState(() => isLoading = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(result?['message'] ?? 'Save failed'), backgroundColor: ThemeProvider.error),
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        existing == null ? 'SAVE CUSTOMER' : 'UPDATE CHANGES',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.selectMode ? 'Select Customer' : 'Customers',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
        actions: [
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
              // Glass Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Container(
                  decoration: theme.glassDecoration.copyWith(
                    borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                    color: theme.isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.2),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Search customers...',
                      hintStyle: TextStyle(color: theme.textHint, fontWeight: FontWeight.w400),
                      prefixIcon: Icon(Icons.search_rounded, color: theme.iconColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                  ),
                ),
              ),
              
              Expanded(
                child: _filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: theme.glassCircleDecoration,
                              child: Icon(Icons.people_outline_rounded, size: 60, color: theme.iconColor),
                            ),
                            const SizedBox(height: 16),
                            Text('No customers found', 
                              style: TextStyle(fontSize: 18, color: theme.textPrimary, fontWeight: FontWeight.w800)),
                            Text('Grow your business! Add a customer', 
                              style: TextStyle(fontSize: 14, color: theme.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final c = _filteredCustomers[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (widget.selectMode) {
                                    Navigator.pop(context, c);
                                  } else {
                                    _navigateToAddCustomer(c);
                                  }
                                },
                                borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                                child: Container(
                                  decoration: theme.glassListDecoration,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(c.name, 
                                              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                                        ),
                                        if (c.discount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: theme.highlight.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: theme.highlight.withOpacity(0.2)),
                                            ),
                                            child: Text('${c.discount}% OFF', 
                                                style: TextStyle(color: theme.highlight, fontSize: 7, fontWeight: FontWeight.w900)),
                                          ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Phone: ${c.phone ?? 'N/A'} | Visits: ${c.visitCount}',
                                        style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${BusinessConfig.instance.currency}. ${c.totalSpent.toStringAsFixed(2)}',
                                          style: TextStyle(color: theme.highlight, fontWeight: FontWeight.w900, fontSize: 13),
                                        ),
                                        Text(
                                          'TOTAL PURCHASE',
                                          style: TextStyle(color: theme.textHint, fontSize: 8, fontWeight: FontWeight.w800),
                                        ),
                                      ],
                                    ),
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
        onPressed: () => _navigateToAddCustomer(),
        backgroundColor: theme.highlight,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('NEW CUSTOMER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        elevation: 8,
      ),
    );
  }
}

// ignore: unused_element
class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const _CustomerTile({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: theme.accent,
          child: Text(customer.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(customer.name, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.phone != null) Text(customer.phone!, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
            if (customer.email != null) Text(customer.email!, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${BusinessConfig.instance.currency}. ${customer.totalSpent.toStringAsFixed(2)}', style: TextStyle(color: theme.highlight, fontWeight: FontWeight.bold)),
            Text('${customer.visitCount} visits', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
