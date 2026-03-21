import 'package:flutter/material.dart';
import 'package:mobile_app/models/pos_cart_item.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';

class POSCartItemTile extends StatelessWidget {
  final POSCartItem item;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final Function(double) onQuantityChanged;
  final Function(double) onPriceChanged;
  final Function(double) onDiscountChanged;

  const POSCartItemTile({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onIncrement,
    required this.onDecrement,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onPriceChanged,
    required this.onDiscountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final qty = item.isWeight
        ? BusinessConfig.instance.formatAmount(item.quantity)
        : '${item.quantity.toInt()}';

    return Column(
      children: [
        InkWell(
          onTap: onToggleExpand,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.whiteAlpha(0.05)))),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.product.name,
                    style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                // QTY
                SizedBox(
                  width: 60,
                  child: Text(
                    qty,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),

                // DISC
                SizedBox(
                  width: 60,
                  child: Text(
                    BusinessConfig.instance.formatAmount(item.discount),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: theme.highlight,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),

                // RATE
                SizedBox(
                  width: 60,
                  child: Text(
                    BusinessConfig.instance.formatAmount(item.price),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: theme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),

                // TOTAL
                SizedBox(
                  width: 75,
                  child: Text(
                    BusinessConfig.instance.formatAmount(item.subtotal),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: -0.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        if (isExpanded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: theme.whiteAlpha(0.02),
              border: Border(bottom: BorderSide(color: theme.whiteAlpha(0.05))),
            ),
            child: Row(
              children: [
                _POSActionButton(
                  icon: Icons.edit_rounded,
                  label: '',
                  onTap: () => _showEditValueDialog(
                    context,
                    title: 'Edit Price',
                    initialValue: item.price,
                    onChanged: onPriceChanged,
                  ),
                ),
                const SizedBox(width: 8),

                _POSActionButton(
                  icon: Icons.discount_rounded,
                  label: 'Disc',
                  onTap: () => _showEditValueDialog(
                    context,
                    title: 'Discount',
                    initialValue: item.discount,
                    onChanged: onDiscountChanged,
                  ),
                ),
                
                const Spacer(),

                _qtyBtn(Icons.remove_rounded, onDecrement, theme.textSecondary),
                InkWell(
                  onTap: () => _showEditValueDialog(
                    context,
                    title: 'Edit Quantity',
                    initialValue: item.quantity,
                    onChanged: onQuantityChanged,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      qty,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                _qtyBtn(Icons.add_rounded, onIncrement, theme.highlight),
                
                const SizedBox(width: 8),

                _POSActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: '',
                  color: ThemeProvider.error,
                  onTap: onRemove,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, Color color) {
    final theme = ThemeProvider.instance;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.whiteAlpha(0.1),
          border: Border.all(color: theme.whiteAlpha(0.15), width: 1),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  void _showEditValueDialog(BuildContext context,
      {required String title,
      required double initialValue,
      required Function(double) onChanged}) {
    final theme = ThemeProvider.instance;
    final ctrl = TextEditingController(text: initialValue.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text(title, style: TextStyle(color: theme.textPrimary)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.whiteAlpha(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null) {
                onChanged(val);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.highlight),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

class _POSActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _POSActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (color ?? theme.highlight).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color ?? theme.highlight),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color ?? theme.highlight,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
