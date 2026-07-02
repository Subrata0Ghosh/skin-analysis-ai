import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../auth/auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _slides = [
    OnboardingItem(
      title: "Meet Your Personal\nSkin Companion",
      description: "AuraSkin AI uses deep visual analysis to map your facial regions and understand the current state of your skin, grain by grain.",
      icon: Icons.face_retouching_natural_outlined,
      gradientColor: AppColors.primaryGold,
    ),
    OnboardingItem(
      title: "Scan in Seconds,\nSee Clearly",
      description: "Capture a quick selfie or upload a photo. Our guided alignment mesh ensures optimal lighting and positioning for precise results.",
      icon: Icons.qr_code_scanner_outlined,
      gradientColor: AppColors.accentSage,
    ),
    OnboardingItem(
      title: "Targeted Routines\n& Actionable Reports",
      description: "Interact with highlighted problem areas on your face and receive customized day & night product routines tailored just for you.",
      icon: Icons.auto_awesome_outlined,
      gradientColor: AppColors.accentRose,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                  },
                  child: Text(
                    "Skip",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ),
            ),
            
            // Slider Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon Container with glowing background
                        Container(
                          height: 160,
                          width: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cardBg,
                            border: Border.all(color: slide.gradientColor.withValues(alpha: 0.2), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: slide.gradientColor.withValues(alpha: 0.08),
                                blurRadius: 40,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: Icon(
                            slide.icon,
                            size: 72,
                            color: slide.gradientColor,
                          ),
                        ),
                        const SizedBox(height: 48),
                        
                        // Slide Title
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                height: 1.25,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Slide Description
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                                height: 1.5,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Page Indicators & Buttons Footer
            Padding(
              padding: const EdgeInsets.only(left: 32.0, right: 32.0, bottom: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicators
                  Row(
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8.0),
                        height: 6,
                        width: _currentPage == index ? 24 : 6,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.primaryGold
                              : AppColors.borderLight,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  
                  // CTA Button
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _currentPage == _slides.length - 1
                        ? ElevatedButton(
                            key: const ValueKey('get_started'),
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const AuthScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text("Get Started"),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                          )
                        : TextButton(
                            key: const ValueKey('next'),
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 450),
                                curve: Curves.easeOutCubic,
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text("Next", style: TextStyle(color: AppColors.primaryGold)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primaryGold),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;
  final Color gradientColor;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColor,
  });
}
