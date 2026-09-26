import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/pos_controller.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/widgets/empty_state_icon.dart';
import 'package:mobile_app/widgets/pos/pos_product_tile.dart';
import 'package:mobile_app/models/deal.dart';

class POSProductGrid extends StatelessWidget {
  final POSController controller;
  final Function(Product) onProductTap;
  final Function(Deal)? onDealTap;

  const POSProductGrid({
    super.key,
    required this.controller,
    required this.onProductTap,
    this.onDealTap,
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
    final int itemCount = controller.selectedCategory == 'deals'
        ? controller.deals.length
        : _getItemCount(filteredProducts);

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
    } else if (controller.selectedCategory != 'top_selling' &&
        controller.selectedCategory != 'recent' &&
        controller.selectedCategory != 'all') {
      final subCats = controller.subCategories.where((c) {
        if (c.parentId?.toString() != controller.selectedCategory) return false;
        final pCount = controller.products
            .where((p) => p.subCategoryId?.toString() == c.id.toString())
            .length;
        return pCount > 1;
      }).toList();
      count += subCats.length;
    }
    return count;
  }

  Widget _buildGridItem(BuildContext context, int index, List<Product> products,
      ThemeProvider theme) {
    if (controller.selectedCategory == 'deals') {
      return _buildDealTile(context, controller.deals[index], theme);
    }
    // 1. Back button
    if (controller.selectedSubCategoryId != null) {
      if (index == 0) {
        return _buildBackTile(theme);
      }
      index -= 1;
    }

    // 2. Subcategories
    if (controller.selectedSubCategoryId == null &&
        controller.selectedCategory != 'top_selling' &&
        controller.selectedCategory != 'recent' &&
        controller.selectedCategory != 'all') {
      final subCats = controller.subCategories.where((c) {
        if (c.parentId?.toString() != controller.selectedCategory) return false;
        final pCount = controller.products
            .where((p) => p.subCategoryId?.toString() == c.id.toString())
            .length;
        return pCount > 1;
      }).toList();
      if (index < subCats.length) {
        return _buildSubCategoryTile(subCats[index], theme);
      }
      index -= subCats.length;
    }

    // 3. Product Tile
    final p = products[index];
    return POSProductTile(
      product: p,
      controller: controller,
      onTap: () => onProductTap(p),
      onLongPress: () {
        // Toggle favorite logic could move to controller
        // For now, assume it's handled via product repository or similar
      },
    );
  }

  Widget _buildDealTile(BuildContext context, Deal deal, ThemeProvider theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onDealTap?.call(deal),
        borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
        child: Container(
          decoration: theme.elevatedTileDecoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: ThemeProvider.gradientGold,
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              flex: 3,
                              fit: FlexFit.loose,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.25)),
                                  ),
                                  child: const Text('🎁',
                                      style: TextStyle(fontSize: 22)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Flexible(
                              flex: 2,
                              fit: FlexFit.loose,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(
                                        ThemeProvider.radiusPill),
                                  ),
                                  child: Text('DEAL',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    color: theme.card,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            deal.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Flexible(
                          fit: FlexFit.loose,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.highlight.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                    ThemeProvider.radiusList),
                              ),
                              child: Text(
                                '${BusinessConfig.instance.currencyDisplay} ${deal.dealPrice.toStringAsFixed(2)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.highlight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackTile(ThemeProvider theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => controller.setSubCategory(null),
        borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: theme.elevatedTileDecoration,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                flex: 3,
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration:
                        theme.glassCircleDecoration(color: theme.highlight),
                    child: Icon(Icons.arrow_back_rounded,
                        color: theme.highlight, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                flex: 2,
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('BACK',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubCategoryTile(ProductCategory cat, ThemeProvider theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => controller.setSubCategory(cat.id),
        borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: theme.elevatedTileDecoration,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                flex: 3,
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration:
                          theme.glassCircleDecoration(color: theme.highlight),
                      child: const Text('📂', style: TextStyle(fontSize: 18))),
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                flex: 2,
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    cat.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          EmptyStateIcon(
            icon: controller.selectedCategory == 'top_selling'
                ? Icons.trending_up_rounded
                : Icons.inventory_2_rounded,
          ),
          const SizedBox(height: 20),
          Text(
              controller.selectedCategory == 'top_selling'
                  ? 'No sales yet'
                  : 'No products found',
              style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Try a different category or search',
              style: TextStyle(color: theme.textSecondary, fontSize: 13)),
        ]),
      ),
    );
  }
}
