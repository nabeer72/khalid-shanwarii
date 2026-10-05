import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_app/screens/login_screen.dart';
import 'package:mobile_app/screens/onboarding_screen.dart';
import 'package:mobile_app/screens/pos_screen.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:shake/shake.dart';
import 'package:mobile_app/db/db_init.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:window_manager/window_manager.dart';

// Global navigator key to allow navigation from anywhere (like a shake event)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    await windowManager.maximize();
  }

  // Initialize database and app settings before deciding the launch route.
  try {
    await initializeDatabase();
    await DatabaseHelper.instance.loadSettings();
  } catch (_) {
    // Keep the app usable even if settings cannot be loaded yet.
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ShakeDetector detector;

  @override
  void initState() {
    super.initState();

    // Initialize shake detector only on mobile platforms
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      detector = ShakeDetector.autoStart(
        onPhoneShake: (event) {
          // Only allow shake navigation if authenticated AND not on Login Screen
          if (LoginScreen.isActive) return;

          final isAuth = BusinessConfig.instance.userId != null ||
              BusinessConfig.instance.staffId != null;
          if (!isAuth) return;

          // Navigate to POS screen ONLY if not already there
          if (!POSScreen.isActive) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (context) => const POSScreen()),
            );
          }
        },
        shakeThresholdGravity: 2.5,
      );
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      detector.stopListening();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider.instance,
      builder: (context, child) {
        final theme = ThemeProvider.instance;
        return MaterialApp(
          navigatorKey: navigatorKey, // Assign the global navigator key
          title: 'Khalid Shinwari',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFB8860B),
              brightness: theme.isDark ? Brightness.dark : Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: theme.background,
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: theme.isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.divider, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.divider, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.highlight, width: 1.5),
              ),
              hintStyle: TextStyle(color: theme.textHint),
              labelStyle: TextStyle(color: theme.textSecondary),
            ),
            searchBarTheme: SearchBarThemeData(
              elevation: const WidgetStatePropertyAll(0),
              shadowColor: const WidgetStatePropertyAll(Colors.transparent),
              surfaceTintColor: WidgetStatePropertyAll(
                  theme.isDark ? Colors.transparent : Colors.white),
              backgroundColor: WidgetStatePropertyAll(
                theme.isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF8FAFC),
              ),
              side: WidgetStatePropertyAll(
                BorderSide(color: theme.divider, width: 1),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              elevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              highlightElevation: 0,
            ),
            cardTheme: const CardThemeData(
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              scrolledUnderElevation: 0,
              shadowColor: Colors.transparent,
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              elevation: 0,
              modalElevation: 0,
              shadowColor: Colors.transparent,
            ),
            popupMenuTheme: const PopupMenuThemeData(elevation: 0),
            drawerTheme: const DrawerThemeData(
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            dialogTheme: DialogThemeData(
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          home: BusinessConfig.instance.hasSeenOnboarding
              ? const LoginScreen()
              : const OnboardingScreen(),
        );
      },
    );
  }
}
