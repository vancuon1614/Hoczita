import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_icon.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/supabase_service.dart';
import 'counting_lesson_screen.dart';
import 'math_ops_lesson_screen.dart';
import 'random_flashcard_screen.dart';
import 'package:google_fonts/google_fonts.dart';
class LearnTab extends ConsumerWidget {
  const LearnTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final username = authState.username ?? 'Chúc bạn học tập tốt';
    final isLoggedIn = authState.status == AuthStatus.authenticated;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with blue gradient
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $username! 👋',
                            style: GoogleFonts.baloo2(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            isLoggedIn
                                ? 'Hãy bắt đầu rèn luyện hôm nay!'
                                : 'Đăng nhập để lưu lại tiến trình học',
                            style: GoogleFonts.baloo2(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
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
                                  Icon(
                                    Icons.stars_rounded,
                                    color: AppColors.accent,
                                    size: 20,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '$points điểm',
                                    style: GoogleFonts.baloo2(
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
                ),
              ),
            ),

            // Content below header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 24),
                  // Main Title
                  Text(
                    'Toán Học 🧮',
                    style: GoogleFonts.baloo2(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Lựa chọn nội dung học tập để rèn luyện tư duy không giới hạn thời gian.',
                    style: GoogleFonts.baloo2(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 24),

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
                  SizedBox(height: 20),

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
                  SizedBox(height: 32),

                  // English Section Title
                  Text(
                    'Tiếng Anh 🇬🇧',
                    style: GoogleFonts.baloo2(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Cải thiện vốn từ vựng mỗi ngày với phương pháp lặp lại ngẫu nhiên.',
                    style: GoogleFonts.baloo2(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 24),

                  // Lesson card 3: Random Flashcards
                  _buildLessonCard(
                    context: context,
                    title: 'Flashcard Từ Vựng',
                    subtitle: 'Học từ vựng không giới hạn với hình ảnh sinh động và phát âm.',
                    icon: Icons.flash_on_rounded,
                    color: Colors.amber,
                    animationType: GameAnimationType.bounce,
                    imagePath: 'ImageFolder/flashcard.gif',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RandomFlashcardScreen(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
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
                SizedBox(width: 20),
                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.baloo2(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Icon(
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
