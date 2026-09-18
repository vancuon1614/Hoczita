import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/providers/chat_context_provider.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatService {
  static final ChatService instance = ChatService._internal();
  ChatService._internal();

  /// Gửi tin nhắn đến Edge Function chat-tutor và nhận phản hồi từ AI
  Future<String> sendMessage({
    required String message,
    ChatContext? context,
  }) async {
    final supabase = SupabaseService.instance;
    final userId = supabase.isOfflineDemoMode
        ? 'demo_student'
        : supabase.client.auth.currentUser?.id;

    // 1. Nếu ở chế độ Offline Demo Mode hoặc chưa cấu hình Supabase -> Trả lời phản hồi thông minh cục bộ
    if (supabase.isOfflineDemoMode || !supabase.isConfigured) {
      await Future.delayed(const Duration(milliseconds: 1000));
      return _generateOfflineTutorReply(message, context);
    }

    // 2. Gọi Edge Function chat-tutor trên Supabase
    try {
      final response = await supabase.client.functions.invoke(
        'chat-tutor',
        body: {
          'userId': userId,
          'message': message,
          'context': context == null
              ? null
              : {
                  'screenName': context.screenName,
                  'data': context.data,
                },
        },
      ).timeout(const Duration(seconds: 15));

      if (response.status == 200 && response.data != null) {
        final reply = response.data['reply'] as String?;
        if (reply != null && reply.isNotEmpty) {
          return reply;
        }
      }

      if (response.status == 429) {
        return 'Bạn đã dùng hết lượt hỏi hôm nay rồi. Mai chúng mình lại cùng học tiếp nhé! 🌟';
      }

      throw Exception('Lỗi gọi AI: mã lỗi ${response.status}');
    } catch (e) {
      debugPrint('Error invoking chat-tutor: $e. Fallback to smart offline response.');
      return _generateOfflineTutorReply(message, context);
    }
  }

  /// Phản hồi dự phòng thông minh, thân thiện với lứa tuổi học sinh
  String _generateOfflineTutorReply(String message, ChatContext? context) {
    final lower = message.toLowerCase().trim();

    // Hỏi về game Magic Words
    if (context?.screenName == 'magic_words_game') {
      if (lower.contains('gợi ý') || lower.contains('hint') || lower.contains('giúp')) {
        final lengths = context?.data['unsolved_word_lengths'] as List?;
        if (lengths != null && lengths.isNotEmpty) {
          return 'HocDi thấy bạn còn các từ có độ dài ${lengths.join(", ")} chữ cái đó! Bạn thử tìm các chữ cái quen thuộc trên bảng rồi nối liền nhau xem sao nhé! 💡';
        }
        return 'Bạn hãy quan sát kỹ các góc của bảng chữ, tìm những nguyên âm (A, E, I, O, U) trước để dễ ghép thành từ tiếng Anh nha! 🌟';
      }
    }

    // Hỏi về game Sudoku
    if (context?.screenName == 'sudoku_game') {
      if (lower.contains('gợi ý') || lower.contains('cách chơi') || lower.contains('giúp')) {
        return 'Trong Sudoku, mỗi hàng ngang, hàng dọc và khối 3×3 đều phải chứa đủ các số từ 1 đến 9 không trùng lặp. Bạn hãy ưu tiên điền những hàng hoặc khối có sẵn nhiều số nhất trước nhé! 🔢';
      }
    }

    // Hỏi chào hỏi
    if (lower.contains('chào') || lower.contains('hello') || lower.contains('hi')) {
      return 'Chào bạn! HocDi rất vui được đồng hành cùng bạn. Hôm nay bạn muốn học từ vựng hay cần hỗ trợ bài tập nào nè? 🌈';
    }

    // Hỏi cảm ơn
    if (lower.contains('cảm ơn') || lower.contains('thank')) {
      return 'Không có chi nè! Cố gắng học tập thật tốt nhé, bạn làm rất tốt đó! 🎉';
    }

    // Câu trả lời chung khuyến khích
    return 'HocDi đã nhận được câu hỏi của bạn rồi! Bạn hãy tập trung vào bài học và mini-game hiện tại, nếu có từ nào chưa hiểu bạn cứ gõ từ đó ra để HocDi giải thích nha! 📚✨';
  }
}
