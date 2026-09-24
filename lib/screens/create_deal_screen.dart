import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_app/controllers/create_deal_controller.dart';
import 'package:mobile_app/models/deal.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/widgets/product_picker_dialog.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/stock.dart';

class CreateDealScreen extends StatefulWidget {
  final Deal? deal;
  const CreateDealScreen({Key? key, this.deal}) : super(key: key);

  @override
  State<CreateDealScreen> createState() => _CreateDealScreenState();
}

class _CreateDealScreenState extends State<CreateDealScreen> {
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
            appBar: AppBar(
              title: Text(controller.screenTitle),
            ),
            body: controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBasicInfo(controller),
                        const SizedBox(height: 16),
                        _buildProductSelection(context, controller),
                        const SizedBox(height: 16),
                        _buildSummary(controller),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeProvider.instance.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () async {
                            final success = await controller.saveDeal();
                            if (success) {
                              Navigator.pop(context, true);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Please fill all required fields and add at least one product.')),
                              );
                            }
                          },
                          child: const Text('Save Deal',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildBasicInfo(CreateDealController controller) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: controller.nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Deal Name *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller.descCtrl,
              decoration: const InputDecoration(
                  labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSelection(
      BuildContext context, CreateDealController controller) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Deal Products',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: controller.items.isNotEmpty
                            ? ThemeProvider.instance.primary.withOpacity(0.12)
                            : Colors.grey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${controller.items.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: controller.items.isNotEmpty
                              ? ThemeProvider.instance.primary
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () async {
                    // Navigate to product list screen in selection mode
                    final result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => const ProductPickerDialog(),
                    );
                    if (result != null) {
                      controller.addProduct(result['product'] as Product,
                          result['stock'] as Stock);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                ),
              ],
            ),
            const Divider(),
            if (controller.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child:
                    Center(child: Text('No products added to this deal yet.')),
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
                      color: ThemeProvider.instance.isDark
                          ? Colors.white.withOpacity(0.05)
                          : const Color(0xFFF7F8FA),
                      border:
                          Border.all(color: ThemeProvider.instance.cardBorder),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color:
                                ThemeProvider.instance.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Icon(Icons.inventory_2,
                                size: 26, color: Color(0xFFF59E0B)),
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
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
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
                                    'Unit: ${item.unitPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          ThemeProvider.instance.textSecondary,
                                    ),
                                  ),
                                  if ((item.barcode ?? '').isNotEmpty)
                                    Text(
                                      '#${item.barcode}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: ThemeProvider
                                            .instance.textSecondary,
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
                                      color:
                                          ThemeProvider.instance.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    lineTotal.toStringAsFixed(2),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: ThemeProvider.instance.highlight,
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
                                  color: ThemeProvider.instance.highlight,
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
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.add_circle_outline_rounded),
                                  iconSize: 26,
                                  color: ThemeProvider.instance.highlight,
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
        ),
      ),
    );
  }

  Widget _buildSummary(CreateDealController controller) {
    return Card(
      elevation: 2,
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Normal Total:', style: TextStyle(fontSize: 16)),
                Text(controller.normalTotal.toStringAsFixed(2),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller.priceCtrl,
              decoration: const InputDecoration(
                  labelText: 'Deal Price *', border: OutlineInputBorder()),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                // Trigger rebuild to update savings
                // Using a microtask to avoid changing state during build
                Future.microtask(() => controller.notifyListeners());
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Savings:',
                    style: TextStyle(fontSize: 16, color: Colors.green)),
                Text(controller.savings.toStringAsFixed(2),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
