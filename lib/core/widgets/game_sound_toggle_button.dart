import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';

/// Nút công tắc bật / tắt giọng đọc phát âm (TTS) dùng chung cho tất cả mini-game & màn hình học tập.
/// Đồng bộ 1 kiểu thiết kế duy nhất cho toàn bộ app: 3D Gel Candy squircle badge.
/// - Màu XANH là BẬT (Icons.volume_up_rounded)
/// - Màu XÁM là TẮT (Icons.volume_off_rounded)
class GameSoundToggleButton extends StatelessWidget {
  final Color? color;
  final double size;
  final EdgeInsetsGeometry? padding;
  final bool showSnackbar;
  final bool isPlayScreen;
  final ValueChanged<bool>? onToggled;

  static DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  const GameSoundToggleButton({
    super.key,
    this.color,
    this.size = 38,
    this.padding,
    this.showSnackbar = true,
    this.isPlayScreen = true,
    this.onToggled,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TtsService.instance.isEnabledNotifier,
      builder: (context, isEnabled, child) {
        return Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 4),
          child: Center(
            child: Tooltip(
              message: isEnabled ? 'Tắt giọng đọc' : 'Bật giọng đọc',
              child: GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  if (now.difference(_lastTapTime).inMilliseconds < 450) {
                    return; // Chống spam click dồn dập
                  }
                  _lastTapTime = now;
                  Feedback.forTap(context);

                  await TtsService.instance.toggleEnabled();
                  final nowEnabled = TtsService.instance.isEnabled;
                  onToggled?.call(nowEnabled);

                  if (showSnackbar && context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(milliseconds: 1200),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        backgroundColor: nowEnabled
                            ? AppColors.primary
                            : const Color(0xFF475569),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        content: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              nowEnabled
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_off_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              nowEnabled
                                  ? 'Đã bật giọng đọc phát âm 🔊'
                                  : 'Đã tắt giọng đọc phát âm 🔇',
                              style: GoogleFonts.baloo2(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
                child: _buildCandyButton(context, isEnabled),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Nút 3D Gel Candy squircle đồng bộ cho toàn bộ màn hình:
  /// - BẬT: Xanh đại dương tươi sáng [Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFF0369A1)]
  /// - TẮT: Xám chuyển sắc [Color(0xFF94A3B8), Color(0xFF64748B), Color(0xFF475569)]
  Widget _buildCandyButton(BuildContext context, bool isEnabled) {
    final gradientColors = isEnabled
        ? const [Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFF0369A1)]
        : const [Color(0xFF94A3B8), Color(0xFF64748B), Color(0xFF475569)];
    final shadowColor = isEnabled ? const Color(0xFF0284C7) : const Color(0xFF64748B);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.25),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        isEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
        color: Colors.white,
        size: size * 0.58,
      ),
    );
  }
}
