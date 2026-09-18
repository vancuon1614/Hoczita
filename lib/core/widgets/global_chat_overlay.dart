import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/views/chat_panel.dart';
import '../providers/chat_context_provider.dart';

class GlobalChatOverlay extends ConsumerWidget {
  final Widget child;
  const GlobalChatOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isLoggedIn = authState.email != null;
    final isChatOpen = ref.watch(isChatPanelOpenProvider);

    return Stack(
      children: [
        child,
        if (isLoggedIn && !isChatOpen)
          Positioned(
            right: 16,
            bottom: 90, // Tránh đè lên bottom navigation bar
            child: Material(
              color: Colors.transparent,
              child: _ChatBubbleButton(
                onTap: () => ChatPanel.show(context, ref),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChatBubbleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ChatBubbleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF00629D), Color(0xFF00A3FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x4000629D),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
          ),
          Positioned(
            bottom: -6,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFE9D00),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
                  ],
                ),
                child: const Text(
                  'HocDi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
