import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../utils/sudoku_generator.dart';
import '../services/sudoku_multiplayer_service.dart';
import 'sudoku_game_screen.dart';

class SudokuLobbyScreen extends StatefulWidget {
  const SudokuLobbyScreen({super.key});

  @override
  State<SudokuLobbyScreen> createState() => _SudokuLobbyScreenState();
}

class _SudokuLobbyScreenState extends State<SudokuLobbyScreen> {
  final SudokuMultiplayerService _multiplayerService = SudokuMultiplayerService();
  final TextEditingController _roomCodeController = TextEditingController();
  SudokuDifficulty _selectedDifficulty = SudokuDifficulty.medium;

  @override
  void initState() {
    super.initState();
    _multiplayerService.addListener(_onMultiplayerStateChanged);
  }

  @override
  void dispose() {
    _multiplayerService.removeListener(_onMultiplayerStateChanged);
    _multiplayerService.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  void _onMultiplayerStateChanged() {
    if (!mounted) return;

    if (_multiplayerService.state == MatchState.countdown) {
      _showCountdownDialog();
    }
  }

  void _showCountdownDialog() {
    // Đóng dialog tìm kiếm nếu đang mở
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final seconds = _multiplayerService.countdownSeconds;
            if (_multiplayerService.state == MatchState.playing) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pop(context);
                _openGameScreen();
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ĐÃ TÌM THẤY ĐỐI THỦ!',
                      style: GoogleFonts.baloo2(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                  const SizedBox(height: 12),
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: Text('⚔️', style: const TextStyle(fontSize: 32)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Đối đầu với: ${_multiplayerService.opponent?.name ?? "Kỳ thủ"}',
                    style: GoogleFonts.baloo2(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$seconds',
                    style: GoogleFonts.baloo2(fontSize: 54, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8)),
                  ),
                  Text('Trận đấu sắp bắt đầu...', style: GoogleFonts.baloo2(color: Colors.grey.shade600)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openGameScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SudokuGameScreen(
          initialDifficulty: _selectedDifficulty,
          multiplayerService: _multiplayerService,
        ),
      ),
    );
  }

  void _startSoloGame(SudokuDifficulty diff) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SudokuGameScreen(initialDifficulty: diff),
      ),
    );
  }

  void _startQuickMatch() {
    _multiplayerService.startQuickMatch(_selectedDifficulty);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final elapsed = _multiplayerService.searchSecondsElapsed;
            final remainingToBot = (15 - elapsed).clamp(0, 15);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(strokeWidth: 4, color: Color(0xFF1D4ED8)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Đang tìm đối thủ...',
                    style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cấp độ: ${_selectedDifficulty.label}',
                    style: GoogleFonts.baloo2(fontSize: 15, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      remainingToBot > 0
                          ? 'Tự động ghép Bot sau: ${remainingToBot}s'
                          : 'Đang kết nối đối thủ...',
                      style: GoogleFonts.baloo2(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        _multiplayerService.cancelMatch();
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Hủy Tìm Kiếm', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateRoomSheet() {
    _multiplayerService.createPrivateRoom(_selectedDifficulty);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PHÒNG ĐẤU RIÊNG',
                  style: GoogleFonts.baloo2(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              const SizedBox(height: 8),
              Text('Gửi mã phòng này cho bạn bè để cùng vào thi đấu:',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(fontSize: 14, color: const Color(0xFF64748B))),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
                ),
                child: Text(
                  _multiplayerService.roomCode ?? 'SK8921',
                  style: GoogleFonts.baloo2(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: const Color(0xFF1D4ED8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text('Đang đợi bạn bè tham gia...',
                      style: GoogleFonts.baloo2(fontSize: 14, color: const Color(0xFF475569))),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    _multiplayerService.cancelMatch();
                    Navigator.pop(ctx);
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Đóng Phòng', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showJoinRoomDialog() {
    _roomCodeController.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Nhập Mã Phòng',
              style: GoogleFonts.baloo2(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nhập mã 6 ký tự do bạn bè chia sẻ:',
                  style: GoogleFonts.baloo2(fontSize: 14, color: const Color(0xFF64748B))),
              const SizedBox(height: 16),
              TextField(
                controller: _roomCodeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
                decoration: InputDecoration(
                  hintText: 'VD: SK8921',
                  hintStyle: TextStyle(color: Colors.grey.shade400, letterSpacing: 2),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Hủy', style: GoogleFonts.baloo2(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final code = _roomCodeController.text.trim();
                if (code.isNotEmpty) {
                  Navigator.pop(ctx);
                  _multiplayerService.joinPrivateRoom(code);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Vào Trận', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Sudoku Trí Tuệ',
          style: GoogleFonts.baloo2(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. BANNER CHÍNH
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đấu Trường Sudoku',
                          style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Thách đấu người chơi trực tiếp, ghép nhanh ngẫu nhiên hoặc tạo phòng so tài cùng bạn bè!',
                          style: GoogleFonts.baloo2(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('🔢', style: TextStyle(fontSize: 32)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. CHẾ ĐỘ ĐỐI KHÁNG ONLINE
            Text(
              'Chế Độ Đấu Trường',
              style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),

            // Chọn độ khó cho thi đấu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Text('Độ khó thi đấu:', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                  const Spacer(),
                  DropdownButton<SudokuDifficulty>(
                    value: _selectedDifficulty,
                    underline: const SizedBox.shrink(),
                    items: SudokuDifficulty.values.map((d) {
                      return DropdownMenuItem(
                        value: d,
                        child: Text(d.label, style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8))),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDifficulty = val);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildLobbyActionCard(
                    title: 'Ghép Tự Động',
                    subtitle: 'Ghép trận nhanh trong 15s',
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFF0284C7),
                    badge: 'Tốc độ',
                    onTap: _startQuickMatch,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildLobbyActionCard(
                    title: 'Tạo Phòng',
                    subtitle: 'Lấy mã mời bạn bè',
                    icon: Icons.group_add_rounded,
                    color: const Color(0xFF7C3AED),
                    badge: 'Mã PIN',
                    onTap: _showCreateRoomSheet,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _showJoinRoomDialog,
                icon: const Icon(Icons.login_rounded, size: 20),
                label: Text('Nhập Mã Phòng Đã Có', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // 3. CHẾ ĐỘ CHƠI ĐƠN (LUYỆN TẬP TỰ DO 6 CẤP ĐỘ)
            Text(
              'Luyện Tập Tự Do (Chơi Đơn)',
              style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),

            ...SudokuDifficulty.values.map((diff) {
              return _buildDifficultyRow(diff);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLobbyActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(badge, style: GoogleFonts.baloo2(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(title, style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            const SizedBox(height: 2),
            Text(subtitle, style: GoogleFonts.baloo2(fontSize: 12, color: const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyRow(SudokuDifficulty diff) {
    final color = switch (diff) {
      SudokuDifficulty.easy => const Color(0xFF16A34A),
      SudokuDifficulty.medium => const Color(0xFF0284C7),
      SudokuDifficulty.hard => const Color(0xFFEA580C),
      SudokuDifficulty.expert => const Color(0xFFDC2626),
      SudokuDifficulty.master => const Color(0xFF9333EA),
      SudokuDifficulty.extreme => const Color(0xFFBE123C),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => _startSoloGame(diff),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            '${diff.targetClues}',
            style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ),
        title: Text(
          diff.label,
          style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
        ),
        subtitle: Text(
          '~${diff.targetClues} ô gợi ý sẵn',
          style: GoogleFonts.baloo2(fontSize: 12.5, color: const Color(0xFF64748B)),
        ),
        trailing: Icon(Icons.play_circle_fill_rounded, color: color, size: 32),
      ),
    );
  }
}
