import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final String _email = 'example@gmail.com';
  final String _mobile = '03********5';
  final TextEditingController _feedbackController = TextEditingController();
  bool _feedbackSent = false;

  // FAQ expansion state
  int? _expandedFaqIndex;

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I record a sale?',
      'answer': 'Go to the POS screen, select the products, choose payment method, and tap "Process Payment".'
    },
    {
      'question': 'How do I refund a transaction?',
      'answer': 'Go to Sales History, find the transaction, tap the refund button, and confirm.'
    },
    {
      'question': 'How do I sync data to the server?',
      'answer': 'Data is synced automatically when your device is connected to the internet.'
    },
    {
      'question': 'How do I add a new product?',
      'answer': 'Go to Products screen, tap the add button, and fill in the product details.'
    },
  ];

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
                      // Hero section
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: theme.highlight.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.highlight.withOpacity(0.3), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.highlight.withOpacity(0.15),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  )
                                ]
                              ),
                              child: Icon(Icons.support_agent_rounded, size: 56, color: theme.highlight),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Need Help?',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: theme.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Contact our support team for any assistance or inquiries.',
                              style: TextStyle(fontSize: 14, color: theme.textSecondary, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      
                      // Contact Section
                      Text(
                        'Get In Touch',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: theme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 10),
      
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
                      
                      const SizedBox(height: 28),
                      
                      // FAQ Section
                      Text(
                        'Frequently Asked Questions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: theme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._faqs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final faq = entry.value;
                        return _buildFaqItem(context, faq['question']!, faq['answer']!, index);
                      }).toList(),
                      
                      const SizedBox(height: 28),
                      
                      // Feedback Section
                      Text(
                        'Send Feedback',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: theme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_feedbackSent)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ThemeProvider.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                            border: Border.all(color: ThemeProvider.success.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: ThemeProvider.success, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Thank you for your feedback! We appreciate it.',
                                  style: TextStyle(color: ThemeProvider.success, fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: theme.glassDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Let us know how we can improve!',
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _feedbackController,
                                maxLines: 3,
                                style: TextStyle(color: theme.textPrimary),
                                decoration: theme.glassInputDecoration('Your feedback...', Icons.feedback_rounded),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.highlight,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (_feedbackController.text.trim().isNotEmpty) {
                                      final message = _feedbackController.text.trim();
                                      try {
                                        final api = ApiService();
                                        await api.post('/feedback', data: {'message': message});
                                        
                                        if (mounted) {
                                          setState(() {
                                            _feedbackSent = true;
                                          });
                                          _feedbackController.clear();
                                          Future.delayed(const Duration(seconds: 3), () {
                                            if (mounted) {
                                              setState(() {
                                                _feedbackSent = false;
                                              });
                                            }
                                          });
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Failed to send feedback: $e'),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  child: const Text(
                                    'SEND FEEDBACK',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
                                  ),
                                ),
                              ),
                            ],
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
        padding: const EdgeInsets.all(16),
        decoration: theme.glassDecoration,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withOpacity(0.25), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: theme.textHint,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: theme.iconColor.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer, int index) {
    final theme = ThemeProvider.instance;
    final isExpanded = _expandedFaqIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: theme.glassDecoration,
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            question,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          trailing: Icon(
            isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: theme.iconColor,
            size: 22,
          ),
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedFaqIndex = expanded ? index : null;
            });
          },
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                answer,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
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
        await launchUrl(uri);
      }
    } catch (e) {
      print('Could not launch phone: $e');
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    final theme = ThemeProvider.instance;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard: $text'),
        backgroundColor: theme.highlight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
}
