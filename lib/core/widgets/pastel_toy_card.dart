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
    this.showPillReflection = true,
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

              // Nội dung chính
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (label != null) ...[
                        Text(
                          label!,
                          style: GoogleFonts.baloo2(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: textColor.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      if (title != null) ...[
                        Text(
                          title!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.baloo2(
                            fontSize: fontSize ??
                                (title!.length > 12
                                    ? 16
                                    : (title!.length > 7 ? 20 : 26)),
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      ?child,
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
        color: colorConfig.background,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Glossy pill reflection
              Positioned(
                top: 8,
                left: 14,
                child: Transform.rotate(
                  angle: -0.26,
                  child: Container(
                    width: 24,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tagText,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: colorConfig.text,
                                  ),
                                ),
                              ),
                              if (chipText != null && chipText!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorConfig.text.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    chipText!,
                                    style: GoogleFonts.baloo2(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: colorConfig.text,
                                    ),
                                  ),
                                ),
                              ],
                              if (stars != null && stars! > 0) ...[
                                const Spacer(),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(
                                    3,
                                    (idx) => Icon(
                                      Icons.star_rounded,
                                      size: 15,
                                      color: idx < stars!
                                          ? const Color(0xFFFFB300)
                                          : colorConfig.text.withValues(alpha: 0.2),
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
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: colorConfig.text,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: GoogleFonts.baloo2(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: colorConfig.text.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: colorConfig.text,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

