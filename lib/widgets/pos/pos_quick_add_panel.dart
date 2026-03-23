import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/add_product_controller.dart';
import 'package:mobile_app/providers/theme_provider.dart';

class POSQuickAddPanel extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onSuccess;
  final void Function(VoidCallback refresh)? onAddCategory;
  final void Function(VoidCallback refresh, String? catId)? onAddSubCategory;

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
                      controller: _controller.stock,
                      label: 'Current Stock',
                      icon: Icons.warehouse_outlined,
                      keyboardType: TextInputType.number,
                    ),
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
              onPressed: () => widget.onAddCategory!(() => _controller.loadCategories()),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
        ],
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
                () => _controller.loadCategories(),
                _controller.selectedCategory?.toString(),
              ),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
        ],
      ],
    );
  }
}
