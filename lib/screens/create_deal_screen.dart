import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_app/controllers/create_deal_controller.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/deal.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/widgets/product_picker_dialog.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/stock.dart';

class CreateDealScreen extends StatefulWidget {
  final Deal? deal;
  const CreateDealScreen({super.key, this.deal});

  @override
  State<CreateDealScreen> createState() => _CreateDealScreenState();
}

class _CreateDealScreenState extends State<CreateDealScreen> {
  final theme = ThemeProvider.instance;
  static const double _formGap = 16;

  Widget _formSpacer() => const SizedBox(height: _formGap);

  Widget _buildSectionHeaderRow(String title, IconData icon, {Color? color}) {
    final c = color ?? theme.highlight;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: theme.glassCircleDecoration(color: c),
          child: Icon(icon, color: c, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    Color? color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: theme.elevatedCardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeaderRow(title, icon, color: color),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
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
    final formFieldPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 18);
    final decoration = theme
        .glassInputDecoration(label, icon, isRequired: isRequired)
        .copyWith(
          suffixIcon: suffixIcon,
          prefixIcon: Icon(icon, color: theme.iconColor),
          contentPadding: formFieldPadding,
        );

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: TextStyle(
        color: enabled ? theme.textPrimary : theme.textSecondary,
        fontWeight: FontWeight.w500,
        fontSize: ThemeProvider.fontLabel,
        decoration: TextDecoration.none,
      ),
      decoration: decoration,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final controller = CreateDealController(widget.deal);
        if (controller.isEditMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.loadInitialItems();
          });
        }
        return controller;
      },
      child: Consumer<CreateDealController>(
        builder: (context, controller, child) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: theme.textPrimary,
              elevation: 0,
              title: Text(
                controller.screenTitle,
                style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5),
              ),
              leading: BackButton(color: theme.textPrimary),
            ),
            body: theme.glassBackground(
              child: controller.isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: theme.highlight))
                  : SafeArea(
                      bottom: false,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBasicInfo(controller),
                            const SizedBox(height: 16),
                            _buildProductSelection(context, controller),
                            const SizedBox(height: 16),
                            _buildSummary(controller),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final success = await controller.saveDeal();
                                  if (success) {
                                    if (context.mounted) {
                                      Navigator.pop(context, true);
                                    }
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            backgroundColor:
                                                ThemeProvider.error,
                                            content: const Text(
                                                'Please fill all required fields and add at least one product.')),
                                      );
                                    }
                                  }
                                },
                                style: theme.primaryButtonStyle,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.save_rounded,
                                        color: Colors.white),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'SAVE DEAL',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBasicInfo(CreateDealController controller) {
    return _buildSectionCard(
      title: 'Deal Details',
      icon: Icons.auto_awesome_rounded,
      color: ThemeProvider.gradientGold.last,
      children: [
        _buildTextField(
          controller: controller.nameCtrl,
          label: 'Deal Name',
          icon: Icons.card_giftcard_rounded,
          isRequired: true,
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Name is required' : null,
        ),
        _formSpacer(),
        _buildTextField(
          controller: controller.descCtrl,
          label: 'Description',
          icon: Icons.description_outlined,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildProductSelection(
      BuildContext context, CreateDealController controller) {
    return _buildSectionCard(
      title: 'Deal Products',
      icon: Icons.shopping_basket_outlined,
      color: ThemeProvider.success,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('${controller.items.length} Item(s)',
                    style: TextStyle(
                        color: theme.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: theme.highlight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ThemeProvider.radiusPill),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusPill),
                  onTap: () async {
                    final result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => const ProductPickerDialog(),
                    );
                    if (result != null) {
                      controller.addProduct(result['product'] as Product,
                          result['stock'] as Stock);
                    }
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_rounded,
                            color: theme.highlight, size: 18),
                        const SizedBox(width: 6),
                        Text('Add Product',
                            style: TextStyle(
                                color: theme.highlight,
                                fontWeight: FontWeight.w900,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (controller.items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: theme.isDark
                  ? Colors.white.withOpacity(0.04)
                  : const Color(0xFFF7F8FA),
              border: Border.all(color: theme.cardBorder, width: 1.2),
              borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration:
                        theme.glassCircleDecoration(color: theme.highlight),
                    child: Icon(Icons.shopping_basket_outlined,
                        color: theme.highlight, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text('No products in this deal yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Tap "Add Product" above to start building your deal',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: theme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = controller.items[index];
              final lineTotal = item.unitPrice * item.quantity;
              return Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                decoration: BoxDecoration(
                  color: theme.isDark
                      ? Colors.white.withOpacity(0.05)
                      : const Color(0xFFF7F8FA),
                  border: Border.all(color: theme.cardBorder),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: ThemeProvider.gradientGold,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: ThemeProvider.gradientGold.first
                                .withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🎁', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.productName ?? 'Product',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: theme.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 10,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Unit: ${BusinessConfig.instance.currencyDisplay} ${item.unitPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.textSecondary,
                                ),
                              ),
                              if ((item.barcode ?? '').isNotEmpty)
                                Text(
                                  '#${item.barcode}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textSecondary,
                                  ),
                                ),
                              Text(
                                'Stock: ${(item.currentStock ?? 0).toStringAsFixed(item.currentStock != null && item.currentStock!.truncateToDouble() == item.currentStock! ? 0 : 2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: (item.currentStock ?? 0) > 0
                                      ? ThemeProvider.success
                                      : ThemeProvider.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Text(
                                'Total: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${BusinessConfig.instance.currencyDisplay} ${lineTotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: theme.highlight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                  Icons.remove_circle_outline_rounded),
                              iconSize: 26,
                              color: theme.highlight,
                              onPressed: () => controller.updateQuantity(
                                  item.productId, item.quantity - 1),
                            ),
                            Container(
                              width: 36,
                              alignment: Alignment.center,
                              child: Text(
                                item.quantity.truncateToDouble() ==
                                        item.quantity
                                    ? '${item.quantity.toInt()}'
                                    : item.quantity.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: theme.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.add_circle_outline_rounded),
                              iconSize: 26,
                              color: theme.highlight,
                              onPressed: () => controller.updateQuantity(
                                  item.productId, item.quantity + 1),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          iconSize: 22,
                          color: ThemeProvider.error,
                          onPressed: () =>
                              controller.updateQuantity(item.productId, 0),
                          tooltip: 'Remove',
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSummary(CreateDealController controller) {
    return _buildSectionCard(
      title: 'Pricing & Savings',
      icon: Icons.price_change_outlined,
      color: ThemeProvider.success,
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.isDark
                ? Colors.white.withOpacity(0.04)
                : const Color(0xFFF7F8FA),
            border: Border.all(color: theme.cardBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: theme.glassCircleDecoration(
                            color: theme.textSecondary),
                        child: Icon(Icons.receipt_long_outlined,
                            size: 18, color: theme.textSecondary),
                      ),
                      const SizedBox(width: 10),
                      Text('Normal Total',
                          style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ],
                  ),
                  Text(
                      '${BusinessConfig.instance.currencyDisplay} ${controller.normalTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: theme.textSecondary)),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration:
                            theme.glassCircleDecoration(color: theme.highlight),
                        child: Icon(Icons.local_offer_outlined,
                            size: 18, color: theme.highlight),
                      ),
                      const SizedBox(width: 10),
                      Text('Deal Price',
                          style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildTextField(
                        controller: controller.priceCtrl,
                        label: 'Enter Deal Price',
                        icon: Icons.attach_money_rounded,
                        isRequired: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Required';
                          }
                          final parsed = num.tryParse(v);
                          if (parsed == null) return 'Invalid number';
                          if (parsed < 0) return 'Cannot be negative';
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              if (controller.savings > 0) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: ThemeProvider.success.withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(ThemeProvider.radiusPill),
                    border: Border.all(
                        color: ThemeProvider.success.withOpacity(0.3)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.savings_outlined,
                              color: ThemeProvider.success, size: 20),
                          const SizedBox(width: 8),
                          Text('You Save',
                              style: TextStyle(
                                  color: ThemeProvider.success,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                              '${BusinessConfig.instance.currencyDisplay} ${controller.savings.toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: ThemeProvider.success,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                          if (controller.savingsPercent > 0)
                            Text(
                                '${controller.savingsPercent.toStringAsFixed(0)}% OFF',
                                style: TextStyle(
                                    color: ThemeProvider.success,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 0.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
