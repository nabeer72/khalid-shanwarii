import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/add_product_controller.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/stock.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/scanner_screen.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class AddProductScreen extends StatefulWidget {
  final Product? product;
  final Stock? initialStock;

  const AddProductScreen({super.key, this.product, this.initialStock});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  late AddProductController _controller;
  final _formKey = GlobalKey<FormState>();
  final theme = ThemeProvider.instance;

  bool _isScannerOpen = false;
  MobileScannerController? _scannerController;
  AudioPlayer? _audioPlayer;
  DateTime? _lastScanTime;

  @override
  void initState() {
    super.initState();
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        _audioPlayer = AudioPlayer();
      }
    } catch (_) {}
    _controller = AddProductController(initialProduct: widget.product, initialStock: widget.initialStock);
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
    _scannerController?.dispose();
    _audioPlayer?.dispose();
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

    final parentCategoryId = _controller.selectedCategory;

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
                  parentId: parentCategoryId,
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
        title: Text(
          _controller.screenTitle,
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleSave,
        backgroundColor: theme.highlight,
        icon: const Icon(Icons.save_rounded, color: Colors.white),
        label: const Text(
          'SAVE PRODUCT',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 8,
      ),
      body: theme.glassBackground(
        child: Form(
          key: _formKey,
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isScannerOpen) ...[
                    _buildInlineScanner(),
                    const SizedBox(height: 16),
                  ],
                  _buildSectionHeader('Basic Information'),
                  _buildCard([
                    LayoutBuilder(builder: (context, constraints) {
                      final isWide = ThemeProvider.isWideScreen(context);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isWide) ...[
                            _buildFormRow([
                              _buildCategorySelector(),
                              _buildSubCategorySelector(),
                            ]),
                            _formSpacer(),
                            _buildFormRow([
                              _buildBrandSelector(),
                              _buildUnitSelector(),
                            ]),
                            _formSpacer(),
                            _buildFormRow([
                              _buildTextField(
                                controller: _controller.name,
                                label: 'Product Name',
                                icon: Icons.inventory_2_outlined,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                                isRequired: true,
                              ),
                              _buildBarcodeScanner(),
                            ]),
                          ] else ...[
                            _buildCategorySelector(),
                            _formSpacer(),
                            _buildSubCategorySelector(),
                            _formSpacer(),
                            _buildBrandSelector(),
                            _formSpacer(),
                            _buildUnitSelector(),
                            _formSpacer(),
                            _buildTextField(
                              controller: _controller.name,
                              label: 'Product Name',
                              icon: Icons.inventory_2_outlined,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                              isRequired: true,
                            ),
                            _formSpacer(),
                            _buildBarcodeScanner(),
                          ],
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
                        final parsed = num.tryParse(v);
                        if (parsed == null) return 'Must be a number';
                        if (parsed < 0) return 'Cannot be negative';
                        if (parsed != parsed.toInt()) return 'Must be a whole number';
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_controller.isBoxUnit) ...[
                            Builder(
                              builder: (context) {
                                final unitName = _controller.getSelectedUnitName();
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildFormRow([
                                      _buildTextField(
                                        controller: _controller.boxPurchasePrice,
                                        label: 'Purchase $unitName Price',
                                        icon: Icons.inventory_2_outlined,
                                        keyboardType: TextInputType.number,
                                        validator: (v) => validateInt(v, true),
                                        isRequired: true,
                                      ),
                                      _buildTextField(
                                        controller: _controller.boxPrice,
                                        label: '$unitName Sale Price',
                                        icon: Icons.account_balance_wallet_outlined,
                                        keyboardType: TextInputType.number,
                                        validator: (v) => validateInt(v, true),
                                        isRequired: true,
                                      ),
                                    ]),
                                    _formSpacer(),
                                    _buildFormRow([
                                      _buildTextField(
                                        controller: _controller.piecesPerBox,
                                        label: '$unitName Quantity',
                                        icon: Icons.grid_view_rounded,
                                        keyboardType: TextInputType.number,
                                        validator: (v) => validateInt(v, true),
                                        isRequired: true,
                                      ),
                                      const SizedBox.shrink(),
                                    ]),
                                    _formSpacer(),
                                    _buildStockAndWholesaleRow(
                                      isWide: isWide,
                                      stockLabel: 'Total ${unitName}s',
                                      wholesaleField: _buildTextField(
                                        controller: _controller.boxWholesalePrice,
                                        label: '$unitName Wholesale Price',
                                        icon: Icons.local_offer_outlined,
                                        keyboardType: TextInputType.number,
                                        validator: (v) => validateInt(v, false),
                                      ),
                                    ),
                                  ],
                                );
                              }
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.highlight.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: theme.highlight.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Pieces Result:',
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${(double.tryParse(_controller.stock.text) ?? 0) * (double.tryParse(_controller.piecesPerBox.text) ?? 1)} Pieces',
                                    style: TextStyle(
                                      color: theme.highlight,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (isWide) ...[
                            _buildFormRow([
                              _buildTextField(
                                controller: _controller.purchasePrice,
                                label: 'Cost Price',
                                icon: Icons.shopping_bag_outlined,
                                keyboardType: TextInputType.number,
                                isRequired: true,
                                validator: (v) => validateInt(v, true),
                              ),
                              _buildTextField(
                                controller: _controller.price,
                                label: 'Sale Price',
                                icon: Icons.monetization_on_outlined,
                                keyboardType: TextInputType.number,
                                validator: (v) => validateInt(v, true),
                                isRequired: true,
                              ),
                            ]),
                            _formSpacer(),
                            _buildStockAndWholesaleRow(isWide: true),
                          ] else ...[
                            _buildTextField(
                              controller: _controller.purchasePrice,
                              label: 'Cost Price',
                              icon: Icons.shopping_bag_outlined,
                              keyboardType: TextInputType.number,
                              isRequired: true,
                              validator: (v) => validateInt(v, true),
                            ),
                            _formSpacer(),
                            _buildTextField(
                              controller: _controller.price,
                              label: 'Sale Price',
                              icon: Icons.monetization_on_outlined,
                              keyboardType: TextInputType.number,
                              validator: (v) => validateInt(v, true),
                              isRequired: true,
                            ),
                            _formSpacer(),
                            _buildStockAndWholesaleRow(isWide: false),
                          ],
                        ],
                      );
                    }),
                    _formSpacer(),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = ThemeProvider.isWideScreen(context);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildStockAlertAndDiscountRow(isWide: isWide),
                            if (BusinessConfig.instance.enableTax) ...[
                              _formSpacer(),
                              _buildTaxWithToggle(isWide: isWide),
                            ],
                          ],
                        );
                      },
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

  // ====================== ALL OTHER METHODS UNCHANGED ======================

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  static const double _formFieldHeight = 56;
  static const double _formGap = 16;
  static const EdgeInsets _formFieldPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 16);

  Widget _formSpacer() => const SizedBox(height: _formGap);

  Widget _buildFormRow(List<Widget?> children) {
    final valid = children.whereType<Widget>().where((w) => w is! SizedBox).toList();
    if (valid.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < valid.length; i++) ...[
          if (i > 0) const SizedBox(width: _formGap),
          Expanded(child: valid[i]),
        ],
      ],
    );
  }

  Widget _buildFieldActionButton({
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return SizedBox(
      height: _formFieldHeight,
      width: 48,
      child: Center(
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.highlight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
            ),
            child: Icon(icon, color: theme.highlight, size: 20),
          ),
        ),
      ),
    );
  }

  InputDecoration _formInputDecoration(
    String label,
    IconData icon, {
    bool isRequired = false,
    Widget? suffixIcon,
    Widget? prefix,
  }) {
    return theme.glassInputDecoration(label, icon, isRequired: isRequired).copyWith(
      suffixIcon: suffixIcon,
      prefix: prefix,
      prefixIcon: prefix != null ? null : Icon(icon, color: theme.iconColor),
      contentPadding: _formFieldPadding,
      isDense: true,
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
    Widget? suffixIcon,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      style: TextStyle(
        color: enabled ? theme.textPrimary : theme.textSecondary,
        fontWeight: FontWeight.w500,
        fontSize: ThemeProvider.fontLabel,
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
      ),
      validator: validator,
      decoration: _formInputDecoration(label, icon, isRequired: isRequired, suffixIcon: suffixIcon),
    );
  }

  Widget _buildStockQuantityField({String label = 'Stock Quantity'}) {
    return _buildTextField(
      controller: _controller.stock,
      label: label,
      icon: Icons.warehouse_outlined,
      keyboardType: TextInputType.number,
      isRequired: true,
      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : _validateStockQuantity(v),
    );
  }

  Widget _buildStockAlertField() {
    return _buildTextField(
      controller: _controller.stockLimit,
      label: 'Stock Alert Limit',
      icon: Icons.notifications_active_outlined,
      keyboardType: TextInputType.number,
      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
      isRequired: true,
    );
  }

  Widget _buildStockAndWholesaleRow({
    required bool isWide,
    String stockLabel = 'Stock Quantity',
    Widget? wholesaleField,
  }) {
    final stockField = _controller.isNonQuantityUnit ? const SizedBox.shrink() : _buildStockQuantityField(label: stockLabel);
    final wholesale = wholesaleField ??
        _buildTextField(
          controller: _controller.wholesalePrice,
          label: 'Wholesale Price',
          icon: Icons.business_center_outlined,
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            final parsed = num.tryParse(v);
            if (parsed == null) return 'Must be a number';
            if (parsed < 0) return 'Cannot be negative';
            if (parsed != parsed.toInt()) return 'Must be a whole number';
            return null;
          },
        );

    if (isWide) {
      return _buildFormRow([wholesale, _controller.isNonQuantityUnit ? null : stockField]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        wholesale,
        if (!_controller.isNonQuantityUnit) ...[
          _formSpacer(),
          stockField,
        ],
      ],
    );
  }

  Widget _buildExpireDateField() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: theme.highlight,
                  onPrimary: Colors.white,
                  surface: theme.surface,
                  onSurface: theme.textPrimary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          setState(() {
            _controller.expireDate.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          });
        }
      },
      child: IgnorePointer(
        child: _buildTextField(
          controller: _controller.expireDate,
          label: 'Expiry Date',
          icon: Icons.calendar_today_outlined,
          validator: (v) => null, // Optional
        ),
      ),
    );
  }

  Widget _buildManufactureDateField() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 3650)),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: theme.highlight,
                  onPrimary: Colors.white,
                  surface: theme.surface,
                  onSurface: theme.textPrimary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          setState(() {
            _controller.manufactureDate.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          });
        }
      },
      child: IgnorePointer(
        child: _buildTextField(
          controller: _controller.manufactureDate,
          label: 'Manufacture Date',
          icon: Icons.precision_manufacturing_outlined,
          validator: (v) => null,
        ),
      ),
    );
  }

  Widget _buildStockAlertAndDiscountRow({required bool isWide}) {
    final alertField = _controller.isNonQuantityUnit ? const SizedBox.shrink() : _buildStockAlertField();
    final discountField = _buildDiscountField();
    final mfgField = _controller.isNonQuantityUnit ? const SizedBox.shrink() : _buildManufactureDateField();
    final expireField = _controller.isNonQuantityUnit ? const SizedBox.shrink() : _buildExpireDateField();

    if (isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFormRow([_controller.isNonQuantityUnit ? null : alertField, discountField]),
          if (!_controller.isNonQuantityUnit) ...[
            _formSpacer(),
            _buildFormRow([mfgField, expireField]),
          ]
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_controller.isNonQuantityUnit) ...[
          alertField,
          _formSpacer(),
        ],
        discountField,
        if (!_controller.isNonQuantityUnit) ...[
          _formSpacer(),
          mfgField,
          _formSpacer(),
          expireField,
        ],
      ],
    );
  }

  String? _validateStockQuantity(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final val = num.tryParse(v);
    if (val == null) return 'Must be a number';
    if (val < 0) return 'Cannot be negative';
    return null;
  }

  Widget _buildDiscountField() {
    return _buildTextField(
      controller: _controller.discountLimit,
      label: 'Max Discount',
      icon: _controller.discountLimitType == 'percentage'
          ? Icons.percent_outlined
          : Icons.monetization_on_outlined,
      keyboardType: TextInputType.number,
      suffixIcon: TextButton(
        onPressed: () {
          setState(() {
            _controller.discountLimitType =
                _controller.discountLimitType == 'percentage' ? 'fixed' : 'percentage';
          });
        },
        child: Text(
          _controller.discountLimitType == 'percentage'
              ? '%'
              : BusinessConfig.instance.currencyDisplay,
          style: TextStyle(color: theme.highlight, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTaxToggle() {
    return SizedBox(
      height: _formFieldHeight,
      child: Align(
        alignment: Alignment.center,
        child: Switch(
          value: _controller.taxEnabled ?? false,
          activeColor: theme.highlight,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (val) {
            setState(() {
              _controller.taxEnabled = val;
              if (val &&
                  (_controller.taxRate.text.trim().isEmpty || _controller.taxRate.text == '0')) {
                _controller.taxRate.text = BusinessConfig.instance.taxRate.toString();
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildTaxField() {
    final enabled = _controller.taxEnabled ?? false;
    return _buildTextField(
      controller: _controller.taxRate,
      label: 'Tax %',
      icon: Icons.percent_outlined,
      keyboardType: TextInputType.number,
      enabled: enabled,
      validator: (v) {
        if (_controller.taxEnabled != true) return null;
        if (v == null || v.trim().isEmpty) return 'Required';
        final val = num.tryParse(v);
        if (val == null || val < 0) return 'Invalid tax rate';
        return null;
      },
    );
  }

  Widget _buildTaxWithToggle({required bool isWide}) {
    const toggleSlot = 48.0;
    const gapAfterField = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = isWide
            ? (constraints.maxWidth - _formGap) / 2
            : constraints.maxWidth - toggleSlot - gapAfterField;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: fieldWidth,
              child: _buildTaxField(),
            ),
            const SizedBox(width: gapAfterField),
            _buildTaxToggle(),
          ],
        );
      },
    );
  }

  Widget _buildDropdownField({
    required dynamic value,
    required String label,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required void Function(dynamic) onChanged,
  }) {
    final key = GlobalKey();
    final displayLabel = items.firstWhere(
      (i) => i['value'] == value,
      orElse: () => {'label': label},
    )['label'] as String;

    return GestureDetector(
      key: key,
      onTap: () async {
        final box = key.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return;
        final pos = box.localToGlobal(Offset.zero);
        final size = box.size;
        final screenWidth = MediaQuery.of(context).size.width;
        
        final dropdownWidth = (size.width > 300) ? size.width : 300.0;
        
        double left = pos.dx;
        if (left + dropdownWidth > screenWidth - 16) {
          left = screenWidth - dropdownWidth - 16;
        }
        if (left < 16) left = 16;

        final result = await showMenu<dynamic>(
          context: context,
          color: theme.surface,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.highlight.withOpacity(0.2), width: 1),
          ),
          constraints: BoxConstraints(
            minWidth: dropdownWidth,
            maxWidth: dropdownWidth,
            maxHeight: 300,
          ),
          position: RelativeRect.fromLTRB(
            left,
            pos.dy + size.height + 4,
            left + dropdownWidth,
            pos.dy + size.height + 304,
          ),
          items: items.map((item) => PopupMenuItem<dynamic>(
            value: item['value'],
            height: 44,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                item['label'] as String,
                style: TextStyle(
                  color: item['value'] == value ? theme.highlight : theme.textPrimary, 
                  fontSize: 14, 
                  fontWeight: item['value'] == value ? FontWeight.bold : FontWeight.w500
                ),
              ),
            ),
          )).toList(),
        );
        if (result != null && result != value) onChanged(result);
      },
      child: InputDecorator(
        decoration: _formInputDecoration(
          label,
          icon,
          isRequired: label == 'Category' || label == 'Unit',
          suffixIcon: Icon(Icons.arrow_drop_down_rounded, color: theme.iconColor),
        ),
        child: Text(
          displayLabel,
          style: TextStyle(
            color: value != null ? theme.textPrimary : theme.textHint,
            fontSize: ThemeProvider.fontLabel,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildDropdownField(
            value: _controller.categories.any((c) => c.id == _controller.selectedCategory)
                ? _controller.selectedCategory
                : null,
            label: 'Category',
            icon: Icons.category_outlined,
            items: [
              {'value': null, 'label': 'No Category'},
              ..._controller.categories
                  .fold<List<ProductCategory>>([], (list, c) => list.any((e) => e.id == c.id) ? list : [...list, c])
                  .map((c) => {'value': c.id, 'label': c.name}),
            ],
            onChanged: _controller.setCategory,
          ),
        ),
        const SizedBox(width: 8),
        _buildFieldActionButton(onPressed: _showAddCategoryDialog, icon: Icons.add),
      ],
    );
  }

  void _openBarcodeScanner() {
    if (kIsWeb) return;
    setState(() {
      if (!_isScannerOpen) {
        _isScannerOpen = true;
        _scannerController = MobileScannerController(
          formats: [
            BarcodeFormat.code128,
            BarcodeFormat.code39,
            BarcodeFormat.code93,
            BarcodeFormat.codabar,
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
            BarcodeFormat.itf,
            BarcodeFormat.upcA,
            BarcodeFormat.upcE,
          ],
        );
      } else {
        _closeBarcodeScanner();
      }
    });
  }

  void _closeBarcodeScanner() {
    setState(() {
      _isScannerOpen = false;
      _scannerController?.dispose();
      _scannerController = null;
    });
  }

  void _onDetectBarcode(BarcodeCapture capture) {
    if (!_isScannerOpen) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        if (_lastScanTime == null || DateTime.now().difference(_lastScanTime!).inMilliseconds > 1500) {
          _lastScanTime = DateTime.now();
          try {
             AudioCache.instance.prefix = '';
             _audioPlayer?.play(AssetSource('asset/beep.mpeg'));
          } catch (_) {}
          setState(() {
            _controller.barcode.text = code;
          });
          _closeBarcodeScanner();
        }
      }
    }
  }

  Widget _buildInlineScanner() {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.highlight, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            if (_scannerController != null && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS))
              MobileScanner(
                controller: _scannerController!,
                onDetect: _onDetectBarcode,
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_enhance_outlined, color: theme.textSecondary.withOpacity(0.5), size: 32),
                    const SizedBox(height: 8),
                    Text('Camera not supported on desktop', 
                        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 10)),
                  ],
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: _closeBarcodeScanner,
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.flash_on, color: Colors.white),
                onPressed: () => _scannerController?.toggleTorch(),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text('Scan Barcode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodeScanner() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTextField(
            controller: _controller.barcode,
            label: 'Barcode',
            icon: Icons.barcode_reader,
            validator: (v) {
              if (_controller.barcodeValidationError != null) {
                return _controller.barcodeValidationError;
              }
              if (v != null && v.isNotEmpty && _controller.errorMessage != null && _controller.errorMessage!.contains('barcode')) {
                return _controller.errorMessage;
              }
              return null;
            },
            suffixIcon: IconButton(
              icon: Icon(Icons.auto_fix_high_rounded, color: theme.highlight, size: 20),
              onPressed: _controller.generateUniqueBarcode,
              tooltip: 'Generate Unique Barcode',
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildFieldActionButton(onPressed: _openBarcodeScanner, icon: Icons.barcode_reader),
      ],
    );
  }

  Widget _buildSubCategorySelector() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildDropdownField(
            value: _controller.subCategories.any((c) => c.id == _controller.selectedSubCategoryId)
                ? _controller.selectedSubCategoryId
                : null,
            label: 'Sub-Category',
            icon: Icons.account_tree_outlined,
            items: [
              {'value': null, 'label': 'No Sub-Category'},
              ..._controller.subCategories.map((c) => {'value': c.id, 'label': c.name}),
            ],
            onChanged: _controller.setSubCategory,
          ),
        ),
        const SizedBox(width: 8),
        _buildFieldActionButton(onPressed: _showAddSubCategoryDialog, icon: Icons.add),
      ],
    );
  }

  Widget _buildBrandSelector() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildDropdownField(
            value: _controller.brands.any((b) => b.id == _controller.selectedBrandId)
                ? _controller.selectedBrandId
                : null,
            label: 'Brand',
            icon: Icons.branding_watermark_outlined,
            items: [
              {'value': null, 'label': 'No Brand'},
              ..._controller.brands.map((b) => {'value': b.id, 'label': b.name}),
            ],
            onChanged: _controller.setBrand,
          ),
        ),
        const SizedBox(width: 8),
        _buildFieldActionButton(onPressed: _showAddBrandDialog, icon: Icons.add),
      ],
    );
  }

  Widget _buildUnitSelector() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildDropdownField(
            value: _controller.units.any((u) => u['id'] == _controller.selectedUnitId)
                ? _controller.selectedUnitId
                : null,
            label: 'Unit',
            icon: Icons.straighten_outlined,
            items: [
              {'value': null, 'label': 'No Unit'},
              ..._controller.units
                .map((u) => {'value': u['id'], 'label': (u['name'] ?? '') as String})
                .toList(),
            ],
            onChanged: _controller.setUnit,
          ),
        ),
        const SizedBox(width: 8),
        _buildFieldActionButton(onPressed: _showUnitSelectionPopup, icon: Icons.add),
      ],
    );
  }

  void _showUnitSelectionPopup() {
    final searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            width: MediaQuery.of(context).size.width > 500 ? 400 : double.infinity,
            height: 550,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 15)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.highlight.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.scale_rounded, color: theme.highlight, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Measurement Units', 
                                style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)
                              ),
                              Text(
                                'Choose a unit for this product', 
                                style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.close, color: Colors.black54, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: TextField(
                      controller: searchController,
                      onChanged: (v) => setDialogState(() {}),
                      style: const TextStyle(color: Colors.black, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search units...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[600]),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),

                  Expanded(
                    child: _controller.units.isEmpty 
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.info_outline_rounded, color: Colors.grey[400], size: 48),
                              const SizedBox(height: 16),
                              Text(
                                'No units available',
                                style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  'Try syncing or adding a new unit from the settings.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          children: [
                            ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              leading: Icon(Icons.block_flipped, color: Colors.grey[600], size: 20),
                              title: const Text('No Specific Unit', style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
                              onTap: () {
                                _controller.setUnit(null);
                                Navigator.pop(context);
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Divider(height: 1, color: Colors.black12),
                            ),
                            ..._controller.units.where((u) {
                              if (searchController.text.isEmpty) return true;
                              final q = searchController.text.toLowerCase();
                              return u['name'].toString().toLowerCase().contains(q) || (u['short_name']?.toString().toLowerCase().contains(q) ?? false);
                            }).map((unit) {
                              final isSelected = _controller.selectedUnitId == unit['id'];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                  dense: true,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  tileColor: isSelected ? theme.highlight.withOpacity(0.08) : null,
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (isSelected ? theme.highlight : Colors.grey[400]!).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      (unit['short_name'] ?? unit['name']?.toString().substring(0, 1) ?? '?').toString().toUpperCase(),
                                      style: TextStyle(
                                        color: isSelected ? theme.highlight : Colors.grey[600],
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    unit['name'] ?? '', 
                                    style: TextStyle(
                                      color: isSelected ? theme.highlight : Colors.black87, 
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500
                                    )
                                  ),
                                  subtitle: unit['short_name'] != null ? Text(
                                    unit['short_name'],
                                    style: TextStyle(color: Colors.grey[600], fontSize: 11)
                                  ) : null,
                                  trailing: Icon(
                                    _controller.selectedUnitIds.contains(unit['id']) 
                                      ? Icons.check_circle_rounded 
                                      : Icons.radio_button_unchecked_rounded,
                                    color: _controller.selectedUnitIds.contains(unit['id']) 
                                      ? theme.highlight 
                                      : Colors.grey[300],
                                    size: 20,
                                  ),
                                  onTap: () {
                                    setDialogState(() {
                                      _controller.toggleUnit(unit['id']);
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                  ),

                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.highlight,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Confirm Selection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddBrandDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Add New Brand', style: TextStyle(color: theme.textPrimary)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: TextStyle(color: theme.textPrimary),
          decoration: theme.glassInputDecoration('Brand Name', Icons.branding_watermark_outlined),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                final success = await _controller.addBrand(nameCtrl.text.trim());
                if (success && mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}