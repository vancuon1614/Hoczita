import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/supabase_service.dart';
import 'counting_lesson_screen.dart';
import 'math_ops_lesson_screen.dart';
import 'random_flashcard_screen.dart';
import 'widgets/week_checkin_row.dart';
import '../../game/views/daily_checkin_game_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../chat/views/chat_panel.dart';

class LearnTab extends ConsumerWidget {
  const LearnTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final username = authState.username ?? 'Chúc bạn học tập tốt';
    final isLoggedIn = authState.status == AuthStatus.authenticated;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP HEADER CONTAINER (COBALT BLUE #0047AB)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF0047AB), // Cobalt Blue
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x330047AB),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: _buildGreetingHeader(context, username, isLoggedIn),
                ),
              ),
            ),

            // 2. MAIN CONTENT (BELOW HEADER)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // DAILY CHECK-IN CARD (Reminder State)
                  if (isLoggedIn) ...[
                    _buildCheckinCard(context),
                    const SizedBox(height: 24),
                  ],

                  // HOCDI AI COMPANION CARD
                  _buildHocDiCard(context, ref),
                  const SizedBox(height: 24),

                  // SUBJECTS HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Khóa Học & Rèn Luyện 📚',
                        style: GoogleFonts.baloo2(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF191C1E),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E3E6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Học kỳ 1',
                          style: GoogleFonts.baloo2(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF3F4852),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // SUBJECTS: TOÁN HỌC & TIẾNG ANH (stitch_daily_check_in_dashboard)
                  _buildMathSubjectCard(context),
                  const SizedBox(height: 18),
                  _buildEnglishSubjectCard(context),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Header Greeting: Chào buổi sáng + Username + Point Badge
  Widget _buildGreetingHeader(BuildContext context, String username, bool isLoggedIn) {
    final hour = DateTime.now().hour;
    final greetingPrefix = hour < 12
        ? 'Chào buổi sáng,'
        : (hour < 18 ? 'Chào buổi chiều,' : 'Chào buổi tối,');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greetingPrefix,
                style: GoogleFonts.baloo2(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              Text(
                '$username! 👋',
                style: GoogleFonts.baloo2(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (isLoggedIn)
          FutureBuilder<int>(
            future: SupabaseService.instance.getTotalScore(),
            builder: (context, snapshot) {
              final points = snapshot.data ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDCBB),
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x20000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Color(0xFFFFB800),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$points Điểm',
                      style: GoogleFonts.baloo2(
                        color: const Color(0xFF2C1700),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCheckinCard(BuildContext context) {
    return WeekCheckinRow(
      onPlayGame: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DailyCheckinGameScreen(),
          ),
        );
      },
    );
  }

  /// HocDi AI Assistant Companion Card
  Widget _buildHocDiCard(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCFE5FF), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D00629D),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0047AB), width: 1.5),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'ImageFolder/Designer.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HocDi - Trợ Lý Học Tập 🤖',
                      style: GoogleFonts.baloo2(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF191C1E),
                      ),
                    ),
                    Text(
                      'Giải đáp bài học, gợi ý mẹo giải đố cho bạn!',
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        color: const Color(0xFF3F4852),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Quick suggestion chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildQuickChip(context, ref, '📖 Hỏi từ vựng'),
              _buildQuickChip(context, ref, '🧮 Gợi ý giải toán'),
              _buildQuickChip(context, ref, '✨ Gửi lời động viên'),
            ],
          ),
          const SizedBox(height: 14),
          // Squishy button to open ChatPanel
          Container(
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9999),
              gradient: const LinearGradient(
                colors: [Color(0xFF00629D), Color(0xFF0077BB)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF004A77),
                  offset: Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(9999),
                onTap: () => ChatPanel.show(context, ref),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Trò chuyện cùng HocDi ngay',
                      style: GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  Widget _buildQuickChip(BuildContext context, WidgetRef ref, String text) {
    return InkWell(
      onTap: () => ChatPanel.show(context, ref),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E3E6)),
        ),
        child: Text(
          text,
          style: GoogleFonts.baloo2(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF00629D),
          ),
        ),
      ),
    );
  }

  /// Math Subject Card (stitch_daily_check_in_dashboard)
  Widget _buildMathSubjectCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFCFE5FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calculate_rounded,
                  color: Color(0xFF00629D),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Toán Học',
                      style: GoogleFonts.baloo2(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF191C1E),
                      ),
                    ),
                    Text(
                      'Phép cộng & trừ trong phạm vi 100',
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        color: const Color(0xFF3F4852),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFCFE5FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Cơ bản',
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00629D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Thick 16px Gel Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tiến độ bài học',
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3F4852),
                    ),
                  ),
                  Text(
                    '60%',
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00629D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E3E6),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.60,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9999),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00629D), Color(0xFF00A3FF)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Two Sub-lessons
          Row(
            children: [
              Expanded(
                child: _buildLessonSubButton(
                  title: 'Đếm Số',
                  icon: Icons.apple_rounded,
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CountingLessonScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLessonSubButton(
                  title: 'Thêm Bớt',
                  icon: Icons.add_circle_outline_rounded,
                  color: const Color(0xFF00629D),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MathOpsLessonScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// English Subject Card (stitch_daily_check_in_dashboard)
  Widget _buildEnglishSubjectCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF6CFE9F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.translate_rounded,
                  color: Color(0xFF006D38),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tiếng Anh',
                      style: GoogleFonts.baloo2(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF191C1E),
                      ),
                    ),
                    Text(
                      'Từ vựng sinh động & Flashcards',
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        color: const Color(0xFF3F4852),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6CFE9F).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Mới',
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF006D38),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Thick 16px Gel Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tiến độ bài học',
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3F4852),
                    ),
                  ),
                  Text(
                    '45%',
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF006D38),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E3E6),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.45,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9999),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF006D38), Color(0xFF00B460)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Squishy Pill Button "Bắt đầu học Flashcard"
          Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9999),
              gradient: const LinearGradient(
                colors: [Color(0xFF00B460), Color(0xFF008A4A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF006D38),
                  offset: Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(9999),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RandomFlashcardScreen(),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Bắt đầu học Flashcard',
                      style: GoogleFonts.baloo2(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonSubButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: const Color(0xFFE0E3E6)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9999),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.baloo2(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF191C1E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
