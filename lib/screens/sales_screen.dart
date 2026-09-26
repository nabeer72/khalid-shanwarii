import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/sale.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final List<Map<String, dynamic>> _cart = [];
  final DatabaseHelper _db = DatabaseHelper.instance;
  double _total = 0;

  void _addToCart(Product product) {
    setState(() {
      final existingIndex = _cart.indexWhere((item) => item['id'] == product.id);
      if (existingIndex >= 0) {
        _cart[existingIndex]['quantity']++;
      } else {
        _cart.add({
          'id': product.id,
          'name': product.name,
          'quantity': 1,
        });
      }
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    // Since we don't have price, just count items for demo
    _total = _cart.fold(0.0, (sum, item) => sum + (item['quantity'] as int));
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
      _calculateTotal();
    });
  }

  void _checkout() async {
    if (_cart.isEmpty) return;

    final sale = Sale(
      businessId: BusinessConfig.instance.businessId ?? 0,
      userId: BusinessConfig.instance.userId,
      staffId: BusinessConfig.instance.staffId ?? 0,
      total: _total,
      status: 1,
    );

    try {
      final List<Map<String, dynamic>> saleItems = _cart.map((item) => {
        'product_id': item['id'],
        'quantity': item['quantity'],
        'price': 0.0, // Default price as sales_screen doesn't track it
        'subtotal': 0.0,
        'discount': 0.0,
      }).toList();

      await _db.insertSale({
        ...sale.toMap(),
        'total': _total,
        'subtotal': _total,
      }, saleItems);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale Saved!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving sale: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scanCamera() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 400,
        decoration: const BoxDecoration(
          color: Color(0xFF16213E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(ThemeProvider.radiusCard)),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Scan Barcode',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                child: (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)
                  ? MobileScanner(
                      onDetect: (capture) {
                        final barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final code = barcodes.first.rawValue;
                          if (code != null) {
                            Navigator.pop(ctx);
                            _processScan(code);
                          }
                        }
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_enhance_outlined, color: Colors.white.withOpacity(0.5), size: 48),
                          const SizedBox(height: 16),
                          Text('Camera not supported on desktop', 
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _processScan(String code) async {
    // Re-use isolated getProducts logic from ProductsCrud
    final allProducts = await _db.getProducts();
    final productMap = allProducts.where((p) => p['id'].toString() == code.toString()).firstOrNull;
    
    if (productMap != null) {
      _addToCart(Product.fromMap(productMap));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added: ${productMap['name']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product not found!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mockScan() async {
    final allProducts = await _db.getProducts();
    if (allProducts.isNotEmpty) {
      final first = allProducts.first;
      _addToCart(Product.fromMap(first));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added: ${first['name']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No products in DB. Sync first!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        title: const Text('New Sale'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _mockScan,
            tooltip: 'Mock Scan (Debug)',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 80,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Cart is empty',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap scan or debug icon to add items',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16213E),
                          borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3282B8),
                              borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                            ),
                            child: Center(
                              child: Text(
                                '${item['quantity']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            item['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeFromCart(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF16213E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(ThemeProvider.radiusCard)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Items',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '${_total.toInt()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _cart.isEmpty ? null : _checkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3282B8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                    ),
                  ),
                  child: const Text(
                    'CHECKOUT',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanCamera,
        backgroundColor: const Color(0xFF3282B8),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('SCAN'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
