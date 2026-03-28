import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/add_product_controller.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/scanner_screen.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/branch.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product;

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  late AddProductController _controller;
  final _formKey = GlobalKey<FormState>();
  final theme = ThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _controller = AddProductController(initialProduct: widget.product);
    _controller.addListener(_updateUI);
    _controller.loadCategories();
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_updateUI);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final result = await _controller.saveProduct();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: result['success'] ? ThemeProvider.success : ThemeProvider.error,
      ),
    );

    if (result['success'] == true) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final catCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Add Category', style: TextStyle(color: theme.textPrimary)),
        content: TextField(
          controller: catCtrl,
          style: TextStyle(color: theme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Category Name',
            labelStyle: TextStyle(color: theme.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.isDark ? theme.textHint : Colors.black.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.isDark ? theme.highlight : Colors.black.withOpacity(0.6)),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.highlight),
            onPressed: () async {
              if (catCtrl.text.trim().isNotEmpty) {
                final success = await _controller.addCategory(catCtrl.text.trim());
                if (success && mounted) {
                  Navigator.pop(c);
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSubCategoryDialog() async {
    if (_controller.selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a main category first')),
      );
      return;
    }

    final catCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Add Sub-Category', style: TextStyle(color: theme.textPrimary)),
        content: TextField(
          controller: catCtrl,
          style: TextStyle(color: theme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Sub-Category Name',
            labelStyle: TextStyle(color: theme.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.isDark ? theme.textHint : Colors.black.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.isDark ? theme.highlight : Colors.black.withOpacity(0.6)),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.highlight),
            onPressed: () async {
              if (catCtrl.text.trim().isNotEmpty) {
                final success = await _controller.addCategory(
                  catCtrl.text.trim(), 
                  parentId: _controller.selectedCategory,
                );
                if (success && mounted) {
                  Navigator.pop(c);
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: theme.highlight)),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _controller.screenTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.surface.withOpacity(0.8),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = ThemeProvider.isWideScreen(context);
              final saveButton = ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.highlight,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                  elevation: 4,
                ),
                child: const Text(
                  'SAVE PRODUCT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              );

              if (isWide) {
                return Row(
                  children: [
                    SizedBox(
                      width: 300,
                      child: saveButton,
                    ),
                  ],
                );
              }

              return SizedBox(
                width: double.infinity,
                child: saveButton,
              );
            },
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.bgGradient,
          ),
        ),
        child: Form(
          key: _formKey,
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Basic Information'),
                  _buildCard([
                    LayoutBuilder(builder: (context, constraints) {
                      final isWide = ThemeProvider.isWideScreen(context);
                      return Column(
                        children: [
                          if (isWide) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildCategorySelector()),
                                const SizedBox(width: 16),
                                Expanded(child: _buildSubCategorySelector()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildBarcodeScanner(),
                          ] else ...[
                            _buildCategorySelector(),
                            const SizedBox(height: 16),
                            _buildSubCategorySelector(),
                            const SizedBox(height: 16),
                            _buildBarcodeScanner(),
                          ],
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _controller.name,
                            label: 'Product Name',
                            icon: Icons.inventory_2_outlined,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                          ),
                        ],
                      );
                    }),
                  ]),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Pricing & Inventory'),
                  _buildCard([
                    LayoutBuilder(builder: (context, constraints) {
                      final isWide = ThemeProvider.isWideScreen(context);

                      String? validateInt(String? v, bool required) {
                        if (v == null || v.trim().isEmpty) return required ? 'Required' : null;
                        final parsed = int.tryParse(v);
                        if (parsed == null) return 'Must be an integer';
                        if (parsed < 0) return 'Cannot be negative';
                        return null;
                      }

                      String? validateStock(String? v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final val = num.tryParse(v);
                        if (val == null) return 'Must be a number';
                        if (val < 0) return 'Cannot be negative';
                        return null;
                      }

                      return Column(
                        children: [
                          if (isWide) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _controller.purchasePrice,
                                    label: 'Cost Price',
                                    icon: Icons.shopping_bag_outlined,
                                    keyboardType: TextInputType.number,
                                    validator: (v) => validateInt(v, false),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _controller.price,
                                    label: 'Sale Price',
                                    icon: Icons.monetization_on_outlined,
                                    keyboardType: TextInputType.number,
                                    validator: (v) => validateInt(v, true),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _controller.wholesalePrice,
                                    label: 'Wholesale Price',
                                    icon: Icons.business_center_outlined,
                                    keyboardType: TextInputType.number,
                                    validator: (v) => validateInt(v, false),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _controller.stock,
                                    label: 'Stock Quantity',
                                    icon: Icons.warehouse_outlined,
                                    keyboardType: TextInputType.number,
                                    validator: validateStock,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            _buildTextField(
                              controller: _controller.purchasePrice,
                              label: 'Cost Price',
                              icon: Icons.shopping_bag_outlined,
                              keyboardType: TextInputType.number,
                              validator: (v) => validateInt(v, false),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _controller.price,
                              label: 'Sale Price',
                              icon: Icons.monetization_on_outlined,
                              keyboardType: TextInputType.number,
                              validator: (v) => validateInt(v, true),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _controller.wholesalePrice,
                              label: 'Wholesale Price',
                              icon: Icons.business_center_outlined,
                              keyboardType: TextInputType.number,
                              validator: (v) => validateInt(v, false),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _controller.stock,
                              label: 'Stock Quantity',
                              icon: Icons.warehouse_outlined,
                              keyboardType: TextInputType.number,
                              validator: validateStock,
                            ),
                          ],
                        ],
                      );
                    }),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _controller.stockLimit,
                            label: 'Stock Alert Limit',
                            icon: Icons.notifications_active_outlined,
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _controller.discountLimit,
                            label: 'Max Discount (%)',
                            icon: Icons.percent_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.background.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                        border: Border.all(color: theme.textHint.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _controller.status == 1 ? Icons.check_circle : Icons.cancel,
                                color: _controller.status == 1 ? ThemeProvider.success : ThemeProvider.error,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _controller.status == 1 ? 'Product Active' : 'Product Inactive',
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: _controller.status == 1,
                            activeColor: ThemeProvider.success,
                            onChanged: (val) => _controller.toggleStatus(val),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.textSecondary.withOpacity(0.8),
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: theme.glassDecoration,
      child: Column(children: children),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w500),
      validator: validator,
      decoration: theme.glassInputDecoration(label, icon),
    );
  }

  Widget _buildCategorySelector() {
    return Row(
      children: [
        Expanded(
          child: _controller.categories.isEmpty 
            ? _buildTextField(controller: TextEditingController(text: 'Loading...'), label: 'Category', icon: Icons.category_outlined, enabled: false)
            : DropdownButtonFormField<dynamic>(
                value: _controller.categories.any((c) => c.id == _controller.selectedCategory) 
                    ? _controller.selectedCategory 
                    : null,
                dropdownColor: theme.surface,
                style: TextStyle(color: theme.textPrimary),
                decoration: theme.glassInputDecoration('Category', Icons.category_outlined),
                items: _controller.categories
                    .fold<List<ProductCategory>>([], (list, c) => list.any((e) => e.id == c.id) ? list : [...list, c])
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: _controller.setCategory,
              ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _showAddCategoryDialog,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.highlight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
            ),
            child: Icon(Icons.add, color: theme.highlight, size: 20),
          ),
        ),
      ],
    );
  }


  Widget _buildBarcodeScanner() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            controller: _controller.barcode,
            label: 'Barcode',
            icon: Icons.qr_code,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () async {
            final String? code = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScannerScreen()),
            );
            if (code != null && mounted) {
              _controller.barcode.text = code;
            }
          },
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.highlight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
            ),
            child: Icon(Icons.qr_code_scanner, color: theme.highlight, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildSubCategorySelector() {
    if (kDebugMode) print('🎨 [UI] Building SubCategorySelector: selected=${_controller.selectedSubCategoryId}, count=${_controller.subCategories.length}');
    for (var sc in _controller.subCategories) {
      if (kDebugMode) print('   - SubCat Item: ${sc.id} (${sc.name})');
    }
    
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<dynamic>(
            value: _controller.subCategories.any((c) => c.id == _controller.selectedSubCategoryId) 
                ? _controller.selectedSubCategoryId 
                : null,
            dropdownColor: theme.surface,
            style: TextStyle(color: theme.textPrimary),
            decoration: theme.glassInputDecoration('Sub-Category', Icons.account_tree_outlined),
            items: [
              const DropdownMenuItem(value: null, child: Text('No Sub-Category')),
              ..._controller.subCategories
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            ],
            onChanged: _controller.setSubCategory,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _showAddSubCategoryDialog,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.highlight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
            ),
            child: Icon(Icons.add, color: theme.highlight, size: 20),
          ),
        ),
      ],
    );
  }
}
