import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/login_screen.dart';
import 'package:mobile_app/db/database_helper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final theme = ThemeProvider.instance;

  final List<OnboardingData> _onboardingPages = [
    OnboardingData(
      title: 'Seamless Sales Tracking',
      description: 'Track every sale in real-time with our intuitive point-of-sale interface. Manage transactions effortlessly.',
      icon: Icons.point_of_sale_rounded,
      gradient: ThemeProvider.gradientOcean,
    ),
    OnboardingData(
      title: 'Effortless Stock Management',
      description: 'Keep your inventory organized. Get low-stock alerts and manage products across multiple branches.',
      icon: Icons.inventory_2_rounded,
      gradient: ThemeProvider.gradientPurple,
    ),
    OnboardingData(
      title: 'Real-time Business Analytics',
      description: 'Gain valuable insights with detailed reports. Monitor sales, expenses, and profits at a glance.',
      icon: Icons.insights_rounded,
      gradient: ThemeProvider.gradientSuccess,
    ),
  ];

  void _finishOnboarding() async {
    await DatabaseHelper.instance.setHasSeenOnboarding(true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 360;
    final buttonMaxWidth = width < 600 ? width - 32 : 420.0;

    return Scaffold(
      body: Stack(
        children: [
          theme.glassBackground(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _onboardingPages.length,
              onPageChanged: (int page) {
                setState(() => _currentPage = page);
              },
              itemBuilder: (context, index) => OnboardingPageWidget(
                data: _onboardingPages[index],
                isLastPage: index == _onboardingPages.length - 1,
              ),
            ),
          ),
          if (_currentPage < _onboardingPages.length - 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 16,
              child: TextButton(
                onPressed: _finishOnboarding,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 28,
            left: 16,
            right: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: buttonMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _onboardingPages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? theme.highlight
                                : theme.textSecondary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: compact ? 52 : 56,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentPage < _onboardingPages.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _finishOnboarding();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.highlight,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _currentPage == _onboardingPages.length - 1
                              ? 'Get Started'
                              : 'Next',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPageWidget extends StatelessWidget {
  final OnboardingData data;
  final bool isLastPage;

  const OnboardingPageWidget({
    super.key,
    required this.data,
    required this.isLastPage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;
    final iconSize = isDesktop
        ? 200.0
        : (size.width < 360 ? 120.0 : size.width * 0.42).clamp(120.0, 200.0);
    final textScale = size.width < 360 ? 0.9 : 1.0;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: size.width < 360 ? 20 : 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 72),
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: data.gradient
                        .map((c) => c.withValues(alpha: 0.2))
                        .toList(),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: data.gradient.first.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: data.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Icon(
                      data.icon,
                      size: isDesktop ? 100 : iconSize * 0.45,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: (isDesktop ? 32 : 28) * textScale,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                data.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: (isDesktop ? 18 : 16) * textScale,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              SizedBox(height: isDesktop ? 100 : size.height * 0.12),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}
