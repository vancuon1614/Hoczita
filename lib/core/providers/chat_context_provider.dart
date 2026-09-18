import 'package:flutter_riverpod/legacy.dart';

class ChatContext {
  final String screenName; // 'magic_words_game', 'flashcard_study', 'home'...
  final Map<String, dynamic> data; // Dữ liệu KHÔNG NHẠY CẢM liên quan (từ đang chơi, chủ đề đang học...)

  ChatContext({required this.screenName, this.data = const {}});
}

final chatContextProvider = StateProvider<ChatContext?>((ref) => null);
