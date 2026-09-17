import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/word_completion_entry.dart';

class MagicWordsReportSheet extends StatefulWidget {
  final List<String> targetWords;
  final int secondsElapsed;
  final List<WordCompletionEntry> completionLog; // MỚI - thay cho việc chỉ dùng targetWords
  final VoidCallback onReplay;
  final VoidCallback onGoHome;

  const MagicWordsReportSheet({
    super.key,
    required this.targetWords,
    required this.secondsElapsed,
    required this.completionLog, // MỚI
    required this.onReplay,
    required this.onGoHome,
  });

  @override
  State<MagicWordsReportSheet> createState() => _MagicWordsReportSheetState();
}

class _MagicWordsReportSheetState extends State<MagicWordsReportSheet> {
  bool _isRewardOpened = false;

  String _formatDuration(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _getStationSpeedText(int index) {
    final entry = widget.completionLog[index];
    final prevElapsed = index == 0 ? 0 : widget.completionLog[index - 1].elapsedSeconds;
    final timeForThisWord = entry.elapsedSeconds - prevElapsed;
    final secondsPerLetter = timeForThisWord / entry.word.length;
    final isLast = index == widget.completionLog.length - 1;

    if (isLast) return 'Về đích ${timeForThisWord}s';
    if (secondsPerLetter <= 3) return 'Siêu nhanh ${timeForThisWord}s';
    if (secondsPerLetter <= 5) return 'Bứt phá ${timeForThisWord}s';
    if (secondsPerLetter <= 8) return 'Đạt chuẩn ${timeForThisWord}s';
    return 'Tăng tốc ${timeForThisWord}s';
  }

  static const List<Color> _nodeColors = [
    Color(0xFF10B981), // Emerald green
    Color(0xFF059669), // Teal green
    Color(0xFF0D9488), // Cyan teal
    Color(0xFF6366F1), // Indigo purple
    Color(0xFF8B5CF6), // Purple
  ];

  @override
  Widget build(BuildContext context) {
    final entries = widget.completionLog;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.85 + (0.15 * value),
            child: child,
          ),
        );
      },
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Trophy Badge
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFDE68A).withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        size: 46,
                        color: Color(0xFFEAB308),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 28,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Title & Subtitle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Kỷ Lục Mới!',
                      style: GoogleFonts.baloo2(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '⚡',
                      style: TextStyle(fontSize: 22),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2, bottom: 8),
                  width: 104,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                Text(
                  'Bé đã chinh phục thử thách với tốc độ đáng kinh ngạc!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Card with Station List & Reward Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      // Stations list
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: entries.length,                    // THAY: words.length
                        itemBuilder: (context, index) {
                          bool isLast = index == entries.length - 1;   // THAY: words.length - 1
                          Color nodeColor = _nodeColors[index % _nodeColors.length];
                          String word = entries[index].word;           // THAY: words[index]
                          String speedText = _getStationSpeedText(index); // THAY: bỏ 3 tham số cũ

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Timeline node & dashed line
                              Column(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: nodeColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (!isLast)
                                    CustomPaint(
                                      size: const Size(2.5, 26),
                                      painter: _DashedLinePainter(
                                        color: nodeColor,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),

                              // Middle: Station label + XP + speed text
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Trạm ${index + 1}: ${word.toUpperCase()}',
                                            style: GoogleFonts.baloo2(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '+25 XP',
                                              style: GoogleFonts.baloo2(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF059669),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        speedText,
                                        style: GoogleFonts.baloo2(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Right check box
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: const Color(0xFF22C55E),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 15,
                                    color: Color(0xFF22C55E),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),

                      // Reward Banner (Diamond + Gift)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFEF3C7), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF08A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: const Text('🎁', style: TextStyle(fontSize: 24)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '+100 Kim Cương 💎',
                                    style: GoogleFonts.baloo2(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF92400E),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.baloo2(
                                        fontSize: 12,
                                        color: const Color(0xFFB45309),
                                      ),
                                      children: const [
                                        TextSpan(text: 'Tiếp theo: '),
                                        TextSpan(
                                          text: 'Bậc Thầy Từ Vựng',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _isRewardOpened
                                  ? null
                                  : () {
                                      setState(() {
                                        _isRewardOpened = true;
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '🎉 Chúc mừng! Bạn nhận được +100 Kim Cương!',
                                            style: GoogleFonts.baloo2(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          backgroundColor: const Color(0xFFF59E0B),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isRewardOpened
                                    ? Colors.grey.shade300
                                    : const Color(0xFFF59E0B),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                _isRewardOpened ? 'ĐÃ MỞ' : 'MỞ',
                                style: GoogleFonts.baloo2(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _isRewardOpened
                                      ? Colors.grey.shade600
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 4. Completion Time
                Column(
                  children: [
                    Text(
                      'Thời gian hoàn thành: ${_formatDuration(widget.secondsElapsed)}',
                      style: GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 140,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE047),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 5. Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: widget.onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Chơi Lại',
                      style: GoogleFonts.baloo2(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onGoHome,
                  child: Text(
                    'Về Trang Chủ',
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
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

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    double dashHeight = 4;
    double dashSpace = 3;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, min(startY + dashHeight, size.height)),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
