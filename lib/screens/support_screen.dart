import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  final String _email = 'example@gmail.com';
  final String _mobile = '03********5';

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Customer Support'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.textPrimary,
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.highlight.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.highlight.withOpacity(0.3), width: 2),
                          ),
                          child: Icon(Icons.support_agent_rounded, size: 64, color: theme.highlight),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Need Help?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: theme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Contact our support team for any assistance or inquiries.',
                        style: TextStyle(fontSize: 14, color: theme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 32),
                      
                      // Email Card
                      _buildContactCard(
                        context,
                        icon: Icons.email_rounded,
                        title: 'Email Us',
                        value: _email,
                        iconColor: theme.secondary,
                        onTap: () => _launchEmail(_email),
                        onLongPress: () => _copyToClipboard(context, _email),
                      ),
                      const SizedBox(height: 16),
      
                      // Phone Card
                      _buildContactCard(
                        context,
                        icon: Icons.phone_rounded,
                        title: 'Call Us',
                        value: _mobile,
                        iconColor: ThemeProvider.success,
                        onTap: () => _launchPhone(_mobile),
                        onLongPress: () => _copyToClipboard(context, _mobile),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    final theme = ThemeProvider.instance;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: theme.glassDecoration,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withOpacity(0.3), width: 1),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: theme.textHint,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.iconColor.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final Uri uri = Uri(scheme: 'mailto', path: email);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
         print('Could not launch $uri: canLaunchUrl returned false');
         await launchUrl(uri);
      }
    } catch (e) {
      print('Could not launch email: $e');
    }
  }

  Future<void> _launchPhone(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        print('Could not launch $uri: canLaunchUrl returned false');
        // Try launching anyway as a fallback
        await launchUrl(uri);
      }
    } catch (e) {
      print('Could not launch phone: $e');
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied to clipboard: $text')),
    );
  }
}
