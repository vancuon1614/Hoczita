import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CheckinCelebrationBanner {
  static void show(BuildContext context, {String? message, int? streakCount, int? rank}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    String finalMessage = message ?? _resolveRankNotice(rank);

    entry = OverlayEntry(
      builder: (_) => _CelebrationContent(
        message: finalMessage,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  static String _resolveRankNotice(int? rank) {
    if (rank == 1) {
      return "👑 Bạn đang ở TOP 1! Phong độ đỉnh cao! Hãy tiếp tục duy trì để mọi người cố gắng theo nhé!";
    } else if (rank == 2 || rank == 3) {
      return "🔥 Xuất sắc! Bạn đã lọt TOP 3! Ngôi vương TOP 1 chỉ còn cách một bước chân. Bứt phá ngay!";
    } else if (rank != null && rank <= 10) {
      return "🌟 Giỏi lắm! Bạn đang thuộc TOP 10! Phong độ rất ổn định, thẳng tiến vào Top 3 thôi nào!";
    } else if (rank != null && rank > 10) {
      return "⚡ Top 10 đang ở rất gần! Chỉ cần thêm một chút cố gắng nữa thôi. Quay lại bứt phá ngay!";
    }
    return "🎉 Điểm danh thành công! Hãy giữ vững phong độ học tập nhé!";
  }
}

class _CelebrationContent extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _CelebrationContent({
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_CelebrationContent> createState() => _CelebrationContentState();
}

class _CelebrationContentState extends State<_CelebrationContent>
  with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _offset = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();

    Future.delayed(const Duration(seconds: 4), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offset,
        child: Material(
          elevation: 6,
          color: const Color(0xFFECFDF5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFA7F3D0), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.message,
                    style: GoogleFonts.baloo2(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF065F46),
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
