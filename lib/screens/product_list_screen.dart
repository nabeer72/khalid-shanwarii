
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
  // ignore: unused_field
  List<ProductCategory> _categories = [];
  bool _loading = true;
  String _searchQuery = '';
  final Set<String> _expandedGroups = {};
  bool _isInactiveView = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final productsData = await DatabaseHelper.instance.getProducts(includeInactive: true);
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

  Future<void> _toggleStatus(Product product) async {
    if (product.id != null) {
      await DatabaseHelper.instance.toggleProductStatus(product.id!, product.status);
      _loadData();
    }
  }

  // ignore: unused_element
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
                child: Row(
                  children: [
                    Expanded(
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
                            setState(() => _searchQuery = val.trim().toLowerCase());
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 50,
                      width: 160,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.whiteAlpha(0.05),
                        borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                        border: Border.all(color: theme.whiteAlpha(0.1)),
                      ),
                      child: Row(
                        children: [
                          _buildTabButton('Active', !_isInactiveView),
                          _buildTabButton('Deactive', _isInactiveView),
                        ],
                      ),
                    ),
                  ],
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

    // Filter by search query and active status
    final filtered = _products.where((p) {
      final matchesStatus = _isInactiveView ? p.status == 0 : p.status == 1;
      if (!matchesStatus) return false;

      if (_searchQuery.isEmpty) return true;
      final name = p.name.toLowerCase();
      final barcode = p.stocks.any((s) => (s.barcode ?? '').toLowerCase().contains(_searchQuery));
      return name.contains(_searchQuery) || barcode;
    }).toList();

    // Group by Name
    final Map<String, List<Product>> grouped = {};
    for (var p in filtered) {
      grouped.putIfAbsent(p.name, () => []).add(p);
    }

    final sortedNames = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: sortedNames.length,
      itemBuilder: (context, index) {
        final name = sortedNames[index];
        final group = grouped[name]!;
        final isExpanded = _expandedGroups.contains(name);
        
        // Aggregate Data
        final totalStock = group.fold(0.0, (sum, p) => sum + p.totalStock);
        final isActive = group.any((p) => p.status == 1);
        
        // Collect all Prices
        final Set<double> uniquePrices = {};
        for (var p in group) {
          for (var s in p.stocks) {
            uniquePrices.add(s.salePrice);
          }
        }
        
        final hasVariants = group.length > 1 || uniquePrices.length > 1;
        final displayPrice = uniquePrices.length == 1 ? uniquePrices.first.toStringAsFixed(2) : '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (hasVariants) {
                      setState(() {
                        if (isExpanded) {
                          _expandedGroups.remove(name);
                        } else {
                          _expandedGroups.add(name);
                        }
                      });
                    } else if (group.isNotEmpty) {
                      _openProductScreen(product: group.first);
                    }
                  },
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                  child: Container(
                    decoration: theme.glassDecoration.copyWith(
                      border: !isActive 
                        ? Border.all(color: ThemeProvider.error.withOpacity(0.4), width: 1.5)
                        : isExpanded ? Border.all(color: theme.highlight.withOpacity(0.3), width: 1.5) : null,
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
                                    'Stock: ${totalStock.toStringAsFixed(0)} | ${group.length} variants',
                                    style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            if (displayPrice.isNotEmpty)
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
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
                            if (hasVariants)
                              Icon(
                                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: theme.highlight,
                                size: 24,
                              ),
                            if (!hasVariants)
                              Switch.adaptive(
                                value: isActive,
                                activeColor: theme.toggleActiveColor,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (val) {
                                  for (var p in group) {
                                    _toggleStatus(p);
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
              if (isExpanded)
                _buildVariantsList(name, group),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVariantsList(String name, List<Product> group) {
    // Find ANY non-null barcode in the entire group to use as fallback
    String? fallbackBarcode;
    for (var prod in group) {
      for (var stk in prod.stocks) {
        if (stk.barcode != null && stk.barcode!.isNotEmpty) {
          fallbackBarcode = stk.barcode;
          break;
        }
      }
      if (fallbackBarcode != null) break;
    }

    final Map<String, MapEntry<Product, Stock>> variants = {};
    for (var p in group) {
      for (var s in p.stocks) {
        // Use individual barcode if present, otherwise fallback to any barcode in group
        final effectiveBarcode = s.barcode ?? fallbackBarcode;
        final key = '${s.salePrice}_${effectiveBarcode ?? 'default'}';
        if (variants.containsKey(key)) {
          final existingStock = variants[key]!.value;
          variants[key] = MapEntry(p, existingStock.copyWith(quantity: existingStock.quantity + s.quantity));
        } else {
          variants[key] = MapEntry(p, s);
        }
      }
    }
    final flattened = variants.values.toList()..sort((a, b) => b.value.salePrice.compareTo(a.value.salePrice));

    return Container(
      margin: const EdgeInsets.only(top: 4, left: 16, right: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.highlight.withOpacity(0.2), width: 2)),
      ),
      child: Column(
        children: flattened.map((entry) {
          final p = entry.key;
          final s = entry.value;
          final bool isLowStock = s.quantity <= p.stockLimit;
          final currentEffectiveBarcode = s.barcode ?? fallbackBarcode ?? 'Default';

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => _openProductScreen(product: p),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${BusinessConfig.instance.currencyDisplay} ${s.salePrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: theme.textPrimary, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 13,
                              decoration: s.status == 0 ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          Text('Barcode: $currentEffectiveBarcode',
                              style: TextStyle(
                                color: theme.textHint, 
                                fontSize: 10,
                                decoration: s.status == 0 ? TextDecoration.lineThrough : null,
                              )),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: s.status == 0
                            ? theme.textHint.withOpacity(0.1)
                            : isLowStock
                                ? ThemeProvider.error.withOpacity(0.1)
                                : ThemeProvider.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        s.status == 0 ? 'Inactive' : '${s.quantity.toStringAsFixed(0)} Unit',
                        style: TextStyle(
                          color: s.status == 0
                              ? theme.textHint
                              : isLowStock
                                  ? ThemeProvider.error
                                  : ThemeProvider.success,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: s.status == 1,
                      activeColor: theme.toggleActiveColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) async {
                        await DatabaseHelper.instance.toggleStockStatus(s.id, s.status);
                        _loadData();
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_note_rounded, color: theme.highlight, size: 18),
                      onPressed: () => _openProductScreen(product: p),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabButton(String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isInactiveView = (label == 'Deactive')),
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
}
