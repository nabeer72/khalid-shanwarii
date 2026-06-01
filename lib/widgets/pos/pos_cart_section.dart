import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/pos_controller.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/widgets/pos/pos_cart_item_tile.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/widgets/add_customer_dialog.dart';

class POSCartSection extends StatefulWidget {
  final POSController controller;
  final VoidCallback onPay;
  final VoidCallback onHold;
  final VoidCallback onClear;
  final VoidCallback onSelectCustomer;
  final VoidCallback onShowHeldOrders;
  final VoidCallback onToggleQuickAdd;
  final VoidCallback onApplyDiscount;
  final VoidCallback onOpenCashDrawer;

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
    required this.onOpenCashDrawer,
  });

  @override
  State<POSCartSection> createState() => _POSCartSectionState();
}

class _POSCartSectionState extends State<POSCartSection> {
  int? _expandedIndex;
  bool _isCustomerDropdownOpen = false;
  List<Customer> _customers = [];
  bool _isLoadingCustomers = false;
  String _customerSearchQuery = '';
  final ScrollController _cartScrollController = ScrollController();
  int _lastCartLength = 0;

  bool _isEditingDiscount = false;
  final TextEditingController _discountCtrl = TextEditingController();
  final FocusNode _discountFocusNode = FocusNode();
  String _discountType = 'fixed';

  @override
  void initState() {
    super.initState();
    _lastCartLength = widget.controller.cart.length;
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _cartScrollController.dispose();
    _discountCtrl.dispose();
    _discountFocusNode.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final currentLength = widget.controller.cart.length;
    final isNewItem = currentLength > _lastCartLength;
    _lastCartLength = currentLength;
    setState(() {});
    // Auto-scroll to bottom when a brand-new item is added
    if (isNewItem) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_cartScrollController.hasClients) {
          _cartScrollController.animateTo(
            _cartScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _syncDiscountEditorFromController() {
    _discountType = widget.controller.globalDiscountType;
    final v = widget.controller.globalDiscountValue;
    if (v > 0) {
      _discountCtrl.text =
          v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
    } else {
      _discountCtrl.text = '';
    }
  }

  void _openDiscountEditor() {
    setState(() {
      _isEditingDiscount = true;
      _syncDiscountEditorFromController();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _discountFocusNode.requestFocus();
      _discountCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _discountCtrl.text.length,
      );
    });
  }

  bool _isDiscountInputOverLimit() {
    if (!BusinessConfig.instance.enableGlobalDiscount) return false;
    if (BusinessConfig.instance.globalDiscountLimit <= 0) return false;

    final text = _discountCtrl.text.trim();
    if (text.isEmpty) return false;
    final val = double.tryParse(text);
    if (val == null) return false;

    return widget.controller.isGlobalDiscountOverLimit(val, _discountType);
  }

  bool get _showDiscountRestricted =>
      widget.controller.isDiscountRestricted || _isDiscountInputOverLimit();

  void _updateDiscountFromField() {
    final text = _discountCtrl.text.trim();
    if (text.isEmpty) return;
    final val = double.tryParse(text);
    if (val == null) return;
    widget.controller.setDiscount(val, type: _discountType);
  }

  void _applyDiscountFromField() {
    final text = _discountCtrl.text.trim();
    if (text.isEmpty) {
      widget.controller.setDiscount(0, type: _discountType);
      return;
    }
    final val = double.tryParse(text) ?? 0;
    widget.controller.setDiscount(val, type: _discountType);
  }

  Future<void> _toggleCustomerDropdown() async {
    if (_isCustomerDropdownOpen) {
      setState(() => _isCustomerDropdownOpen = false);
      return;
    }

    setState(() => _isLoadingCustomers = true);
    final data = await DatabaseHelper.instance.getCustomers();
    
    if (!mounted) return;
    
    if (data.isEmpty) {
      setState(() => _isLoadingCustomers = false);
      _addCustomerDirectly();
      return;
    }

    setState(() {
      _customers = data.map((c) => Customer.fromMap(c)).toList();
      _isLoadingCustomers = false;
      _customerSearchQuery = ''; // Reset search on open
      _isCustomerDropdownOpen = true;
    });
  }

  Future<void> _addCustomerDirectly() async {
    final newCust = await AddCustomerDialog.show(context);
    if (newCust != null && mounted) {
      widget.controller.setSelectedCustomer(newCust);
      setState(() => _isCustomerDropdownOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Column(
      children: [
        _buildCustomerHeader(theme),
        Expanded(
          child: Stack(
            children: [
              Column(
                children: [
                  if (widget.controller.cart.isNotEmpty) _buildTableHeader(theme),
                  Expanded(
                    child: widget.controller.cart.isEmpty
                        ? _buildEmptyCart(theme)
                        : ListView.separated(
                            controller: _cartScrollController,
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
                              isReturn: widget.controller.isReturn,
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
              ),
              _buildCustomerDropdown(theme),
            ],
          ),
        ),
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
                onTap: _toggleCustomerDropdown,
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

  Widget _buildCustomerDropdown(ThemeProvider theme) {
    if (!_isCustomerDropdownOpen) return const SizedBox.shrink();
    
    final filtered = _customers.where((c) {
      if (_customerSearchQuery.isEmpty) return true;
      final q = _customerSearchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) || 
             (c.phone?.contains(q) ?? false);
    }).toList();
    
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 8,
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 350),
          decoration: theme.glassDecoration.copyWith(
            color: theme.surface,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border.all(color: theme.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  autofocus: true,
                  style: TextStyle(color: theme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search customer...',
                    hintStyle: TextStyle(color: theme.textHint),
                    prefixIcon: Icon(Icons.search, color: theme.iconColor, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) => setState(() => _customerSearchQuery = v),
                ),
              ),
              if (_isLoadingCustomers)
                const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      if (!BusinessConfig.instance.requireCustomer && _customerSearchQuery.isEmpty)
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.person_outline_rounded, color: theme.highlight),
                          title: Text('Walk-in Guest', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
                          onTap: () {
                            widget.controller.setSelectedCustomer(null);
                            setState(() => _isCustomerDropdownOpen = false);
                          },
                        ),
                      ...filtered.map((c) => ListTile(
                            dense: true,
                            leading: Icon(Icons.person_rounded, color: theme.textSecondary),
                            title: Text(c.name, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
                            subtitle: c.phone != null && c.phone!.isNotEmpty ? Text(c.phone!, style: TextStyle(color: theme.textSecondary, fontSize: 11)) : null,
                            onTap: () {
                              widget.controller.setSelectedCustomer(c);
                              setState(() => _isCustomerDropdownOpen = false);
                            },
                          )),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('No matching customers found.', textAlign: TextAlign.center, style: TextStyle(color: theme.textSecondary))
                        ),
                    ],
                  ),
                ),
              Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.cardBorder))),
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.person_add_rounded, color: theme.highlight),
                  title: Text('Add New Customer', style: TextStyle(color: theme.highlight, fontWeight: FontWeight.bold)),
                  onTap: _addCustomerDirectly,
                ),
              ),
            ],
          ),
        ),
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
            width: 60,
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
            child: Text('DISC',
                textAlign: TextAlign.right,
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
    final int productCount = widget.controller.cart.length;
    final double totalQuantity = widget.controller.cart.fold(0.0, (sum, item) => sum + item.quantity);
    final String qtyDisplay = totalQuantity.truncateToDouble() == totalQuantity 
        ? totalQuantity.toInt().toString() 
        : totalQuantity.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.cardBorder)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Products',
                  style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              Text('$productCount',
                  style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Quantity',
                  style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(qtyDisplay,
                  style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _totalRow(theme, 'Subtotal', widget.controller.subtotal),
          if (BusinessConfig.instance.enableTax) ...[
            const SizedBox(height: 6),
            _totalRow(theme, 'Tax', widget.controller.tax),
          ],
          if (BusinessConfig.instance.enableGlobalDiscount && _isEditingDiscount) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.highlight.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _showDiscountRestricted
                      ? ThemeProvider.error.withOpacity(0.5)
                      : theme.highlight.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                       IconButton(
                         icon: Text(_discountType == 'percentage' ? '%' : BusinessConfig.instance.currencyDisplay, style: TextStyle(color: theme.highlight, fontWeight: FontWeight.bold, fontSize: 16)),
                         onPressed: () {
                           setState(() {
                             _discountType = _discountType == 'fixed' ? 'percentage' : 'fixed';
                           });
                           _updateDiscountFromField();
                         },
                         constraints: const BoxConstraints(),
                         padding: EdgeInsets.zero,
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: TextField(
                           controller: _discountCtrl,
                           focusNode: _discountFocusNode,
                           keyboardType: const TextInputType.numberWithOptions(decimal: true),
                           style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                           decoration: InputDecoration(
                             hintText: 'Enter discount...',
                             hintStyle: TextStyle(color: theme.textHint, fontSize: 13),
                             border: InputBorder.none,
                             isDense: true,
                             contentPadding: const EdgeInsets.symmetric(vertical: 8),
                           ),
                           onChanged: (_) {
                             _updateDiscountFromField();
                           },
                           onSubmitted: (_) {
                             _applyDiscountFromField();
                             setState(() => _isEditingDiscount = false);
                           },
                         ),
                       ),
                       IconButton(
                         icon: Icon(Icons.check_circle_rounded, color: theme.highlight, size: 20),
                         onPressed: () {
                           _applyDiscountFromField();
                           setState(() => _isEditingDiscount = false);
                         },
                         constraints: const BoxConstraints(),
                         padding: EdgeInsets.zero,
                       ),
                    ],
                  ),
                  if (_showDiscountRestricted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ThemeProvider.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: ThemeProvider.error.withOpacity(0.3)),
                            ),
                            child: Text(
                              'RESTRICTED',
                              style: TextStyle(color: ThemeProvider.error, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ] else if (BusinessConfig.instance.enableGlobalDiscount &&
              (widget.controller.discount > 0 ||
                  widget.controller.globalDiscountValue > 0)) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: _openDiscountEditor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Cart Discount',
                          style: TextStyle(
                              color: theme.highlight,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_rounded,
                          size: 14, color: theme.highlight.withOpacity(0.7)),
                      if (widget.controller.isDiscountRestricted)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: ThemeProvider.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: ThemeProvider.error.withOpacity(0.3)),
                          ),
                          child: Text(
                            'RESTRICTED',
                            style: TextStyle(color: ThemeProvider.error, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  Text(
                      '-${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(widget.controller.discount)}',
                      style: TextStyle(
                          color: theme.highlight,
                          fontSize: 13,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ] else if (widget.controller.totalDiscount > 0 &&
              widget.controller.discount == 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Discount',
                    style: TextStyle(
                        color: theme.highlight,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Text(
                    '-${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(widget.controller.totalDiscount)}',
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
                  '${widget.controller.isReturn ? "-" : ""}${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(widget.controller.total)}',
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
    final showDiscount = BusinessConfig.instance.enableGlobalDiscount;
    return Column(
      children: [
          Row(
            children: [
              if (showDiscount) ...[
                Expanded(
                  child: Center(
                    child: _buildCartAction(
                      theme: theme,
                      icon: Icons.discount_rounded,
                      label: 'Discount',
                      color: theme.highlight,
                      onTap: () {
                        if (_isEditingDiscount) {
                          _applyDiscountFromField();
                          setState(() => _isEditingDiscount = false);
                        } else {
                          _openDiscountEditor();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Center(
                  child: _buildCartAction(
                    theme: theme,
                    icon: Icons.receipt_long_rounded,
                    label: 'Unhold',
                    color: ThemeProvider.warning,
                    onTap: widget.onShowHeldOrders,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: _buildCartAction(
                    theme: theme,
                    icon: Icons.point_of_sale_rounded,
                    label: 'Cash Drawer',
                    color: ThemeProvider.success,
                    onTap: widget.onOpenCashDrawer,
                  ),
                ),
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
                onTap: widget.controller.cart.isEmpty
                    ? null
                    : () {
                        if (_isEditingDiscount) {
                          _applyDiscountFromField();
                          setState(() => _isEditingDiscount = false);
                        }
                        widget.onPay();
                      },
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
        Text('${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(value)}',
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
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: 56, height: 52),
      child: Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(height: 4),
                Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
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
