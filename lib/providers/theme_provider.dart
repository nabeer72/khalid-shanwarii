import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider instance = ThemeProvider._();
  ThemeProvider._();

  // Typography scale (mobile POS guideline)
  static const double fontBody   = 16;  // Main body / paragraph
  static const double fontList   = 15;  // List items, menus
  static const double fontTable  = 14;  // Dense data, table cells
  static const double fontButton = 15;  // Buttons & primary labels
  static const double fontCaption = 13; // Secondary / helper text
  static const double fontTitle  = 20;  // Section / window titles
  static const double fontLabel  = 14;  // Form field labels
  static const double fontSmall  = 12;  // Tooltips, badges

  // Border Radius standards
  static const double radiusList = 8;
  static const double radiusCard = 8;
  static const double radiusInput = 8;
  static const double radiusGlass = 8;

  bool _isDark = true;
  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  // Premium Dark theme colors
  static const darkBackground = Color(0xFF0F0F1E);
  static const darkSurface = Color(0xFF1A1A2E);
  static const darkCard = Color(0xFF16213E);
  static const darkPrimary = Color(0xFF0F3460);
  static const darkAccent = Color(0xFF533483);
  static const darkHighlight = Color(0xFFE94560);

  // Premium Light theme colors
  static const lightBackground = Color(0xFFF8F9FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightPrimary = Color(0xFF1A73E8);
  static const lightAccent = Color(0xFF4285F4);
  static const lightHighlight = Color(0xFFEA4335);

  // Status colors
  static const success = Color(0xFF00D26A);
  static const warning = Color(0xFFFFB800);
  static const error = Color(0xFFFF4757);
  static const info = Color(0xFF3498DB);

  // Gradient presets
  static const gradientPrimary = [Color(0xFF667eea), Color(0xFF764ba2)];
  static const gradientSuccess = [Color(0xFF11998e), Color(0xFF38ef7d)];
  static const gradientWarning = [Color(0xFFF7971E), Color(0xFFFFD200)];
  static const gradientDanger = [Color(0xFFeb3349), Color(0xFFf45c43)];
  static const gradientPurple = [Color(0xFF6441A5), Color(0xFF2a0845)];
  static const gradientOcean = [Color(0xFF2193b0), Color(0xFF6dd5ed)];

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
  Color get primary => _isDark ? darkPrimary : lightPrimary;
  Color get accent => _isDark ? darkAccent : lightAccent;
  Color get highlight => _isDark ? darkHighlight : lightHighlight;
  Color get textPrimary => _isDark ? Colors.white : const Color(0xFF1F2937);
  Color get textSecondary => _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  Color get textHint => _isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF);
  Color get divider => _isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
  Color get secondary => _isDark ? const Color(0xFF16213E) : const Color(0xFF1565C0);
  Color get cardBorder => _isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04);
  Color get iconColor => _isDark ? Colors.white : Colors.black;

  // Responsive UI Helpers
  static bool isWideScreen(BuildContext context) => MediaQuery.of(context).size.width > 600;

  // Glassmorphism effect
  BoxDecoration get glassDecoration => BoxDecoration(
    color: (_isDark ? Colors.white : Colors.white).withOpacity(_isDark ? 0.05 : 0.15),
    borderRadius: BorderRadius.circular(radiusGlass),
    border: Border.all(color: (_isDark ? Colors.white : Colors.white).withOpacity(_isDark ? 0.1 : 0.2), width: 1.5),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(_isDark ? 0.3 : 0.05),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );

  BoxDecoration get glassCircleDecoration => BoxDecoration(
    color: (_isDark ? Colors.white : Colors.white).withOpacity(_isDark ? 0.05 : 0.15),
    shape: BoxShape.circle,
    border: Border.all(color: (_isDark ? Colors.white : Colors.white).withOpacity(_isDark ? 0.1 : 0.2), width: 1.5),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(_isDark ? 0.3 : 0.05),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );

  // Background Gradients
  List<Color> get bgGradient => _isDark 
    ? [darkBackground, darkSurface] 
    : [const Color(0xFFE0F2F1), const Color(0xFFE3F2FD)];

  // Input Field Glass style
  InputDecoration glassInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563)),
      prefixIcon: Icon(icon, color: iconColor),
      filled: true,
      fillColor: (_isDark ? Colors.white : Colors.white).withOpacity(_isDark ? 0.08 : 0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusInput),
        borderSide: BorderSide(color: _isDark ? Colors.transparent : Colors.black.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusInput),
        borderSide: BorderSide(color: _isDark ? Colors.transparent : Colors.black.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusInput),
        borderSide: BorderSide(color: _isDark ? highlight : Colors.black.withOpacity(0.3), width: 1.5),
      ),
    );
  }

  // Global background wrapper
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

  // Helper for white with opacity
  Color whiteAlpha(double opacity) => Colors.white.withOpacity(opacity);
}
