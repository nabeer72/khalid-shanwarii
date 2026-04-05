import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/models/credit_sale.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:intl/intl.dart';

class CustomerCreditSalesScreen extends StatefulWidget {
  final Customer customer;

  const CustomerCreditSalesScreen({super.key, required this.customer});

  @override
  State<CustomerCreditSalesScreen> createState() => _CustomerCreditSalesScreenState();
}

class _CustomerCreditSalesScreenState extends State<CustomerCreditSalesScreen> {
  final theme = ThemeProvider.instance;
  List<CreditSale> _creditSales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCreditSales();
  }

  Future<void> _loadCreditSales() async {
    setState(() => _loading = true);
    try {
      final data = await DatabaseHelper.instance.getCreditSales(customerId: widget.customer.id);
      if (mounted) {
        setState(() {
          _creditSales = data.map((c) => CreditSale.fromMap(c)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading credit sales: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Credit Transactions',
              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              widget.customer.name,
              style: TextStyle(color: theme.highlight, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        leading: BackButton(color: theme.textPrimary),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: theme.highlight))
              : _creditSales.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 64, color: theme.whiteAlpha(0.2)),
                          const SizedBox(height: 16),
                          Text('No credit transactions found', style: TextStyle(color: theme.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _creditSales.length,
                      itemBuilder: (context, index) {
                        final sale = _creditSales[index];
                        return _CreditSaleCard(sale: sale);
                      },
                    ),
        ),
      ),
    );
  }
}

class _CreditSaleCard extends StatelessWidget {
  final CreditSale sale;

  const _CreditSaleCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final date = sale.createdAt != null ? DateFormat('MMM dd, yyyy HH:mm').format(sale.createdAt!) : 'Unknown Date';
    final isCleared = sale.remainingBalance <= 0.01;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: theme.glassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BILL #${sale.saleId}',
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: TextStyle(color: theme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCleared ? ThemeProvider.success.withOpacity(0.1) : ThemeProvider.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isCleared ? 'CLEARED' : 'OUTSTANDING',
                  style: TextStyle(
                    color: isCleared ? ThemeProvider.success : ThemeProvider.warning,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ORIGINAL AMOUNT', style: TextStyle(color: theme.textHint, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      '${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(sale.amount)}',
                      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('REMAINING BALANCE', style: TextStyle(color: theme.textHint, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      '${BusinessConfig.instance.currencyDisplay} ${BusinessConfig.instance.formatAmount(sale.remainingBalance)}',
                      style: TextStyle(
                        color: isCleared ? theme.textSecondary : ThemeProvider.error,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
