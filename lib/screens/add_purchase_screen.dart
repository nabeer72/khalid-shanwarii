import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/controllers/add_purchase_controller.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/scanner_screen.dart';
import 'package:mobile_app/screens/add_supplier_screen.dart';
import 'package:mobile_app/screens/add_product_screen.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class AddPurchaseScreen extends StatefulWidget {
  final int? preSelectedProductId;
  const AddPurchaseScreen({super.key, this.preSelectedProductId});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  late AddPurchaseController _controller;
  final theme = ThemeProvider.instance;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = AddPurchaseController();
    _controller.addListener(_rebuild);
    _controller.onProductSelected = (productId) {
      _showAddItemDialog(productId: productId);
    };

    if (widget.preSelectedProductId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Wait for products to load before showing dialog
        if (!_controller.isLoading) {
          _showAddItemDialog(productId: widget.preSelectedProductId);
        } else {
          // If loading, add a one-time listener to show dialog when loaded
          void onLoaded() {
            if (!_controller.isLoading) {
              _controller.removeListener(onLoaded);
              _showAddItemDialog(productId: widget.preSelectedProductId);
            }
          }
          _controller.addListener(onLoaded);
        }
      });
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: theme.highlight)),
      );
    }

    // Show feedback messages from controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_controller.errorMessage!),
            backgroundColor: ThemeProvider.error,
          ),
        );
        _controller.clearFeedback();
      }
      if (_controller.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_controller.successMessage!),
            backgroundColor: ThemeProvider.success,
          ),
        );
        _controller.clearFeedback();
        Navigator.pop(context);
      }
    });

    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'New Purchase',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
      ),
      floatingActionButton: isDesktop
          ? FloatingActionButton.extended(
              onPressed: _controller.canSave ? _handleSavePurchase : null,
              backgroundColor: _controller.canSave ? theme.highlight : theme.highlight.withOpacity(0.3),
              foregroundColor: Colors.white,
              elevation: _controller.canSave ? 8 : 0,
              icon: const Icon(Icons.save_rounded),
              label: const Text('SAVE PURCHASE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
            )
          : null,
      body: theme.glassBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total display
                      _TotalCard(total: _controller.formattedTotal, theme: theme),

                      const SizedBox(height: 24),

                      // Purchase info
                      _PurchaseInfoCard(
                        controller: _controller,
                        theme: theme,
                        onDateTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _controller.purchaseDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) _controller.setPurchaseDate(picked);
                        },
                        onAddSupplier: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddSupplierScreen()),
                          );
                          await _controller.reloadSuppliers();
                        },
                      ),

                      const SizedBox(height: 32),

                      // Items header + button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Items',
                            style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [theme.highlight, theme.highlight.withOpacity(0.85)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.highlight.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _showAddItemDialog,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'ADD ITEM', 
                                        style: TextStyle(
                                          color: Colors.white, 
                                          fontWeight: FontWeight.w900, 
                                          fontSize: 12, 
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Items list or empty state
                      if (_controller.items.isEmpty)
                        _EmptyItemsState(theme: theme)
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _controller.items.length,
                          itemBuilder: (context, index) {
                            final item = _controller.items[index];
                            return _ItemTile(
                              item: item,
                              theme: theme,
                              currency: BusinessConfig.instance.currency,
                              onRemove: () => _controller.removeItem(index),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // Bottom save bar (mobile only)
              if (!isDesktop)
                _SaveButton(
                  theme: theme,
                  total: _controller.formattedTotal,
                  previous: _controller.formattedPreviousCredit,
                  onPressed: _controller.canSave ? _handleSavePurchase : null,
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  void _handleSavePurchase() {
    if (_formKey.currentState!.validate()) {
      _controller.savePurchase();
    }
  }

  InputDecoration _dialogInputDecoration(ThemeProvider theme, String label, IconData icon, {bool isRequired = false}) {
    return InputDecoration(
      label: isRequired 
        ? RichText(
            text: TextSpan(
              text: label,
              style: TextStyle(color: theme.textSecondary),
              children: [
                TextSpan(text: ' *', style: TextStyle(color: theme.highlight, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        : Text(label, style: TextStyle(color: theme.textSecondary)),
      labelStyle: TextStyle(color: theme.textSecondary),
      prefixIcon: Icon(icon, color: theme.iconColor),
      filled: true,
      fillColor: theme.whiteAlpha(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThemeProvider.radiusInput),
        borderSide: BorderSide(color: theme.highlight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.highlight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.highlight, width: 1.5),
      ),
    );
  }

  void _showAddItemDialog({int? productId}) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final wholesaleCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final piecesCtrl = TextEditingController(text: '1');
    final searchCtrl = TextEditingController();
    bool isScannerOpen = false;
    bool isDropdownOpen = false;
    MobileScannerController? scannerController;
    AudioPlayer? audioPlayer;
    DateTime? lastScanTime;
    List<Map<String, dynamic>> queuedItems = [];

    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        audioPlayer = AudioPlayer();
      }
    } catch (_) {}

    int? selectedProductId = productId;
    int? selectedCategoryId;
    int? selectedUnitId;
    int stock = 0;
    double currCost = 0;
    double currWholesale = 0;
    double currPrice = 0;
    bool isManualEntry = false;
    bool isBoxUnit = false;

    // Initialize if productId is provided
    if (selectedProductId != null) {
      final p = _controller.products.firstWhere((x) => x['id'] == selectedProductId, orElse: () => {});
      if (p.isNotEmpty) {
        nameCtrl.text = p['name'] as String;
        
        final stocks = p['stocks'] as List<dynamic>? ?? [];
        if (stocks.isNotEmpty) {
          final latestStock = stocks.last; 
          currCost = (latestStock['cost_price'] as num? ?? 0).toDouble();
          currWholesale = (latestStock['wholesale_price'] as num? ?? 0).toDouble();
          currPrice = (latestStock['sale_price'] as num? ?? 0).toDouble();
          stock = (latestStock['quantity'] as num? ?? 0).toInt();
        } else {
          currCost = (p['purchase_price'] as num? ?? 0).toDouble();
          currWholesale = (p['wholesale_price'] as num? ?? 0).toDouble();
          currPrice = (p['price'] as num? ?? 0).toDouble();
          stock = 0;
        }

        costCtrl.text = currCost.toStringAsFixed(2);
        wholesaleCtrl.text = currWholesale.toStringAsFixed(2);
        priceCtrl.text = currPrice.toStringAsFixed(2);
        
        if (p['unit_id'] != null) {
          selectedUnitId = p['unit_id'];
          final unit = _controller.units.firstWhere((u) => u['id'] == selectedUnitId, orElse: () => {});
          isBoxUnit = ['box', 'carton', 'bag'].any((w) => (unit['name'] ?? '').toString().toLowerCase().contains(w));
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void clearInputs() {
              setDialogState(() {
                selectedProductId = null;
                searchCtrl.clear();
                qtyCtrl.text = '1';
                costCtrl.text = '0.00';
                wholesaleCtrl.text = '0.00';
                priceCtrl.text = '0.00';
                stock = 0;
              });
            }
            final filteredProducts = _controller.products;

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              content: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                ),
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add Purchase Item',
                            style: TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 18, 
                              fontWeight: FontWeight.w900, 
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => setDialogState(() {
                              isManualEntry = !isManualEntry;
                              selectedProductId = null;
                              if (isManualEntry) {
                                nameCtrl.clear();
                                costCtrl.clear();
                                wholesaleCtrl.clear();
                                priceCtrl.clear();
                              }
                            }),
                            icon: Icon(isManualEntry ? Icons.list_rounded : Icons.edit_note_rounded, size: 18),
                            label: Text(isManualEntry ? 'Select Existing' : 'Manual Entry', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      if (!isManualEntry) ...[
                        // Searchable Product Selector
                        // Searchable Product Selector using Column (pushes content down)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isScannerOpen)
                              Container(
                                height: 160,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: theme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.highlight.withOpacity(0.3)),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)
                                  ? MobileScanner(
                                      controller: scannerController ??= MobileScannerController(),
                                      onDetect: (capture) async {
                                        final List<Barcode> barcodes = capture.barcodes;
                                        if (barcodes.isNotEmpty) {
                                          final code = barcodes.first.rawValue;
                                          if (code != null) {
                                            final now = DateTime.now();
                                            if (lastScanTime == null || now.difference(lastScanTime!) > const Duration(seconds: 2)) {
                                              lastScanTime = now;
                                              try { audioPlayer?.play(AssetSource('beep.mp3')); } catch (_) {}
                                              
                                              final p = _controller.products.firstWhere(
                                                (x) => x['barcode']?.toString() == code,
                                                orElse: () => {},
                                              );
                                              if (p.isNotEmpty) {
                                                setDialogState(() {
                                                  selectedProductId = p['id'] as int;
                                                  nameCtrl.text = p['name'] as String;
                                                  searchCtrl.text = p['name'] as String;
                                                  isScannerOpen = false;
                                                  isDropdownOpen = false;
                                                  
                                                  final stocks = p['stocks'] as List<dynamic>? ?? [];
                                                  if (stocks.isNotEmpty) {
                                                    final latestStock = stocks.last; 
                                                    currCost = (latestStock['cost_price'] as num? ?? 0).toDouble();
                                                    currWholesale = (latestStock['wholesale_price'] as num? ?? 0).toDouble();
                                                    currPrice = (latestStock['sale_price'] as num? ?? 0).toDouble();
                                                    stock = (latestStock['quantity'] as num? ?? 0).toInt();
                                                  } else {
                                                    currCost = (p['purchase_price'] as num? ?? 0).toDouble();
                                                    currWholesale = (p['wholesale_price'] as num? ?? 0).toDouble();
                                                    currPrice = (p['price'] as num? ?? 0).toDouble();
                                                    stock = 0;
                                                  }
                                                  costCtrl.text = currCost.toStringAsFixed(2);
                                                  wholesaleCtrl.text = currWholesale.toStringAsFixed(2);
                                                  priceCtrl.text = currPrice.toStringAsFixed(2);
                                                });
                                              }
                                            }
                                          }
                                        }
                                      },
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.camera_enhance_outlined, color: theme.textSecondary.withOpacity(0.5), size: 32),
                                          const SizedBox(height: 12),
                                          Text('Camera not available on desktop', 
                                              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                                          const SizedBox(height: 8),
                                          TextButton(
                                            onPressed: () => setDialogState(() => isScannerOpen = false),
                                            child: Text('Close Scanner', style: TextStyle(color: theme.highlight)),
                                          ),
                                        ],
                                      ),
                                    ),
                              ),
                            TextFormField(
                              controller: searchCtrl,
                              decoration: _dialogInputDecoration(theme, 'Search Product...', Icons.search_rounded).copyWith(
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (searchCtrl.text.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 20),
                                        onPressed: () {
                                          setDialogState(() {
                                            searchCtrl.clear();
                                            selectedProductId = null;
                                          });
                                        },
                                      ),
                                    IconButton(
                                      icon: Icon(isScannerOpen ? Icons.close_rounded : Icons.qr_code_scanner_rounded, color: theme.highlight),
                                      onPressed: () {
                                        setDialogState(() {
                                          isScannerOpen = !isScannerOpen;
                                          if (!isScannerOpen) scannerController?.dispose();
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(isDropdownOpen ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, color: theme.iconColor),
                                      onPressed: () {
                                        setDialogState(() {
                                          isDropdownOpen = !isDropdownOpen;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                              ),
                              onChanged: (v) => setDialogState(() {
                                if (v.isNotEmpty) isDropdownOpen = true;
                              }),
                              onTap: () => setDialogState(() {
                                if (selectedProductId != null) {
                                  selectedProductId = null;
                                  searchCtrl.clear();
                                  isDropdownOpen = true;
                                }
                              }),
                            ),
                            if (isDropdownOpen && selectedProductId == null)
                              Container(
                                constraints: const BoxConstraints(maxHeight: 180),
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
                                  ],
                                  border: Border.all(color: theme.highlight.withOpacity(0.1)),
                                ),
                                child: ListView(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  children: _controller.products
                                      .where((p) => 
                                          searchCtrl.text.isEmpty ||
                                          p['name'].toString().toLowerCase().contains(searchCtrl.text.toLowerCase()) ||
                                          p['barcode'].toString().contains(searchCtrl.text))
                                      .map((p) => ListTile(
                                            title: Text(p['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                            subtitle: (p['barcode'] == null || p['barcode'].toString() == 'null' || p['barcode'].toString().isEmpty) 
                                                ? null 
                                                : Text('Barcode: ${p['barcode']}', style: const TextStyle(fontSize: 11)),
                                            dense: true,
                                            onTap: () {
                                              setDialogState(() {
                                                selectedProductId = p['id'] as int;
                                                nameCtrl.text = p['name'] as String;
                                                searchCtrl.text = p['name'] as String;
                                                isDropdownOpen = false;
                                                
                                                final stocks = p['stocks'] as List<dynamic>? ?? [];
                                                if (stocks.isNotEmpty) {
                                                  final latestStock = stocks.last; 
                                                  currCost = (latestStock['cost_price'] as num? ?? 0).toDouble();
                                                  currWholesale = (latestStock['wholesale_price'] as num? ?? 0).toDouble();
                                                  currPrice = (latestStock['sale_price'] as num? ?? 0).toDouble();
                                                  stock = (latestStock['quantity'] as num? ?? 0).toInt();
                                                } else {
                                                  currCost = (p['purchase_price'] as num? ?? 0).toDouble();
                                                  currWholesale = (p['wholesale_price'] as num? ?? 0).toDouble();
                                                  currPrice = (p['price'] as num? ?? 0).toDouble();
                                                  stock = 0;
                                                }
                                                costCtrl.text = currCost.toStringAsFixed(2);
                                                wholesaleCtrl.text = currWholesale.toStringAsFixed(2);
                                                priceCtrl.text = currPrice.toStringAsFixed(2);
                                              });
                                            },
                                          ))
                                      .toList(),
                                ),
                              ),
                          ],
                        ),
                      ] else ...[
                        TextField(
                          controller: nameCtrl,
                          decoration: _dialogInputDecoration(theme, 'Product Name', Icons.edit_note_rounded, isRequired: true),
                          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ],

                      const SizedBox(height: 12),
                      if (false) ...[
                        Builder(
                          builder: (context) {
                            final unitMap = selectedUnitId != null ? _controller.units.firstWhere((u) => u['id'] == selectedUnitId, orElse: () => {}) : {};
                            final unitName = unitMap['name']?.toString() ?? 'Box';
                            return Column(
                              children: [
                                // Row 1: Cost per Unit + Wholesale per Unit
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: costCtrl,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: _dialogInputDecoration(theme, 'Purchase $unitName Price', Icons.inventory_2_outlined, isRequired: true),
                                        style: TextStyle(color: theme.textPrimary),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: wholesaleCtrl,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: _dialogInputDecoration(theme, '$unitName Wholesale Price', Icons.local_offer_outlined),
                                        style: TextStyle(color: theme.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Row 2: Sale Price per Unit + Qty per Unit
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: priceCtrl,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: _dialogInputDecoration(theme, '$unitName Sale Price', Icons.account_balance_wallet_outlined, isRequired: true),
                                        style: TextStyle(color: theme.textPrimary),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: piecesCtrl,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: _dialogInputDecoration(theme, '$unitName Quantity', Icons.grid_view_rounded, isRequired: true),
                                        style: TextStyle(color: theme.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Row 3: Initial Units
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: qtyCtrl,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: _dialogInputDecoration(theme, 'Initial ${unitName}s', Icons.warehouse_outlined, isRequired: true),
                                        style: TextStyle(color: theme.textPrimary),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(child: SizedBox()),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Total Pieces Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: theme.highlight.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: theme.highlight.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Total Pieces Result:', style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                                      Text(
                                        '${(double.tryParse(qtyCtrl.text) ?? 0) * (double.tryParse(piecesCtrl.text) ?? 1)} Pieces',
                                        style: TextStyle(color: theme.highlight, fontSize: 13, fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
                        ),
                      ] else ...[
                        // Non-box: show regular fields
                        if (selectedProductId != null)
                          _ProductStats(
                            stock: stock,
                            cost: currCost,
                            currency: BusinessConfig.instance.currency,
                            theme: theme,
                            isDialog: true,
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setDialogState(() {}),
                                decoration: _dialogInputDecoration(theme, 'Stock Quantity', Icons.numbers_rounded, isRequired: true),
                                style: TextStyle(color: theme.textPrimary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: costCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setDialogState(() {}),
                                decoration: _dialogInputDecoration(theme, 'Cost Price', Icons.attach_money_rounded, isRequired: true),
                                style: TextStyle(color: theme.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: wholesaleCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setDialogState(() {}),
                                decoration: _dialogInputDecoration(theme, 'Wholesale Price', Icons.business_center_rounded),
                                style: TextStyle(color: theme.textPrimary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: priceCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setDialogState(() {}),
                                decoration: _dialogInputDecoration(theme, 'Sale Price', Icons.price_change_rounded, isRequired: true),
                                style: TextStyle(color: theme.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx), 
                              child: const Text('CANCEL', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w900)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [theme.highlight, theme.highlight.withOpacity(0.85)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.highlight.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    final name = nameCtrl.text.trim();
                                    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                                    final pCost = double.tryParse(costCtrl.text.trim()) ?? 0;
                                    final pieces = double.tryParse(piecesCtrl.text.trim()) ?? 1.0;
                                    
                                    if (name.isEmpty || qty <= 0 || pCost <= 0) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(content: Text('Please enter valid name, quantity and cost')),
                                      );
                                      return;
                                    }
     
                                    _controller.addItem(
                                      productId: selectedProductId,
                                      productName: name,
                                      barcode: selectedProductId != null 
                                        ? _controller.products.firstWhere((x) => x['id'] == selectedProductId)['barcode'] as String?
                                        : null,
                                      existingStock: stock.toDouble(),
                                      quantity: qty,
                                      purchasePrice: pCost,
                                      wholesalePrice: double.tryParse(wholesaleCtrl.text.trim()) ?? 0,
                                      sellingPrice: double.tryParse(priceCtrl.text.trim()) ?? 0,
                                      unitId: selectedUnitId,
                                      piecesPerBox: pieces,
                                    );
                                    Navigator.pop(ctx);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    alignment: Alignment.center,
                                    height: 44,
                                    child: const Text(
                                      'ADD ITEM', 
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900, 
                                        fontSize: 13,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String total;
  final ThemeProvider theme;
  const _TotalCard({required this.total, required this.theme});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: theme.glassDecoration.copyWith(
        gradient: LinearGradient(
          colors: [theme.highlight.withOpacity(0.2), theme.highlight.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TOTAL PURCHASE', style: TextStyle(color: theme.highlight, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(total, style: TextStyle(color: theme.textPrimary, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.highlight, shape: BoxShape.circle),
            child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

class _PurchaseInfoCard extends StatelessWidget {
  final AddPurchaseController controller;
  final ThemeProvider theme;
  final VoidCallback onDateTap;
  final VoidCallback onAddSupplier;

  const _PurchaseInfoCard({
    required this.controller,
    required this.theme,
    required this.onDateTap,
    required this.onAddSupplier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: theme.glassDecoration,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: controller.selectedSupplierId,
                  dropdownColor: theme.surface,
                  validator: (v) => v == null ? 'Supplier is required' : null,
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
                  decoration: theme.glassInputDecoration('Supplier', Icons.business_rounded, isRequired: true),
                  items: controller.suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: controller.setSupplier,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: theme.highlight.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                ),
                child: IconButton(
                  icon: Icon(Icons.add_rounded, color: theme.highlight, size: 22),
                  tooltip: 'Add New Supplier',
                  onPressed: onAddSupplier,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // New Row for Category and Product selection
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: controller.mainProductId,
                  dropdownColor: theme.surface,
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                  decoration: theme.glassInputDecoration('Product', Icons.inventory_rounded),
                  items: controller.products
                    .map((p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['name'] as String, overflow: TextOverflow.ellipsis)))
                    .toList(),
                  onChanged: controller.setMainProduct,
                ),
              ),
            ],
          ),
          if (controller.selectedSupplier != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ThemeProvider.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                  border: Border.all(color: ThemeProvider.error.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, color: ThemeProvider.error, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'Prev. Credit: ${controller.formattedPreviousCredit}',
                      style: TextStyle(
                        color: ThemeProvider.error, 
                        fontSize: 13, 
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onDateTap,
                  child: InputDecorator(
                    decoration: theme.glassInputDecoration('Date', Icons.calendar_today_rounded, isRequired: true),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(DateFormat('yyyy-MM-dd').format(controller.purchaseDate), maxLines: 1, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller.invoiceCtrl,
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
                  decoration: theme.glassInputDecoration('Invoice #', Icons.receipt_rounded, isRequired: true),
                  onChanged: (v) => controller.checkInvoiceDuplicate(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (controller.isInvoiceDuplicate) return 'Invoice already exists';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: controller.paymentType,
            dropdownColor: theme.surface,
            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
            decoration: theme.glassInputDecoration('Payment Type', Icons.payment_rounded),
            items: controller.paymentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => v != null ? controller.setPaymentType(v) : null,
          ),
          if (controller.paymentType == 'Cheque') ...[
            const SizedBox(height: 16),
            TextField(controller: controller.chequeNoCtrl, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600), decoration: theme.glassInputDecoration('Cheque Number', Icons.confirmation_number_rounded)),
          ] else if (controller.paymentType == 'Bank Transfer') ...[
            const SizedBox(height: 16),
            TextField(controller: controller.bankNameCtrl, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600), decoration: theme.glassInputDecoration('Bank Name', Icons.account_balance_rounded)),
            const SizedBox(height: 16),
            TextField(controller: controller.transRefCtrl, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600), decoration: theme.glassInputDecoration('Transaction Reference', Icons.receipt_long_rounded)),
          ],
          const SizedBox(height: 16),
          // Payment Section (Prominent)
          TextField(
            controller: controller.paidAmountCtrl,
            enabled: controller.paymentType == 'Partial',
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: controller.paymentType == 'Partial' ? theme.textPrimary : theme.textSecondary, 
              fontWeight: FontWeight.w600
            ),
            // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
            onChanged: (v) => controller.notifyListeners(),
            decoration: theme.glassInputDecoration('Paid Amount', Icons.payments_rounded),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.whiteAlpha(0.05),
              borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
              border: Border.all(color: theme.whiteAlpha(0.1)),
            ),
            child: Column(
              children: [
                _SummaryRow(label: 'Net Total', value: controller.formattedTotal, theme: theme, isBold: true),
                const SizedBox(height: 8),
                _SummaryRow(label: 'Paid', value: '${BusinessConfig.instance.currency}. ${controller.paidAmount.toStringAsFixed(2)}', theme: theme),
                const Divider(height: 24, color: Colors.white10),
                _SummaryRow(
                  label: 'To Balance', 
                  value: '${BusinessConfig.instance.currency}. ${controller.creditAmount.toStringAsFixed(2)}', 
                  theme: theme, 
                  valueColor: controller.creditAmount > 0 ? ThemeProvider.error : ThemeProvider.success,
                  isBold: true,
                ),
                const SizedBox(height: 4),
                _SummaryRow(
                  label: 'New Balance', 
                  value: '${BusinessConfig.instance.currency}. ${controller.newBalance.toStringAsFixed(2)}', 
                  theme: theme,
                  isItalic: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: controller.notesCtrl, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600), maxLines: 2, decoration: theme.glassInputDecoration('Notes', Icons.note_rounded)),
        ],
      ),
    );
  }
}

class _EmptyItemsState extends StatelessWidget {
  final ThemeProvider theme;
  const _EmptyItemsState({required this.theme});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      alignment: Alignment.center,
      decoration: theme.glassDecoration,
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, color: theme.iconColor, size: 48),
          const SizedBox(height: 16),
          Text('No items added yet', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Tap "Add Item" to start.', style: TextStyle(color: theme.textHint, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeProvider theme;
  final bool isBold;
  final bool isItalic;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.theme,
    this.isBold = false,
    this.isItalic = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            fontStyle: isItalic ? FontStyle.italic : null,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? theme.textPrimary,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            fontStyle: isItalic ? FontStyle.italic : null,
          ),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final ThemeProvider theme;
  final String currency;
  final VoidCallback onRemove;

  const _ItemTile({required this.item, required this.theme, required this.currency, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: theme.glassListDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(item['product_name'] ?? 'Unknown', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Qty: ${item['quantity']} x $currency. ${item['purchase_price']}',
            style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$currency. ${(item['subtotal'] as double).toStringAsFixed(2)}',
              style: TextStyle(color: theme.highlight, fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.remove_circle_outline_rounded, color: ThemeProvider.error, size: 20), onPressed: onRemove),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final ThemeProvider theme;
  final VoidCallback? onPressed;
  final String? total;
  final String? previous;
  const _SaveButton({required this.theme, this.onPressed, this.total, this.previous});
  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: theme.glassDecoration.copyWith(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(ThemeProvider.radiusCard)),
        // Ensure visibility in light mode by adding a subtle border or background adjustment
        color: theme.isDark ? null : Colors.white.withOpacity(0.9),
        border: theme.isDark ? null : Border(top: BorderSide(color: Colors.black.withOpacity(0.05), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 200,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.highlight, 
                foregroundColor: Colors.white, 
                disabledBackgroundColor: theme.highlight.withOpacity(0.3),
                disabledForegroundColor: Colors.white.withOpacity(0.7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
                elevation: isDisabled ? 0 : 8, 
                shadowColor: theme.highlight.withOpacity(0.5),
              ),
              onPressed: onPressed,
              child: Text(
                'SAVE PURCHASE',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ),
          ),
          if (isDisabled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Add supplier and items to save',
                style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerButton extends StatelessWidget {
  final ThemeProvider theme;
  final Function(String) onScan;
  const _ScannerButton({required this.theme, required this.onScan});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: theme.highlight.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: IconButton(
        icon: Icon(Icons.qr_code_scanner_rounded, color: theme.highlight),
        onPressed: () async {
          final String? code = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
          if (code != null) onScan(code);
        },
      ),
    );
  }
}

class _ProductStats extends StatelessWidget {
  final int stock;
  final double cost;
  final String currency;
  final ThemeProvider theme;
  final bool isDialog;
  const _ProductStats({required this.stock, required this.cost, required this.currency, required this.theme, this.isDialog = false});
  @override
  Widget build(BuildContext context) {
    final bgColor = isDialog 
        ? Colors.black.withOpacity(0.05) 
        : (theme.isDark ? Colors.white10 : Colors.black12);
    final textColor = isDialog 
        ? const Color(0xFF1F2937) 
        : theme.textPrimary;
    final labelColor = isDialog
        ? const Color(0xFF6B7280)
        : theme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildMiniStat('In Stock', '$stock Items', labelColor, textColor),
          const Divider(height: 16),
          _buildMiniStat('Current Cost', '$currency. ${cost.toStringAsFixed(2)}', labelColor, textColor),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color labelColor, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
