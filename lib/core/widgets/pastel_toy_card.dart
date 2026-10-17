import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PastelToyCardColor {
  final Color background;
  final Color text;

  const PastelToyCardColor({required this.background, required this.text});

  static const blue = PastelToyCardColor(
    background: Color(0xFFCFE5FF),
    text: Color(0xFF00375A),
  );

  static const orange = PastelToyCardColor(
    background: Color(0xFFFFDCBB),
    text: Color(0xFF663C00),
  );

  static const grey = PastelToyCardColor(
    background: Color(0xFFE6E8EB),
    text: Color(0xFF191C1E),
  );

  static const green = PastelToyCardColor(
    background: Color(0xFFD1FAE5),
    text: Color(0xFF003D1D),
  );

  static const List<PastelToyCardColor> standardFour = [blue, orange, grey, green];
}

class PastelToyCard extends StatelessWidget {
  final String? label;
  final String? title;
  final Widget? child;
  final PastelToyCardColor colorConfig;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool? isCorrect; // null: default, true: green border, false: red border
  final double borderRadius;
  final double? height;
  final double? fontSize;
  final bool showPillReflection;

  const PastelToyCard({
    super.key,
    this.label,
    this.title,
    this.child,
    this.colorConfig = PastelToyCardColor.blue,
    this.onTap,
    this.isSelected = false,
    this.isCorrect,
    this.borderRadius = 22,
    this.height = 110,
    this.fontSize,
    this.showPillReflection = false,
  });

  @override
  Widget build(BuildContext context) {
    Color cardBg = colorConfig.background;
    Color textColor = colorConfig.text;
    Border? border;

    if (isCorrect != null) {
      if (isCorrect == true) {
        cardBg = const Color(0xFF6CFE9F);
        border = Border.all(color: const Color(0xFF00B460), width: 3);
      } else {
        cardBg = const Color(0xFFFFDAD6);
        border = Border.all(color: const Color(0xFFBA1A1A), width: 3);
      }
    } else if (isSelected) {
      border = Border.all(color: textColor, width: 2.5);
    }

    String? displayLabel = label;
    if (displayLabel != null) {
      final trimmed = displayLabel.trim();
      final matchLegacy = RegExp(r'^(?:LỰA CHỌN|OPTION)\s*([A-Za-z0-9])$', caseSensitive: false).firstMatch(trimmed);
      if (matchLegacy != null) {
        displayLabel = '(${matchLegacy.group(1)!.toUpperCase()})';
      } else {
        final matchSingle = RegExp(r'^\(?([A-Za-z0-9])\)?$').firstMatch(trimmed);
        if (matchSingle != null) {
          displayLabel = '(${matchSingle.group(1)!.toUpperCase()})';
        }
      }
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: Stack(
            children: [
              // Vệt bóng viên thuốc nghiêng (Glossy Pill Reflection)
              if (showPillReflection)
                Positioned(
                  top: 8,
                  left: 14,
                  child: Transform.rotate(
                    angle: -0.26,
                    child: Container(
                      width: 22,
                      height: 6.5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

              // Nhãn lựa chọn ở góc trên cùng bên trái: (A), (B), (C), (D)...
              if (displayLabel != null)
                Positioned(
                  top: 9,
                  left: 14,
                  child: Text(
                    displayLabel,
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor.withValues(alpha: 0.70),
                      height: 1.0,
                    ),
                  ),
                ),

              // Nội dung chính: Đáp án ở vị trí trung tâm nổi bật (+2 đơn vị kích thước)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (title != null) ...[
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              title!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.baloo2(
                                fontSize: fontSize ??
                                    (title!.length > 12
                                        ? 18
                                        : (title!.length > 7 ? 22 : 28)),
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      if (child != null) Flexible(child: child!),
                    ],
                  ),
                ),
              ),

              // Badge Đúng / Sai ở góc phải khi trả lời
              if (isCorrect != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCorrect == true ? const Color(0xFF00B460) : const Color(0xFFBA1A1A),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCorrect == true ? Icons.check_rounded : Icons.close_rounded,
                      color: Colors.white,
                      size: 16,
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

/// Thẻ lựa chọn chế độ chơi phong cách Pastel Toy Card + Gel Candy 3D
class PastelModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String tagText;
  final String? chipText;
  final Widget icon;
  final PastelToyCardColor colorConfig;
  final VoidCallback onTap;
  final int? stars;

  const PastelModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tagText,
    this.chipText,
    required this.icon,
    required this.colorConfig,
    required this.onTap,
    this.stars,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorConfig.text.withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F6EA0).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: const Color(0xFF4F6EA0).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            child: Row(
              children: [
                icon,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: colorConfig.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tagText,
                              style: GoogleFonts.baloo2(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorConfig.text,
                              ),
                            ),
                          ),
                          if (chipText != null && chipText!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                chipText!,
                                style: GoogleFonts.baloo2(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: GoogleFonts.baloo2(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.baloo2(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

