import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/supabase_service.dart';

class DailyCheckinReportDialog extends StatefulWidget {
  final int foundPaths;
  final int pointsEarned;
  final int currentStreak;
  final int? initialRank;
  final VoidCallback? onPlayAgain;
  final VoidCallback onGoHome;

  const DailyCheckinReportDialog({
    super.key,
    required this.foundPaths,
    this.pointsEarned = 0,
    this.currentStreak = 0,
    this.initialRank,
    this.onPlayAgain,
    required this.onGoHome,
  });

  @override
  State<DailyCheckinReportDialog> createState() => _DailyCheckinReportDialogState();
}

class _DailyCheckinReportDialogState extends State<DailyCheckinReportDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  Timer? _autoCloseTimer;
  int? _resolvedRank;

  @override
  void initState() {
    super.initState();
    _resolvedRank = widget.initialRank;
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();
    _fetchRank();

    // Tự động đóng popup sau 5 giây theo yêu cầu
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        widget.onGoHome();
      }
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  void _fetchRank() {
    SupabaseService.instance.saveAndGetTodayRank(widget.foundPaths).then((data) {
      final rank = data['rank'] as int;
      if (mounted && _resolvedRank != rank) {
        setState(() {
          _resolvedRank = rank;
        });
      }
    }).catchError((e) {
      debugPrint('Error fetching rank: $e');
    });
  }

  _ReportTheme _getTheme(int? rank) {
    if (rank == 1) {
      return _ReportTheme(
        badgeIcon: const Text('👑', style: TextStyle(fontSize: 32)),
        badgeLabel: 'TOP 1',
        badgeOuterGradient: const [
          Color(0xFFFBBF24),
          Color(0xFFFDE047),
          Color(0xFFF59E0B),
        ],
        badgeInnerGradient: const [
          Color(0xFFFBBF24),
          Color(0xFFD97706),
        ],
        badgeBorderColor: const Color(0xFFFEF08A),
        badgeTextColor: const Color(0xFF451A03),
        badgeShadowColor: const Color(0xFFEAB308),
        tagText: '✨ BẢNG VÀNG THÀNH TÍCH',
        tagTextColor: const Color(0xFFFDE047),
        tagBorderColor: const Color(0xFFFDE047).withValues(alpha: 0.4),
        tagBgColor: const Color(0xFFFDE047).withValues(alpha: 0.16),
        title: '🎉 XUẤT SẮC! BẠN ĐANG DẪN ĐẦU! 🎉',
        titleColor: const Color(0xFFFDE047),
        subtitlePrefix: 'Sự nỗ lực không ngừng nghỉ đã đưa bạn lên vị trí ',
        rankHighlight: 'TOP 1',
        subtitleSuffix:
            '! Đây là khoảnh khắc của bạn! Hãy tiếp tục giữ vững phong độ và thiết lập kỷ lục mới nhé!',
        highlightColor: const Color(0xFFFDE047),
        glowColor: const Color(0xFFFDE047),
      );
    } else if (rank == 2) {
      return _ReportTheme(
        badgeIcon: const Text('🥈', style: TextStyle(fontSize: 32)),
        badgeLabel: 'TOP 2',
        badgeOuterGradient: const [
          Color(0xFFF8FAFC),
          Color(0xFFE2E8F0),
          Color(0xFF94A3B8),
        ],
        badgeInnerGradient: const [
          Color(0xFFF1F5F9),
          Color(0xFF64748B),
        ],
        badgeBorderColor: Colors.white,
        badgeTextColor: const Color(0xFF0F172A),
        badgeShadowColor: const Color(0xFF94A3B8),
        tagText: '🥈 BẢNG BẠC VINH DANH',
        tagTextColor: const Color(0xFFFDE047), // Chữ vàng nổi bật theo yêu cầu
        tagBorderColor: const Color(0xFFFDE047).withValues(alpha: 0.4),
        tagBgColor: const Color(0xFFFDE047).withValues(alpha: 0.16),
        title: '✨ TUYỆT VỜI! BẠN LÀ Á QUÂN! ✨',
        titleColor: const Color(0xFFFDE047), // Chữ vàng nổi bật theo yêu cầu
        subtitlePrefix:
            'Phong độ của bạn đang cực kỳ ấn tượng! Bạn đã xuất sắc giành vị trí ',
        rankHighlight: 'TOP 2',
        subtitleSuffix:
            '. Hãy bứt phá mạnh mẽ hơn nữa trong hôm nay để vươn lên vị trí TOP 1 nhé!',
        highlightColor: const Color(0xFFFDE047), // Chữ vàng in đậm
        glowColor: const Color(0xFFFDE047),
      );
    } else if (rank == 3) {
      return _ReportTheme(
        badgeIcon: const Text('🥉', style: TextStyle(fontSize: 32)),
        badgeLabel: 'TOP 3',
        badgeOuterGradient: const [
          Color(0xFFFED7AA),
          Color(0xFFFB923C),
          Color(0xFFEA580C),
        ],
        badgeInnerGradient: const [
          Color(0xFFFDBA74),
          Color(0xFFC2410C),
        ],
        badgeBorderColor: const Color(0xFFFFEDD5),
        badgeTextColor: const Color(0xFF431407),
        badgeShadowColor: const Color(0xFFEA580C),
        tagText: '🥉 BẢNG ĐỒNG BỨT PHÁ',
        tagTextColor: const Color(0xFFFDE047), // Chữ vàng nổi bật theo yêu cầu
        tagBorderColor: const Color(0xFFFDE047).withValues(alpha: 0.4),
        tagBgColor: const Color(0xFFFDE047).withValues(alpha: 0.16),
        title: '✨ TUYỆT VỜI! BẠN ĐÃ VÀO TOP 3! ✨',
        titleColor: const Color(0xFFFDE047), // Chữ vàng nổi bật theo yêu cầu
        subtitlePrefix:
            'Phong độ của bạn đang cực kỳ ấn tượng! Bạn đã tiến rất gần đến đỉnh cao nhất với vị trí ',
        rankHighlight: 'TOP 3',
        subtitleSuffix:
            '. Hãy bứt phá mạnh mẽ hơn nữa trong hôm nay để vươn lên vị trí TOP 1 nhé!',
        highlightColor: const Color(0xFFFDE047), // Chữ vàng in đậm
        glowColor: const Color(0xFFFDE047),
      );
    } else if (rank != null && rank <= 10) {
      // Top 10: Ngọn lửa ngọc lam kèm tag "NGÔI SAO ĐANG LÊN"
      return _ReportTheme(
        badgeIcon: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0F2FE), Color(0xFF38BDF8), Color(0xFF0284C7)],
          ).createShader(bounds),
          child: const Icon(
            Icons.local_fire_department_rounded,
            size: 36,
            color: Colors.white,
          ),
        ),
        badgeLabel: 'TOP $rank',
        badgeOuterGradient: const [
          Color(0xFFA5F3FC),
          Color(0xFF22D3EE),
          Color(0xFF0891B2),
        ],
        badgeInnerGradient: const [
          Color(0xFF06B6D4),
          Color(0xFF0E7490),
        ],
        badgeBorderColor: const Color(0xFFE0F2FE),
        badgeTextColor: const Color(0xFF083344),
        badgeShadowColor: const Color(0xFF06B6D4),
        tagText: '🔥 NGÔI SAO ĐANG LÊN',
        tagTextColor: const Color(0xFF67E8F9),
        tagBorderColor: const Color(0xFF22D3EE).withValues(alpha: 0.5),
        tagBgColor: const Color(0xFF06B6D4).withValues(alpha: 0.22),
        title: '🚀 CHÚC MỪNG BẠN LỌT TOP 10! 🚀',
        titleColor: Colors.white,
        subtitlePrefix:
            'Bạn đang nằm trong nhóm những người dùng xuất sắc nhất với vị trí ',
        rankHighlight: 'HẠNG $rank',
        subtitleSuffix:
            '! Hãy giữ vững đà tiến này và chinh phục các cột mốc tiếp theo nhé!',
        highlightColor: const Color(0xFF67E8F9),
        glowColor: const Color(0xFF38BDF8),
      );
    }

    // Ngoài Top 10 hoặc Chưa có hạng: Ngọn lửa ngọc lam kèm tag "NGÔI SAO ĐANG LÊN"
    return _ReportTheme(
      badgeIcon: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0F2FE), Color(0xFF38BDF8), Color(0xFF0284C7)],
        ).createShader(bounds),
        child: const Icon(
          Icons.local_fire_department_rounded,
          size: 36,
          color: Colors.white,
        ),
      ),
      badgeLabel: 'BỨT PHÁ',
      badgeOuterGradient: const [
        Color(0xFFA5F3FC),
        Color(0xFF22D3EE),
        Color(0xFF0891B2),
      ],
      badgeInnerGradient: const [
        Color(0xFF06B6D4),
        Color(0xFF0E7490),
      ],
      badgeBorderColor: const Color(0xFFE0F2FE),
      badgeTextColor: const Color(0xFF083344),
      badgeShadowColor: const Color(0xFF06B6D4),
      tagText: '🔥 NGÔI SAO ĐANG LÊN',
      tagTextColor: const Color(0xFF67E8F9),
      tagBorderColor: const Color(0xFF22D3EE).withValues(alpha: 0.5),
      tagBgColor: const Color(0xFF06B6D4).withValues(alpha: 0.22),
      title: '🔥 CỐ LÊN! TIẾN RẤT GẦN TOP 10! 🔥',
      titleColor: Colors.white,
      subtitlePrefix:
          'Mọi sự cố gắng đều mang lại kết quả! Bạn chỉ còn cách Top 10 một khoảng ngắn nữa để bước vào ',
      rankHighlight: 'BẢNG XẾP HẠNG',
      subtitleSuffix:
          '. Tiếp tục luyện tập và bứt phá ngay trong hôm nay nhé!',
      highlightColor: const Color(0xFF67E8F9),
      glowColor: const Color(0xFF38BDF8),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getTheme(_resolvedRank);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Khung thẻ chính kèm viền phát sáng tự động chạy quanh khung
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 38), // Chừa khoảng trống cho huy hiệu nổi trên đỉnh
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return CustomPaint(
                  foregroundPainter: _AutoGlowSweepBorderPainter(
                    progress: _glowController.value,
                    glowColor: theme.glowColor,
                    borderRadius: BorderRadius.circular(28),
                    borderWidth: 2.2,
                  ),
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 50, 22, 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF2563EB),
                      Color(0xFF1D4ED8),
                      Color(0xFF1E40AF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF002878).withValues(alpha: 0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                    BoxShadow(
                      color: theme.glowColor.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Tag danh hiệu viên thuốc
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.tagBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: theme.tagBorderColor, width: 1.2),
                      ),
                      child: Text(
                        theme.tagText,
                        style: GoogleFonts.baloo2(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: theme.tagTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tiêu đề nổi bật
                    Text(
                      theme.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: theme.titleColor,
                        height: 1.25,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Nội dung mô tả kèm rank highlight màu vàng & in đậm
                    Text.rich(
                      TextSpan(
                        style: GoogleFonts.baloo2(
                          fontSize: 13.5,
                          color: const Color(0xFFF0F5FF),
                          height: 1.45,
                        ),
                        children: [
                          TextSpan(text: theme.subtitlePrefix),
                          TextSpan(
                            text: theme.rankHighlight,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: theme.highlightColor,
                            ),
                          ),
                          TextSpan(text: theme.subtitleSuffix),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Nút duy nhất: "Về Trang Chủ ->" (Nổi bật màu trắng chữ xanh)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _autoCloseTimer?.cancel();
                          widget.onGoHome();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1D4ED8),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 4,
                          shadowColor: Colors.black.withValues(alpha: 0.25),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Về Trang Chủ',
                              style: GoogleFonts.baloo2(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Color(0xFF1D4ED8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Huy hiệu nổi (Floating Badge phá cách trên đỉnh)
          Positioned(
            top: 0,
            child: Transform.rotate(
              angle: 0.05,
              child: Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: theme.badgeOuterGradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.badgeShadowColor.withValues(alpha: 0.5),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: theme.badgeInnerGradient,
                    ),
                    border: Border.all(
                      color: theme.badgeBorderColor,
                      width: 2,
                    ),
                  ),
                  child: Transform.rotate(
                    angle: -0.05,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        theme.badgeIcon,
                        const SizedBox(height: 2),
                        Text(
                          theme.badgeLabel,
                          style: GoogleFonts.baloo2(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: theme.badgeTextColor,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoGlowSweepBorderPainter extends CustomPainter {
  final double progress;
  final Color glowColor;
  final BorderRadius borderRadius;
  final double borderWidth;

  _AutoGlowSweepBorderPainter({
    required this.progress,
    required this.glowColor,
    required this.borderRadius,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final halfWidth = borderWidth / 2;
    final rect = Rect.fromLTWH(
      halfWidth,
      halfWidth,
      size.width - borderWidth,
      size.height - borderWidth,
    );
    final rrect = borderRadius.toRRect(rect);

    // 1. Viền mờ nền nhẹ
    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect, basePaint);

    // 2. Viền vệt sáng rộng mờ (Soft outer glow aura)
    final auraPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth * 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: 2 * pi,
        transform: GradientRotation(progress * 2 * pi),
        colors: [
          Colors.transparent,
          glowColor.withValues(alpha: 0.0),
          glowColor.withValues(alpha: 0.25),
          glowColor.withValues(alpha: 0.6),
          Colors.white.withValues(alpha: 0.7),
          glowColor.withValues(alpha: 0.6),
          glowColor.withValues(alpha: 0.25),
          glowColor.withValues(alpha: 0.0),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.44, 0.48, 0.5, 0.52, 0.56, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, auraPaint);

    // 3. Vệt sáng sắc nét trung tâm (Sharp bright core beam)
    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: 2 * pi,
        transform: GradientRotation(progress * 2 * pi),
        colors: [
          Colors.transparent,
          glowColor.withValues(alpha: 0.0),
          glowColor.withValues(alpha: 0.4),
          glowColor,
          Colors.white,
          glowColor,
          glowColor.withValues(alpha: 0.4),
          glowColor.withValues(alpha: 0.0),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.44, 0.48, 0.5, 0.52, 0.56, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _AutoGlowSweepBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class _ReportTheme {
  final Widget badgeIcon;
  final String badgeLabel;
  final List<Color> badgeOuterGradient;
  final List<Color> badgeInnerGradient;
  final Color badgeBorderColor;
  final Color badgeTextColor;
  final Color badgeShadowColor;
  final String tagText;
  final Color tagTextColor;
  final Color tagBorderColor;
  final Color tagBgColor;
  final String title;
  final Color titleColor;
  final String subtitlePrefix;
  final String rankHighlight;
  final String subtitleSuffix;
  final Color highlightColor;
  final Color glowColor;

  const _ReportTheme({
    required this.badgeIcon,
    required this.badgeLabel,
    required this.badgeOuterGradient,
    required this.badgeInnerGradient,
    required this.badgeBorderColor,
    required this.badgeTextColor,
    required this.badgeShadowColor,
    required this.tagText,
    required this.tagTextColor,
    required this.tagBorderColor,
    required this.tagBgColor,
    required this.title,
    required this.titleColor,
    required this.subtitlePrefix,
    required this.rankHighlight,
    required this.subtitleSuffix,
    required this.highlightColor,
    required this.glowColor,
  });
}
