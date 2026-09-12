import 'package:flutter/material.dart';

class CheckinCelebrationBanner {
  static void show(BuildContext context, {String? message, int? streakCount}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _CelebrationContent(
        message: message ?? 'Điểm danh thành công! 🎉',
        streakCount: streakCount,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _CelebrationContent extends StatefulWidget {
  final String message;
  final int? streakCount;
  final VoidCallback onDismiss;

  const _CelebrationContent({
    required this.message,
    required this.onDismiss,
    this.streakCount,
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

    Future.delayed(const Duration(seconds: 3), () async {
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
          borderRadius: BorderRadius.circular(16),
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.streakCount != null
                        ? '${widget.message} Chuỗi ${widget.streakCount} ngày!'
                        : widget.message,
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
