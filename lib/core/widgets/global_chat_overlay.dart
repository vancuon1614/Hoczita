import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/views/chat_panel.dart';
import '../providers/chat_context_provider.dart';
import '../providers/game_interaction_provider.dart';

class GlobalChatOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const GlobalChatOverlay({super.key, required this.child});

  @override
  ConsumerState<GlobalChatOverlay> createState() => _GlobalChatOverlayState();
}

class _GlobalChatOverlayState extends ConsumerState<GlobalChatOverlay>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(300, 500); // vị trí mặc định ban đầu
  bool _initializedPosition = false;
  bool _isDragging = false;
  bool _isPanelOpen = false;

  late AnimationController _attentionController;
  late Animation<double> _attentionScale;
  Timer? _attentionTimer;

  @override
  void initState() {
    super.initState();
    _attentionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _attentionScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _attentionController, curve: Curves.easeInOut),
    );
    _scheduleAttentionPulse();
  }

  void _scheduleAttentionPulse() {
    _attentionTimer?.cancel();
    _attentionTimer = Timer(const Duration(seconds: 45), () {
      if (!mounted) return;
      if (_isDragging || _isPanelOpen) {
        _scheduleAttentionPulse();
        return;
      }
      _attentionController.forward().then((_) {
        if (mounted) {
          _attentionController.reverse();
          _scheduleAttentionPulse();
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedPosition) {
      final size = MediaQuery.of(context).size;
      // Vị trí mặc định: sát cạnh phải, ngay phía trên bottom navigation bar
      _position = Offset(size.width - 76.0, size.height - 180.0);
      _initializedPosition = true;
    }
  }

  @override
  void dispose() {
    _attentionTimer?.cancel();
    _attentionController.dispose();
    super.dispose();
  }

  void _snapToEdge(Size screenSize) {
    final isLeft = _position.dx < screenSize.width / 2;
    final targetX = isLeft ? 16.0 : screenSize.width - 76.0;
    final clampedY = _position.dy.clamp(60.0, screenSize.height - 140.0);

    setState(() {
      _position = Offset(targetX, clampedY);
    });
  }

  void _openPanel() async {
    setState(() => _isPanelOpen = true);
    ref.read(hasChatHintProvider.notifier).state = false; // clear badge khi mở
    await ChatPanel.show(context, ref);
    if (mounted) {
      setState(() => _isPanelOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoggedIn = authState.email != null;
    final isSuppressed = ref.watch(isGameDraggingProvider);
    final hasHint = ref.watch(hasChatHintProvider);
    final isPanelOpenGlobal = ref.watch(isChatPanelOpenProvider);
    final isPanelOpen = _isPanelOpen || isPanelOpenGlobal;
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        widget.child,
        if (isLoggedIn && !isPanelOpen)
          AnimatedPositioned(
            duration: _isDragging
                ? Duration.zero
                : const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            left: _position.dx,
            top: _position.dy,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSuppressed ? 0.15 : 1.0,
              child: IgnorePointer(
                ignoring: isSuppressed, // không nhận chạm khi đang bận thao tác game
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _isDragging = true),
                  onPanUpdate: (details) {
                    setState(() {
                      _position += details.delta;
                    });
                  },
                  onPanEnd: (_) {
                    setState(() => _isDragging = false);
                    _snapToEdge(screenSize);
                  },
                  onTap: _openPanel,
                  child: ScaleTransition(
                    scale: _attentionScale,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Avatar bong bóng với hình Designer.png
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFF0047AB), // Cobalt Blue
                              width: 2.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x330047AB),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'ImageFolder/Designer.png',
                              width: 58,
                              height: 58,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Badge nhãn "HocDi"
                        Positioned(
                          bottom: -6,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0047AB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
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
                        // Badge chấm đỏ nếu có gợi ý mới
                        if (hasHint)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
