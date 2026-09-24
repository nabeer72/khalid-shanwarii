import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/stock.dart';
import 'package:mobile_app/providers/theme_provider.dart';

/// A simple dialog that displays a list of all products (including inactive) and
/// returns the selected [Product] together with its first [Stock] (if any).
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
  bool _loading = true;
  List<Product> _products = [];
  Map<int, Stock?> _productStocks = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final productsData = await DatabaseHelper.instance.getProducts(includeInactive: true);
      final List<Product> loaded = [];
      final Map<int, Stock?> stockMap = {};
      for (final pData in productsData) {
        final stocksData = List<Map<String, dynamic>>.from(pData['stocks'] ?? []);
        final product = Product.fromMap(pData, stocks: stocksData.map((s) => Stock.fromMap(s)).toList());
        loaded.add(product);
        // Keep the first stock (or null) for quick access.
        stockMap[product.id!] = product.stocks.isNotEmpty ? product.stocks.first : null;
      }
      if (mounted) {
        setState(() {
          _products = loaded;
          _productStocks = stockMap;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading products for picker: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
      child: Container(
        width: double.maxFinite,
        height: 500,
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Select Product', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _theme.primary)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _products.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final stock = _productStocks[product.id!];
                        return ListTile(
                          title: Text(product.name),
                          subtitle: Text('Price: ${product.latestPrice.toStringAsFixed(2)} | Stock: ${stock?.quantity ?? "-"}'),
                          onTap: () {
                            Navigator.of(context).pop({
                              'product': product,
                              'stock': stock,
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
