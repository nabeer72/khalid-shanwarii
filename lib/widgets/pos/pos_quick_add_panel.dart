import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/add_product_controller.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';

class POSQuickAddPanel extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onSuccess;
  final void Function(void Function(int newId) refresh)? onAddCategory;
  final void Function(void Function(int newId) refresh, String? catId)? onAddSubCategory;

  const POSQuickAddPanel({
    super.key,
    required this.onClose,
    required this.onSuccess,
    this.onAddCategory,
    this.onAddSubCategory,
  });

  @override
  State<POSQuickAddPanel> createState() => _POSQuickAddPanelState();
}

class _POSQuickAddPanelState extends State<POSQuickAddPanel> {
  final _formKey = GlobalKey<FormState>();
  final _controller = AddProductController();
  final theme = ThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _controller.loadCategories();
    _controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final result = await _controller.saveProduct();

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: ThemeProvider.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to save product'),
          backgroundColor: ThemeProvider.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return Container(
        color: theme.surface,
        child: Center(child: CircularProgressIndicator(color: theme.highlight)),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(left: BorderSide(color: theme.whiteAlpha(0.1))),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.whiteAlpha(0.1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                    'QUICK ADD PRODUCT',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.textSecondary, size: 20),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDropdownField(),
                    const SizedBox(height: 12),
                    _buildSubCategoryDropdownField(),
                    const SizedBox(height: 12),
                    _buildBrandDropdownField(),
                    const SizedBox(height: 12),
                    _buildUnitDropdownField(),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _controller.name,
                      label: 'Product Name',
                      icon: Icons.inventory_2_outlined,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _controller.barcode,
                      label: 'Barcode',
                      icon: Icons.qr_code_rounded,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _controller.price,
                            label: 'Sell Price',
                            icon: Icons.monetization_on_outlined,
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(
                            controller: _controller.purchasePrice,
                            label: 'Cost Price',
                            icon: Icons.shopping_bag_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _controller.wholesalePrice,
                      label: 'Wholesale Price',
                      icon: Icons.business_center_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _controller.stock,
                            label: 'Current Stock',
                            icon: Icons.warehouse_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(
                            controller: _controller.stockLimit,
                            label: 'Stock Alert',
                            icon: Icons.notifications_active_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDiscountField(),
                    const SizedBox(height: 12),
                    _buildDateField(_controller.manufactureDate, 'Manufacture Date', Icons.precision_manufacturing_outlined),
                    const SizedBox(height: 12),
                    _buildDateField(_controller.expireDate, 'Expiry Date', Icons.calendar_today_outlined),
                    const SizedBox(height: 12),
                    if (BusinessConfig.instance.enableTax) _buildTaxWithToggle(),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.whiteAlpha(0.1))),
              ),
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.highlight,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text('SAVE PRODUCT', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.textSecondary, fontSize: 12),
        prefixIcon: Icon(icon, color: theme.highlight.withOpacity(0.7), size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: theme.whiteAlpha(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<dynamic>(
            value: _controller.categories.any((c) => c.id == _controller.selectedCategory)
                ? _controller.selectedCategory
                : null,
            dropdownColor: theme.surface,
            isExpanded: true,
            style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: TextStyle(color: theme.textSecondary, fontSize: 12),
              prefixIcon: Icon(Icons.category_outlined, color: theme.highlight.withOpacity(0.7), size: 18),
              filled: true,
              fillColor: theme.whiteAlpha(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: _controller.categories
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: _controller.setCategory,
          ),
        ),
        if (widget.onAddCategory != null) ...[
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.highlight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.add_rounded, color: theme.highlight, size: 20),
              onPressed: () => widget.onAddCategory!(
                (int newId) async {
                  await _controller.loadCategories();
                  _controller.setCategory(newId.toString());
                },
              ),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBrandDropdownField() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<dynamic>(
            value: _controller.brands.any((b) => b.id == _controller.selectedBrandId)
                ? _controller.selectedBrandId
                : null,
            dropdownColor: theme.surface,
            isExpanded: true,
            style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Brand',
              labelStyle: TextStyle(color: theme.textSecondary, fontSize: 12),
              prefixIcon: Icon(Icons.branding_watermark_outlined, color: theme.highlight.withOpacity(0.7), size: 18),
              filled: true,
              fillColor: theme.whiteAlpha(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('No Brand')),
              ..._controller.brands
                  .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                  .toList(),
            ],
            onChanged: _controller.setBrand,
          ),
        ),
      ],
    );
  }

  Widget _buildUnitDropdownField() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<dynamic>(
            value: _controller.units.any((u) => u['id'] == _controller.selectedUnitId)
                ? _controller.selectedUnitId
                : null,
            dropdownColor: theme.surface,
            isExpanded: true,
            style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Unit',
              labelStyle: TextStyle(color: theme.textSecondary, fontSize: 12),
              prefixIcon: Icon(Icons.straighten_outlined, color: theme.highlight.withOpacity(0.7), size: 18),
              filled: true,
              fillColor: theme.whiteAlpha(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('No Unit')),
              ..._controller.units
                  .map((u) => DropdownMenuItem(value: u['id'], child: Text(u['name'])))
                  .toList(),
            ],
            onChanged: _controller.setUnit,
          ),
        ),
      ],
    );
  }

  Widget _buildSubCategoryDropdownField() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<dynamic>(
            value: _controller.subCategories.any((c) => c.id == _controller.selectedSubCategoryId)
                ? _controller.selectedSubCategoryId
                : null,
            dropdownColor: theme.surface,
            isExpanded: true,
            style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Sub-Category',
              labelStyle: TextStyle(color: theme.textSecondary, fontSize: 12),
              prefixIcon: Icon(Icons.account_tree_outlined, color: theme.highlight.withOpacity(0.7), size: 18),
              filled: true,
              fillColor: theme.whiteAlpha(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('No Sub-Category')),
              ..._controller.subCategories
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
            ],
            onChanged: _controller.setSubCategory,
          ),
        ),
        if (widget.onAddSubCategory != null) ...[
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.highlight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.add_rounded, color: theme.highlight, size: 20),
              onPressed: () => widget.onAddSubCategory!(
                (int newId) => _controller.reloadSubCategories(selectId: newId),
                _controller.selectedCategory?.toString(),
              ),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
        ],
      ],
    );
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

  Widget _buildDateField(TextEditingController controller, String label, IconData icon) {
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
            controller.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          });
        }
      },
      child: IgnorePointer(
        child: _buildTextField(
          controller: controller,
          label: label,
          icon: icon,
        ),
      ),
    );
  }

  Widget _buildTaxWithToggle() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            controller: _controller.taxRate,
            label: 'Tax %',
            icon: Icons.percent_outlined,
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 8),
        Switch(
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
      ],
    );
  }
}
