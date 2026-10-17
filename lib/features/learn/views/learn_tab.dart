import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/supabase_service.dart';
import 'counting_lesson_screen.dart';
import 'math_ops_lesson_screen.dart';
import 'advanced_flashcard_screen.dart';
import 'topic_selection_sheet.dart';
import '../services/learning_progress_service.dart';
import 'widgets/week_checkin_row.dart';
import '../../game/views/daily_checkin_game_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../chat/views/chat_panel.dart';
import '../../../core/providers/game_interaction_provider.dart';

class LearnTab extends ConsumerWidget {
  const LearnTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final username = authState.username ?? 'Chúc bạn học tập tốt';
    final isLoggedIn = authState.status == AuthStatus.authenticated;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FD),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP HEADER CONTAINER (COBALT BLUE #0047AB)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0047AB), Color(0xFF1E60D0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                    _buildCheckinCard(context, ref),
                    const SizedBox(height: 24),
                  ],

                  // HOCDI AI COMPANION CARD
                  if (isLoggedIn) ...[
                    _buildHocDiCard(context, ref),
                    const SizedBox(height: 24),
                  ],

                  // SUBJECTS HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Khóa Học & Rèn Luyện',
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
                  color: Colors.white.withValues(alpha: 0.88),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x25000000),
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
                        color: const Color(0xFF0047AB),
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

  Widget _buildCheckinCard(BuildContext context, WidgetRef ref) {
    return WeekCheckinRow(
      onPlayGame: () async {
        ref.read(isGameActiveProvider.notifier).state = true;
        try {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DailyCheckinGameScreen(),
            ),
          );
        } finally {
          ref.read(isGameActiveProvider.notifier).state = false;
        }
      },
    );
  }

  /// HocDi AI Assistant Companion Card
  Widget _buildHocDiCard(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF4F6EA0).withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x124F6EA0),
            blurRadius: 24,
            offset: Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Color(0x064F6EA0),
            blurRadius: 10,
            offset: Offset(0, 2),
            spreadRadius: -2,
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
                  color: const Color(0xFFEFF6FF),
                  border: Border.all(
                    color: const Color(0xFF1E60D0).withValues(alpha: 0.25),
                    width: 2.0,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'ImageFolder/Designer.png',
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
                        color: const Color(0xFF64748B),
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
          // Modern Action Button to open ChatPanel
          Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9999),
              gradient: const LinearGradient(
                colors: [Color(0xFF1E60D0), Color(0xFF0047AB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0047AB).withValues(alpha: 0.25),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
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
                    const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Trò chuyện cùng HocDi ngay',
                      style: GoogleFonts.baloo2(
                        fontSize: 15.5,
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
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Text(
          text,
          style: GoogleFonts.baloo2(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0047AB),
          ),
        ),
      ),
    );
  }

  /// Math Subject Card (from des.zip design)
  Widget _buildMathSubjectCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFEFF6FF).withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x124F6EA0),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Color(0x084F6EA0),
            blurRadius: 8,
            offset: Offset(0, 2),
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
              // Math Squircle Icon with 100 Badge (from des.zip)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF06B6D4)],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40BAE6FD),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.calculate_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x10000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        '100',
                        style: GoogleFonts.baloo2(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF075985),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Toán Học',
                      style: GoogleFonts.baloo2(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Phép cộng & trừ trong phạm vi 100',
                      style: GoogleFonts.baloo2(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Text(
                  'Cơ bản',
                  style: GoogleFonts.baloo2(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dynamic Progress Bar from LearningProgressService
          FutureBuilder<Map<String, dynamic>>(
            future: LearningProgressService.instance.getMathTodayProgress(),
            builder: (context, snapshot) {
              final count = snapshot.data?['count'] ?? 0;
              final target = snapshot.data?['target'] ?? 20;
              final ratio = (snapshot.data?['ratio'] as double?) ?? 0.0;
              final percent = snapshot.data?['percent'] ?? 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tiến độ rèn luyện hôm nay',
                        style: GoogleFonts.baloo2(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '$count/$target câu ($percent%)',
                        style: GoogleFonts.baloo2(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: ratio > 0.04 ? ratio : 0.04,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9999),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF4F46E5)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Action Buttons (matching app primary theme & image reference)
          Row(
            children: [
              Expanded(
                child: AnimatedSubjectButton(
                  title: 'Đếm Số',
                  mainColor: const Color(0xFF1E60D0),
                  lightColor: const Color(0xFFF1F6FE),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CountingLessonScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSubjectButton(
                  title: 'Thêm Bớt',
                  mainColor: const Color(0xFF1E60D0),
                  lightColor: const Color(0xFFF1F6FE),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MathOpsLessonScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// English Subject Card (from des.zip design)
  Widget _buildEnglishSubjectCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFECFDF5).withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x124F6EA0),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Color(0x084F6EA0),
            blurRadius: 8,
            offset: Offset(0, 2),
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
              // Globe Squircle Icon with A1-C1 Badge (from des.zip)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40A7F3D0),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.public_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x10000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        'A1–C1',
                        style: GoogleFonts.baloo2(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tiếng Anh',
                      style: GoogleFonts.baloo2(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Từ vựng sinh động & Flashcards đa cấp độ',
                      style: GoogleFonts.baloo2(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  '2 Chế Độ',
                  style: GoogleFonts.baloo2(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dynamic English Progress Bar from LearningProgressService
          FutureBuilder<Map<String, dynamic>>(
            future: LearningProgressService.instance.getEnglishBasicProgress(),
            builder: (context, snapshot) {
              final count = snapshot.data?['count'] ?? 0;
              final total = snapshot.data?['total'] ?? 120;
              final ratio = (snapshot.data?['ratio'] as double?) ?? 0.0;
              final percent = snapshot.data?['percent'] ?? 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Vốn từ đã khám phá',
                        style: GoogleFonts.baloo2(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '$count/$total từ ($percent%)',
                        style: GoogleFonts.baloo2(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: ratio > 0.04 ? ratio : 0.04,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9999),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF34D399), Color(0xFF14B8A6)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Action Buttons (matching app primary theme & image reference)
          Row(
            children: [
              // Tile 1: Cơ Bản (12 Chủ đề)
              Expanded(
                child: AnimatedSubjectButton(
                  title: 'Cơ Bản (12 Chủ đề)',
                  mainColor: const Color(0xFF059669),
                  lightColor: const Color(0xFFECFDF5),
                  onTap: () => TopicSelectionSheet.show(context),
                ),
              ),
              const SizedBox(width: 12),

              // Tile 2: Nâng Cao (IPA & Ví dụ)
              Expanded(
                child: AnimatedSubjectButton(
                  title: 'Nâng Cao (IPA & Ví dụ)',
                  mainColor: const Color(0xFF059669),
                  lightColor: const Color(0xFFECFDF5),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdvancedFlashcardScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


}

class AnimatedSubjectButton extends StatefulWidget {
  final String title;
  final Color mainColor;
  final Color lightColor;
  final dynamic Function() onTap;

  const AnimatedSubjectButton({
    super.key,
    required this.title,
    required this.mainColor,
    required this.lightColor,
    required this.onTap,
  });

  @override
  State<AnimatedSubjectButton> createState() => _AnimatedSubjectButtonState();
}

class _AnimatedSubjectButtonState extends State<AnimatedSubjectButton> {
  bool _isSelected = false;

  void _handleTap() async {
    if (_isSelected) return;
    
    // 1. Phản hồi lập tức (Active state)
    setState(() => _isSelected = true);
    
    // 2. Logic thời gian chờ hợp lý (350ms) để user nhận diện lựa chọn
    await Future.delayed(const Duration(milliseconds: 350));
    
    // 3. Thực thi hành động
    final result = widget.onTap();
    if (result is Future) {
      await result;
    }
    
    // 4. Trả về trạng thái cũ nếu quay lại màn hình này
    if (mounted) {
      setState(() => _isSelected = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: _isSelected ? widget.mainColor : widget.lightColor,
        border: Border.all(
          color: _isSelected ? Colors.transparent : widget.mainColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: _isSelected
            ? [
                BoxShadow(
                  color: widget.mainColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _handleTap,
          splashColor: widget.mainColor.withValues(alpha: 0.1),
          highlightColor: widget.mainColor.withValues(alpha: 0.1),
          child: Center(
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: _isSelected ? Colors.white : widget.mainColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


