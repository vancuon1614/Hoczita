import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Đồng hồ đếm thời gian tăng dần chuẩn (tiêu chuẩn English Crossword)
class GameCountUpTimer extends StatelessWidget {
  final String? timeString;
  final int? elapsedSeconds;
  final EdgeInsetsGeometry? margin;

  const GameCountUpTimer({
    super.key,
    this.timeString,
    this.elapsedSeconds,
    this.margin,
  }) : assert(timeString != null || elapsedSeconds != null, 'Phải truyền timeString hoặc elapsedSeconds');

  static String formatSeconds(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final displayStr = timeString ?? formatSeconds(elapsedSeconds!);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.timer_outlined,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            displayStr,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Đồng hồ đếm ngược thời gian chuẩn (tiêu chuẩn Flashcard Speedrun)
class GameCountdownTimer extends StatelessWidget {
  final double progress; // 0.0 -> 1.0 (1.0 là đầy, 0.0 là hết giờ)
  final int remainingSeconds;
  final int totalSeconds;
  final double size;
  final Color? customColor;

  const GameCountdownTimer({
    super.key,
    required this.progress,
    required this.remainingSeconds,
    this.totalSeconds = 10,
    this.size = 40.0,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    Color timerColor;
    if (customColor != null) {
      timerColor = customColor!;
    } else {
      if (remainingSeconds <= 3) {
        timerColor = AppColors.error;
      } else if (remainingSeconds <= (totalSeconds / 2).ceil()) {
        timerColor = AppColors.accent;
      } else {
        timerColor = AppColors.success;
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppColors.border,
            color: timerColor,
            strokeWidth: 4.5,
          ),
          Text(
            remainingSeconds.toString(),
            style: GoogleFonts.baloo2(
              fontSize: size * 0.35,
              fontWeight: FontWeight.bold,
              color: timerColor,
            ),
          ),
        ],
      ),
    );
  }
}
