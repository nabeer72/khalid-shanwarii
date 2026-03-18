import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/models/held_order.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/pos_screen.dart';
import 'package:mobile_app/db/mock_data.dart';

class HeldOrdersScreen extends StatefulWidget {
  const HeldOrdersScreen({super.key});

  @override
  State<HeldOrdersScreen> createState() => _HeldOrdersScreenState();
}

class _HeldOrdersScreenState extends State<HeldOrdersScreen> {
  final theme = ThemeProvider.instance;
  List<HeldOrder> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    final ordersData = await DatabaseHelper.instance.getHeldOrders();
    final List<HeldOrder> loadedOrders = [];
    
    for (var data in ordersData) {
      final items = await DatabaseHelper.instance.getHeldOrderItems(data['id']);
      Customer? customer;
      if (data['customer_id'] != null) {
        final cData = await DatabaseHelper.instance.getCustomer(data['customer_id']);
        if (cData != null) customer = Customer.fromMap(cData);
      }
      loadedOrders.add(HeldOrder.fromMap(data, childItems: items, customer: customer));
    }

    if (mounted) {
      setState(() {
        _orders = loadedOrders;
        _loading = false;
      });
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
          'Held Orders',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
        actions: [
          IconButton(
            icon: Icon(theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: theme.iconColor),
            onPressed: () => setState(() => theme.toggleTheme()),
          ),
        ],
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: _loading 
              ? Center(child: CircularProgressIndicator(color: theme.highlight))
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: theme.glassCircleDecoration,
                            child: Icon(Icons.pause_circle_outline_rounded, size: 60, color: theme.iconColor),
                          ),
                          const SizedBox(height: 24),
                          Text('No held orders', style: TextStyle(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text('Parked orders will appear here', style: TextStyle(color: theme.textSecondary, fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        return _HeldOrderTile(
                          order: order,
                          onResume: () => _resumeOrder(order),
                          onDelete: () => _deleteOrder(order),
                        );
                      },
                    ),
        ),
      ),
    );
  }

  Future<void> _resumeOrder(HeldOrder order) async {
    await DatabaseHelper.instance.deleteHeldOrder(order.id);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => POSScreen(resumeOrder: order)));
    }
  }

  Future<void> _deleteOrder(HeldOrder order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(24),
          decoration: theme.glassDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Delete Order?', style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text('This will permanently delete "${order.name}"', textAlign: TextAlign.center, style: TextStyle(color: theme.textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('CANCEL', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeProvider.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteHeldOrder(order.id);
      _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order deleted'), backgroundColor: ThemeProvider.error));
      }
    }
  }
}

class _HeldOrderTile extends StatelessWidget {
  final HeldOrder order;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  const _HeldOrderTile({required this.order, required this.onResume, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final elapsed = DateTime.now().difference(order.createdAt);
    final elapsedStr = elapsed.inMinutes < 60 
        ? '${elapsed.inMinutes}m ago'
        : '${elapsed.inHours}h ${elapsed.inMinutes % 60}m ago';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: theme.glassDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: onResume,
        title: Row(
          children: [
            Expanded(
              child: Text(order.name, 
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            Text(elapsedStr, 
                style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.items.map((i) => '${i['quantity']}x ${i['name'] ?? 'Item'}').join(', '),
                style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (order.customer != null)
                Text(
                  'Customer: ${order.customer!.name}',
                  style: TextStyle(color: theme.textHint, fontSize: 11, fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${BusinessConfig.instance.currency}. ${order.total.toStringAsFixed(2)}',
                  style: TextStyle(color: ThemeProvider.warning, fontWeight: FontWeight.w900, fontSize: 13),
                ),
                Text(
                  'PARKED',
                  style: TextStyle(color: theme.textHint, fontSize: 8, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: ThemeProvider.error.withOpacity(0.5), size: 18),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to hold an order from POS
Future<int> holdOrder(String name, List<Map<String, dynamic>> items, double total, Customer? customer) async {
  final orderData = {
    'name': name,
    'total': total,
    'customer_id': customer?.id,
  };
  return await DatabaseHelper.instance.insertHeldOrder(orderData, items);
}
