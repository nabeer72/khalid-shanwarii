import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mobile_app/utils/keyboard_shortcuts.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  final GlobalKey _receiptKey = GlobalKey();
  String _storeName = '';
  String _storeAddress = '';
  String _storePhone = '';
  String _receiptFooter = '';

  @override
  void initState() {
    super.initState();
    _storeName = BusinessConfig.instance.businessName;
    _storeAddress = BusinessConfig.instance.businessAddress;
    _storePhone = BusinessConfig.instance.businessPhone;
    _receiptFooter = BusinessConfig.instance.receiptFooter;
    _initData();
  }

  Future<void> _loadStoreInfo() async {
    try {
      final db = DatabaseHelper.instance;
      final name = await db.getSetting('business_name');
      final address = await db.getSetting('business_address');
      final phone = await db.getSetting('business_phone');
      final footer = await db.getSetting('receipt_footer');
      if (!mounted) return;
      setState(() {
        if (name != null && name.isNotEmpty) _storeName = name;
        if (address != null && address.isNotEmpty) _storeAddress = address;
        if (phone != null && phone.isNotEmpty) _storePhone = phone;
        if (footer != null && footer.isNotEmpty) _receiptFooter = footer;
      });
    } catch (_) {}
  }

  Future<void> _initData() async {
    await _loadStoreInfo();
    // If items are already passed (from POS), use them
    if (widget.sale['items'] != null && (widget.sale['items'] as List).isNotEmpty) {
      setState(() {
        _items = List<Map<String, dynamic>>.from(widget.sale['items']);
      });
      return;
    }

    // Otherwise, fetch from database (from History)
    final saleId = widget.sale['id'];
    final isReturn = widget.sale['is_return'] == 1;
    if (saleId != null) {
      setState(() => _loadingItems = true);
      try {
        List<Map<String, dynamic>> dbItems;
        if (isReturn) {
          // Fetch from return_items table and join product name
          final db = await DatabaseHelper.instance.database;
          dbItems = await db.rawQuery('''
            SELECT ri.*, p.name as product_name
            FROM return_items ri
            LEFT JOIN products p ON ri.product_id = p.id
            WHERE ri.return_id = ?
          ''', [saleId]);
        } else {
          dbItems = await DatabaseHelper.instance.getSaleItems(saleId);
        }
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

  Future<pw.Document?> _captureReceiptAsPdf() async {
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      final pdfImage = pw.MemoryImage(pngBytes);

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            image.width / 3.0,
            image.height / 3.0,
          ),
          build: (context) => pw.Center(
            child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
          ),
        ),
      );
      return pdf;
    } catch (e) {
      return null;
    }
  }

  Future<void> _handlePrint() async {
    final pdf = await _captureReceiptAsPdf();
    if (pdf == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture receipt'), backgroundColor: ThemeProvider.error),
        );
      }
      return;
    }
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Future<void> _handleShare() async {
    final pdf = await _captureReceiptAsPdf();
    if (pdf == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture receipt'), backgroundColor: ThemeProvider.error),
        );
      }
      return;
    }
    final bytes = await pdf.save();
    final sale = widget.sale;
    final invoiceId = sale['invoice_number'] ?? sale['id']?.toString() ?? 'receipt';
    await Printing.sharePdf(bytes: bytes, filename: 'receipt_$invoiceId.pdf');
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

    return CallbackShortcuts(
      bindings: POSKeyboardShortcuts.getReceiptBindings(
        onEscape: () => Navigator.of(context).pop(),
      ),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.textPrimary,
        title: const Text('Receipt', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _handleShare,
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            onPressed: _handlePrint,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: RepaintBoundary(
            key: _receiptKey,
            child: Container(
            width: 380,
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: theme.cardBorder),
              boxShadow: theme.cardShadow,
            ),
            child: Column(
              children: [
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.highlight,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.highlight,
                          boxShadow: [
                            BoxShadow(
                              color: theme.highlight.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _storeName.toUpperCase(),
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_storeAddress.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                           
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _storeAddress,
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 12,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_storePhone.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone_outlined, size: 13, color: theme.textSecondary),
                            const SizedBox(width: 5),
                            Text(
                              _storePhone,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isReturn ? ThemeProvider.warning.withOpacity(0.15) : theme.muted,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isReturn ? ThemeProvider.warning.withOpacity(0.3) : theme.divider),
                        ),
                        child: Text(
                          isReturn ? 'REFUND RECEIPT' : 'SALES RECEIPT',
                          style: TextStyle(
                            color: isReturn ? ThemeProvider.warning : theme.highlight,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Divider(color: theme.divider, thickness: 1.2, height: 1),
                      const SizedBox(height: 12),

                      // Meta Info Row 1: Bill No & Date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Bill No: $receiptNumber', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(
                            timestamp != null ? '${timestamp.month}/${timestamp.day}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')} ${timestamp.hour >= 12 ? 'PM' : 'AM'}' : '',
                            style: TextStyle(color: theme.textPrimary, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Meta Info Row 2: Casher & Customer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Casher: ${employee.toUpperCase()}', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('Customer: ${customer ?? "Walk-In"}', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      const _DashedLine(),
                      const SizedBox(height: 4),

                      // Header & Items Section
                      if (_loadingItems)
                        Center(child: CircularProgressIndicator(color: theme.highlight))
                      else
                        Column(
                          children: [
                            // Header Row
                            Table(
                              columnWidths: {
                                0: const FlexColumnWidth(3),
                                1: const FlexColumnWidth(1),
                                2: const FlexColumnWidth(1.5),
                                if (hasItemDiscounts) 3: const FlexColumnWidth(1),
                                4: const FlexColumnWidth(1.5),
                              },
                              children: [
                                TableRow(
                                  children: [
                                    Text('Description',
                                      style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                                    Text('QTY',
                                        textAlign: TextAlign.center,
                                      style: TextStyle(color: theme.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
                                    Text('Price',
                                        textAlign: TextAlign.right,
                                      style: TextStyle(color: theme.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
                                    if (hasItemDiscounts)
                                      Text('Disc',
                                          textAlign: TextAlign.right,
                                        style: TextStyle(color: theme.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
                                    Text('Total',
                                        textAlign: TextAlign.right,
                                      style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
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
                                0: const FlexColumnWidth(3),
                                1: const FlexColumnWidth(1),
                                2: const FlexColumnWidth(1.5),
                                if (hasItemDiscounts) 3: const FlexColumnWidth(1),
                                4: const FlexColumnWidth(1.5),
                              },
                              children: _items.map((item) {
                                final name = item['product_name'] ?? item['name'] ?? 'Item';
                                final qty = (item['quantity'] as num? ?? 0).toDouble();
                                final price = (item['price'] as num? ?? 0).toDouble();
                                final subtotal = (item['sub_total'] ?? item['subtotal'] as num? ?? 0).toDouble();
                                final disc = (item['discount'] as num? ?? 0).toDouble();

                                return TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6, right: 4),
                                      child: Text(name.toUpperCase(),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                                    ),
                                    Text(BusinessConfig.instance.formatAmount(qty),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: theme.textPrimary, fontSize: 11)),
                                    Text(BusinessConfig.instance.formatAmount(price),
                                        textAlign: TextAlign.right,
                                        style: TextStyle(color: theme.textPrimary, fontSize: 11)),
                                    if (hasItemDiscounts)
                                      Text(BusinessConfig.instance.formatAmount(disc),
                                          textAlign: TextAlign.right,
                                          style: TextStyle(color: theme.textPrimary, fontSize: 11)),
                                    Text(BusinessConfig.instance.formatAmount(subtotal),
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
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
                          Text('[${_items.length}] Items', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('[${BusinessConfig.instance.formatAmount(_items.fold<double>(0, (p, e) => p + (e['quantity'] as num? ?? 0)))}] Qty', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const _DashedLine(),
                      const SizedBox(height: 12),

            // Totals Section (Two Columns)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Gross & Disc
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryRow(
                        label: 'Gross:', 
                        value: BusinessConfig.instance.formatAmount(total + discount),
                        alignment: MainAxisAlignment.start,
                        labelWidth: 55,
                      ),
                      if (discount > 0)
                        _SummaryRow(
                          label: 'Disc:', 
                          value: '-${BusinessConfig.instance.formatAmount(discount)}',
                          alignment: MainAxisAlignment.start,
                          labelWidth: 55,
                        ),
                      _SummaryRow(
                        label: 'Type:', 
                        value: paymentMethod.toUpperCase(),
                        alignment: MainAxisAlignment.start,
                        labelWidth: 55,
                      ),

                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Right Column: Net Total & Cash
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _SummaryRow(
                        label: 'Net:', 
                        value: BusinessConfig.instance.formatAmount(total), 
                        isBold: true, 
                        fontSize: 16,
                        alignment: MainAxisAlignment.end,
                        labelWidth: 40,
                      ),
                      if (tendered > 0) ...[
                        _SummaryRow(
                          label: 'Rec:', 
                          value: BusinessConfig.instance.formatAmount(tendered),
                          alignment: MainAxisAlignment.end,
                          labelWidth: 40,
                        ),
                        if (change > 0)
                          _SummaryRow(
                            label: 'Back:', 
                            value: BusinessConfig.instance.formatAmount(change),
                            alignment: MainAxisAlignment.end,
                            labelWidth: 40,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
                      
                      if (discount > 0) ...[
                        const SizedBox(height: 12),
                        const _DottedLine(),
                        const SizedBox(height: 12),
                        Text(
                          'You Saved: ${BusinessConfig.instance.formatAmount(discount)}',
                          style: TextStyle(color: theme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        const _DottedLine(),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        decoration: BoxDecoration(
                          color: theme.muted,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.divider),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _receiptFooter.isNotEmpty
                                  ? _receiptFooter
                                  : '*** Thanks For Your Kind Visit ***',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Powered by Khalid Shinwari',
                              style: TextStyle(
                                color: theme.textHint,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
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

class _DashedLine extends StatelessWidget {
  const _DashedLine();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Row(
      children: List.generate(80, (i) => Expanded(
        child: Container(
          height: 1,
          color: i.isEven ? theme.divider : Colors.transparent,
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
    final theme = ThemeProvider.instance;
    return Row(
      children: List.generate(120, (i) => Expanded(
        child: Container(
          height: 1.2,
          color: i.isEven ? theme.divider : Colors.transparent,
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
  final MainAxisAlignment alignment;
  final double labelWidth;

  const _SummaryRow({
    required this.label, 
    required this.value, 
    this.isBold = false, 
    this.fontSize = 12,
    this.alignment = MainAxisAlignment.end,
    this.labelWidth = 80,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: alignment,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label,
                style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: fontSize,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: alignment == MainAxisAlignment.start
                  ? TextAlign.left
                  : TextAlign.right,
              style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
