import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/views/main_screen.dart';

class OnboardingStep {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;

  OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
  });
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoPlayTimer;
  Timer? _redirectTimer;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: 'Học Mà Chơi, Chơi Mà Học',
      description: 'Học tập tương tác trực quan với các trò chơi toán học và ngoại ngữ sinh động.',
      icon: Icons.school_rounded,
      accentColor: AppColors.primary,
    ),
    OnboardingStep(
      title: 'Toán Lớp 1 Thú Vị',
      description: 'Khám phá thế giới con số qua game đếm táo thần kỳ và phép tính vui nhộn.',
      icon: Icons.calculate_rounded,
      accentColor: AppColors.accent,
    ),
    OnboardingStep(
      title: 'Chinh Phục Ngoại Ngữ',
      description: 'Phát triển từ vựng tiếng Anh qua flashcard tốc độ và trò chơi lật thẻ ghép cặp.',
      icon: Icons.translate_rounded,
      accentColor: AppColors.success,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Auto-advance slides every 1 second
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentPage < _steps.length - 1) {
        _currentPage++;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    // Auto-navigate to MainScreen after 3 seconds total
    _redirectTimer = Timer(const Duration(milliseconds: 3200), () {
      _navigateToMain();
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _redirectTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToMain() {
    _autoPlayTimer?.cancel();
    _redirectTimer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background soft shapes
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight.withValues(alpha: 0.5),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight.withValues(alpha: 0.3),
              ),
            ),
          ),

          // Core PageView Content
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 40),
                // Logo & App Name
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.rocket_launch_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'HocZiTa',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 26,
                            color: AppColors.primary,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ],
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _steps.length,
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Big visual icon with animated background pulse
                            Container(
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                color: step.accentColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                step.icon,
                                size: 100,
                                color: step.accentColor,
                              ),
                            ),
                            SizedBox(height: 50),
                            Text(
                              step.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              step.description,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Dots indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _steps.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _currentPage == index
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 40),

                // "Bỏ qua" button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _navigateToMain,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Bắt đầu học ngay'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
