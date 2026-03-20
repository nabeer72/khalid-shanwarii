import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/pos_controller.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/providers/theme_provider.dart';

class POSCategorySelector extends StatelessWidget {
  final POSController controller;

  const POSCategorySelector({super.key, required this.controller});

  String _getCategoryEmoji(String? icon) {
    switch (icon) {
      case 'devices': return '📱';
      case 'headphones': return '🎧';
      case 'cable': return '🔌';
      default: return '📦';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final categories = [
      ProductCategory(id: -1, name: 'Favorites', icon: '⭐', businessId: 0),
      ProductCategory(id: -2, name: 'Recent', icon: '🕐', businessId: 0),
      ProductCategory(id: 0, name: 'All Items', icon: '📝', businessId: 0),
      ...controller.categories.where((c) => c.parentId == null),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 8,
        runSpacing: 8,
        children: categories.map((cat) {
          final catIdStr = cat.id == -1 ? 'favorites' : (cat.id == -2 ? 'recent' : (cat.id == 0 ? 'all' : cat.id.toString()));
          final isSelected = controller.selectedCategory == catIdStr;
          
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => controller.setCategory(catIdStr),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: theme.glassDecoration.copyWith(
                  color: isSelected
                      ? theme.highlight
                      : (theme.isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.white.withOpacity(0.4)),
                  border: Border.all(
                      color: isSelected
                          ? theme.highlight
                          : theme.cardBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        cat.id == -1 || cat.id == -2 || cat.id == 0
                            ? cat.icon!
                            : _getCategoryEmoji(cat.icon),
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Text(
                      cat.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : theme.textPrimary,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
