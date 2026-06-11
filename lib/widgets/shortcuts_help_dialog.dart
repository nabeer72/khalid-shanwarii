import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/database_helper.dart';

class ShortcutsHelpDialog {
  static Future<void> show(BuildContext context) async {
    // Mark as seen
    await DatabaseHelper.instance.setSetting('has_seen_shortcuts', '1');

    final theme = ThemeProvider.instance;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          width: 520,
          constraints: const BoxConstraints(maxHeight: 620),
          decoration: theme.glassDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(ThemeProvider.radiusCard)),
                  border: Border(
                    bottom: BorderSide(color: theme.divider, width: 1.0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.keyboard_rounded,
                          color: theme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Keyboard Shortcuts',
                              style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3)),
                          const SizedBox(height: 2),
                          Text('Master your POS with speed ⚡',
                              style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded,
                          color: theme.textSecondary, size: 20),
                    ),
                  ],
                ),
              ),

              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sectionTitle('POS Screen', Icons.point_of_sale_rounded,
                          theme.primary, theme),
                      const SizedBox(height: 8),
                      _shortcutTile('F1', 'Clear Cart',
                          Icons.remove_shopping_cart_rounded, theme),
                      _shortcutTile('F2', 'Add / Select Customer',
                          Icons.person_add_rounded, theme),
                      _shortcutTile('F3', 'Toggle Return Mode',
                          Icons.swap_horiz_rounded, theme),
                      _shortcutTile('F4', 'Quick Add Product',
                          Icons.add_box_rounded, theme),
                      _shortcutTile('F5', 'Toggle Discount Editor',
                          Icons.discount_rounded, theme),
                      _shortcutTile('F6', 'View All History',
                          Icons.receipt_long_rounded, theme),
                      _shortcutTile(
                          'F7', 'Switch Theme', Icons.palette_rounded, theme),
                      _shortcutTile(
                          'ESC', 'Exit POS', Icons.exit_to_app_rounded, theme),
                      _shortcutTile('Enter', 'Search / Go to Payment',
                          Icons.search_rounded, theme),
                      _shortcutTile('↑ ↓', 'Change Quantity',
                          Icons.exposure_rounded, theme),
                      const SizedBox(height: 16),
                      _sectionTitle('Payment Screen', Icons.payment_rounded,
                          theme.accent, theme),
                      const SizedBox(height: 8),
                      _shortcutTile('Enter', 'Complete Transaction',
                          Icons.check_circle_rounded, theme),
                      _shortcutTile('F8', 'Exact Total',
                          Icons.price_check_rounded, theme),
                      _shortcutTile(
                          'F9', 'Toggle Receipt', Icons.receipt_rounded, theme),
                      _shortcutTile(
                          'F10', 'Cash Drawer', Icons.point_of_sale, theme),
                      _shortcutTile('← → ↑ ↓', 'Switch Payment Method',
                          Icons.swap_horizontal_circle_rounded, theme),
                      _shortcutTile(
                          'ESC', 'Go Back', Icons.arrow_back_rounded, theme),
                      const SizedBox(height: 16),
                      _sectionTitle('Receipt Screen',
                          Icons.receipt_long_rounded, theme.highlight, theme),
                      const SizedBox(height: 8),
                      _shortcutTile('ESC', 'Back to POS',
                          Icons.arrow_back_rounded, theme),
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

  static Widget _sectionTitle(
      String title, IconData icon, Color color, ThemeProvider theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: theme.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  static Widget _shortcutTile(
      String key, String description, IconData icon, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.divider, width: 1.0),
            ),
            child: Text(
              key,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: theme.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 16, color: theme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Blinking Shortcut Help Icon ──────────────────────────────────────

class ShortcutHelpIcon extends StatefulWidget {
  const ShortcutHelpIcon({super.key});

  @override
  State<ShortcutHelpIcon> createState() => _ShortcutHelpIconState();
}

class _ShortcutHelpIconState extends State<ShortcutHelpIcon>
    with SingleTickerProviderStateMixin {
  bool _hasSeenShortcuts = true; // default: no blink until loaded
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  final theme = ThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _loadSeenStatus();
  }

  Future<void> _loadSeenStatus() async {
    final seen = await DatabaseHelper.instance.getSetting('has_seen_shortcuts');
    if (mounted) {
      setState(() {
        _hasSeenShortcuts = seen == '1';
      });
      if (!_hasSeenShortcuts) {
        _blinkController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  void _openDialog() {
    ShortcutsHelpDialog.show(context);
    if (!_hasSeenShortcuts) {
      _blinkController.stop();
      _blinkController.value = 1.0;
      setState(() => _hasSeenShortcuts = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: theme.glassCircleDecoration,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _blinkAnimation,
            builder: (context, child) {
              return IconButton(
                icon: Icon(
                  Icons.keyboard_command_key_rounded,
                  color: _hasSeenShortcuts
                      ? (theme.isDark ? Colors.white : Colors.black)
                      : Color.lerp(
                          const Color(0xFF667eea),
                          const Color(0xFFE94560),
                          _blinkAnimation.value,
                        ),
                  size: 20,
                ),
                tooltip: 'Keyboard Shortcuts',
                onPressed: _openDialog,
              );
            },
          ),
          // Notification dot when not seen
          if (!_hasSeenShortcuts)
            Positioned(
              top: 6,
              right: 6,
              child: AnimatedBuilder(
                animation: _blinkAnimation,
                builder: (context, _) => Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE94560)
                        .withOpacity(_blinkAnimation.value),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE94560)
                            .withOpacity(_blinkAnimation.value * 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
