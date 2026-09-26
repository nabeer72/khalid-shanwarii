import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/stock.dart';
import 'package:mobile_app/db/mock_data.dart'; // For BusinessConfig if needed.
import 'package:mobile_app/screens/add_purchase_screen.dart';

class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen> {
  final theme = ThemeProvider.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  bool _showOnlyLowStock = false;
  
  // Summary Stats
  double _totalCostValue = 0;
  double _totalSalesValue = 0;
  int _totalItems = 0;
  int _lowStockCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final productsData = await DatabaseHelper.instance.getProducts();
      
      double costVal = 0;
      double salesVal = 0;
      int totalItems = 0;
      int lowStockItems = 0;

      final List<Product> products = productsData.map((pData) {
        final stocksData = List<Map<String, dynamic>>.from(pData['stocks'] ?? []);
        return Product.fromMap(pData, stocks: stocksData.map<Stock>((s) => Stock.fromMap(s)).toList());
      }).toList();

      for (var product in products) {
        for (var s in product.stocks) {
          if (s.quantity > 0) {
            costVal += (s.quantity * s.costPrice);
            salesVal += (s.quantity * s.salePrice);
            totalItems += s.quantity.toInt();
          }
        }
        
        if (product.totalStock <= product.stockLimit) {
          lowStockItems++;
        }
      }

      if (mounted) {
        setState(() {
          _products = productsData; // Keeping raw data for the list or map to Product
          _totalCostValue = costVal;
          _totalSalesValue = salesVal;
          _totalItems = totalItems;
          _lowStockCount = lowStockItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading stock report: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Stock Report',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
      ),
      body: theme.glassBackground(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: theme.highlight))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Grid
                      GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: isTablet ? 240 : 300,
                          mainAxisExtent: isTablet ? 140 : 160,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        children: [
                          _buildSummaryCard('Cost Value', _totalCostValue, Icons.account_balance_wallet_rounded, theme.highlight),
                          _buildSummaryCard('Sales Value', _totalSalesValue, Icons.insights_rounded, theme.secondary),
                          _buildSummaryCard('Total Items', _totalItems.toDouble(), Icons.inventory_2_rounded, ThemeProvider.warning, isCurrency: false),
                          _buildSummaryCard('Low Stock', _lowStockCount.toDouble(), Icons.notification_important_rounded, ThemeProvider.error, isCurrency: false, onTap: () {
                            setState(() {
                              _showOnlyLowStock = !_showOnlyLowStock;
                            });
                          }),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Text('Inventory Details', 
                          style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 12),

                      // Product List
                      Builder(
                        builder: (context) {
                          final displayedProducts = _showOnlyLowStock 
                              ? _products.where((pData) {
                                  final stocksData = List<Map<String, dynamic>>.from(pData['stocks'] ?? []);
                                  final p = Product.fromMap(pData, stocks: stocksData.map<Stock>((s) => Stock.fromMap(s)).toList());
                                  return p.totalStock <= p.stockLimit;
                                }).toList()
                              : _products;
                              
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: displayedProducts.length,
                            itemBuilder: (context, index) {
                              final pData = displayedProducts[index];
                          final stocksData = List<Map<String, dynamic>>.from(pData['stocks'] ?? []);
                          final p = Product.fromMap(pData, stocks: stocksData.map<Stock>((s) => Stock.fromMap(s)).toList());
                          
                          final stock = p.totalStock.toInt();
                          final isLow = p.totalStock <= p.stockLimit;
                          
                          double totalCostVal = 0;
                          for (var s in p.stocks) {
                            totalCostVal += (s.quantity * s.costPrice);
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: theme.glassListDecoration,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(p.name, 
                                        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                                  ),
                                  if (isLow)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: ThemeProvider.error.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: ThemeProvider.error.withOpacity(0.2)),
                                      ),
                                      child: const Text('LOW STOCK', 
                                          style: TextStyle(color: ThemeProvider.error, fontSize: 7, fontWeight: FontWeight.w900)),
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Stock: $stock | Batches: ${p.stocks.length} | Price: ${p.priceRange}',
                                  style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${BusinessConfig.instance.currencyDisplay} ${totalCostVal.toStringAsFixed(2)}',
                                    style: TextStyle(color: theme.highlight, fontWeight: FontWeight.w900, fontSize: 13),
                                  ),
                                  Text(
                                    'TOTAL COST VALUE',
                                    style: TextStyle(color: theme.textHint, fontSize: 8, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                                onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AddPurchaseScreen(preSelectedProductId: pData['id'] as int?)),
                                );
                              },
                            ),
                          );
                        },
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, double value, IconData icon, Color color, {bool isCurrency = true, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(theme.isDark ? 0.15 : 0.12),
              color.withOpacity(theme.isDark ? 0.05 : 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
          border: Border.all(
            color: color.withOpacity(theme.isDark ? 0.3 : 0.4),
            width: onTap != null && _showOnlyLowStock && title == 'Low Stock' ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(theme.isDark ? 0.12 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: theme.isDark
                  ? Colors.black26
                  : Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
          const SizedBox(height: 14),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isCurrency 
                    ? '${BusinessConfig.instance.currencyDisplay} ${value.toStringAsFixed(0)}' 
                    : value.toInt().toString(),
                style: TextStyle(color: theme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(title.toUpperCase(), 
              style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
        ],
      ),
    ));
  }
}
