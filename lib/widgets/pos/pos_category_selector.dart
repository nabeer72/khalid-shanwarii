import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/pos_controller.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/providers/theme_provider.dart';

class POSCategorySelector extends StatelessWidget {
  final POSController controller;

  const POSCategorySelector({
    super.key,
    required this.controller,
  });

  String _getCategoryEmoji(String? icon) {
    switch (icon) {
      case 'devices':
        return '📱';
      case 'headphones':
        return '🎧';
      case 'cable':
        return '🔌';
      default:
        return '📦';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final categories = [
      ProductCategory(id: -3, name: 'Deals', icon: '🎁', businessId: 0),
      ProductCategory(id: -1, name: 'Top Selling', icon: '📈', businessId: 0),
      ProductCategory(id: -2, name: 'Recent', icon: '🕐', businessId: 0),
      ProductCategory(id: 0, name: 'All Items', icon: '📝', businessId: 0),
      ...controller.categories.where((c) => c.parentId == null),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 8,
            runSpacing: 8,
            children: [
              ...categories.map((cat) {
                final catIdStr = cat.id == -3
                    ? 'deals'
                    : (cat.id == -1
                        ? 'top_selling'
                        : (cat.id == -2
                            ? 'recent'
                            : (cat.id == 0 ? 'all' : cat.id.toString())));
                final isSelected = controller.selectedCategory == catIdStr;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => controller.setCategory(catIdStr),
                    borderRadius:
                        BorderRadius.circular(ThemeProvider.radiusPill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: isSelected
                          ? BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: ThemeProvider.gradientGold,
                              ),
                              borderRadius: BorderRadius.circular(
                                  ThemeProvider.radiusPill),
                              boxShadow: theme.cardShadow,
                              border: Border.all(
                                  color: theme.highlight.withOpacity(0.4)),
                            )
                          : BoxDecoration(
                              color: theme.card,
                              borderRadius: BorderRadius.circular(
                                  ThemeProvider.radiusPill),
                              border: Border.all(color: theme.cardBorder),
                              boxShadow: theme.tileShadow,
                            ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              cat.id == -3 ||
                                      cat.id == -1 ||
                                      cat.id == -2 ||
                                      cat.id == 0
                                  ? cat.icon!
                                  : _getCategoryEmoji(cat.icon),
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            cat.name,
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.white : theme.textPrimary,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),

          // Sub-categories row
          if (controller.selectedCategory != 'all' &&
              controller.selectedCategory != 'top_selling' &&
              controller.selectedCategory != 'recent' &&
              controller.selectedCategory != 'deals') ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  ...controller.subCategories
                      .where((sc) =>
                          sc.parentId.toString() == controller.selectedCategory)
                      .map((sc) {
                    final isSubSelected =
                        controller.selectedSubCategoryId?.toString() ==
                            sc.id.toString();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(ThemeProvider.radiusPill),
                          onTap: () => controller
                              .setSubCategory(isSubSelected ? null : sc.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: isSubSelected
                                ? theme.badgeDecoration(theme.highlight,
                                    hollow: true)
                                : BoxDecoration(
                                    color: theme.card,
                                    borderRadius: BorderRadius.circular(
                                        ThemeProvider.radiusPill),
                                    border: Border.all(color: theme.cardBorder),
                                  ),
                            child: Text(sc.name,
                                style: TextStyle(
                                  color: isSubSelected
                                      ? theme.highlight
                                      : theme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: isSubSelected
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                )),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
