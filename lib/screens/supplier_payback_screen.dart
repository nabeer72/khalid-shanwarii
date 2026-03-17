import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/supplier_payback_form_screen.dart';

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
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierPaybackFormScreen(supplier: supplier),
      ),
    );

    if (result == true && mounted) {
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
              '${BusinessConfig.instance.currency}. ${creditBalance.toStringAsFixed(2)}',
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
