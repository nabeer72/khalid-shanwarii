import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/stock.dart';
import 'package:mobile_app/providers/theme_provider.dart';

/// Displays products with or without stock and returns the product with its
/// newest active [Stock] batch, if one exists.
///
/// The dialog is used from the `CreateDealScreen` when the user taps the
/// "Add Product" button. It does **not** modify any other UI elements.
class ProductPickerDialog extends StatefulWidget {
  const ProductPickerDialog({Key? key}) : super(key: key);

  @override
  State<ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<ProductPickerDialog> {
  final ThemeProvider _theme = ThemeProvider.instance;
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  List<Product> _products = [];
  Map<int, Stock?> _productStocks = {};
  String _query = '';
  String? _loadError;

  List<Product> get _filteredProducts {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _products;
    return _products.where((product) {
      final barcode = product.latestBarcode?.toLowerCase() ?? '';
      return product.name.toLowerCase().contains(query) ||
          barcode.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final productsData =
          await DatabaseHelper.instance.getProducts(includeInactive: true);
      final List<Product> loaded = [];
      final Map<int, Stock?> stockMap = {};
      for (final pData in productsData) {
        final stocksData =
            List<Map<String, dynamic>>.from(pData['stocks'] ?? []);
        final product = Product.fromMap(pData,
            stocks: stocksData.map((s) => Stock.fromMap(s)).toList());
        final activeStocks =
            product.stocks.where((stock) => stock.status == 1).toList()
              ..sort((a, b) {
                final aId = (a.id as num?)?.toInt() ?? 0;
                final bId = (b.id as num?)?.toInt() ?? 0;
                return bId.compareTo(aId);
              });
        final inStockBatches =
            activeStocks.where((stock) => stock.quantity > 0).toList();

        loaded.add(product);
        stockMap[product.id!] = inStockBatches.isNotEmpty
            ? inStockBatches.first
            : activeStocks.isNotEmpty
                ? activeStocks.first
                : null;
      }
      if (mounted) {
        setState(() {
          _products = loaded;
          _productStocks = stockMap;
          _loadError = null;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading products for picker: $e');
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _theme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeProvider.radiusDialog),
        side: BorderSide(color: _theme.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 540,
              maxHeight: maxHeight,
            ),
            child: SizedBox(
              width: 540,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _theme.highlight.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.inventory_2_outlined,
                              color: _theme.highlight, size: 23),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add product',
                                style: TextStyle(
                                  color: _theme.textPrimary,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _loading
                                    ? 'Loading inventory'
                                    : '${_filteredProducts.length} products available',
                                style: TextStyle(
                                  color: _theme.textSecondary,
                                  fontSize: ThemeProvider.fontSmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close_rounded,
                              color: _theme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      style: TextStyle(color: _theme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search products or scan barcode',
                        hintStyle: TextStyle(color: _theme.textHint),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: _theme.textSecondary),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: Icon(Icons.close_rounded,
                                    color: _theme.textSecondary),
                              ),
                        filled: true,
                        fillColor: _theme.muted,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(ThemeProvider.radiusInput),
                          borderSide: BorderSide(color: _theme.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(ThemeProvider.radiusInput),
                          borderSide: BorderSide(color: _theme.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(ThemeProvider.radiusInput),
                          borderSide:
                              BorderSide(color: _theme.highlight, width: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: _buildProductList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductList() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: _theme.highlight),
      );
    }

    if (_loadError != null) {
      return _buildEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Products could not be loaded',
        message: 'Check the inventory and try opening the picker again.',
      );
    }

    final products = _filteredProducts;
    if (products.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off_rounded,
        title: _query.isEmpty ? 'No products found' : 'No matching products',
        message: _query.isEmpty
            ? 'Add products to inventory before building this deal.'
            : 'Try a different product name or barcode.',
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final product = products[index];
        final stock = _productStocks[product.id!];
        final quantity = stock?.quantity ?? 0;
        final hasStock = quantity > 0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
            onTap: () {
              Navigator.of(context).pop({
                'product': product,
                'stock': stock,
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: _theme.card,
                borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                border: Border.all(color: _theme.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _theme.highlight.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.inventory_2_outlined,
                        color: _theme.highlight, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _theme.textPrimary,
                            fontSize: ThemeProvider.fontList,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              hasStock
                                  ? Icons.inventory_outlined
                                  : Icons.remove_circle_outline_rounded,
                              size: 13,
                              color: hasStock
                                  ? _theme.textSecondary
                                  : ThemeProvider.warning,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                hasStock
                                    ? 'Stock ${quantity.toStringAsFixed(0)}'
                                    : 'No stock - manual sale',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: hasStock
                                      ? _theme.textSecondary
                                      : ThemeProvider.warning,
                                  fontSize: ThemeProvider.fontSmall,
                                ),
                              ),
                            ),
                            if (product.status == 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                'INACTIVE',
                                style: TextStyle(
                                  color: _theme.textHint,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    product.priceRange,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: _theme.highlight,
                      fontSize: ThemeProvider.fontSmall,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: _theme.textHint),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: _theme.muted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: _theme.textSecondary, size: 25),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _theme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: ThemeProvider.fontLabel,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _theme.textSecondary,
                fontSize: ThemeProvider.fontSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
