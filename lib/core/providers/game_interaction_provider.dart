import 'package:flutter_riverpod/legacy.dart';

/// Báo cho AI chatbot biết người dùng đang kéo / vuốt / thao tác trong mini-game để tự động ẩn chatbot
final isGameDraggingProvider = StateProvider<bool>((ref) => false);

/// Báo cho AI chatbot biết người dùng đang ở trong màn chơi mini-game
final isGameActiveProvider = StateProvider<bool>((ref) => false);

/// Badge chấm đỏ trên bong bóng khi có gợi ý mới
final hasChatHintProvider = StateProvider<bool>((ref) => false);
