import 'package:flutter/material.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: product.isFavorite
                  ? ThemeProvider.warning.withOpacity(0.5)
                  : theme.cardBorder,
              width: product.isFavorite ? 1.2 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(theme.isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Emoji and Stock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.highlight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: theme.primary,
                        size: 18,
                      ),
                    ),
                  ),
                  if (product.isFavorite)
                    Icon(Icons.star_rounded,
                        color: ThemeProvider.warning, size: 14)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.highlight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text(
                      product.priceRange,
                      style: TextStyle(
                          color: theme.highlight,
                          fontSize: 12,
                          fontWeight: FontWeight.w900),
                    ),
                    if (product.stocks.length > 1) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${product.stocks.length} batches',
                        style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
