import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_icon.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/supabase_service.dart';
import 'counting_lesson_screen.dart';
import 'math_ops_lesson_screen.dart';

class LearnTab extends ConsumerWidget {
  const LearnTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final username = authState.username ?? 'Chúc bạn học tập tốt';
    final isLoggedIn = authState.status == AuthStatus.authenticated;

    return Scaffold(
      body: Stack(
        children: [
          // Background blue header gradient
          Container(
            height: 100,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Welcome Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $username! 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isLoggedIn
                                ? 'Hãy bắt đầu rèn luyện hôm nay!'
                                : 'Đăng nhập để lưu lại tiến trình học',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (isLoggedIn)
                        FutureBuilder<int>(
                          future: SupabaseService.instance.getTotalScore(),
                          builder: (context, snapshot) {
                            final points = snapshot.data ?? 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.stars_rounded,
                                    color: AppColors.accent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$points điểm',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(
                    height: 40,
                  ), // Spacing to push below the header curve
                  // Main Title
                  const Text(
                    'Toán Lớp 1 📚',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Lựa chọn nội dung học tập để rèn luyện tư duy không giới hạn thời gian.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Lesson card 1: Counting (Using mathcount.gif animation)
                  _buildLessonCard(
                    context: context,
                    title: 'Đếm Số Thông Minh',
                    subtitle:
                        'Nhìn hình ảnh sinh động và đếm số lượng vật thể phù hợp.',
                    icon: Icons.apple_rounded,
                    color: Colors.redAccent,
                    animationType: GameAnimationType.pulse,
                    imagePath: 'ImageFolder/mathcount.gif',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CountingLessonScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Lesson card 2: Math operations (Using thembotvuinhon.gif animation)
                  _buildLessonCard(
                    context: context,
                    title: 'Thêm Bớt Vui Nhộn',
                    subtitle:
                        'Luyện tập các phép tính cộng, trừ trong phạm vi 100.',
                    icon: Icons.add_circle_outline_rounded,
                    color: Colors.blueAccent,
                    animationType: GameAnimationType.bounce,
                    imagePath: 'ImageFolder/thembotvuinhon.gif',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MathOpsLessonScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required GameAnimationType animationType,
    String? imagePath,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // Icon/Image frame (using padding adjustment for larger images)
                Container(
                  padding: imagePath != null
                      ? const EdgeInsets.all(10)
                      : const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: imagePath != null
                      ? Image.asset(
                          imagePath,
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                        )
                      : AnimatedGameIcon(
                          icon: icon,
                          color: color,
                          size: 32,
                          animationType: animationType,
                        ),
                ),
                const SizedBox(width: 20),
                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
