import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/services/api_service.dart';
import 'setup_business_screen.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final theme = ThemeProvider.instance;
  final _phoneCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _api = ApiService();
  bool _loading = false;

  void _saveProfile() async {
    if (_phoneCtrl.text.isEmpty || _cnicCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields'), backgroundColor: ThemeProvider.error),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final userId = BusinessConfig.instance.userId;
      
      await DatabaseHelper.instance.updateUserFields(userId, {
        'phone': _phoneCtrl.text.trim(),
        'cnic': _cnicCtrl.text.trim(),
      });

      try {
        await _api.updateProfile({
          'phone': _phoneCtrl.text.trim(),
          'cell_number': _phoneCtrl.text.trim(),
          'cnic': _cnicCtrl.text.trim(),
          'cnic_number': _cnicCtrl.text.trim(), // Exact key for server
        });
      } catch (e) {
        print('⚠️ API profile update failed: $e');
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupBusinessScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: ThemeProvider.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Stack(
        children: [
          theme.glassBackground(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Premium Header
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: ThemeProvider.gradientOcean.map((c) => c.withOpacity(0.2)).toList(),
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(color: theme.highlight.withOpacity(0.3), width: 1.5),
                                ),
                                child: Icon(Icons.person_pin_rounded, size: 48, color: theme.highlight),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'PROFILE SETUP',
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Complete your account details',
                                style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Glass Card for Form
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: theme.glassDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ACCOUNT INFORMATION', 
                                style: TextStyle(
                                  color: theme.textSecondary, 
                                  fontSize: 12, 
                                  fontWeight: FontWeight.w800, 
                                  letterSpacing: 2.0
                                )),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w500),
                                decoration: theme.glassInputDecoration('Cell Number', Icons.phone_android_rounded),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _cnicCtrl,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w500),
                                decoration: theme.glassInputDecoration('CNIC Number', Icons.badge_rounded),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.highlight,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: theme.highlight.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                            ),
                            child: _loading 
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Text('CONTINUE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                                    SizedBox(width: 12),
                                    Icon(Icons.arrow_forward_rounded, size: 20),
                                  ],
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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
