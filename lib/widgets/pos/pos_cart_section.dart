import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/pos_controller.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/widgets/pos/pos_cart_item_tile.dart';
import 'package:mobile_app/db/mock_data.dart';

class POSCartSection extends StatefulWidget {
  final POSController controller;
  final VoidCallback onPay;
  final VoidCallback onHold;
  final VoidCallback onClear;
  final VoidCallback onSelectCustomer;
  final VoidCallback onShowHeldOrders;
  final VoidCallback onToggleQuickAdd;
  final VoidCallback onApplyDiscount;

  const POSCartSection({
    super.key,
    required this.controller,
    required this.onPay,
    required this.onHold,
    required this.onClear,
    required this.onSelectCustomer,
    required this.onShowHeldOrders,
    required this.onToggleQuickAdd,
    required this.onApplyDiscount,
  });

  @override
  State<POSCartSection> createState() => _POSCartSectionState();
}

class _POSCartSectionState extends State<POSCartSection> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Column(
      children: [
        _buildCustomerHeader(theme),
        if (widget.controller.cart.isNotEmpty) _buildTableHeader(theme),
        Expanded(
          child: widget.controller.cart.isEmpty
              ? _buildEmptyCart(theme)
              : ListView.separated(
                  itemCount: widget.controller.cart.length,
                  padding: EdgeInsets.zero,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: theme.cardBorder,
                    indent: 12,
                    endIndent: 12,
                  ),
                  itemBuilder: (ctx, i) => POSCartItemTile(
                    item: widget.controller.cart[i],
                    isExpanded: _expandedIndex == i,
                    onToggleExpand: () => setState(() {
                      _expandedIndex = (_expandedIndex == i) ? null : i;
                    }),
                    onIncrement: () => widget.controller.updateQuantity(i, 1),
                    onDecrement: () => widget.controller.updateQuantity(i, -1),
                    onQuantityChanged: (qty) => widget.controller.setQuantity(i, qty),
                    onRemove: () => widget.controller.removeFromCart(i),
                    onPriceChanged: (price) {
                      widget.controller.cart[i].price = price;
                      widget.controller.cart[i].updateSubtotal();
                      widget.controller.calculateTotals();
                    },
                    onDiscountChanged: (disc) {
                      widget.controller.cart[i].discount = disc;
                      widget.controller.cart[i].updateSubtotal();
                      widget.controller.calculateTotals();
                    },
                  ),
                ),
        ),
        _buildTotals(theme),
      ],
    );
  }

  Widget _buildCustomerHeader(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CUSTOMER',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.controller.selectedCustomer?.name ?? 'Walk-in Guest',
                  style: TextStyle(
                    color: widget.controller.selectedCustomer != null ? theme.highlight : theme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderButton(
                icon: widget.controller.selectedCustomer != null ? Icons.person_rounded : Icons.person_add_rounded,
                label: 'Customer',
                color: widget.controller.selectedCustomer != null ? theme.highlight : theme.textSecondary,
                onTap: widget.onSelectCustomer,
                tooltip: '',
                theme: theme,
              ),
              const SizedBox(width: 8),
              _buildHeaderButton(
                icon: widget.controller.isReturn
                    ? Icons.shopping_cart_checkout_rounded
                    : Icons.assignment_return_rounded,
                label: widget.controller.isReturn ? 'Sale' : 'Return',
                color: widget.controller.isReturn ? ThemeProvider.success : ThemeProvider.error,
                onTap: () => widget.controller.toggleReturn(!widget.controller.isReturn),
                tooltip: '',
                theme: theme,
              ),
              const SizedBox(width: 8),
              _buildHeaderButton(
                icon: Icons.add_business_rounded,
                label: 'Quick Add',
                color: theme.highlight,
                onTap: widget.onToggleQuickAdd,
                tooltip: '',
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.whiteAlpha(0.03),
        border: Border(bottom: BorderSide(color: theme.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('PRODUCTS',
                style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text('QTY',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text('PRICE',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 75,
            child: Text('TOTAL',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(ThemeProvider theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_shopping_cart_rounded,
                size: 48, color: theme.iconColor.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text('Cart is empty',
                style: TextStyle(
                    color: theme.textSecondary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTotals(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.cardBorder)),
      ),
      child: Column(
        children: [
          _totalRow(theme, 'Subtotal', widget.controller.subtotal),
          const SizedBox(height: 6),
          _totalRow(theme, 'Tax', widget.controller.tax),
          if (widget.controller.discount > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Discount',
                    style: TextStyle(
                        color: theme.highlight,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Text(
                    '-${BusinessConfig.instance.currency}. ${widget.controller.discount.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: theme.highlight,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ],
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL AMOUNT',
                  style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
              Text(
                  '${BusinessConfig.instance.currency}. ${widget.controller.total.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: theme.highlight,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionButtons(theme),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeProvider theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildCartAction(
              theme: theme,
              icon: Icons.discount_rounded,
              label: 'Discount',
              color: theme.highlight,
              onTap: widget.onApplyDiscount,
            ),
            const SizedBox(width: 4),
            _buildCartAction(
              theme: theme,
              icon: Icons.receipt_long_rounded,
              label: 'Unhold',
              color: ThemeProvider.warning,
              onTap: widget.onShowHeldOrders,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _mainBtn(
                label: 'CLEAR',
                color: ThemeProvider.error,
                onTap: widget.controller.cart.isEmpty ? null : widget.onClear,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _mainBtn(
                label: 'HOLD',
                color: ThemeProvider.warning,
                onTap: widget.controller.cart.isEmpty ? null : widget.onHold,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _mainBtn(
                label: widget.controller.isReturn ? 'REFUND' : 'PAY',
                color: widget.controller.isReturn ? ThemeProvider.error : ThemeProvider.success,
                onTap: widget.controller.cart.isEmpty ? null : widget.onPay,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _totalRow(ThemeProvider theme, String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: theme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        Text('${BusinessConfig.instance.currency}. ${value.toStringAsFixed(2)}',
            style: TextStyle(
                color: theme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _mainBtn({required String label, required Color color, VoidCallback? onTap}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
    required ThemeProvider theme,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartAction({
    required ThemeProvider theme,
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: onTap == null ? theme.iconColor.withOpacity(0.5) : color, size: 20),
            const SizedBox(height: 4),
            Text(label.toUpperCase(),
                style: TextStyle(
                  color: onTap == null ? theme.textSecondary.withOpacity(0.5) : color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                )),
          ],
        ),
      ),
    );
  }
}
