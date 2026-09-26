import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_app/controllers/deals_controller.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/deal.dart';
import 'package:mobile_app/screens/create_deal_screen.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/widgets/empty_state_icon.dart';

class DealsListScreen extends StatefulWidget {
  const DealsListScreen({super.key});

  @override
  State<DealsListScreen> createState() => _DealsListScreenState();
}

class _DealsListScreenState extends State<DealsListScreen> {
  final theme = ThemeProvider.instance;
  bool _isInactiveView = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildTabButton(String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isInactiveView = (label == 'Inactive')),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: active
              ? theme.badgeDecoration(theme.highlight, hollow: true)
              : BoxDecoration(
                  color: theme.card,
                  borderRadius:
                      BorderRadius.circular(ThemeProvider.radiusPill - 2),
                  border: Border.all(color: theme.cardBorder, width: 1.0),
                ),
          child: Center(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: active ? theme.highlight : theme.textSecondary,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleStatus(DealsController ctrl, Deal deal) async {
    await ctrl.toggleStatus(deal);
  }

  Future<void> _confirmDelete(DealsController ctrl, Deal deal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Delete Deal', style: TextStyle(color: theme.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${deal.name}"? This action cannot be undone.',
          style: TextStyle(color: theme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  Text('Cancel', style: TextStyle(color: theme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeProvider.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ctrl.deleteDeal(deal.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Deal deleted'),
              backgroundColor: ThemeProvider.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DealsController(),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: theme.textPrimary,
          elevation: 0,
          title: Text(
            'Manage Deals',
            style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5),
          ),
          leading: BackButton(color: theme.textPrimary),
        ),
        body: theme.glassBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: theme.card,
                          borderRadius:
                              BorderRadius.circular(ThemeProvider.radiusPill),
                          elevation: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.white,
                              borderRadius:
                                  BorderRadius.circular(ThemeProvider.radiusPill),
                              border: Border.all(color: theme.cardBorder, width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: TextFormField(
                                controller: _searchCtrl,
                                style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  icon: Icon(Icons.search_rounded,
                                      color: theme.highlight, size: 20),
                                  hintText: 'Search deals...',
                                  hintStyle: TextStyle(
                                      color: theme.textHint,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? GestureDetector(
                                          onTap: () {
                                            _searchCtrl.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                          child: Icon(Icons.cancel_rounded,
                                              color: theme.textHint, size: 18),
                                        )
                                      : null,
                                ),
                                onChanged: (val) =>
                                    setState(() => _searchQuery = val.trim()),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 50,
                        width: 160,
                        padding: const EdgeInsets.all(4),
                        decoration: theme.elevatedCardDecoration.copyWith(
                          borderRadius:
                              BorderRadius.circular(ThemeProvider.radiusPill),
                        ),
                        child: Row(
                          children: [
                            _buildTabButton('Active', !_isInactiveView),
                            _buildTabButton('Inactive', _isInactiveView),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Consumer<DealsController>(
              builder: (context, controller, child) {
                if (controller.isLoading) {
                  return Center(
                      child:
                          CircularProgressIndicator(color: theme.highlight));
                }

                final filtered = controller.deals.where((d) {
                  final matchesStatus =
                      _isInactiveView ? d.status == 0 : d.status == 1;
                  if (!matchesStatus) return false;
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  final name = d.name.toLowerCase();
                  final desc = (d.description ?? '').toLowerCase();
                  return name.contains(q) || desc.contains(q);
                }).toList()
                  ..sort((a, b) {
                    if (a.status != b.status) return b.status - a.status;
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  });

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            const EmptyStateIcon(icon: Icons.card_giftcard_rounded),
                          const SizedBox(height: 18),
                          Text(
                            _isInactiveView
                                ? 'No Inactive Deals'
                                : _searchQuery.isNotEmpty
                                    ? 'No Deals Found'
                                    : 'No Deals Yet!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isInactiveView
                                ? 'There are no deactivated deals yet.'
                                : _searchQuery.isNotEmpty
                                    ? 'Try a different search term.'
                                    : 'Tap the button below to create your first deal!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: theme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final deal = filtered[index];
                    final bool isActive = deal.status == 1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      CreateDealScreen(deal: deal)),
                            );
                            if (result == true) {
                              controller.loadDeals();
                            }
                          },
                          borderRadius: BorderRadius.circular(
                              ThemeProvider.radiusCard),
                          child: Container(
                            decoration: theme.elevatedTileDecoration.copyWith(
                              border: !isActive
                                  ? Border.all(
                                      color: ThemeProvider.error
                                          .withOpacity(0.4),
                                      width: 1.5)
                                  : null,
                            ),
                            child: Opacity(
                              opacity: isActive ? 1.0 : 0.88,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: theme.glassCircleDecoration(
                                          color: theme.highlight),
                                      padding: const EdgeInsets.all(10),
                                      child: Icon(
                                          Icons.card_giftcard_rounded,
                                          color: theme.highlight,
                                          size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            deal.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: theme.textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              decoration: !isActive
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          if ((deal.description ?? '')
                                              .isNotEmpty)
                                            Text(
                                              deal.description!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: theme.textSecondary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${BusinessConfig.instance.currencyDisplay} ${deal.dealPrice.toStringAsFixed(2)}',
                                          style: TextStyle(
                                              color: theme.highlight,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13),
                                        ),
                                        Text(
                                          'DEAL PRICE',
                                          style: TextStyle(
                                              color: theme.textHint,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(Icons.edit_note_rounded,
                                          color: theme.highlight, size: 20),
                                      onPressed: () async {
                                        final result =
                                            await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => CreateDealScreen(
                                                  deal: deal)),
                                        );
                                        if (result == true) {
                                          controller.loadDeals();
                                        }
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints(
                                              minWidth: 36, minHeight: 36),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Switch.adaptive(
                                      value: isActive,
                                      activeColor: theme.toggleActiveColor,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (_) =>
                                          _toggleStatus(controller, deal),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline_rounded,
                                          color: ThemeProvider.error, size: 20),
                                      onPressed: () =>
                                          _confirmDelete(controller, deal),
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints(
                                              minWidth: 36, minHeight: 36),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          ],
        ),
      ),
    ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton.extended(
            backgroundColor: theme.primary,
            elevation: 6,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'NEW DEAL',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1),
            ),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateDealScreen()),
              );
              if (result == true) {
                if (context.mounted) {
                  ctx.read<DealsController>().loadDeals();
                }
              }
            },
          ),
        ),
      ),
    );
  }
}
