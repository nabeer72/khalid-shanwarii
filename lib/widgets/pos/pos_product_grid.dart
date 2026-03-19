import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/pos_controller.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/widgets/pos/pos_product_tile.dart';

class POSProductGrid extends StatelessWidget {
  final POSController controller;
  final Function(Product) onProductTap;

  const POSProductGrid({
    super.key,
    required this.controller,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final screenWidth = MediaQuery.of(context).size.width;
    final gridColumns = screenWidth > 1400
        ? 8
        : (screenWidth > 1100
            ? 7
            : (screenWidth > 800 ? 6 : (screenWidth > 500 ? 4 : 3)));

    final filteredProducts = controller.filteredProducts;
    final int itemCount = _getItemCount(filteredProducts);

    if (itemCount == 0) {
      return _buildEmptyState(theme);
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridColumns,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: itemCount,
      itemBuilder: (ctx, i) {
        return _buildGridItem(ctx, i, filteredProducts, theme);
      },
    );
  }

  int _getItemCount(List<Product> products) {
    int count = products.length;
    if (controller.selectedSubCategoryId != null) {
      count += 1; // Back button
    } else if (controller.selectedCategory != 'favorites' && 
               controller.selectedCategory != 'recent' && 
               controller.selectedCategory != 'all') {
      final subCats = controller.categories.where((c) => 
          c.parentId?.toString() == controller.selectedCategory).toList();
      count += subCats.length;
    }
    return count;
  }

  Widget _buildGridItem(BuildContext context, int index, List<Product> products, ThemeProvider theme) {
    // 1. Back button
    if (controller.selectedSubCategoryId != null) {
      if (index == 0) {
        return _buildBackTile(theme);
      }
      index -= 1;
    }

    // 2. Subcategories
    if (controller.selectedSubCategoryId == null && 
        controller.selectedCategory != 'favorites' && 
        controller.selectedCategory != 'recent' && 
        controller.selectedCategory != 'all') {
      final subCats = controller.categories.where((c) => 
          c.parentId?.toString() == controller.selectedCategory).toList();
      if (index < subCats.length) {
        return _buildSubCategoryTile(subCats[index], theme);
      }
      index -= subCats.length;
    }

    // 3. Product Tile
    final p = products[index];
    return POSProductTile(
      product: p,
      onTap: () => onProductTap(p),
      onLongPress: () {
        // Toggle favorite logic could move to controller
        // For now, assume it's handled via product repository or similar
      },
    );
  }

  Widget _buildBackTile(ThemeProvider theme) {
    return InkWell(
      onTap: () => controller.setSubCategory(null),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: theme.glassDecoration.copyWith(
          color: theme.highlight.withOpacity(0.05),
          border: Border.all(color: theme.highlight.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.highlight.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back_rounded, color: theme.highlight, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              'BACK', 
              style: TextStyle(
                color: theme.highlight, 
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.5,
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategoryTile(ProductCategory cat, ThemeProvider theme) {
    return InkWell(
      onTap: () => controller.setSubCategory(cat.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: theme.glassDecoration.copyWith(
          color: theme.highlight.withOpacity(0.05),
          border: Border.all(color: theme.highlight.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.highlight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                ),
                child: Text('📂', style: const TextStyle(fontSize: 20))),
            const SizedBox(height: 8),
            Text(
              cat.name.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: theme.glassCircleDecoration,
              child: Text(
                  controller.selectedCategory == 'favorites' ? '⭐' : '📦',
                  style: const TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 16),
            Text(
                controller.selectedCategory == 'favorites'
                    ? 'No favorites yet'
                    : 'No products found',
                style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            Text('Try a different category or search',
                style: TextStyle(
                    color: theme.textSecondary, fontSize: 13)),
          ]),
    );
  }
}
