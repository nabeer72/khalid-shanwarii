import 'package:flutter/material.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/add_purchase_screen.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/services/sync_service.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final theme = ThemeProvider.instance;
  List<Purchase> _purchases = [];
  bool _isLoading = true;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final SyncService _syncService = SyncService();
  bool _isOnlineSearch = false;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);
    try {
      final localData = await DatabaseHelper.instance.getPurchases();
      List<Map<String, dynamic>> finalData = localData;

      if (_query.isNotEmpty && !_isOnlineSearch) {
        final q = _query.toLowerCase();
        final localFiltered = localData.where((p) {
          final supplier = (p['supplier_name'] ?? '').toString().toLowerCase();
          final id = p['id'].toString();
          final date = (p['purchase_date'] ?? '').toString().toLowerCase();
          return supplier.contains(q) || id.contains(q) || date.contains(q);
        }).toList();

        if (localFiltered.isEmpty) {
          final onlineData = await _syncService.searchOnline(_query, 'purchases');
          if (onlineData.isNotEmpty) {
            finalData = onlineData;
            _isOnlineSearch = true;
          }
        }
      } else if (_isOnlineSearch) {
        finalData = await _syncService.searchOnline(_query, 'purchases');
      }

      if (mounted) {
        setState(() {
          _purchases = finalData.map((e) => Purchase.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading purchases: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmDelete(Purchase purchase) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(24),
          decoration: theme.glassDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: ThemeProvider.error, size: 48),
              const SizedBox(height: 16),
              Text('Delete Purchase?', style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Are you sure you want to delete this purchase memory?', 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('CANCEL', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeProvider.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                      ),
                      onPressed: () async {
                        await DatabaseHelper.instance.deletePurchase(purchase.id ?? 0);
                        await _loadPurchases();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Purchase record deleted'), backgroundColor: ThemeProvider.error),
                          );
                        }
                      },
                      child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          'Purchases History',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
        actions: [
          if (_isOnlineSearch)
            TextButton(
              onPressed: () {
                setState(() {
                  _isOnlineSearch = false;
                  _query = '';
                  _searchCtrl.clear();
                  _loadPurchases();
                });
              },
              child: const Text('LOCAL', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
        ],
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  decoration: theme.glassDecoration,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
                      _query = v;
                      if (v.isEmpty && _isOnlineSearch) {
                        setState(() => _isOnlineSearch = false);
                      }
                      _loadPurchases();
                    },
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search purchases...',
                      hintStyle: TextStyle(color: theme.textHint),
                      prefixIcon: Icon(Icons.search_rounded, color: theme.highlight),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              if (_isOnlineSearch)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_done_rounded, color: theme.highlight, size: 14),
                      const SizedBox(width: 8),
                      Text('SHOWING RESULTS FROM SERVER', 
                        style: TextStyle(color: theme.highlight, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoading
              ? Center(child: CircularProgressIndicator(color: theme.highlight))
              : _purchases.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: theme.glassCircleDecoration,
                            child: Icon(Icons.receipt_long_rounded, size: 60, color: theme.iconColor.withOpacity(0.5)),
                          ),
                          const SizedBox(height: 24),
                          Text('No purchases yet', 
                            style: TextStyle(fontSize: 18, color: theme.textPrimary, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text('Restock your inventory to see them here', 
                            style: TextStyle(fontSize: 13, color: theme.textSecondary, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _purchases.length,
                      itemBuilder: (context, index) {
                        final purchase = _purchases[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: theme.glassDecoration,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPurchaseScreen())).then((_) => _loadPurchases()),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(purchase.supplierName ?? 'Direct Purchase', 
                                      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                                ),
                                Text('ID: ${purchase.id ?? '??'}', 
                                    style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.w800)),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                DateFormat('MMM dd, yyyy | HH:mm').format(purchase.purchaseDate),
                                style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
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
                                      '${BusinessConfig.instance.currencyDisplay} ${purchase.totalAmount.toStringAsFixed(2)}',
                                      style: TextStyle(color: theme.highlight, fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                                    if (_isOnlineSearch)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(color: theme.highlight.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                        child: Text('ONLINE', style: TextStyle(color: theme.highlight, fontSize: 7, fontWeight: FontWeight.w900)),
                                      ),
                                    Text(
                                      'PURCHASE',
                                      style: TextStyle(color: theme.textHint, fontSize: 8, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, color: ThemeProvider.error.withOpacity(0.5), size: 18),
                                  onPressed: () => _confirmDelete(purchase),
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
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
          boxShadow: [
            BoxShadow(
              color: theme.highlight.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPurchaseScreen())).then((_) => _loadPurchases()),
          backgroundColor: theme.highlight,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
          icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
          label: const Text('NEW PURCHASE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
        ),
      ),
    );
  }
}
