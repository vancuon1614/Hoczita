import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GelCandyBadge extends StatelessWidget {
  final Widget? icon;
  final String? emoji;
  final double size;
  final List<Color> gradientColors;
  final Color shadowColor;
  final String? miniBadge;
  final Color? miniBadgeColor;
  final bool isOutlined;
  final Color? borderColor;
  final Color? backgroundColor;

  const GelCandyBadge({
    super.key,
    this.icon,
    this.emoji,
    this.size = 52,
    required this.gradientColors,
    required this.shadowColor,
    this.miniBadge,
    this.miniBadgeColor,
    this.isOutlined = false,
    this.borderColor,
    this.backgroundColor,
  }) : assert(icon != null || emoji != null);

  // Pre-configured Candy Styles
  factory GelCandyBadge.blue({
    Widget? icon,
    String? emoji,
    double size = 52,
    String? miniBadge,
  }) {
    return GelCandyBadge(
      icon: icon,
      emoji: emoji,
      size: size,
      gradientColors: const [Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFF0369A1)],
      shadowColor: const Color(0xFF0284C7),
      miniBadge: miniBadge,
      miniBadgeColor: const Color(0xFFBAE6FD),
    );
  }

  factory GelCandyBadge.green({
    Widget? icon,
    String? emoji,
    double size = 52,
    String? miniBadge,
  }) {
    return GelCandyBadge(
      icon: icon,
      emoji: emoji,
      size: size,
      gradientColors: const [Color(0xFF4ADE80), Color(0xFF16A34A), Color(0xFF15803D)],
      shadowColor: const Color(0xFF16A34A),
      miniBadge: miniBadge,
      miniBadgeColor: const Color(0xFFBBF7D0),
    );
  }

  factory GelCandyBadge.purple({
    Widget? icon,
    String? emoji,
    double size = 52,
    String? miniBadge,
  }) {
    return GelCandyBadge(
      icon: icon,
      emoji: emoji,
      size: size,
      gradientColors: const [Color(0xFFA855F7), Color(0xFF7E22CE), Color(0xFF6B21A8)],
      shadowColor: const Color(0xFF7E22CE),
      miniBadge: miniBadge,
      miniBadgeColor: const Color(0xFFE9D5FF),
    );
  }

  factory GelCandyBadge.orange({
    Widget? icon,
    String? emoji,
    double size = 52,
    String? miniBadge,
  }) {
    return GelCandyBadge(
      icon: icon,
      emoji: emoji,
      size: size,
      gradientColors: const [Color(0xFFFB923C), Color(0xFFEA580C), Color(0xFFC2410C)],
      shadowColor: const Color(0xFFEA580C),
      miniBadge: miniBadge,
      miniBadgeColor: const Color(0xFFFFEDD5),
    );
  }

  factory GelCandyBadge.grey({
    Widget? icon,
    String? emoji,
    double size = 52,
    String? miniBadge,
  }) {
    return GelCandyBadge(
      icon: icon,
      emoji: emoji,
      size: size,
      gradientColors: const [Color(0xFF94A3B8), Color(0xFF64748B), Color(0xFF475569)],
      shadowColor: const Color(0xFF64748B),
      miniBadge: miniBadge,
      miniBadgeColor: const Color(0xFFCBD5E1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? (gradientColors.isNotEmpty ? gradientColors[1] : shadowColor);
    final isOutlineMode = isOutlined || backgroundColor != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Modern iOS Educational Squircle Badge (des.zip style)
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.32),
            color: isOutlineMode ? (backgroundColor ?? Colors.white) : null,
            gradient: isOutlineMode
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
            boxShadow: [
              BoxShadow(
                color: (isOutlineMode ? effectiveBorderColor : shadowColor)
                    .withValues(alpha: isOutlineMode ? 0.12 : 0.22),
                offset: const Offset(0, 3),
                blurRadius: isOutlineMode ? 6 : 8,
              ),
            ],
            border: Border.all(
              color: isOutlineMode ? effectiveBorderColor : Colors.white.withValues(alpha: 0.35),
              width: isOutlineMode ? 2.0 : 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: emoji != null
              ? Text(
                  emoji!,
                  style: TextStyle(
                    fontSize: size * 0.52,
                  ),
                )
              : Theme(
                  data: Theme.of(context).copyWith(
                    iconTheme: IconThemeData(
                      color: isOutlineMode ? effectiveBorderColor : Colors.white,
                      size: size * 0.54,
                    ),
                  ),
                  child: icon!,
                ),
        ),

        // Corner Mini Badge (des.zip style - e.g. 100, A1-C1)
        if (miniBadge != null)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: miniBadgeColor ?? const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                miniBadge!,
                style: GoogleFonts.baloo2(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
