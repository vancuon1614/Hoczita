import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hoczita_app/core/theme/app_theme.dart';
import 'package:hoczita_app/features/game/utils/game_rating_logic.dart';

class ResultReportSheet extends StatelessWidget {
  final GameType gameType;
  final int starCount;
  final Duration elapsedTime;
  final VoidCallback onReplay;
  final VoidCallback onGoHome;
  final Widget? customMiddleWidget;
  final Color? accentColor;
  final bool showStars;

  const ResultReportSheet({
    Key? key,
    required this.gameType,
    required this.starCount,
    required this.elapsedTime,
    required this.onReplay,
    required this.onGoHome,
    this.customMiddleWidget,
    this.accentColor,
    this.showStars = true,
  }) : super(key: key);

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // Tween animation for scaling and fading in
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: child,
          ),
        );
      },
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: (accentColor ?? Colors.amber).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '🏆',
                    style: TextStyle(fontSize: 40),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                resolveReportTitle(starCount),
                style: GoogleFonts.baloo2(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                resolveReportSubtitle(gameType),
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              if (customMiddleWidget != null) ...[
                customMiddleWidget!,
                const SizedBox(height: 16),
              ],
              
              if (showStars) ...[
                // Stars
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    bool earned = index < starCount;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(
                        earned ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: earned ? Colors.amber : Colors.grey.shade300,
                        size: 48,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
              ],
              
              // Time
              Text(
                "Thời gian hoàn thành: ${_formatDuration(elapsedTime)}",
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              
              // Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onReplay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Chơi Lại",
                    style: GoogleFonts.baloo2(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onGoHome,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: Text(
                  "Về Trang Chủ",
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
