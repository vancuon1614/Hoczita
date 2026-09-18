import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/chat_context_provider.dart';
import '../services/chat_service.dart';

class ChatPanel extends ConsumerStatefulWidget {
  const ChatPanel({super.key});

  static Future<void> show(BuildContext context, WidgetRef ref) async {
    ref.read(isChatPanelOpenProvider.notifier).state = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const ChatPanel(),
      );
    } finally {
      ref.read(isChatPanelOpenProvider.notifier).state = false;
    }
  }

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Tin nhắn chào mừng ban đầu
    _messages.add(
      ChatMessage(
        id: 'welcome',
        text: 'Chào bạn! Mình là HocDi 🤖 - trợ lý học tập thông minh và là người bạn đồng hành của bạn. Bạn có thắc mắc về từ vựng, toán học hay bài tập, cứ hỏi HocDi nhé! 🌟',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage([String? predefinedText]) async {
    final text = (predefinedText ?? _textController.text).trim();
    if (text.isEmpty || _isLoading) return;

    if (predefinedText == null) {
      _textController.clear();
    }

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    final currentContext = ref.read(chatContextProvider);

    try {
      final replyText = await ChatService.instance.sendMessage(
        message: text,
        context: currentContext,
      );

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
              text: replyText,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
              text: 'Xin lỗi bạn, mạng đang hơi chập chờn. Bạn thử hỏi lại lần nữa nhé! 🔄',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  String _getContextDisplayName(ChatContext? context) {
    if (context == null) return 'Gia sư Tiếng Anh';
    return switch (context.screenName) {
      'magic_words_game' => 'Trợ giúp: Trạm Từ Diệu Kỳ 🔤',
      'sudoku_game' => 'Trợ giúp: Sudoku Trí Tuệ 🔢',
      'magic_number_path' => 'Trợ giúp: Đường Số Diệu Kỳ 🛤️',
      'flashcard_study' => 'Trợ giúp: Thẻ Từ Vựng 📚',
      _ => 'Học tập & Rèn luyện',
    };
  }

  List<String> _getQuickSuggestions(ChatContext? context) {
    if (context?.screenName == 'magic_words_game') {
      return ['💡 Gợi ý cho mình nhé', '📖 Giải thích nghĩa từ', '🎯 Cách chơi game này'];
    }
    if (context?.screenName == 'sudoku_game') {
      return ['💡 Mẹo giải hàng này', '🔢 Hướng dẫn luật Sudoku'];
    }
    return ['📚 Cho ví dụ câu tiếng Anh', '✨ Gửi lời động viên'];
  }

  @override
  Widget build(BuildContext context) {
    final currentContext = ref.watch(chatContextProvider);
    final suggestions = _getQuickSuggestions(currentContext);

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // 1. THANH HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HocDi - Trợ Lý Học Tập',
                        style: GoogleFonts.baloo2(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        _getContextDisplayName(currentContext),
                        style: GoogleFonts.baloo2(
                          fontSize: 13,
                          color: const Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // 2. DANH SÁCH TIN NHẮN
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Loading indicator khi AI đang soạn câu trả lời
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'HocDi đang suy nghĩ...',
                    style: GoogleFonts.baloo2(fontSize: 13.5, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),

          // 3. GỢI Ý CÂU HỎI NHANH (QUICK SUGGESTIONS)
          if (suggestions.isNotEmpty && !_isLoading)
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(
                        suggestions[index],
                        style: GoogleFonts.baloo2(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1D4ED8)),
                      ),
                      backgroundColor: const Color(0xFFEFF6FF),
                      side: BorderSide(color: Colors.blue.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onPressed: () => _handleSendMessage(suggestions[index]),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          // 4. THANH NHẬP LIỆU
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _textController,
                      style: GoogleFonts.baloo2(fontSize: 15, color: const Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: 'Hỏi HocDi về bài học...',
                        hintStyle: GoogleFonts.baloo2(fontSize: 15, color: const Color(0xFF94A3B8)),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _handleSendMessage,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFDBEAFE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 18, color: Color(0xFF1D4ED8)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF2563EB) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: GoogleFonts.baloo2(
                  fontSize: 15,
                  color: isUser ? Colors.white : const Color(0xFF1E293B),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
