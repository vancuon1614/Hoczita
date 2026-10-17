import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Đồng hồ đếm thời gian tăng dần chuẩn (tiêu chuẩn English Crossword)
class GameCountUpTimer extends StatelessWidget {
  final String? timeString;
  final int? elapsedSeconds;
  final EdgeInsetsGeometry? margin;

  final Color? textColor;
  final Color? bgColor;
  final Color? borderColor;

  const GameCountUpTimer({
    super.key,
    this.timeString,
    this.elapsedSeconds,
    this.margin,
    this.textColor,
    this.bgColor,
    this.borderColor,
  }) : assert(timeString != null || elapsedSeconds != null, 'Phải truyền timeString hoặc elapsedSeconds');

  static String formatSeconds(int seconds) {
    if (seconds >= 3600) {
      final hours = seconds ~/ 3600;
      final mins = (seconds % 3600) ~/ 60;
      final secs = seconds % 60;
      return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    String displayStr;
    if (elapsedSeconds != null) {
      displayStr = formatSeconds(elapsedSeconds!);
    } else if (timeString != null) {
      final clean = timeString!.replaceAll('s', '').trim();
      final parsedDouble = double.tryParse(clean);
      if (parsedDouble != null) {
        displayStr = formatSeconds(parsedDouble.round());
      } else {
        displayStr = timeString!;
      }
    } else {
      displayStr = '00:00';
    }

    final effectiveTextColor = textColor ?? const Color(0xFF0284C7);
    final effectiveBgColor = bgColor ?? Colors.white;
    final effectiveBorderColor = borderColor ?? const Color(0xFFBAE6FD);
    final bool isLong = displayStr.length > 5;
    final double containerWidth = isLong ? 96 : 80;
    final double textWidth = isLong ? 56 : 42;

    return Container(
      width: containerWidth,
      alignment: Alignment.center,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: effectiveBorderColor,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 15,
            color: effectiveTextColor,
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: textWidth,
            child: Text(
              displayStr,
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: effectiveTextColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
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
    final timerColor = customColor ?? const Color(0xFFDC2626);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFFEE2E2),
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
