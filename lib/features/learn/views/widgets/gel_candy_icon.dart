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

  const GelCandyBadge({
    super.key,
    this.icon,
    this.emoji,
    this.size = 52,
    required this.gradientColors,
    required this.shadowColor,
    this.miniBadge,
    this.miniBadgeColor,
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 3D Gel Candy Base Container
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.38),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            boxShadow: [
              // 3D Bottom Depth Shadow
              BoxShadow(
                color: shadowColor.withValues(alpha: 0.42),
                offset: const Offset(0, 5),
                blurRadius: 10,
                spreadRadius: 0,
              ),
              // Soft Ambient Glow
              BoxShadow(
                color: shadowColor.withValues(alpha: 0.18),
                offset: const Offset(0, 1),
                blurRadius: 3,
                spreadRadius: 1,
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              // Glossy Reflection Highlight (Top Half Dome)
              Positioned(
                top: 2,
                left: 4,
                right: 4,
                height: size * 0.42,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(size * 0.36),
                      bottom: Radius.circular(size * 0.15),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.55),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
              ),
              // Centered Icon or Emoji
              Center(
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
                            color: Colors.white,
                            size: size * 0.54,
                          ),
                        ),
                        child: icon!,
                      ),
              ),
            ],
          ),
        ),

        // Optional Mini Accent Badge (e.g. ✨, 🌟, 🚀)
        if (miniBadge != null)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: miniBadgeColor ?? Colors.amber.shade300,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                miniBadge!,
                style: GoogleFonts.baloo2(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
