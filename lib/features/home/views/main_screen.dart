import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/views/login_screen.dart';
import '../../learn/views/learn_tab.dart';
import '../../game/views/game_tab.dart';
import '../../profile/views/profile_tab.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;
  final List<bool> _isHovered = [false, false, false];

  final List<Widget> _tabs = [
    const LearnTab(),
    const GameTab(),
    const ProfileTab(),
  ];

  void _onItemTapped(int index) {
    final authState = ref.read(authProvider);
    final isLoggedIn = authState.status == AuthStatus.authenticated;

    // Phân quyền cho Guest (Chỉ được học, không được vào Game & Account)
    if (index > 0 && !isLoggedIn) {
      _showLoginRequirementDialog();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _showLoginRequirementDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: AppColors.accent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Tính Năng Giới Hạn',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Để tham gia chơi Game tích điểm và xuất hiện trên Bảng xếp hạng thành viên, bạn cần phải đăng nhập tài khoản.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text(
                        'Để sau',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Đăng nhập'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.unauthenticated && previous?.status == AuthStatus.authenticated) {
        setState(() {
          _selectedIndex = 0;
        });
      }
    });

    final authState = ref.watch(authProvider);
    final isLoggedIn = authState.status == AuthStatus.authenticated;

    return Scaffold(
      extendBody: false,
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(
                  index: 0,
                  icon: Icons.menu_book_rounded,
                  label: 'Học tập',
                  isSelected: _selectedIndex == 0,
                  isHovered: _isHovered[0],
                  isLocked: false,
                ),
                _buildTabItem(
                  index: 1,
                  icon: Icons.sports_esports_rounded,
                  label: 'Trò chơi',
                  isSelected: _selectedIndex == 1,
                  isHovered: _isHovered[1],
                  isLocked: !isLoggedIn,
                  badge: !isLoggedIn
                      ? Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 8,
                            minHeight: 8,
                          ),
                        )
                      : null,
                ),
                _buildTabItem(
                  index: 2,
                  icon: Icons.person_rounded,
                  label: 'Tài khoản',
                  isSelected: _selectedIndex == 2,
                  isHovered: _isHovered[2],
                  isLocked: !isLoggedIn,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isHovered,
    required bool isLocked,
    Widget? badge,
  }) {
    final showWarning = isLocked && isHovered;
    final activeColor = showWarning 
        ? AppColors.error 
        : (isSelected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.6));
    
    final bubbleColor = showWarning
        ? AppColors.error.withValues(alpha: 0.12)
        : (isSelected 
            ? AppColors.primary.withValues(alpha: 0.12) 
            : AppColors.primary.withValues(alpha: 0.05));

    return Expanded(
      child: MouseRegion(
        cursor: isLocked ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered[index] = true),
        onExit: (_) => setState(() => _isHovered[index] = false),
        child: GestureDetector(
          onTap: () => _onItemTapped(index),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  transform: Matrix4.translationValues(
                    0,
                    isSelected ? -8 : (isHovered ? (isLocked ? -2 : -4) : 0),
                    0,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut, // Safe curve with no overshoot to prevent negative blurRadius assertion
                        width: isSelected ? 48 : (isHovered ? 40 : 0),
                        height: isSelected ? 48 : (isHovered ? 40 : 0),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          shape: BoxShape.circle,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : (showWarning 
                                  ? [
                                      BoxShadow(
                                        color: AppColors.error.withValues(alpha: 0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null),
                        ),
                      ),
                      AnimatedScale(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        scale: isSelected ? 1.25 : (isHovered ? 1.15 : 1.0),
                        child: Icon(
                          showWarning ? Icons.lock_outline_rounded : icon,
                          color: activeColor,
                          size: 26,
                        ),
                      ),
                      if (badge != null && !showWarning)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: badge,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Outfit',
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
