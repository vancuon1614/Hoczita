import 'dart:math' as math;
import 'package:flutter/material.dart';

enum GameAnimationType {
  pulse,    // Phù hợp cho Đếm số (Quả táo thở nhẹ)
  rotate,   // Phù hợp cho Thêm bớt/Trắc nghiệm (Xoay tròn nhẹ)
  bounce,   // Phù hợp cho Chạy nhanh/Flashcard/Tàu hỏa (Nhấp nhô)
  swing,    // Phù hợp cho So sánh/Ghép cặp (Lắc lư qua lại)
}

class AnimatedGameIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final GameAnimationType animationType;

  const AnimatedGameIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 32,
    required this.animationType,
  });

  @override
  State<AnimatedGameIcon> createState() => _AnimatedGameIconState();
}

class _AnimatedGameIconState extends State<AnimatedGameIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Tạo AnimationController chạy lặp đi lặp lại vô hạn
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: widget.animationType != GameAnimationType.rotate);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.animationType) {
      case GameAnimationType.pulse:
        // Phóng to thu nhỏ nhẹ nhàng (breathing/pulse)
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.15).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
          ),
          child: Icon(widget.icon, size: widget.size, color: widget.color),
        );

      case GameAnimationType.rotate:
        // Xoay tròn liên tục
        return RotationTransition(
          turns: _controller,
          child: Icon(widget.icon, size: widget.size, color: widget.color),
        );

      case GameAnimationType.bounce:
        // Nhấp nhô lên xuống
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double translation = Tween<double>(begin: 0, end: -8)
                .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut))
                .value;
            return Transform.translate(
              offset: Offset(0, translation),
              child: Icon(widget.icon, size: widget.size, color: widget.color),
            );
          },
        );

      case GameAnimationType.swing:
        // Lắc lư qua lại trái phải
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double rotation = Tween<double>(begin: -0.15, end: 0.15)
                .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut))
                .value;
            return Transform.rotate(
              angle: rotation * math.pi,
              child: Icon(widget.icon, size: widget.size, color: widget.color),
            );
          },
        );
    }
  }
}
