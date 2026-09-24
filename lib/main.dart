import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_app/screens/login_screen.dart';
import 'package:mobile_app/screens/onboarding_screen.dart';
import 'package:mobile_app/screens/pos_screen.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:shake/shake.dart';

// Conditional import for desktop SQLite
import 'package:mobile_app/db/db_init.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/services/sync_service.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:window_manager/window_manager.dart';

// Global navigator key to allow navigation from anywhere (like a shake event)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    await windowManager.maximize();
  }
  
  // Initialize database for non-web platforms
  if (!kIsWeb) {
    await initializeDatabase();
    await DatabaseHelper.instance.loadSettings();

    // Data Change listener for immediate sync (Online-First)
    DatabaseHelper.onDataChanged = () async {
      SyncService().triggerDebouncedSync();
    };
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

          final isAuth = BusinessConfig.instance.userId != null || BusinessConfig.instance.staffId != null;
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
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
