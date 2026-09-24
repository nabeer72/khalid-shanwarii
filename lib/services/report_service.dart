import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ReportService {
  static Future<void> generateShiftReport(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final activeShift = data['activeShift'] as Map?;
    final totals = data['totals'] as Map?;
    final businessName = data['businessName']?.toString() ?? 'Khalid Shinwari';
    final currency = data['currency']?.toString() ?? '\$';

    if (activeShift == null || totals == null) {
      throw Exception('Shift data or totals missing');
    }

    final openingCash = (activeShift['opening_cash'] as num? ?? 0).toDouble();
    final closingCashCounted = (activeShift['closing_cash'] as num? ?? 0).toDouble();
    
    final cashSales = (totals['cash_sales'] as num? ?? 0).toDouble();
    final mobileSales = (totals['mobile_sales'] as num? ?? 0).toDouble();
    final cardSales = (totals['card_sales'] as num? ?? 0).toDouble();
    final creditSalesTotal = (totals['credit_sales_total'] as num? ?? 0).toDouble();
    final creditReceived = (totals['credit_received'] as num? ?? 0).toDouble();
    final totalExpenses = (totals['total_expenses'] as num? ?? 0).toDouble();
    final totalPurchases = (totals['total_purchases'] as num? ?? 0).toDouble();
    
    final totalShiftRevenue = (cashSales + mobileSales + cardSales + creditSalesTotal);
    final totalCashExpected = (openingCash + cashSales + creditReceived);
    final discrepancy = closingCashCounted - totalCashExpected;

    final startTimeStr = activeShift['start_time'];
    final startTime = startTimeStr != null ? DateTime.parse(startTimeStr) : DateTime.now();
    final endTime = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd HH:mm');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(businessName.toUpperCase(), 
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(child: pw.Text('DETAILED SHIFT SUMMARY', style: pw.TextStyle(fontSize: 12))),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 0.5),
              pw.Text('Shift ID: ${activeShift['id'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Start Time: ${formatter.format(startTime)}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('End Time: ${formatter.format(endTime)}', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              _buildReportRow('Opening Cash (Clock-In)', '$currency. ${openingCash.toStringAsFixed(2)}'),
              pw.SizedBox(height: 15),
              pw.Text('PAYMENT BREAKDOWN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.5),
              _buildReportRow('Cash Sales', '$currency. ${cashSales.toStringAsFixed(2)}'),
              _buildReportRow('Mobile Transfer', '$currency. ${mobileSales.toStringAsFixed(2)}'),
              _buildReportRow('Card Payments', '$currency. ${cardSales.toStringAsFixed(2)}'),
              _buildReportRow('Credit Sales (Total)', '$currency. ${creditSalesTotal.toStringAsFixed(2)}'),
              _buildReportRow('Credit Received (Paid Now)', '$currency. ${creditReceived.toStringAsFixed(2)}'),
              _buildReportRow('Credit Outstanding', '$currency. ${(creditSalesTotal - creditReceived).toStringAsFixed(2)}', isBold: true),
              
              pw.SizedBox(height: 15),
              pw.Text('EXPENSES & PURCHASES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.5),
              _buildReportRow('Daily Expenses', '$currency. ${totalExpenses.toStringAsFixed(2)}'),
              _buildReportRow('Total Purchases', '$currency. ${totalPurchases.toStringAsFixed(2)}'),

              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.5),
              _buildReportRow('TOTAL SHIFT REVENUE', '$currency. ${totalShiftRevenue.toStringAsFixed(2)}', isBold: true),
              pw.SizedBox(height: 15),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.5),
                ),
                child: pw.Column(
                  children: [
                    _buildReportRow('Expected Cash in Drawer', '$currency. ${totalCashExpected.toStringAsFixed(2)}'),
                    _buildReportRow('Actual Cash Counted', '$currency. ${closingCashCounted.toStringAsFixed(2)}', isBold: true),
                    if (discrepancy != 0) ...[
                      pw.SizedBox(height: 5),
                      _buildReportRow(
                        discrepancy > 0 ? 'Surplus' : 'Shortage', 
                        '$currency. ${discrepancy.abs().toStringAsFixed(2)}',
                        isBold: true
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Center(child: pw.Text('Thank you for your business!', style: const pw.TextStyle(fontSize: 9))),
              pw.Center(child: pw.Text('Report Generated: ${formatter.format(DateTime.now())}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Shift_Report_${activeShift['id'] ?? 'unknown'}.pdf',
    );
  }

  static pw.Row _buildReportRow(String label, String value, {bool isBold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }
}
