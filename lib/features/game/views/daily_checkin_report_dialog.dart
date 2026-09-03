import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../../../core/theme/app_theme.dart';

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
  final VoidCallback onPlayAgain;
  final VoidCallback onGoHome;

  const DailyCheckinReportDialog({
    super.key,
    required this.foundPaths,
    required this.pointsEarned,
    required this.currentStreak,
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

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _fetchRank();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _fetchRank() {
    // Mock API call to GET /checkin/today-rank?userId={id}
    _rankFuture = Future.delayed(const Duration(seconds: 2), () {
      // simulate random network error 10% of the time
      if (Random().nextDouble() < 0.1) {
        throw Exception("Network Error");
      }
      return TodayRankData(
        rank: Random().nextInt(100) + 1,
        totalPlayersToday: 500,
        yourScore: widget.foundPaths,
        averageScore: max(1.0, widget.foundPaths - 2 + Random().nextDouble() * 4), // average around user score
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6B48FF), AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "🎉",
                          style: TextStyle(fontSize: 40),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Điểm Danh Thành Công!",
                          style: GoogleFonts.baloo2(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Thật tuyệt vời, bạn đã hoàn thành nhiệm vụ hôm nay!",
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
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
                                icon: Icons.link_rounded,
                                iconColor: Colors.blue,
                                title: "Số cách tìm được:",
                                valueWidget: Text(
                                  "${widget.foundPaths}",
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
                                onPressed: widget.onPlayAgain,
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
                                onPressed: widget.onGoHome,
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
    if (widget.foundPaths > data.averageScore) {
      statusMsg = "Bạn đang vượt trội!";
      statusColor = AppColors.success;
    } else if (widget.foundPaths == data.averageScore) {
      statusMsg = "Bạn đạt mức trung bình!";
      statusColor = AppColors.info;
    } else {
      statusMsg = "Hãy cố gắng hơn nhé!";
      statusColor = AppColors.accent;
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
              "Trung bình người chơi: ${data.averageScore.toStringAsFixed(1)} cách",
              style: GoogleFonts.baloo2(fontSize: 13, color: AppColors.textSecondary),
            ),
            Text(
              statusMsg,
              style: GoogleFonts.baloo2(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Custom progress bar comparison
        Stack(
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
                    margin: const EdgeInsets.only(top: -2), // protrude slightly
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
