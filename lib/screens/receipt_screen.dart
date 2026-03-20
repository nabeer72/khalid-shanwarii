import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';

class ReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> sale;
  
  const ReceiptScreen({super.key, required this.sale});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loadingItems = false;
  final theme = ThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // If items are already passed (from POS), use them
    if (widget.sale['items'] != null && (widget.sale['items'] as List).isNotEmpty) {
      setState(() {
        _items = List<Map<String, dynamic>>.from(widget.sale['items']);
      });
      return;
    }

    // Otherwise, fetch from database (from History)
    final saleId = widget.sale['id'];
    if (saleId != null) {
      setState(() => _loadingItems = true);
      try {
        final dbItems = await DatabaseHelper.instance.getSaleItems(saleId);
        if (mounted) {
          setState(() {
            _items = dbItems;
            _loadingItems = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _loadingItems = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final timestamp = DateTime.tryParse(sale['created_at'] ?? sale['timestamp'] ?? '');
    final isReturn = sale['is_return'] == 1 || sale['isReturn'] == true;
    final total = (sale['total'] as num? ?? 0).toDouble();
    final discount = (sale['discount'] as num? ?? 0).toDouble();
    final paymentMethod = (sale['payment_method'] ?? sale['paymentMethod'] ?? 'Cash').toString();
    final customer = sale['customer_name'] ?? sale['customerName'];
    
    // SAFE ID SUBSTRING
    String rawId = sale['id']?.toString() ?? 'N/A';
    final receiptNumber = rawId.length > 8 ? rawId.substring(0, 8).toUpperCase() : rawId.padLeft(4, '0').toUpperCase();

    final employeeStr = (sale['employee_name']?.toString() ?? BusinessConfig.instance.staffName).trim();
    final employee = employeeStr.isEmpty ? 'Admin' : employeeStr;
    final tendered = (sale['amount_tendered'] as num? ?? total).toDouble();
    final change = (sale['change'] as num? ?? 0).toDouble();

    // Check if any item has a discount
    final hasItemDiscounts = _items.any((item) => (item['discount'] as num? ?? 0) > 0);

    return Scaffold(
      backgroundColor: theme.isDark ? Colors.black : Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.textPrimary,
        title: const Text('Receipt', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: 380,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
              ],
            ),
            child: Column(
              children: [
                // Top "Paper Cut" effect or just padding
                const SizedBox(height: 20),
                
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Header
                      Text(
                        BusinessConfig.instance.businessName.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (BusinessConfig.instance.businessAddress.isNotEmpty)
                        Text(
                          BusinessConfig.instance.businessAddress,
                          style: const TextStyle(color: Colors.black87, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      if (BusinessConfig.instance.businessPhone.isNotEmpty)
                        Text(
                          BusinessConfig.instance.businessPhone,
                          style: const TextStyle(color: Colors.black87, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      
                      const SizedBox(height: 8),
                      const Divider(color: Colors.black, thickness: 1),
                      const SizedBox(height: 8),

                      // Meta Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Bill No: $receiptNumber', style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(
                            timestamp != null ? '${timestamp.month}/${timestamp.day}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')} ${timestamp.hour >= 12 ? 'PM' : 'AM'}' : '',
                            style: const TextStyle(color: Colors.black, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Casher: ${employee.toUpperCase()}', style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Customer: ${customer ?? "Walk-In"}', style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      
                      const SizedBox(height: 8),
                      const _DashedLine(),
                      const SizedBox(height: 4),

                      // Header & Items Section
                      if (_loadingItems)
                        const Center(child: CircularProgressIndicator(color: Colors.black))
                      else
                        Column(
                          children: [
                            // Header Row
                            Table(
                              columnWidths: {
                                0: const FlexColumnWidth(4.5),
                                1: const FlexColumnWidth(1),
                                2: const FlexColumnWidth(2),
                                if (hasItemDiscounts) 3: const FlexColumnWidth(1.5),
                                4: const FlexColumnWidth(2.5),
                              },
                              children: [
                                TableRow(
                                  children: [
                                    const Text('Description',
                                        style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                                    const Text('QTY',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                                    const Text('Price',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                                    if (hasItemDiscounts)
                                      const Text('Disc',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                                    const Text('Total',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const _DashedLine(),
                            const SizedBox(height: 8),

                            // Items Table
                            Table(
                              columnWidths: {
                                0: const FlexColumnWidth(4.5),
                                1: const FlexColumnWidth(1),
                                2: const FlexColumnWidth(2),
                                if (hasItemDiscounts) 3: const FlexColumnWidth(1.5),
                                4: const FlexColumnWidth(2.5),
                              },
                              children: _items.map((item) {
                                final name = item['product_name'] ?? item['name'] ?? 'Item';
                                final qty = (item['quantity'] as num? ?? 0).toDouble();
                                final price = (item['price'] as num? ?? 0).toDouble();
                                final subtotal = (item['subtotal'] as num? ?? 0).toDouble();
                                final disc = (item['discount'] as num? ?? 0).toDouble();

                                return TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(name.toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.black, fontSize: 11, fontWeight: FontWeight.w600)),
                                    ),
                                    Text(qty.toStringAsFixed(0),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.black, fontSize: 11)),
                                    Text(price.toStringAsFixed(0),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(color: Colors.black, fontSize: 11)),
                                    if (hasItemDiscounts)
                                      Text(disc.toStringAsFixed(0),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(color: Colors.black, fontSize: 11)),
                                    Text(subtotal.toStringAsFixed(0),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      
                      const SizedBox(height: 4),
                      const _DashedLine(),
                      const SizedBox(height: 4),

                      // Item levels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('[${_items.length}] Items', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('[${_items.fold<double>(0, (p, e) => p + (e['quantity'] as num? ?? 0)).toStringAsFixed(0)}] Qty', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const _DashedLine(),
                      const SizedBox(height: 12),

            // Totals Section
            _SummaryRow(label: 'Gross Total', value: (total + discount).toStringAsFixed(2)),
            if (discount > 0)
              _SummaryRow(label: '(-)Total Disc', value: discount.toStringAsFixed(2)),
            _SummaryRow(label: 'Net Total', value: total.toStringAsFixed(2), isBold: true, fontSize: 18),
            
            if (tendered > 0) ...[
              const SizedBox(height: 8),
              _SummaryRow(label: 'Cash Received', value: tendered.toStringAsFixed(2)),
              if (change > 0)
                _SummaryRow(label: 'Cash Back', value: change.toStringAsFixed(2)),
            ],
                      
                      const SizedBox(height: 12),
                      const _DottedLine(),
                      const SizedBox(height: 12),

                      // You Saved
                      if (discount > 0)
                        Text(
                          'You Saved: ${discount.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                      
                      const SizedBox(height: 12),
                      const _DottedLine(),
                      const SizedBox(height: 16),

                      const Text(
                        '*** Thanks For Your Kind Visit ***',
                        style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(80, (i) => Expanded(
        child: Container(
          height: 1,
          color: i.isEven ? Colors.black : Colors.transparent,
          margin: const EdgeInsets.symmetric(horizontal: 0.2),
        ),
      )),
    );
  }
}

class _DottedLine extends StatelessWidget {
  const _DottedLine();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(120, (i) => Expanded(
        child: Container(
          height: 1.2,
          color: i.isEven ? Colors.black : Colors.transparent,
          margin: const EdgeInsets.symmetric(horizontal: 0.3),
        ),
      )),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final double fontSize;

  const _SummaryRow({required this.label, required this.value, this.isBold = false, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(label, style: TextStyle(color: Colors.black, fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          const SizedBox(width: 20),
          SizedBox(
            width: 100,
            child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: Colors.black, fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          ),
        ],
      ),
    );
  }
}
