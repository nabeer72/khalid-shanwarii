import 'package:flutter/material.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/pos_screen.dart';
import 'package:mobile_app/screens/pos_screen.dart';

// Held orders storage
class HeldOrdersStore {
  static final HeldOrdersStore instance = HeldOrdersStore._();
  HeldOrdersStore._();
  
  final List<HeldOrder> orders = [];
}

class HeldOrder {
  final int id;
  final String name;
  final List<Map<String, dynamic>> items;
  final double total;
  final Customer? customer;
  final DateTime createdAt;

  HeldOrder({required this.id, required this.name, required this.items, required this.total, this.customer, required this.createdAt});
}

class HeldOrdersScreen extends StatefulWidget {
  const HeldOrdersScreen({super.key});

  @override
  State<HeldOrdersScreen> createState() => _HeldOrdersScreenState();
}

class _HeldOrdersScreenState extends State<HeldOrdersScreen> {
  final theme = ThemeProvider.instance;

  @override
  Widget build(BuildContext context) {
    final orders = HeldOrdersStore.instance.orders;

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
          child: orders.isEmpty
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
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
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

  void _resumeOrder(HeldOrder order) {
    HeldOrdersStore.instance.orders.remove(order);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => POSScreen(resumeOrder: order)));
  }

  void _deleteOrder(HeldOrder order) {
    showDialog(
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
                      onPressed: () => Navigator.pop(ctx),
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
                      onPressed: () {
                        HeldOrdersStore.instance.orders.remove(order);
                        Navigator.pop(ctx);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order deleted'), backgroundColor: ThemeProvider.error));
                      },
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
                order.items.map((i) => '${i['quantity']}x ${i['name']}').join(', '),
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
void holdOrder(String name, List<Map<String, dynamic>> items, double total, Customer? customer) {
  HeldOrdersStore.instance.orders.add(HeldOrder(
    id: DateTime.now().millisecondsSinceEpoch,
    name: name,
    items: List.from(items),
    total: total,
    customer: customer,
    createdAt: DateTime.now(),
  ));
}
