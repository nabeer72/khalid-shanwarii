import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_app/controllers/deals_controller.dart';
import 'package:mobile_app/screens/create_deal_screen.dart';
import 'package:mobile_app/providers/theme_provider.dart';

class DealsListScreen extends StatelessWidget {
  const DealsListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DealsController(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Deals'),
        ),
        body: Consumer<DealsController>(
          builder: (context, controller, child) {
            if (controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.deals.isEmpty) {
              return const Center(
                child: Text('No deals found. Create a new one!'),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: controller.deals.length,
              itemBuilder: (context, index) {
                final deal = controller.deals[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    title: Text(deal.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Deal Price: ${deal.dealPrice.toStringAsFixed(2)}\nStatus: ${deal.status == 1 ? 'Active' : 'Inactive'}'
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: deal.status == 1,
                          activeColor: ThemeProvider.instance.primary,
                          onChanged: (val) {
                            controller.toggleStatus(deal);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CreateDealScreen(deal: deal)),
                            );
                            if (result == true) {
                              controller.loadDeals();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Deal'),
                                content: const Text('Are you sure you want to delete this deal?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                ],
                              )
                            );
                            if (confirm == true) {
                              controller.deleteDeal(deal.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton(
            backgroundColor: ThemeProvider.instance.primary,
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateDealScreen()),
              );
              if (result == true) {
                ctx.read<DealsController>().loadDeals();
              }
            },
          ),
        ),
      ),
    );
  }
}
