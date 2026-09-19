import 'package:flutter_riverpod/legacy.dart';

final isGameDraggingProvider = StateProvider<bool>((ref) => false);
final hasChatHintProvider = StateProvider<bool>((ref) => false); // badge chấm đỏ
