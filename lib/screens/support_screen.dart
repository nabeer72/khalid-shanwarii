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

  // FAQ and Terms expansion state
  int? _expandedFaqIndex;
  int? _expandedTermIndex;
  
  List<dynamic> _terms = [];
  bool _isLoadingTerms = true;

  @override
  void initState() {
    super.initState();
    _fetchTerms();
  }

  Future<void> _fetchTerms() async {
    try {
      final api = ApiService();
      final res = await api.getTermsAndConditions();
      if (res != null && res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _terms = res.data['data'] ?? [];
            _isLoadingTerms = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTerms = false);
      }
    }
  }

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
        title: Text(
          'Customer Support',
          style: TextStyle(
              color: theme.textPrimary,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: theme.textPrimary),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              const SizedBox(height: 12),
              
              // Contact Section
              const _SectionHeader(title: 'GET IN TOUCH'),
              _SupportTile(
                icon: Icons.email_rounded,
                title: 'Email Us',
                subtitle: _email,
                onTap: () => _launchEmail(_email),
                onLongPress: () => _copyToClipboard(context, _email),
                showTrailing: true,
              ),
              _SupportTile(
                icon: Icons.phone_rounded,
                title: 'Call Us',
                subtitle: _mobile,
                onTap: () => _launchPhone(_mobile),
                onLongPress: () => _copyToClipboard(context, _mobile),
                showTrailing: true,
              ),
              
              const SizedBox(height: 24),
              // FAQ Section
              const _SectionHeader(title: 'FREQUENTLY ASKED QUESTIONS'),
              ..._faqs.asMap().entries.map((entry) {
                final index = entry.key;
                final faq = entry.value;
                return _buildFaqItem(context, faq['question']!, faq['answer']!, index);
              }).toList(),
              
              const SizedBox(height: 24),
              // Terms & Conditions Section
              const _SectionHeader(title: 'TERMS & CONDITIONS'),
              if (_isLoadingTerms)
                Center(child: Padding(padding: const EdgeInsets.all(16), child: CircularProgressIndicator(color: theme.highlight)))
              else if (_terms.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('No terms & conditions available.', style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                )
              else
                ..._terms.asMap().entries.map((entry) {
                  final index = entry.key;
                  final term = entry.value;
                  return _buildTermItem(context, term['title'] ?? '', term['content'] ?? '', index);
                }).toList(),
              
              const SizedBox(height: 24),
              // Feedback Section
              const _SectionHeader(title: 'SEND FEEDBACK'),
              if (_feedbackSent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeProvider.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
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
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: theme.glassListDecoration,
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            height: 40,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.highlight,
                              foregroundColor: Colors.white,
                              elevation: 6,
                              shadowColor: theme.highlight.withAlpha(102),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                              ),
                            ),
                            onPressed: () async {
                              if (_feedbackController.text.trim().isNotEmpty) {
                                final message = _feedbackController.text.trim();
                                try {
                                  final api = ApiService();
                                  await api.submitFeedback(message);
                                  
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.send_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'SEND FEEDBACK',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer, int index) {
    final theme = ThemeProvider.instance;
    final isExpanded = _expandedFaqIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: theme.glassListDecoration,
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
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          expandedAlignment: Alignment.centerLeft,
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
                textAlign: TextAlign.left,
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

  Widget _buildTermItem(BuildContext context, String title, String content, int index) {
    final theme = ThemeProvider.instance;
    final isExpanded = _expandedTermIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: theme.glassListDecoration,
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            title,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          expandedAlignment: Alignment.centerLeft,
          trailing: Icon(
            isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: theme.iconColor,
            size: 22,
          ),
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedTermIndex = expanded ? index : null;
            });
          },
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                content,
                textAlign: TextAlign.left,
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: theme.highlight,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showTrailing;

  const _SupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
    this.showTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: theme.glassListDecoration,
          child: ListTile(
            onTap: onTap,
            onLongPress: onLongPress,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
              child: Icon(icon, color: theme.highlight, size: 22),
            ),
            title: Text(title,
                style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
            subtitle: Text(subtitle,
                style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            trailing: showTrailing
                ? Icon(Icons.chevron_right_rounded,
                    size: 20, color: theme.iconColor.withOpacity(0.6))
                : null,
          ),
        ),
      ),
    );
  }
}
