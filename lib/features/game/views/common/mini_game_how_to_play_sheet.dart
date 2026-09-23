import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

class GameTutorialStep {
  final int stepNumber;
  final String title;
  final String description;
  final IconData icon;
  final Color themeColor;
  final Widget? illustration;

  const GameTutorialStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.icon,
    required this.themeColor,
    this.illustration,
  });
}

class MiniGameHowToPlaySheet extends StatelessWidget {
  final String gameTitle;
  final String subtitle;
  final List<GameTutorialStep> steps;
  final String tipText;
  final VoidCallback onStart;

  const MiniGameHowToPlaySheet({
    super.key,
    required this.gameTitle,
    this.subtitle = 'Bé chạm & ghép thật dễ dàng!',
    required this.steps,
    required this.tipText,
    required this.onStart,
  });

  static Future<void> show(
    BuildContext context, {
    required String gameTitle,
    String subtitle = 'Bé chạm & ghép thật dễ dàng!',
    required List<GameTutorialStep> steps,
    required String tipText,
    required VoidCallback onStart,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MiniGameHowToPlaySheet(
        gameTitle: gameTitle,
        subtitle: subtitle,
        steps: steps,
        tipText: tipText,
        onStart: onStart,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),

            // Header Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFDCBB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: Color(0xFF885200),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'HƯỚNG DẪN NHANH 1 PHÚT',
                          style: GoogleFonts.baloo2(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF885200),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cách Chơi ',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.baloo2(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF191C1E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Step cards (Scrollable)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    ...steps.map((step) => _buildStepCard(step)),
                    const SizedBox(height: 12),

                    // Tip pill from HocDi
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6E8EB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lightbulb_rounded,
                            size: 20,
                            color: Color(0xFF885200),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.baloo2(
                                  fontSize: 12,
                                  color: const Color(0xFF3F4852),
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Mẹo nhỏ: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF191C1E),
                                    ),
                                  ),
                                  TextSpan(text: tipText),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom CTA Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onStart();
                  },
                  icon: const Icon(Icons.rocket_launch_rounded, size: 22, color: Colors.white),
                  label: Text(
                    'Đã Hiểu & Bắt Đầu Chơi',
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 3,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(GameTutorialStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Step number circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: step.themeColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '',
                style: GoogleFonts.baloo2(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: step.themeColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Step details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'BƯỚC ',
                      style: GoogleFonts.baloo2(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: step.themeColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(step.icon, size: 15, color: step.themeColor),
                  ],
                ),
                Text(
                  step.title,
                  style: GoogleFonts.baloo2(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF191C1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.description,
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                if (step.illustration != null) ...[
                  const SizedBox(height: 8),
                  step.illustration!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
