import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/receipt_screen.dart';
import 'package:mobile_app/screens/customer_list_screen.dart';
import 'package:mobile_app/db/mock_data.dart';

class PaymentScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final bool isReturn;
  final int? originalSaleId;
  final Customer? customer;

  const PaymentScreen({
    super.key,
    required this.cart,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    required this.isReturn,
    this.originalSaleId,
    this.customer,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final theme = ThemeProvider.instance;
  String _selectedPayment = 'Cash';
  double _amountTendered = 0;
  double _tipPercent = 0;
  final _cashController = TextEditingController();
  final _partialController = TextEditingController();

  double get _tipAmount => widget.total * (_tipPercent / 100);
  double get _grandTotal => widget.total + _tipAmount;
  double get _change => _selectedPayment == 'Cash' ? (_amountTendered - _grandTotal) : 0;
  Customer? _selectedCustomer;
  bool _processing = false;
  bool _generateReceipt = BusinessConfig.instance.autoReceipt;
  bool _openCashDrawer = BusinessConfig.instance.openCashDrawer;
  List<Map<String, dynamic>> _currencyNotes = [];

  @override
  void initState() {
    super.initState();
    _amountTendered = widget.total;
    _cashController.text = BusinessConfig.instance.formatAmount(widget.total);
    _partialController.text = BusinessConfig.instance.formatAmount(widget.total);
    _selectedCustomer = widget.customer;
    _loadCurrencyNotes();
  }

  Future<void> _loadCurrencyNotes() async {
    final notes = await DatabaseHelper.instance.getCurrencyNotes();
    if (mounted) {
      setState(() {
        _currencyNotes = notes.where((n) => n['status'] == 1).toList();
      });
    }
  }

  void _processPayment() async {
    if (_processing) return;

    // Validate partial/credit payment requires customer
    final unpaidAmount = _grandTotal - _amountTendered;
    if ((_selectedPayment == 'Credit' || unpaidAmount > 0.01) && _selectedCustomer == null) {
      final customer = await _showCustomerSelectionDialog();
      if (customer == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Partial payments and credit sales require a customer. Please select a customer.'),
              backgroundColor: ThemeProvider.error,
            ),
          );
        }
        return;
      }
      setState(() {
        _selectedCustomer = customer;
      });
    }

    setState(() => _processing = true);

    try {
      final activeShift = await DatabaseHelper.instance.getActiveShift();
      final isReturnVal = widget.isReturn ? 1 : 0;
      final sign = widget.isReturn ? -1.0 : 1.0;
      
      final sale = {
        'business_id': BusinessConfig.instance.businessId,
        'branch_id': BusinessConfig.instance.branchId,
        'customer_id': _selectedCustomer?.id,
        'user_id': BusinessConfig.instance.adminId,
        'total': _grandTotal * sign,
        'subtotal': widget.subtotal * sign,
        'tax': widget.tax * sign,
        'discount': widget.discount * sign,
        'tip': _tipAmount * sign,
        'is_return': isReturnVal,
        'payment_method': _selectedPayment,
        'status': 1,
        'is_synced': 0,
        'shift_id': activeShift?['id'],
        'created_at': DateTime.now().toIso8601String(),
      };

      final saleItems = widget.cart.map((item) {
        return {
          'product_id': item['id'] ?? item['productId'],
          'stock_id': item['stock_id'],
          'quantity': item['quantity'],
          'price': item['price'],
          'subtotal': item['subtotal'],
          'is_synced': 0,
        };
      }).toList();

      int saleId = 0;
      if (widget.isReturn) {
        final returnData = {
          'business_id': BusinessConfig.instance.businessId,
          'branch_id': BusinessConfig.instance.branchId,
          'admin_id': BusinessConfig.instance.adminId,
          'sale_id': widget.originalSaleId,
          'customer_id': _selectedCustomer?.id,
          'user_id': BusinessConfig.instance.adminId,
          'total_amount': _grandTotal,
          'reason': 'Refund',
          'status': 1,
          'is_synced': 0,
        };
        final returnItems = widget.cart.map((item) {
          return {
            'sale_item_id': null,
            'product_id': item['id'] ?? item['productId'],
            'stock_id': item['stock_id'],
            'quantity': item['quantity'],
            'price': item['price'],
            'subtotal': item['subtotal'],
          };
        }).toList();
        saleId = await DatabaseHelper.instance.insertReturn(returnData, returnItems);
      } else {
        saleId = await DatabaseHelper.instance.insertSale(sale, saleItems);
      }
      
      if (!widget.isReturn && (_selectedPayment == 'Credit' || unpaidAmount > 0.01) && _selectedCustomer != null) {
        final creditSale = {
          'business_id': BusinessConfig.instance.businessId,
          'branch_id': BusinessConfig.instance.branchId,
          'customer_id': _selectedCustomer!.id,
          'sale_id': saleId,
          'amount': _grandTotal,
          'remaining_balance': _grandTotal,
          'status': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        final creditSaleId = await DatabaseHelper.instance.insertCreditSale(creditSale);
        await DatabaseHelper.instance.updateCustomerCreditBalance(_selectedCustomer!.id ?? 0, _grandTotal);

        if (_amountTendered > 0) {
          final payment = {
            'business_id': BusinessConfig.instance.businessId,
            'branch_id': BusinessConfig.instance.branchId,
            'credit_sale_id': creditSaleId,
            'customer_id': _selectedCustomer!.id,
            'amount': _amountTendered,
            'payment_date': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
            'notes': 'Paid at time of sale',
          };
          await DatabaseHelper.instance.insertCreditPayment(payment);
        }
      }
      
      final saleForReceipt = {
        'id': saleId,
        'business_id': BusinessConfig.instance.businessId,
        'branch_id': BusinessConfig.instance.branchId,
        'customer_id': _selectedCustomer?.id,
        'user_id': BusinessConfig.instance.adminId,
        'total': _grandTotal * sign,
        'subtotal': widget.subtotal * sign,
        'tax': widget.tax * sign,
        'discount': widget.discount * sign,
        'tip': _tipAmount * sign,
        'is_return': isReturnVal,
        'payment_method': _selectedPayment,
        'status': 1,
        'is_synced': 0,
        'created_at': DateTime.now().toIso8601String(),
        'items': widget.cart.map((item) => {
          'name': item['name'],
          'price': (item['price'] as num).toDouble(),
          'quantity': item['quantity'],
          'subtotal': (item['subtotal'] as num).toDouble(),
          'discount': (item['discount'] as num? ?? 0).toDouble(),
        }).toList(),
        'timestamp': DateTime.now().toIso8601String(),
        'isReturn': widget.isReturn,
        'paymentMethod': _selectedPayment,
        'customerName': _selectedCustomer?.name,
        'amount_tendered': _amountTendered,
        'change': _change,
        'employee_name': BusinessConfig.instance.staffName,
      };

      if (_openCashDrawer) _handleOpenCashDrawer();

      if (mounted) {
        if (_generateReceipt) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => ReceiptScreen(sale: saleForReceipt)),
          );
        } else {
          Navigator.of(context).pop();
          if (widget.isReturn) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Refund completed!'), backgroundColor: ThemeProvider.success),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sale completed successfully!'), backgroundColor: ThemeProvider.success),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction failed: $e'),
            backgroundColor: ThemeProvider.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isReturn ? 'Process Refund' : 'Payment',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 700;
    
                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: _buildPaymentMethods(isMobile: false),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: _buildSummary(true),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _buildPaymentMethods(isMobile: true),
                          const SizedBox(height: 12),
                          _buildSummary(false),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPaymentMethods({bool isMobile = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: theme.glassDecoration.copyWith(
        borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
      ),
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: dialpad + amount field (The "Start")
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                   _buildAmountField(),
                  const SizedBox(height: 8),
                  _buildUniversalDialPad(),
                  if (_amountTendered < _grandTotal && _selectedPayment != 'Credit') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ThemeProvider.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                        border: Border.all(color: ThemeProvider.warning.withOpacity(0.3), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: ThemeProvider.warning, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Remaining ${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(_grandTotal - _amountTendered)} added to credit.',
                              style: TextStyle(color: theme.textPrimary, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Right column: payment method + options
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Payment Method',
                      style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MockDataStore.instance.paymentMethods
                        .map(
                          (pm) => _PaymentMethodButton(
                            name: pm.name,
                            iconName: pm.icon,
                            selected: _selectedPayment == pm.name,
                            onTap: () {
                              setState(() {
                                _selectedPayment = pm.name;
                                if (pm.name == 'Credit') {
                                  _amountTendered = 0;
                                  _cashController.text = '0.00';
                                  _partialController.text = '0.00';
                                } else if (pm.name == 'Cash') {
                                  _amountTendered = _grandTotal;
                                  _cashController.text = BusinessConfig.instance.formatAmount(_grandTotal);
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),

                  // Payment Options Toggles
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOptionToggle(
                        label: 'Receipt',
                        icon: Icons.receipt_long_rounded,
                        value: _generateReceipt,
                        onChanged: (v) => setState(() => _generateReceipt = v ?? false),
                      ),
                      _buildOptionToggle(
                        label: 'Cash Drawer',
                        icon: Icons.door_sliding_rounded,
                        value: _openCashDrawer,
                        onChanged: (v) => setState(() => _openCashDrawer = v ?? false),
                      ),
                    ],
                  ),

                  if (!widget.isReturn) ...[
                    const SizedBox(height: 12),
                    Text('Gratuity (Tip)',
                        style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _TipButton(
                            percent: 0,
                            selected: _tipPercent == 0,
                            onTap: () => setState(() => _tipPercent = 0)),
                        _TipButton(
                            percent: 5,
                            selected: _tipPercent == 15,
                            onTap: () => setState(() => _tipPercent = 15)),
                        _TipButton(
                            percent: 10,
                            selected: _tipPercent == 18,
                            onTap: () => setState(() => _tipPercent = 18)),
                        _TipButton(
                            percent: 15,
                            selected: _tipPercent == 20,
                            onTap: () => setState(() => _tipPercent = 20)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(bool isWide) {
    return Container(
    
      padding: const EdgeInsets.all(16),
      decoration: theme.glassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        
        mainAxisSize: MainAxisSize.min,
        children: [
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order Summary',
                  style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    
                    color: theme.whiteAlpha(0.05),
                    borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded, size: 14, color: theme.highlight),
                      const SizedBox(width: 6),
                      Text(
                        _selectedCustomer?.name ?? 'Walk-in Guest',
                        style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                if (_selectedCustomer == null && (_amountTendered < _grandTotal || _selectedPayment == 'Credit'))
                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded, size: 20, color: theme.highlight),
                    onPressed: () async {
                      final customer = await _showCustomerSelectionDialog();
                      if (customer != null) setState(() => _selectedCustomer = customer);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            _buildItemList(shrinkWrap: true, physics: const NeverScrollableScrollPhysics()),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),

            _SummaryRow(
                label: 'Subtotal',
                value:
                    '${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(widget.subtotal)}'),
            _SummaryRow(
                label: 'Tax',
                value:
                    '${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(widget.tax)}'),
            if (widget.discount > 0)
              _SummaryRow(
                  label: 'Discount',
                  value:
                      '-${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(widget.discount)}',
                  valueColor: ThemeProvider.warning),
            if (_tipAmount > 0)
              _SummaryRow(
                  label: 'Tip',
                  value:
                      '${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(_tipAmount)}',
                valueColor: ThemeProvider.success),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('GRAND TOTAL',
                  style: TextStyle(
                      color: theme.textHint,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(_grandTotal)}',
                    style: TextStyle(
                        color: theme.highlight,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),


          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (_processing || (_selectedPayment == 'Cash' &&
                      _amountTendered < _grandTotal))
                  ? null
                  : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    widget.isReturn ? ThemeProvider.warning : ThemeProvider.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                elevation: 4,
                shadowColor: (widget.isReturn ? ThemeProvider.warning : ThemeProvider.success).withOpacity(0.3),
              ),
              child: _processing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.isReturn 
                        ? 'PROCESS REFUND' 
                        : (_amountTendered < _grandTotal ? 'COMPLETE & ADD TO CREDIT' : 'COMPLETE TRANSACTION'),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleOpenCashDrawer() {
    // Hardware integration for cash drawer would go here.
    // For now, we simulate the action and log it.
    debugPrint('Opening Cash Drawer...');
  }

  Widget _buildOptionToggle({
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.textSecondary, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: theme.highlight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Customer?> _showCustomerSelectionDialog() async {
    final customersData = await DatabaseHelper.instance.getCustomers();
    final List<Customer> allCustomers =
        customersData.map<Customer>((c) => Customer.fromMap(c)).toList();

    if (!mounted) return null;

    return await showDialog<Customer?>(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = allCustomers
                .where((c) =>
                    c.name.toLowerCase().contains(query.toLowerCase()) ||
                    (c.phone?.contains(query) ?? false))
                .toList();

            return AlertDialog(
              backgroundColor: theme.surface,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select Customer',
                      style: TextStyle(color: theme.textPrimary)),
                  IconButton(
                    icon: Icon(Icons.person_add, color: theme.highlight),
                    onPressed: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CustomerListScreen()));
                      final updatedData =
                          await DatabaseHelper.instance.getCustomers();
                      setDialogState(() {
                        allCustomers.clear();
                        allCustomers.addAll(
                            updatedData.map((c) => Customer.fromMap(c)));
                      });
                    },
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6),
                child: SizedBox(
                  width: 350,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          autofocus: true,
                          style: TextStyle(color: theme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search customer...',
                            hintStyle: TextStyle(color: theme.textHint),
                            prefixIcon:
                                Icon(Icons.search, color: theme.iconColor),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (v) => setDialogState(() => query = v),
                        ),
                        const SizedBox(height: 12),
                          if (!BusinessConfig.instance.requireCustomer) ...[
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: theme.highlight.withAlpha(40),
                                child: Icon(Icons.person_outline,
                                    color: theme.highlight, size: 20),
                              ),
                              title: Text('Walk-in Guest',
                                  style: TextStyle(
                                      color: theme.textPrimary,
                                      fontWeight: FontWeight.bold)),
                              onTap: () => Navigator.pop(ctx, null),
                            ),
                            const Divider(),
                          ],
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('No customers found',
                                style: TextStyle(color: theme.textSecondary)),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final customer = filtered[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: theme.highlight,
                                  child: Text(customer.name[0].toUpperCase(),
                                      style:
                                          const TextStyle(color: Colors.white)),
                                ),
                                title: Text(customer.name,
                                    style: TextStyle(
                                        color: theme.textPrimary,
                                        fontWeight: FontWeight.w600)),
                                subtitle: customer.phone != null
                                    ? Text(customer.phone!,
                                        style: TextStyle(
                                            color: theme.textSecondary))
                                    : null,
                                onTap: () => Navigator.pop(ctx, customer),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildItemList({bool shrinkWrap = false, ScrollPhysics? physics}) {
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: widget.cart.length,
      itemBuilder: (context, index) {
        final item = widget.cart[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: theme.whiteAlpha(0.05), borderRadius: BorderRadius.circular(4)),
                child: Text('${item['quantity']}x',
                    style: TextStyle(
                        color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(item['name'],
                    style: TextStyle(
                        color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Text(
                '${BusinessConfig.instance.currencyDisplay} ${(item['subtotal'] as double).toStringAsFixed(2)}',
                style: TextStyle(
                    color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      },
    );
  }

  TextEditingController get _activeController => _selectedPayment == 'Credit' ? _partialController : _cashController;

  Widget _buildAmountField() {
    String label = _selectedPayment == 'Cash' ? 'Amount Tendered' : (_selectedPayment == 'Credit' ? 'Partial Payment' : 'Confirmation');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: theme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        TextField(
          controller: _activeController,
          readOnly: true,
          style: TextStyle(
              color: theme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900),
          decoration: theme.glassInputDecoration('Amount', Icons.payments_rounded).copyWith(
            prefixText: '${BusinessConfig.instance.currencyDisplay} ',
            prefixStyle: TextStyle(color: theme.highlight, fontWeight: FontWeight.w900, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            suffixIcon: IconButton(
              icon: Icon(Icons.refresh_rounded, color: theme.highlight, size: 16),
              onPressed: () => _setCash(_grandTotal),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUniversalDialPad() {
    final leftNotes = _currencyNotes.take((_currencyNotes.length / 2).ceil()).toList();
    final rightNotes = _currencyNotes.skip(leftNotes.length).toList();

    // Fallback if no notes defined
    final displayLeft = leftNotes.isNotEmpty ? leftNotes : [{'value': 10}, {'value': 20}, {'value': 50}];
    final displayRight = rightNotes.isNotEmpty ? rightNotes : [{'value': 100}, {'value': 500}, {'value': 1000}];

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Notes
            Expanded(
              flex: 1,
              child: Column(
                children: displayLeft.map((note) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _NoteButton(amount: (note['value'] as num).toDouble(), onTap: () => _setCash((note['value'] as num).toDouble())),
                )).toList(),
              ),
            ),
            const SizedBox(width: 8),
            // Dial Pad
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildDialRow(['1', '2', '3']),
                  const SizedBox(height: 6),
                  _buildDialRow(['4', '5', '6']),
                  const SizedBox(height: 6),
                  _buildDialRow(['7', '8', '9']),
                  const SizedBox(height: 6),
                  _buildDialRow(['.', '0', '⌫'], isIcons: [false, false, true]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right Notes
            Expanded(
              flex: 1,
              child: Column(
                children: displayRight.map((note) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _NoteButton(amount: (note['value'] as num).toDouble(), onTap: () => _setCash((note['value'] as num).toDouble())),
                )).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: _QuickCashButton(
              amount: _grandTotal,
              label: 'EXACT TOTAL',
              onTap: () => _setCash(_grandTotal)),
        ),
      ],
    );
  }

  void _setCash(double amount) {
    setState(() {
      _amountTendered = amount;
      _activeController.text = amount.toStringAsFixed(2);
    });
  }

  Widget _buildDialRow(List<String> keys, {List<bool>? isIcons}) {
    return Row(
      children: keys.asMap().entries.map((entry) {
        int idx = entry.key;
        String key = entry.value;
        bool isIcon = isIcons != null && isIcons[idx];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: idx < keys.length - 1 ? 6 : 0),
            child: _DialButton(
              label: key,
              isIcon: isIcon,
              onTap: () => _onDialTap(key),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _onDialTap(String key) {
    String current = _activeController.text;
    if (key == '⌫') {
      if (current.isNotEmpty) {
        current = current.substring(0, current.length - 1);
      }
    } else if (key == '.') {
      if (!current.contains('.')) {
        current += '.';
      }
    } else {
      if (current == '0' || current == '0.00' || current == widget.total.toStringAsFixed(2)) {
        current = key;
      } else {
        current += key;
      }
    }
    
    setState(() {
      _activeController.text = current;
      _amountTendered = double.tryParse(current) ?? 0;
    });
  }
}

class _DialButton extends StatelessWidget {
  final String label;
  final bool isIcon;
  final VoidCallback onTap;

  const _DialButton({required this.label, required this.onTap, this.isIcon = false});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: theme.whiteAlpha(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.whiteAlpha(0.1)),
          ),
          child: Center(
            child: isIcon 
              ? Icon(Icons.backspace_outlined, color: theme.textPrimary, size: 16)
              : Text(label, style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

class _NoteButton extends StatelessWidget {
  final double amount;
  final VoidCallback onTap;

  const _NoteButton({required this.amount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 36,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.highlight.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.highlight.withOpacity(0.2)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(amount.toStringAsFixed(0), style: TextStyle(color: theme.highlight, fontWeight: FontWeight.w900, fontSize: 12)),
                
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodButton extends StatelessWidget {
  final String name;
  final String iconName;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodButton({
    required this.name,
    required this.iconName,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon {
    switch (iconName) {
      case 'credit_card':
        return Icons.credit_card_rounded;
      case 'phone_android':
        return Icons.phone_android_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 75,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: theme.glassDecoration.copyWith(
          color: selected ? theme.highlight : theme.whiteAlpha(0.05),
          border: Border.all(
              color: selected ? theme.highlight : theme.whiteAlpha(0.1), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(0.2) : theme.whiteAlpha(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon,
                  color: selected ? Colors.white : theme.iconColor,
                  size: 17),
            ),
            const SizedBox(height: 8),
            Text(name.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: selected ? Colors.white : theme.textPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _QuickCashButton extends StatelessWidget {
  final double amount;
  final String? label;
  final VoidCallback onTap;

  const _QuickCashButton(
      {required this.amount, this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.whiteAlpha(0.05),
          borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
          border: Border.all(color: theme.whiteAlpha(0.1)),
        ),
        child: Text(
          label ??
              '${BusinessConfig.instance.currencyDisplay} ${amount.toStringAsFixed(0)}',
          style: TextStyle(
              color: theme.textPrimary, fontWeight: FontWeight.w900, fontSize: 13),
        ),
      ),
    );
  }
}

class _TipButton extends StatelessWidget {
  final int percent;
  final bool selected;
  final VoidCallback onTap;

  const _TipButton(
      {required this.percent, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? theme.highlight : theme.whiteAlpha(0.05),
          borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
          border: Border.all(
              color: selected ? theme.highlight : theme.whiteAlpha(0.1)),
        ),
        child: Text(
          percent == 0 ? 'NO TIP' : '$percent%',
          style: TextStyle(
              color: selected ? Colors.white : theme.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 10),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(color: theme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
