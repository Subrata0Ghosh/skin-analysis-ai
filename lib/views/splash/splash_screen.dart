import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../onboarding/questionnaire_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic)),
    );

    // Initialize looping aesthetics background video safely
    try {
      _videoController = VideoPlayerController.asset("assets/videos/full-hero-mobile-v2.webm")
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isVideoInitialized = true;
            });
          }
        }).catchError((e) {
          debugPrint("Video initialization failed: $e");
        });
      _videoController.setLooping(true);
      _videoController.setVolume(0.0);
      _videoController.play().catchError((e) {
        debugPrint("Video play failed: $e");
      });
    } catch (e) {
      debugPrint("Video controller setup failed: $e");
    }

    _controller.forward().then((_) => _checkAuthentication());
  }

  @override
  void dispose() {
    _videoController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuthentication() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Allow animation to be satisfying
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!mounted) return;

    if (authService.isLoggedIn) {
      final storageService = Provider.of<StorageService>(context, listen: false);
      final profile = await storageService.getUserProfile(authService.currentUid!);
      
      if (!mounted) return;

      if (profile != null && profile.name.isNotEmpty) {
        // Fully onboarded, route to home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // Authenticated but questionnaire incomplete
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
        );
      }
    } else {
      // First-time visitor or signed out
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Video
          if (_isVideoInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            ),

          // Semitransparent dimming overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.65),
            ),
          ),

          // Central Loading Logo content
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Brand Logo Mark with glowing glassmorphic background
                        ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.cardBg.withValues(alpha: 0.35),
                                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                                    blurRadius: 40,
                                    spreadRadius: 10,
                                  )
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.spa_outlined,
                                  size: 52,
                                  color: AppColors.primaryGold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // App Name
                        Text(
                          "A U R A S K I N",
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontSize: 26,
                                letterSpacing: 6.0,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        // Subtitle Tagline
                        Text(
                          "Understand your skin, clearly.",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                letterSpacing: 0.8,
                                color: AppColors.textSecondary.withValues(alpha: 0.8),
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
