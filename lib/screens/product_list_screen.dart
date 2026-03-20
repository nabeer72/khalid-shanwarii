import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/stock.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/add_product_screen.dart';
import 'package:mobile_app/screens/pos_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final theme = ThemeProvider.instance;
  List<Product> _products = [];
  List<ProductCategory> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final productsData = await DatabaseHelper.instance.getProducts();
      final categoriesData = await DatabaseHelper.instance.getCategories();
      
      if (mounted) {
        setState(() {
          _products = productsData.map((pData) {
            final stocksData = List<Map<String, dynamic>>.from(pData['stocks'] ?? []);
            return Product.fromMap(pData, stocks: stocksData.map<Stock>((s) => Stock.fromMap(s)).toList());
          }).toList();
          _categories = categoriesData.map((c) => ProductCategory.fromMap(c)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      print('Error loading data: $e');
    }
  }

  Future<void> _openProductScreen({Product? product}) async {
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(product: product),
      ),
    );

    if (result == true && mounted) {
      _loadData();
    }
  }

  Future<void> _toggleFavorite(Product product) async {
    if (product.id != null) {
      await DatabaseHelper.instance.toggleProductFavorite(product.id!, product.isFavorite);
      _loadData(); // Refresh list and counts
    }
  }

  void _addToPOS(Product product) {
    // This could navigate to POS and auto-add or just provide feedback
    // For now, let's show a snackbar or navigate to POS
    Navigator.push(context, MaterialPageRoute(builder: (_) => const POSScreen())).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Product Catalog',
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
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: TextStyle(color: theme.textHint, fontWeight: FontWeight.w400),
                      prefixIcon: Icon(Icons.search_rounded, color: theme.iconColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    onChanged: (val) {
                      // Add filter logic if needed
                    },
                  ),
                ),
              ),
              
              Expanded(
                child: _loading 
                    ? Center(child: CircularProgressIndicator(color: theme.highlight))
                    : _buildProductList()
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductScreen(),
        backgroundColor: theme.highlight,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('NEW PRODUCT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        elevation: 8,
      ),
    );
  }

  Widget _buildProductList() {
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: theme.glassCircleDecoration,
              child: Icon(Icons.inventory_2_outlined, size: 60, color: theme.iconColor),
            ),
            const SizedBox(height: 16),
            Text('No products found', 
              style: TextStyle(fontSize: 18, color: theme.textPrimary, fontWeight: FontWeight.w800)),
            Text('Add items to your catalog', 
              style: TextStyle(fontSize: 14, color: theme.textSecondary)),
          ],
        ),
      );
    }

    // Group by Name
    final Map<String, List<Product>> grouped = {};
    for (var p in _products) {
      grouped.putIfAbsent(p.name, () => []).add(p);
    }

    final sortedNames = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: sortedNames.length,
      itemBuilder: (context, index) {
        final name = sortedNames[index];
        final group = grouped[name]!;
        
        // Aggregate Data
        final totalStock = group.fold(0.0, (sum, p) => sum + p.totalStock);
        final isAnyFavorite = group.any((p) => p.isFavorite);
        final isActive = group.any((p) => p.status == 1);
        
        // Collect all Prices
        final Set<double> uniquePrices = {};
        for (var p in group) {
          if (p.stocks.isNotEmpty) {
            for (var s in p.stocks) {
              uniquePrices.add(s.salePrice);
            }
          } else if (p.price != 0) {
            uniquePrices.add(p.price);
          }
        }
        
        final hasMultiplePrices = uniquePrices.length > 1;
        final displayPrice = uniquePrices.length == 1 ? uniquePrices.first.toStringAsFixed(2) : '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (group.length == 1 && !hasMultiplePrices) {
                  _openProductScreen(product: group.first);
                } else {
                  _showGroupPopup(name, group);
                }
              },
              borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
              child: Container(
                decoration: theme.glassDecoration.copyWith(
                  border: !isActive 
                    ? Border.all(color: ThemeProvider.error.withOpacity(0.4), width: 1.5)
                    : null,
                ),
                child: Opacity(
                  opacity: !isActive ? 0.7 : 1.0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  decoration: !isActive ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Stock: ${totalStock.toStringAsFixed(0)} | ${group.length} variants | ${isActive ? 'active' : 'inactive'}',
                                style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (displayPrice.isNotEmpty)
                              Text(
                                '${BusinessConfig.instance.currencyDisplay} $displayPrice',
                                style: TextStyle(color: theme.highlight, fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                            Text(
                              'UNIT PRICE',
                              style: TextStyle(color: theme.textHint, fontSize: 8, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        if (hasMultiplePrices)
                          IconButton(
                            icon: Icon(Icons.list_alt_rounded, color: theme.highlight, size: 22),
                            onPressed: () => _showGroupPopup(name, group),
                            tooltip: 'View price variants',
                          ),
                        IconButton(
                          icon: Icon(
                            isAnyFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: isAnyFavorite ? ThemeProvider.warning : theme.iconColor.withOpacity(0.4),
                            size: 24,
                          ),
                          onPressed: () {
                            for (var p in group) {
                              _toggleFavorite(p);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGroupPopup(String name, List<Product> group) {
    final theme = ThemeProvider.instance;
    final currency = BusinessConfig.instance.currency;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(ThemeProvider.radiusCard)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: theme.textHint.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Price Variants', style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text(name, style: TextStyle(color: theme.textPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
            ...group.expand((p) => p.stocks.map((s) => MapEntry(p, s))).map((entry) {
              final p = entry.key;
              final s = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: theme.glassDecoration.copyWith(
                  color: theme.highlight.withOpacity(0.05),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    'Price: $currency ${s.salePrice.toStringAsFixed(2)}',
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  subtitle: Text('Batch Quantity: ${s.quantity.toStringAsFixed(0)}', 
                      style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w600)),
                  trailing: Icon(Icons.edit_note_rounded, color: theme.highlight),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openProductScreen(product: p);
                  },
                ),
              );
            }),
            ],
          ),
        );
      },
    );
  }
}
