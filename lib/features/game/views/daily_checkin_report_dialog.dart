import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class TodayRankData {
  final int rank;
  final int totalPlayersToday;
  final int yourScore;
  final double averageScore;

  TodayRankData({
    required this.rank,
    required this.totalPlayersToday,
    required this.yourScore,
    required this.averageScore,
  });
}

class DailyCheckinReportDialog extends StatefulWidget {
  final int foundPaths;
  final int pointsEarned;
  final int currentStreak;
  final int? initialRank;
  final VoidCallback onPlayAgain;
  final VoidCallback onGoHome;

  const DailyCheckinReportDialog({
    super.key,
    required this.foundPaths,
    required this.pointsEarned,
    required this.currentStreak,
    this.initialRank,
    required this.onPlayAgain,
    required this.onGoHome,
  });

  @override
  State<DailyCheckinReportDialog> createState() => _DailyCheckinReportDialogState();
}

class _DailyCheckinReportDialogState extends State<DailyCheckinReportDialog>
    with SingleTickerProviderStateMixin {
  late Future<TodayRankData> _rankFuture;
  late AnimationController _confettiController;
  Timer? _autoCloseTimer;
  int? _resolvedRank;

  @override
  void initState() {
    super.initState();
    _resolvedRank = widget.initialRank;
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _fetchRank();

    // Tự động đóng popup sau 5 giây theo yêu cầu
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  void _fetchRank() {
    _rankFuture = SupabaseService.instance.saveAndGetTodayRank(widget.foundPaths).then((data) {
      final rank = data['rank'] as int;
      if (mounted && _resolvedRank != rank) {
        setState(() {
          _resolvedRank = rank;
        });
      }
      return TodayRankData(
        rank: rank,
        totalPlayersToday: data['totalPlayersToday'] as int,
        yourScore: data['yourScore'] as int,
        averageScore: (data['averageScore'] as num).toDouble(),
      );
    });
  }

  Map<String, String> _getHeaderInfo(int? rank) {
    if (rank == 1) {
      return {
        'emoji': '👑',
        'title': '🎉 XUẤT SẮC! BẠN ĐANG DẪN ĐẦU! 🎉',
        'subtitle':
            'Sự nỗ lực không ngừng nghỉ đã đưa bạn lên vị trí TOP 1. Đây là khoảnh khắc của bạn! Hãy tiếp tục giữ vững phong độ và thiết lập kỷ lục mới nhé!',
      };
    } else if (rank == 2 || rank == 3) {
      return {
        'emoji': '✨',
        'title': '✨ TUYỆT VỜI! BẠN ĐÃ VÀO TOP 3! ✨',
        'subtitle':
            'Phong độ của bạn đang cực kỳ ấn tượng! Bạn đã tiến rất gần đến đỉnh cao nhất. Hãy bứt phá mạnh mẽ hơn nữa trong hôm nay để vươn lên vị trí TOP 1 nhé!',
      };
    } else if (rank != null && rank <= 10) {
      return {
        'emoji': '🚀',
        'title': '🚀 CHÚC MỪNG BẠN LỌT TOP 10! 🚀',
        'subtitle':
            'Bạn đang nằm trong nhóm những người dùng xuất sắc nhất! Hãy giữ vững đà tiến này và chinh phục các cột mốc tiếp theo nhé!',
      };
    } else if (rank != null && rank > 10) {
      return {
        'emoji': '🔥',
        'title': '🔥 CỐ LÊN! BẠN TIẾN RẤT GẦN TOP 10! 🔥',
        'subtitle':
            'Mọi sự cố gắng đều mang lại kết quả. Bạn chỉ còn cách Top 10 một khoảng ngắn nữa thôi! Tiếp tục luyện tập để ghi tên mình vào Bảng Xếp Hạng ngay hôm nay!',
      };
    }
    return {
      'emoji': '✨',
      'title': '🎉 ĐIỂM DANH THÀNH CÔNG! 🎉',
      'subtitle':
          'Phong độ của bạn đang rất ấn tượng! Hãy tiếp tục duy trì và bứt phá mạnh mẽ hơn nữa nhé!',
    };
  }

  @override
  Widget build(BuildContext context) {
    final headerInfo = _getHeaderInfo(_resolvedRank);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Confetti background effect (simple scale/fade for celebration)
              Positioned.fill(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.1).animate(
                    CurvedAnimation(parent: _confettiController, curve: Curves.easeOut),
                  ),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                      CurvedAnimation(parent: _confettiController, curve: const Interval(0.5, 1.0)),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primaryLight.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                          radius: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min, // shrink to fit, no extra empty spaces
                children: [
                  // Header Gradient
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6B48FF), AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          headerInfo['emoji']!,
                          style: const TextStyle(fontSize: 40),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          headerInfo['title']!,
                          style: GoogleFonts.baloo2(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.25,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          headerInfo['subtitle']!,
                          style: GoogleFonts.baloo2(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.95),
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Badges Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildBadge(
                              icon: Icons.star_rounded,
                              text: "+${widget.pointsEarned} điểm",
                              bgColor: Colors.orange.withValues(alpha: 0.15),
                              textColor: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 12),
                            _buildBadge(
                              icon: Icons.local_fire_department_rounded,
                              text: "${widget.currentStreak} ngày liên tiếp",
                              bgColor: AppColors.error.withValues(alpha: 0.1),
                              textColor: AppColors.error,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min, // only 3 rows, no empty space
                            children: [
                              _buildInfoRow(
                                icon: Icons.stars_rounded,
                                iconColor: Colors.amber,
                                title: "Điểm hoàn thành:",
                                valueWidget: Text(
                                  "${widget.foundPaths} điểm",
                                  style: GoogleFonts.baloo2(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const Divider(height: 24),
                              
                              // FutureBuilder for Rank & Average
                              FutureBuilder<TodayRankData>(
                                future: _rankFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return _buildLoadingRank();
                                  } else if (snapshot.hasError) {
                                    return _buildErrorRank();
                                  } else if (snapshot.hasData) {
                                    return _buildSuccessRank(snapshot.data!);
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                onPressed: () {
                                  _autoCloseTimer?.cancel();
                                  widget.onPlayAgain();
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  side: const BorderSide(color: AppColors.primaryLight, width: 2),
                                ),
                                child: Text(
                                  'Chơi Lại',
                                  style: GoogleFonts.baloo2(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () {
                                  _autoCloseTimer?.cancel();
                                  widget.onGoHome();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Về Trang Chủ',
                                  style: GoogleFonts.baloo2(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Button "X" phía bên trên bên trái của hộp thoại để tắt
              Positioned(
                top: 10,
                left: 10,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      _autoCloseTimer?.cancel();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({required IconData icon, required String text, required Color bgColor, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.baloo2(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required Color iconColor, required String title, required Widget valueWidget}) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.baloo2(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        valueWidget,
      ],
    );
  }

  // --- Network States for Rank ---

  Widget _buildLoadingRank() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          icon: Icons.emoji_events_rounded,
          iconColor: Colors.amber,
          title: "Vị trí hôm nay:",
          valueWidget: _buildPulsePlaceholder(width: 80, height: 20),
        ),
        const SizedBox(height: 16),
        Text(
          "Trung bình người chơi:",
          style: GoogleFonts.baloo2(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        _buildPulsePlaceholder(width: double.infinity, height: 8),
      ],
    );
  }

  Widget _buildErrorRank() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          icon: Icons.emoji_events_rounded,
          iconColor: Colors.amber,
          title: "Vị trí hôm nay:",
          valueWidget: Text(
            "Đang cập nhật...",
            style: GoogleFonts.baloo2(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessRank(TodayRankData data) {
    // Determine status text & color
    String statusMsg;
    Color statusColor;
    if (data.rank == 1) {
      statusMsg = "👑 Đang đứng đầu bảng!";
      statusColor = AppColors.accent;
    } else if (data.rank == 2 || data.rank == 3) {
      statusMsg = "✨ Đang trong Top 3!";
      statusColor = AppColors.primary;
    } else if (data.rank <= 10) {
      statusMsg = "🎯 Top 10 xuất sắc!";
      statusColor = AppColors.success;
    } else {
      statusMsg = "🔥 Tiến rất gần Top 10!";
      statusColor = const Color(0xFFEA580C);
    }

    // Progress bar math (max score assumed around average * 2 for visual scale)
    double maxScale = max(widget.foundPaths.toDouble(), data.averageScore * 2);
    if (maxScale == 0) maxScale = 1; // prevent div by zero
    double userRatio = widget.foundPaths / maxScale;
    double avgRatio = data.averageScore / maxScale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          icon: Icons.emoji_events_rounded,
          iconColor: Colors.amber,
          title: "Vị trí hôm nay:",
          valueWidget: RichText(
            text: TextSpan(
              style: GoogleFonts.baloo2(fontSize: 16, color: AppColors.textPrimary),
              children: [
                const TextSpan(text: "Hạng "),
                TextSpan(
                  text: "${data.rank}",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                TextSpan(text: " / ${data.totalPlayersToday} bạn"),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Điểm trung bình:",
              style: GoogleFonts.baloo2(fontSize: 13, color: AppColors.textSecondary),
            ),
            Text(
              "${data.averageScore.toStringAsFixed(1)} điểm",
              style: GoogleFonts.baloo2(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Custom progress bar comparison
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Background
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // User Progress
            FractionallySizedBox(
              widthFactor: min(1.0, userRatio),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // Average marker
            Positioned(
              left: 0,
              right: 0,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: min(1.0, avgRatio),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 4,
                    height: 12,
                    transform: Matrix4.translationValues(0, -2, 0),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            statusMsg,
            style: GoogleFonts.baloo2(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }

  // Simple pulsing placeholder for loading state
  Widget _buildPulsePlaceholder({required double width, required double height}) {
    return _PulsePlaceholder(width: width, height: height);
  }
}

class _PulsePlaceholder extends StatefulWidget {
  final double width;
  final double height;
  const _PulsePlaceholder({required this.width, required this.height});

  @override
  State<_PulsePlaceholder> createState() => _PulsePlaceholderState();
}

class _PulsePlaceholderState extends State<_PulsePlaceholder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(widget.height / 2),
        ),
      ),
    );
  }
}
