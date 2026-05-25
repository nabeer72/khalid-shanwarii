import 'package:flutter/material.dart';
import 'package:mobile_app/models/pos_cart_item.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';

class POSCartItemTile extends StatefulWidget {
  final POSCartItem item;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final bool isReturn;
  final Function(double) onQuantityChanged;
  final Function(double) onPriceChanged;
  final Function(double) onDiscountChanged;

  const POSCartItemTile({
    super.key,
    required this.item,
    required this.isExpanded,
    this.isReturn = false,
    required this.onToggleExpand,
    required this.onIncrement,
    required this.onDecrement,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onPriceChanged,
    required this.onDiscountChanged,
  });

  @override
  State<POSCartItemTile> createState() => _POSCartItemTileState();
}

class _POSCartItemTileState extends State<POSCartItemTile> {
  TextEditingController? _qtyCtrl;
  TextEditingController? _priceCtrl;
  TextEditingController? _discCtrl;
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _priceFocusNode = FocusNode();
  final FocusNode _discFocusNode = FocusNode();
  String _discType = 'fixed';

  // Lazy initializer — safe to call multiple times.
  void _ensureControllers() {
    _qtyCtrl ??= TextEditingController(text: _qtyText());
    _priceCtrl ??= TextEditingController(text: widget.item.price.toStringAsFixed(2));
    _discCtrl ??= TextEditingController(text: widget.item.discountValue.toStringAsFixed(2));
    _discType = widget.item.discountType;
  }

  @override
  void initState() {
    super.initState();
    _ensureControllers();
  }

  @override
  void didUpdateWidget(POSCartItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureControllers(); // guards against hot-reload edge cases

    // Sync qty field
    final newQtyText = _qtyText();
    if (_qtyCtrl!.text != newQtyText) {
      _qtyCtrl!.value = _qtyCtrl!.value.copyWith(text: newQtyText);
    }
    // Sync price field
    final newPriceText = widget.item.price.toStringAsFixed(2);
    if (_priceCtrl!.text != newPriceText) {
      _priceCtrl!.value = _priceCtrl!.value.copyWith(text: newPriceText);
    }
    // Sync disc field
    final newDiscText = widget.item.discountValue.toStringAsFixed(2);
    if (_discCtrl!.text != newDiscText) {
      _discCtrl!.value = _discCtrl!.value.copyWith(text: newDiscText);
    }
    if (_discType != widget.item.discountType) {
      _discType = widget.item.discountType;
    }
  }

  @override
  void dispose() {
    _qtyCtrl?.dispose();
    _priceCtrl?.dispose();
    _discCtrl?.dispose();
    _qtyFocusNode.dispose();
    _priceFocusNode.dispose();
    _discFocusNode.dispose();
    super.dispose();
  }

  String _qtyText() => widget.item.isWeight
      ? BusinessConfig.instance.formatAmount(widget.item.quantity)
      : '${widget.item.quantity.toInt()}';

  void _submitQty() {
    _ensureControllers();
    final val = double.tryParse(_qtyCtrl!.text);
    if (val != null && val > 0) {
      widget.onQuantityChanged(val);
    } else {
      _qtyCtrl!.text = _qtyText();
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _submitPrice() {
    _ensureControllers();
    final val = double.tryParse(_priceCtrl!.text);
    if (val != null && val >= 0) {
      widget.onPriceChanged(val);
    } else {
      _priceCtrl!.text = widget.item.price.toStringAsFixed(2);
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _submitDiscount() {
    _ensureControllers();
    final val = double.tryParse(_discCtrl!.text) ?? 0.0;
    final item = widget.item;
    double limitValue = item.stock.discountLimit;
    String limitType = item.stock.discountLimitType;

    bool isAllowed = true;
    if (limitValue > 0) {
      if (_discType == limitType) {
        if (val > limitValue) isAllowed = false;
      } else {
        if (_discType == 'percentage') {
          double amount = (item.price * item.quantity) * (val / 100);
          if (amount > limitValue) isAllowed = false;
        } else {
          double percent = (item.price * item.quantity) > 0
              ? (val / (item.price * item.quantity)) * 100
              : 0;
          if (percent > limitValue) isAllowed = false;
        }
      }
    }

    if (!isAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Discount exceeds max allowed limit of $limitValue${limitType == "percentage" ? "%" : BusinessConfig.instance.currencyDisplay}!'),
          backgroundColor: ThemeProvider.error,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _discCtrl!.text = item.discountValue.toStringAsFixed(2);
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }

    item.isManual = true;
    item.discountType = _discType;
    item.discountValue = val;
    item.updateSubtotal();
    widget.onDiscountChanged(item.discount);
    FocusManager.instance.primaryFocus?.unfocus();
  }


  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final item = widget.item;
    final isReturn = widget.isReturn;
    final qty = _qtyText();

    // Visual highlight state
    final bool isNewItem = item.isNew;
    final bool isMultiQty = !item.isNew && item.quantity >= 2;

    Color? rowBg;
    Color? accentColor;
    if (isNewItem) {
      rowBg = ThemeProvider.success.withValues(alpha: 0.08);
      accentColor = ThemeProvider.success;
    } else if (isMultiQty) {
      rowBg = const Color(0xFFFFA726).withValues(alpha: 0.08); // amber
      accentColor = const Color(0xFFFFA726);
    }

    return Column(
      children: [
        InkWell(
          onTap: widget.onToggleExpand,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: rowBg,
              border: Border(
                bottom: BorderSide(color: theme.whiteAlpha(0.05)),
                left: accentColor != null
                    ? BorderSide(color: accentColor, width: 3)
                    : BorderSide.none,
              ),
            ),
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
                    '${isReturn ? "-" : ""}${BusinessConfig.instance.formatAmount(item.price)}',
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
                    '${isReturn ? "-" : ""}${BusinessConfig.instance.formatAmount(item.subtotal)}',
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
        
        if (widget.isExpanded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: theme.whiteAlpha(0.02),
              border: Border(bottom: BorderSide(color: theme.whiteAlpha(0.05))),
            ),
            child: Row(
              children: [
                // Inline Price field
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Price',
                          style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _priceCtrl,
                        focusNode: _priceFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: theme.cardBorder)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: theme.cardBorder)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide:
                                  BorderSide(color: theme.highlight, width: 1.5)),
                        ),
                        onSubmitted: (_) => _submitPrice(),
                        onEditingComplete: _submitPrice,
                        onTapOutside: (_) => _submitPrice(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Inline Discount field with type toggle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text('Discount',
                              style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() {
                              _discType =
                                  _discType == 'percentage' ? 'fixed' : 'percentage';
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.highlight.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _discType == 'percentage'
                                    ? '%'
                                    : BusinessConfig.instance.currencyDisplay,
                                style: TextStyle(
                                    color: theme.highlight,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _discCtrl,
                        focusNode: _discFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                            color: theme.highlight,
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: theme.cardBorder)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: theme.cardBorder)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide:
                                  BorderSide(color: theme.highlight, width: 1.5)),
                        ),
                        onSubmitted: (_) => _submitDiscount(),
                        onEditingComplete: _submitDiscount,
                        onTapOutside: (_) => _submitDiscount(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _qtyBtn(Icons.remove_rounded, widget.onDecrement, theme.textSecondary),
                // Inline editable qty field
                SizedBox(
                  width: 52,
                  child: TextField(
                    controller: _qtyCtrl,
                    focusNode: _qtyFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: theme.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: theme.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: theme.highlight, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _submitQty(),
                    onEditingComplete: _submitQty,
                    onTapOutside: (_) => _submitQty(),
                  ),
                ),
                _qtyBtn(Icons.add_rounded, widget.onIncrement, theme.highlight),
                
                const SizedBox(width: 8),

                _POSActionButton(
                  icon: Icons.close_rounded,
                  label: '',
                  color: ThemeProvider.error,
                  onTap: widget.onRemove,
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
