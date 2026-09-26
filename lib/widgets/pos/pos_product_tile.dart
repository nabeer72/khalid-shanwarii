import 'package:flutter/material.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/controllers/pos_controller.dart';

class POSProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final POSController controller;
  final VoidCallback? onWeightTap;

  const POSProductTile({
    super.key,
    required this.product,
    required this.onTap,
    required this.onLongPress,
    required this.controller,
    this.onWeightTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onWeightTap ?? onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: theme.elevatedTileDecoration.copyWith(
            border: Border.all(
              color: product.isFavorite
                  ? ThemeProvider.warning.withOpacity(0.6)
                  : theme.cardBorder,
              width: product.isFavorite ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon and Stock / Favorite badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration:
                        theme.glassCircleDecoration(color: theme.highlight),
                    child: Center(
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: theme.highlight,
                        size: 18,
                      ),
                    ),
                  ),
                  if (product.isFavorite)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: theme.badgeDecoration(ThemeProvider.warning),
                      child: Icon(Icons.star_rounded,
                          color: ThemeProvider.warning, size: 14),
                    )
                  else if (!controller.isNoStockProduct(product))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration:
                          theme.badgeDecoration(theme.highlight, hollow: true),
                      child: Text(
                        '${product.totalStock - controller.getProductQuantityInCart(product.id)}',
                        style: TextStyle(
                            color: theme.highlight,
                            fontSize: 10,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              // Bottom Row: Details
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.highlight.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(ThemeProvider.radiusList),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (product.stocks.length > 1)
                        Text(
                          'Multiple Prices',
                          style: TextStyle(
                              color: theme.highlight,
                              fontSize: 11,
                              fontWeight: FontWeight.w800),
                        )
                      else
                        Text(
                          product.priceRange,
                          style: TextStyle(
                              color: theme.highlight,
                              fontSize: 12,
                              fontWeight: FontWeight.w900),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
