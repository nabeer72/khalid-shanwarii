import 'package:flutter/material.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/screens/add_customer_screen.dart';

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
    final data = await DatabaseHelper.instance.getAllCustomers();
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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddCustomerScreen(customer: existing)),
    );
    if (result == true) {
      _loadCustomers();
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
                                  decoration: theme.glassDecoration,
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
