import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:mobile_app/screens/setup_profile_screen.dart';
import 'package:mobile_app/screens/login_screen.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:provider/provider.dart';

class PaymentProcessingScreen extends StatefulWidget {
  const PaymentProcessingScreen({super.key});

  @override
  State<PaymentProcessingScreen> createState() => _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final ApiService _api = ApiService();
  Timer? _statusTimer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start polling
    _startPolling();
  }

  void _startPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkStatus();
    });
    // Initial check
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      final isActive = await _api.checkSubscriptionStatus();
      if (isActive && mounted) {
        _statusTimer?.cancel();
        // We need businessId and userId for SetupProfileScreen
        // Since we just registered, we can fetch the user data
        final response = await _api.get('/user');
        if (response.statusCode == 200) {
          final data = response.data;
          final userId = int.tryParse(data['id'].toString());
          final businessId = int.tryParse(data['business_id'].toString());
          
          if (userId != null && businessId != null) {
            BusinessConfig.instance.subscriptionStatus = 'active';
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const SetupProfileScreen()),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      print('Status check error: $e');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;

    return Scaffold(
      body: Stack(
        children: [
          // Premium Gradient Background
          theme.glassBackground(
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: theme.glassDecoration.copyWith(
                        color: theme.isDark 
                            ? theme.surface.withOpacity(0.4) 
                            : Colors.white.withOpacity(0.85),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pulse Icon
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [theme.highlight.withOpacity(0.2), theme.highlight.withOpacity(0.05)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(color: theme.highlight.withOpacity(0.5), width: 2),
                              ),
                              child: Icon(Icons.shield_outlined, color: theme.highlight, size: 40),
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Titles
                          Text(
                            'Verification Pending',
                            style: TextStyle(color: theme.textPrimary, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Your activation is in progress. The system will unlock automatically once our team verifies your payment receipt.',
                            style: TextStyle(color: theme.textSecondary, fontSize: 14, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          
                          // Status Monitor Box
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: theme.surface.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.divider),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.highlight),
                                ),
                                const SizedBox(width: 16),
                                Flexible(
                                  child: Text(
                                    'Monitoring account status...',
                                    style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          
                          // Action Buttons
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {}, // TODO: Implement support link
                              icon: const Icon(Icons.headset_mic_rounded, size: 20),
                              label: const Text('Contact Support Team'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.highlight,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 8,
                                shadowColor: theme.highlight.withOpacity(0.4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await _api.logout();
                                if (mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                                    (route) => false,
                                  );
                                }
                              },
                              icon: Icon(Icons.logout_rounded, size: 20, color: theme.textSecondary),
                              label: Text('Sign Out', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: theme.divider),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
