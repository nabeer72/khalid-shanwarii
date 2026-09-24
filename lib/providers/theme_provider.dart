import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider instance = ThemeProvider._();
  ThemeProvider._();

  // Typography scale (mobile POS guideline)
  static const double fontBody = 16;
  static const double fontList = 15;
  static const double fontTable = 14;
  static const double fontButton = 15;
  static const double fontCaption = 13;
  static const double fontTitle = 20;
  static const double fontLabel = 14;
  static const double fontSmall = 12;
  static const double fontHeadline = 26;
  static const double fontKpi = 28;

  // Border Radius standards
  static const double radiusList = 12;
  static const double radiusCard = 16;
  static const double radiusInput = 12;
  static const double radiusGlass = 16;
  static const double radiusPill = 999;
  static const double radiusDialog = 20;
  static const double radiusHero = 24;

  bool _isDark = false;
  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  // Premium Dark theme colors
  static const darkBackground = Color(0xFF050504);
  static const darkSurface = Color(0xFF151514);
  static const darkCard = Color(0xFF1E1E1C);
  static const darkPrimary = Color(0xFFB8860B);
  static const darkAccent = Color(0xFF996515);
  static const darkHighlight = Color(0xFFB8860B);
  static const darkMuted = Color(0xFF27272A);

  // Premium Light theme colors
  static const lightBackground = Color(0xFFF8FAFC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightPrimary = Color(0xFF8B6914);
  static const lightAccent = Color(0xFF996515);
  static const lightHighlight = Color(0xFF8B6914);
  static const lightMuted = Color(0xFFF1F5F9);

  // Status colors
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFDCFCE7);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0xFFFEF3C7);
  static const error = Color(0xFFEF4444);
  static const errorSoft = Color(0xFFFEE2E2);
  static const info = Color(0xFF2563EB);
  static const infoSoft = Color(0xFFDBEAFE);

  // Gradient presets
  static const gradientPrimary = [Color(0xFF6366F1), Color(0xFF8B5CF6)];
  static const gradientSuccess = [Color(0xFF10B981), Color(0xFF059669)];
  static const gradientWarning = [Color(0xFFF59E0B), Color(0xFFD97706)];
  static const gradientDanger = [Color(0xFFEF4444), Color(0xFFDC2626)];
  static const gradientPurple = [Color(0xFF8B5CF6), Color(0xFF6366F1)];
  static const gradientOcean = [Color(0xFF0EA5E9), Color(0xFF2563EB)];
  static const gradientInfo = [Color(0xFF2563EB), Color(0xFF0EA5E9)];
  static const gradientAmber = [Color(0xFFF59E0B), Color(0xFFB45309)];
  static const gradientRose = [Color(0xFFF43F5E), Color(0xFFE11D48)];
  static const gradientGold = [Color(0xFFE1A800), Color(0xFF8B6914)];

  // Business type colors
  static const Map<String, Color> businessColors = {
    'general': Color(0xFF1A73E8),
    'garments': Color(0xFFE91E63),
    'produce': Color(0xFF4CAF50),
    'restaurant': Color(0xFFFF5722),
    'electronics': Color(0xFF2196F3),
  };

  // Getters for current theme
  Color get background => _isDark ? darkBackground : lightBackground;
  Color get surface => _isDark ? darkSurface : lightSurface;
  Color get card => _isDark ? darkCard : lightCard;
  Color get muted => _isDark ? darkMuted : lightMuted;
  Color get primary => _isDark ? darkPrimary : lightPrimary;
  Color get accent => _isDark ? darkAccent : lightAccent;
  Color get highlight => _isDark ? darkHighlight : lightHighlight;
  Color get textPrimary =>
      _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get textSecondary =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get textHint =>
      _isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get divider =>
      _isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
  Color get secondary =>
      _isDark ? const Color(0xFF16213E) : const Color(0xFF1565C0);
  Color get cardBorder =>
      _isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06);
  Color get iconColor => highlight;
  Color get toggleActiveColor => _isDark ? success : const Color(0xFF02401E);
  Color get switchActiveColor => toggleActiveColor;

  // Layered shadows — light mode = soft/diffused; dark mode = subtle elevation
  List<BoxShadow> get cardShadow => _isDark
      ? const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x1E000000),
            blurRadius: 24,
            offset: Offset(0, 10),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ];

  List<BoxShadow> get tileShadow => _isDark
      ? const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 5),
            spreadRadius: -6,
          ),
        ];

  List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: highlight.withOpacity(_isDark ? 0.30 : 0.25),
          blurRadius: _isDark ? 14 : 18,
          offset: const Offset(0, 6),
          spreadRadius: _isDark ? 0 : -3,
        ),
      ];

  List<BoxShadow> get insetShadow => [
        BoxShadow(
          color: whiteAlpha(_isDark ? 0.04 : 0.08),
          blurRadius: 0,
          spreadRadius: 0,
          offset: const Offset(0, 1),
        ),
      ];

  // ---------- Decoration Helpers ----------

  // Elevated card: surface color + radius 16 + layered shadow + subtle border
  BoxDecoration get elevatedCardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radiusCard),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: cardShadow,
      );

  // Tile-style decoration for list rows (lighter shadow, radius 12)
  BoxDecoration get elevatedTileDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radiusList),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: tileShadow,
      );

  // Gradient-filled stat card
  BoxDecoration statCardDecoration(
    List<Color>? colors, {
    Color? borderColor,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    final gradientColors = colors ?? gradientPrimary;
    return BoxDecoration(
      gradient: LinearGradient(
        colors: gradientColors,
        begin: begin,
        end: end,
      ),
      borderRadius: BorderRadius.circular(radiusCard),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(0.12),
        width: 1.0,
      ),
      boxShadow: cardShadow,
    );
  }

  // Status badge
  BoxDecoration badgeDecoration(
    Color color, {
    bool hollow = false,
    double radius = radiusPill,
  }) {
    return BoxDecoration(
      color: hollow ? Colors.transparent : color.withOpacity(_isDark ? 0.25 : 0.12),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: hollow ? color : color.withOpacity(0.35), width: 1.2),
    );
  }

  // Glassmorphism-style card (kept for backwards compatibility; now elevated)
  BoxDecoration get glassDecoration => elevatedCardDecoration;

  // Glassmorphism list tile (kept for backwards compatibility; now tile elevation)
  BoxDecoration get glassListDecoration => elevatedTileDecoration;

  // Circle container with tinted background + border
  BoxDecoration glassCircleDecoration({Color? color, double? size}) {
    final c = color ?? highlight;
    return BoxDecoration(
      color: c.withOpacity(_isDark ? 0.18 : 0.10),
      shape: BoxShape.circle,
      border: Border.all(color: c.withOpacity(0.25), width: 1.0),
      boxShadow: [
        BoxShadow(
          color: c.withOpacity(_isDark ? 0.20 : 0.10),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  // Background gradients (light and dark mode)
  List<Color> get bgGradient => _isDark
      ? const [Color(0xFF08080A), Color(0xFF121210), Color(0xFF1A1A16)]
      : const [Color(0xFFEEF2F7), Color(0xFFFFFFFF), Color(0xFFF8FAFC)];

  // Background screen wrapper — gradient-filled
  Widget glassBackground({required Widget child}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bgGradient,
        ),
      ),
      child: child,
    );
  }

  // ---------- Input Field Style ----------

  InputDecoration glassInputDecoration(
    String label,
    IconData icon, {
    bool isRequired = false,
    Widget? suffixIcon,
    String? hintText,
  }) {
    final labelStyle = TextStyle(
      color: textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final fillColor = _isDark
        ? Colors.white.withOpacity(0.04)
        : const Color(0xFFF8FAFC);

    return InputDecoration(
      label: isRequired
          ? RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: label, style: labelStyle),
                  TextSpan(
                      text: ' *',
                      style: TextStyle(
                          color: error,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            )
          : Text(label, style: labelStyle),
      hintText: hintText,
      hintStyle: TextStyle(color: textHint, fontWeight: FontWeight.w400),
      prefixIcon: Icon(icon, color: iconColor, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor,
      isDense: false,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusInput),
        borderSide: BorderSide(color: divider, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusInput),
        borderSide: BorderSide(color: divider, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusInput),
        borderSide: BorderSide(color: highlight, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusInput),
        borderSide: BorderSide(color: error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusInput),
        borderSide: BorderSide(color: error, width: 2.0),
      ),
    );
  }

  // ---------- Button Style ----------

  ButtonStyle get primaryButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: highlight,
      foregroundColor: Colors.white,
      disabledBackgroundColor: highlight.withOpacity(0.45),
      disabledForegroundColor: Colors.white.withOpacity(0.8),
      elevation: 0,
      shadowColor: highlight,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      textStyle: TextStyle(
        fontSize: fontButton,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusInput),
      ),
    ).copyWith(
      elevation: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.hovered)) return 4;
        if (states.contains(MaterialState.pressed)) return 0;
        return 2;
      }),
      shadowColor: MaterialStateProperty.all(highlight),
    );
  }

  ButtonStyle primaryButtonStyleSmall({Color? bgColor}) {
    final c = bgColor ?? highlight;
    return ElevatedButton.styleFrom(
      backgroundColor: c,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      textStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusList),
      ),
    );
  }

  ButtonStyle secondaryButtonStyle({Color? borderColor}) {
    final c = borderColor ?? divider;
    return OutlinedButton.styleFrom(
      foregroundColor: textPrimary,
      backgroundColor: Colors.transparent,
      side: BorderSide(color: c, width: 1.2),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      textStyle: TextStyle(
        fontSize: fontButton,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusInput),
      ),
    );
  }

  ButtonStyle get dangerButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: error,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: TextStyle(
          fontSize: fontButton,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusInput),
        ),
      );

  // Responsive helper
  static bool isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width > 600;

  // Helper for contrast layer (white in dark, black in light)
  Color whiteAlpha(double opacity) => _isDark
      ? Colors.white.withOpacity(opacity)
      : Colors.black.withOpacity(opacity);
}
