import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class DailyCheckinDashboardScreen extends ConsumerStatefulWidget {
  const DailyCheckinDashboardScreen({super.key});

  @override
  ConsumerState<DailyCheckinDashboardScreen> createState() => _DailyCheckinDashboardScreenState();
}

class _DailyCheckinDashboardScreenState extends ConsumerState<DailyCheckinDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildCheckInCard(),
              const SizedBox(height: 24),
              _buildSubjectsGrid(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chào buổi sáng,',
              style: GoogleFonts.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              'tuihocAnhVan! 👋',
              style: GoogleFonts.quicksand(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFDCBB), // secondary-fixed
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 20),
              const SizedBox(width: 6),
              Text(
                '1,250 Điểm',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C1700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFE9D00), width: 2), // animate pulse border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF4E5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Color(0xFFFE9D00)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "🎯 Đừng quên 'check-in' lớp học hôm nay nhé!",
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Điểm Danh Hôm Nay',
                      style: GoogleFonts.quicksand(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E3E6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Tuần 4',
                        style: GoogleFonts.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3F4852),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildWeeklyTracker(),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⚠️ Chuỗi 2 ngày sắp bị mất nếu không điểm danh hôm nay!',
                          style: GoogleFonts.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildPlayGameButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTracker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildDayCircle('T2', isDone: true),
        _buildLine(isDone: true),
        _buildDayCircle('T3', isDone: true),
        _buildLine(isDone: false),
        _buildTodayCircle(),
        _buildLine(isDone: false),
        _buildDayCircle('T5', isLocked: true),
        _buildLine(isDone: false),
        _buildDayCircle('T6', isLocked: true),
      ],
    );
  }

  Widget _buildLine({required bool isDone}) {
    return Expanded(
      child: Container(
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFF00B460).withOpacity(0.5) : const Color(0xFFE0E3E6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildDayCircle(String label, {bool isDone = false, bool isLocked = false}) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFF00B460) : const Color(0xFFE0E3E6),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDone ? Icons.check_rounded : Icons.lock_outline_rounded,
            color: isDone ? Colors.white : const Color(0xFF6F7883),
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF3F4852),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayCircle() {
    return Column(
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFE9D00), width: 4),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Color(0xFFFE9D00),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hôm nay',
          style: GoogleFonts.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFE9D00),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayGameButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFB26E00), // bottom shadow edge
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.sports_esports_rounded, color: Colors.white),
        label: Text(
          '🎮 Chơi Game Điểm Danh',
          style: GoogleFonts.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFE9D00),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0, // we use container shadow for 3D effect
        ),
      ),
    );
  }

  Widget _buildSubjectsGrid() {
    // In Flutter, using GridView inside ScrollView needs shrinkWrap, or we can just use a Wrap or Column with Row
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return Row(
            children: [
              Expanded(child: _buildMathCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildEnglishCard()),
            ],
          );
        } else {
          return Column(
            children: [
              _buildMathCard(),
              const SizedBox(height: 16),
              _buildEnglishCard(),
            ],
          );
        }
      },
    );
  }

  Widget _buildMathCard() {
    return _buildSubjectCard(
      title: 'Toán Học',
      subtitle: 'Phép cộng trong phạm vi 10',
      icon: Icons.calculate_rounded,
      iconBgColor: const Color(0xFFCFE5FF),
      iconColor: const Color(0xFF00629D),
      badgeText: 'Cơ bản',
      badgeBgColor: const Color(0xFFCFE5FF).withOpacity(0.2),
      badgeTextColor: const Color(0xFF00A3FF),
      progress: 0.6,
      progressColor: const Color(0xFF00629D),
      progressBgColor: const Color(0xFFE0E3E6),
      btnText: 'Tiếp tục học',
      btnBgColor: const Color(0xFFE0E3E6),
      btnTextColor: const Color(0xFF3F4852),
    );
  }

  Widget _buildEnglishCard() {
    return _buildSubjectCard(
      title: 'Tiếng Anh',
      subtitle: 'Từ vựng động vật',
      icon: Icons.translate_rounded,
      iconBgColor: const Color(0xFF6CFE9F),
      iconColor: const Color(0xFF006D38),
      badgeText: 'Mới',
      badgeBgColor: const Color(0xFF6CFE9F).withOpacity(0.2),
      badgeTextColor: const Color(0xFF00B460),
      progress: 0.1,
      progressColor: const Color(0xFF006D38),
      progressBgColor: const Color(0xFFE0E3E6),
      btnText: 'Bắt đầu ngay',
      btnBgColor: const Color(0xFF00B460),
      btnTextColor: Colors.white,
      btnShadowColor: const Color(0xFF008A4A),
    );
  }

  Widget _buildSubjectCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String badgeText,
    required Color badgeBgColor,
    required Color badgeTextColor,
    required double progress,
    required Color progressColor,
    required Color progressBgColor,
    required String btnText,
    required Color btnBgColor,
    required Color btnTextColor,
    Color? btnShadowColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.quicksand(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tiến độ bài học',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: progressBgColor,
            color: progressColor,
            minHeight: 16,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: btnShadowColor != null
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: btnShadowColor,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  )
                : null,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: btnBgColor,
                foregroundColor: btnTextColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    btnText,
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    btnShadowColor != null ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
