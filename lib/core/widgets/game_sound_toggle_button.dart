import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/tts_service.dart';

/// Nút công tắc bật / tắt giọng đọc phát âm (TTS) dùng chung cho tất cả mini-game Tiếng Anh & Toán học.
class GameSoundToggleButton extends StatelessWidget {
  final Color? color;
  final double size;
  final EdgeInsetsGeometry? padding;
  final bool showSnackbar;

  const GameSoundToggleButton({
    super.key,
    this.color,
    this.size = 22,
    this.padding,
    this.showSnackbar = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TtsService.instance.isEnabledNotifier,
      builder: (context, isEnabled, child) {
        return IconButton(
          icon: Icon(
            isEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            color: isEnabled
                ? (color ?? AppColors.primary)
                : AppColors.textSecondary.withValues(alpha: 0.5),
            size: size,
          ),
          padding: padding ?? const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          tooltip: isEnabled ? 'Tắt giọng đọc' : 'Bật giọng đọc',
          onPressed: () async {
            await TtsService.instance.toggleEnabled();
            final nowEnabled = TtsService.instance.isEnabled;

            if (showSnackbar && context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(milliseconds: 1200),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  backgroundColor: nowEnabled
                      ? AppColors.primary
                      : const Color(0xFF374151),
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
        );
      },
    );
  }
}
