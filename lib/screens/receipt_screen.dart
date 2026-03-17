import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';

class ReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> sale;
  
  const ReceiptScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final timestamp = DateTime.tryParse(sale['timestamp'] ?? '');
    final isReturn = sale['isReturn'] == true;
    final total = sale['total'] as double? ?? 0;
    final discount = sale['discount'] as double? ?? 0;
    final items = sale['items'] as List? ?? [];
    final paymentMethod = sale['paymentMethod'] ?? 'Cash';
    final customer = sale['customerName'];
    final receiptNumber = sale['id']?.toString().substring(0, 8).toUpperCase() ?? 'N/A';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.textPrimary,
        title: const Text('Receipt', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!'), backgroundColor: ThemeProvider.warning),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Print feature coming soon!'), backgroundColor: ThemeProvider.warning),
              );
            },
          ),
        ],
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header
                      const Icon(Icons.store_rounded, size: 64, color: Color(0xFF0A2647)),
                      const SizedBox(height: 16),
                      Text(BusinessConfig.instance.businessName.toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5), textAlign: TextAlign.center),
                      Text(BusinessConfig.instance.businessType?.toUpperCase() ?? 'RETAIL STORE', style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                      const SizedBox(height: 12),
                      if (BusinessConfig.instance.businessAddress.isNotEmpty)
                        Text(BusinessConfig.instance.businessAddress, style: const TextStyle(fontSize: 12, color: Colors.black54), textAlign: TextAlign.center),
                      if (BusinessConfig.instance.businessPhone.isNotEmpty)
                        Text('Phone: ${BusinessConfig.instance.businessPhone}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      
                      const SizedBox(height: 24),
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 16),
    
                      // Receipt info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('RECEIPT #', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                          Text(receiptNumber, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('DATE:', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                          Text(
                            timestamp != null ? '${timestamp.day}/${timestamp.month}/${timestamp.year}' : '',
                            style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      if (customer != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('CUSTOMER:', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            Text(customer, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('PAYMENT:', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                          Text(paymentMethod.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      if (isReturn) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: ThemeProvider.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(ThemeProvider.radiusList), border: Border.all(color: ThemeProvider.warning.withOpacity(0.5))),
                          child: const Text('RETURN', style: TextStyle(color: ThemeProvider.warning, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                        ),
                      ],
    
                      const SizedBox(height: 24),
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 16),
    
                      // Items
                      ...items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'] ?? 'Unknown', style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600)),
                                  Text('${item['quantity']} x ${BusinessConfig.instance.currency}. ${(item['price'] as num? ?? 0).toDouble().toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                ],
                              ),
                            ),
                            Text('${BusinessConfig.instance.currency}. ${(item['subtotal'] as num? ?? 0).toDouble().toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      )),
    
                      const SizedBox(height: 16),
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 16),
    
                      // Totals
                      _ReceiptRow(label: 'Subtotal', value: '${BusinessConfig.instance.currency}. ${(total.abs() / 1.08).toStringAsFixed(2)}'),
                      _ReceiptRow(label: 'Tax (8%)', value: '${BusinessConfig.instance.currency}. ${(total.abs() - total.abs() / 1.08).toStringAsFixed(2)}'),
                      if (discount > 0)
                        _ReceiptRow(label: 'Discount', value: '-${BusinessConfig.instance.currency}. ${(discount as num).toDouble().toStringAsFixed(2)}', valueColor: ThemeProvider.warning),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5)),
                          Text('${BusinessConfig.instance.currency}. ${total.abs().toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0A2647), letterSpacing: -1)),
                        ],
                      ),
    
                      const SizedBox(height: 32),
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 24),
    
                      // Footer
                      Text(BusinessConfig.instance.receiptFooter, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(12, (i) => Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            shape: BoxShape.circle,
                          ),
                        )),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        timestamp != null ? '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}' : '',
                        style: const TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ReceiptRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontSize: 13, color: valueColor ?? Colors.black87, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
