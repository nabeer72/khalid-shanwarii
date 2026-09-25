import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final String _email = 'nabee@company.com';
  final String _mobile = '03********5';

  // FAQ expansion state
  int? _expandedFaqIndex;

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I record a sale?',
      'answer':
          'Go to the POS screen, select the products, choose payment method, and tap "Process Payment".'
    },
    {
      'question': 'How do I refund a transaction?',
      'answer':
          'Go to Sales History, find the transaction, tap the refund button, and confirm.'
    },
    {
      'question': 'How do I sync data to the server?',
      'answer':
          'Data is synced automatically when your device is connected to the internet.'
    },
    {
      'question': 'How do I add a new product?',
      'answer':
          'Go to Products screen, tap the add button, and fill in the product details.'
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
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: theme.textPrimary,
        ),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            children: [
              const SizedBox(height: 12),

              // Contact Section
              const _SectionHeader(
                title: 'GET IN TOUCH',
              ),

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
              const _SectionHeader(
                title: 'FREQUENTLY ASKED QUESTIONS',
              ),

              ..._faqs.asMap().entries.map((entry) {
                final index = entry.key;
                final faq = entry.value;

                return _buildFaqItem(
                  context,
                  faq['question']!,
                  faq['answer']!,
                  index,
                );
              }).toList(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(
    BuildContext context,
    String question,
    String answer,
    int index,
  ) {
    final theme = ThemeProvider.instance;
    final isExpanded = _expandedFaqIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: theme.glassListDecoration,
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          title: Text(
            question,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 2,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          expandedAlignment: Alignment.centerLeft,
          trailing: Icon(
            isExpanded
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded,
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
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

  Future<void> _launchEmail(String email) async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: email,
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Could not launch email: $e');
    }
  }

  Future<void> _launchPhone(String phone) async {
    final Uri uri = Uri(
      scheme: 'tel',
      path: phone,
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Could not launch phone: $e');
    }
  }

  void _copyToClipboard(
    BuildContext context,
    String text,
  ) {
    final theme = ThemeProvider.instance;

    Clipboard.setData(
      ClipboardData(text: text),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied to clipboard: $text',
        ),
        backgroundColor: theme.highlight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        8,
        16,
        16,
        8,
      ),
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
              borderRadius: BorderRadius.circular(
                ThemeProvider.radiusList,
              ),
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  ThemeProvider.radiusList,
                ),
              ),
              child: Icon(
                icon,
                color: theme.highlight,
                size: 22,
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: showTrailing
                ? Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: theme.iconColor.withOpacity(0.6),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

