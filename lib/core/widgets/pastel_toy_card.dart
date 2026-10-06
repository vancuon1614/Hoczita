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
                        color: Colors.white.withValues(alpha: 0.72),
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
