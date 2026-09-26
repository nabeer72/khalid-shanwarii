import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';

class EmptyStateIcon extends StatelessWidget {
  const EmptyStateIcon({
    super.key,
    required this.icon,
    this.size = 60,
    this.padding = 32,
  });

  final IconData icon;
  final double size;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: theme.glassCircleDecoration(),
      child: Icon(icon, size: size, color: theme.iconColor),
    );
  }
}