import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../learn/providers/checkin_provider.dart';
import '../../learn/views/widgets/checkin_logic.dart';
import '../models/queens_puzzle.dart';
import '../utils/queens_generator.dart';
import 'daily_checkin_report_dialog.dart';

class _QueensMove {
  final int row;
  final int col;
  final QueensCellMark previousMark;
  final QueensCellMark newMark;

  _QueensMove({
    required this.row,
    required this.col,
    required this.previousMark,
    required this.newMark,
  });
}

class DailyCheckinGameScreen extends ConsumerStatefulWidget {
  const DailyCheckinGameScreen({super.key});

  @override
  ConsumerState<DailyCheckinGameScreen> createState() => _DailyCheckinGameScreenState();
}

class _DailyCheckinGameScreenState extends ConsumerState<DailyCheckinGameScreen> {
  late DateTime _today;
  late int _gridSize;
  late QueensPuzzle _puzzle;
  late List<List<QueensCell>> _board;

  final List<_QueensMove> _history = [];
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isGameOver = false;
  bool _isRulesExpanded = true;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    final isWeekend = _today.weekday == DateTime.saturday || _today.weekday == DateTime.sunday;
    // Thứ 2 -> Thứ 6: 7x7; Thứ 7 & CN: 9x9 (chuẩn mobile)
    _gridSize = isWeekend ? 9 : 7;
    _initPuzzle();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isGameOver) return;
      setState(() => _secondsElapsed++);
    });
  }

  void _initPuzzle({int? customSize}) {
    if (customSize != null) {
      _gridSize = customSize;
    }
    _puzzle = QueensGenerator.generateDailyPuzzle(_today, customSize: _gridSize);

    _board = List.generate(_gridSize, (r) {
      return List.generate(_gridSize, (c) {
        return QueensCell(
          row: r,
          col: c,
          region: _puzzle.regionMap[r][c],
          mark: QueensCellMark.empty,
        );
      });
    });

    _history.clear();
    _isGameOver = false;
    _validateBoard();
  }

  void _onCellTap(int r, int c) {
    if (_isGameOver) return;

    final cell = _board[r][c];
    final oldMark = cell.mark;
    QueensCellMark nextMark;

    // Cycle: Trống -> X -> Queen -> Trống
    switch (oldMark) {
      case QueensCellMark.empty:
        nextMark = QueensCellMark.cross;
        break;
      case QueensCellMark.cross:
        nextMark = QueensCellMark.queen;
        break;
      case QueensCellMark.queen:
        nextMark = QueensCellMark.empty;
        break;
    }

    _applyMove(r, c, nextMark);
  }

  void _onCellDoubleTap(int r, int c) {
    if (_isGameOver) return;

    final cell = _board[r][c];
    // Chạm hai lần: Trực tiếp đặt Queen (hoặc xoá nếu đã là Queen)
    final nextMark = cell.isQueen ? QueensCellMark.empty : QueensCellMark.queen;
    _applyMove(r, c, nextMark);
  }

  void _applyMove(int r, int c, QueensCellMark nextMark) {
    final cell = _board[r][c];
    if (cell.mark == nextMark) return;

    setState(() {
      _history.add(_QueensMove(
        row: r,
        col: c,
        previousMark: cell.mark,
        newMark: nextMark,
      ));
      cell.mark = nextMark;
      _validateBoard();
    });

    _checkWinCondition();
  }

  void _undo() {
    if (_history.isEmpty || _isGameOver) return;

    final lastMove = _history.removeLast();
    setState(() {
      _board[lastMove.row][lastMove.col].mark = lastMove.previousMark;
      _validateBoard();
    });
  }

  void _validateBoard() {
    // Reset toàn bộ cờ conflict
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        _board[r][c].isConflict = false;
      }
    }

    final queenCells = <QueensCell>[];
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (_board[r][c].isQueen) {
          queenCells.add(_board[r][c]);
        }
      }
    }

    // 1. Kiểm tra trùng hàng, cột, vùng màu và vị trí kề nhau
    for (int i = 0; i < queenCells.length; i++) {
      final q1 = queenCells[i];
      for (int j = i + 1; j < queenCells.length; j++) {
        final q2 = queenCells[j];

        bool hasConflict = false;

        // Cùng hàng
        if (q1.row == q2.row) hasConflict = true;

        // Cùng cột
        if (q1.col == q2.col) hasConflict = true;

        // Cùng vùng màu
        if (q1.region == q2.region) hasConflict = true;

        // Chạm nhau (kể cả đường chéo: Chebyshev distance <= 1)
        if ((q1.row - q2.row).abs() <= 1 && (q1.col - q2.col).abs() <= 1) {
          hasConflict = true;
        }

        if (hasConflict) {
          q1.isConflict = true;
          q2.isConflict = true;
        }
      }
    }
  }

  void _checkWinCondition() async {
    int queenCount = 0;
    bool hasAnyConflict = false;

    final rowCounts = List<int>.filled(_gridSize, 0);
    final colCounts = List<int>.filled(_gridSize, 0);
    final regionCounts = List<int>.filled(_gridSize, 0);

    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        final cell = _board[r][c];
        if (cell.isConflict) hasAnyConflict = true;
        if (cell.isQueen) {
          queenCount++;
          rowCounts[r]++;
          colCounts[c]++;
          regionCounts[cell.region]++;
        }
      }
    }

    if (queenCount == _gridSize && !hasAnyConflict) {
      final allRowsValid = rowCounts.every((cnt) => cnt == 1);
      final allColsValid = colCounts.every((cnt) => cnt == 1);
      final allRegionsValid = regionCounts.every((cnt) => cnt == 1);

      if (allRowsValid && allColsValid && allRegionsValid) {
        _isGameOver = true;
        _timer?.cancel();
        _onVictory();
      }
    }
  }

  void _onVictory() async {
    // 1. Cập nhật local provider ngay lập tức để chuyển màu xanh thành công
    if (mounted) {
      ref.read(checkinProvider.notifier).markTodayAsCompletedLocal();
    }

    // 2. Tính điểm dựa theo thời gian
    final baseScore = 100;
    final timePenalty = (_secondsElapsed ~/ 15).clamp(0, 50);
    final finalScore = max(50, baseScore - timePenalty);

    int? userRank;
    try {
      final rankData = await SupabaseService.instance.saveAndGetTodayRank(finalScore);
      userRank = rankData['rank'] as int?;
      if (mounted) {
        ref.read(checkinProvider.notifier).markTodayAsCompletedLocal(
          rank: userRank,
          totalPlayers: rankData['totalPlayersToday'] as int?,
        );
        ref.read(checkinProvider.notifier).refreshStatus();
      }
    } catch (e) {
      debugPrint('Lỗi lưu điểm danh Supabase: $e');
    }

    if (!mounted) return;

    final streak = CheckinLogic.calculateStreak(
      ref.read(checkinProvider).checkedDates,
      _today,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DailyCheckinReportDialog(
        foundPaths: finalScore,
        pointsEarned: 20,
        currentStreak: streak > 0 ? streak : 1,
        initialRank: userRank,
        onPlayAgain: () {
          Navigator.pop(context);
          setState(() {
            _initPuzzle();
            _secondsElapsed = 0;
          });
          _startTimer();
        },
        onGoHome: () {
          Navigator.pop(context); // Đóng dialog
          Navigator.pop(context); // Quay về Home
        },
      ),
    );
  }

  void _showQuitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tạm dừng điểm danh?', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold)),
        content: Text(
          'Tiến trình giải câu đố hôm nay sẽ chưa được ghi nhận hoàn thành.',
          style: GoogleFonts.baloo2(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Giải tiếp', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('Thoát', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showQuitConfirmation();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Bar
              _buildTopBar(),

              // 2. Scrollable Main Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      // Queens Board
                      _buildQueensBoard(),
                      const SizedBox(height: 20),

                      // Collapsible Rules Card: "Cách chơi"
                      _buildRulesCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final canUndo = _history.isNotEmpty && !_isGameOver;

    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Tiêu đề căn chính giữa màn hình (chuẩn theo tâm camera punch hole)
          Center(
            child: Text(
              'Daily Checkin',
              style: GoogleFonts.baloo2(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // 2. Nút quay lại góc trái
          Positioned(
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
              onPressed: _showQuitConfirmation,
            ),
          ),

          // 3. Nút Hoàn tác (thay thế vị trí loa) + Đồng hồ đếm thời gian
          Positioned(
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.undo_rounded,
                    color: canUndo ? AppColors.textPrimary : Colors.black26,
                    size: 24,
                  ),
                  tooltip: 'Hoàn tác',
                  onPressed: canUndo ? _undo : null,
                ),
                const SizedBox(width: 4),
                GameCountUpTimer(elapsedSeconds: _secondsElapsed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueensBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardWidth = constraints.maxWidth.clamp(280.0, 480.0);

        return Center(
          child: Container(
            width: boardWidth,
            height: boardWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              // Viền ngoài đậm 3.0px chuẩn mẫu ảnh
              border: Border.all(color: Colors.black, width: 3.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: List.generate(_gridSize, (r) {
                return Expanded(
                  child: Row(
                    children: List.generate(_gridSize, (c) {
                      return Expanded(
                        child: _buildCellWidget(r, c),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCellWidget(int r, int c) {
    final cell = _board[r][c];
    final regColor = QueensColors.getRegionColor(cell.region);

    // Tính toán độ dày viền các cạnh:
    // Cạnh giữa 2 vùng khác nhau: in đậm 2.5px
    // Cạnh giữa 2 ô cùng vùng: mỏng 0.8px mờ
    const thickBorder = BorderSide(color: Colors.black, width: 2.2);
    final thinBorder = BorderSide(color: Colors.black.withValues(alpha: 0.18), width: 0.8);

    final rightBorder = (c < _gridSize - 1)
        ? (_board[r][c].region != _board[r][c + 1].region ? thickBorder : thinBorder)
        : BorderSide.none;

    final bottomBorder = (r < _gridSize - 1)
        ? (_board[r][c].region != _board[r + 1][c].region ? thickBorder : thinBorder)
        : BorderSide.none;

    final bgColor = cell.isConflict
        ? Color.alphaBlend(Colors.red.withValues(alpha: 0.45), regColor)
        : regColor;

    return GestureDetector(
      onTap: () => _onCellTap(r, c),
      onDoubleTap: () => _onCellDoubleTap(r, c),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            right: rightBorder,
            bottom: bottomBorder,
          ),
        ),
        alignment: Alignment.center,
        child: _buildCellContent(cell),
      ),
    );
  }

  Widget _buildCellContent(QueensCell cell) {
    if (cell.isQueen) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(3.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '👑',
                style: TextStyle(
                  fontSize: _gridSize > 9 ? 20 : 26,
                ),
              ),
              if (cell.isConflict)
                const Icon(
                  Icons.close_rounded,
                  color: Colors.red,
                  size: 28,
                ),
            ],
          ),
        ),
      );
    } else if (cell.isCross) {
      return Text(
        '✕',
        style: GoogleFonts.baloo2(
          fontSize: _gridSize > 9 ? 14 : 18,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF262626),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRulesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isRulesExpanded = !_isRulesExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cách chơi',
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Icon(
                    _isRulesExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (_isRulesExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRuleStep(
                    number: '1',
                    content: RichText(
                      text: TextSpan(
                        style: GoogleFonts.baloo2(
                          fontSize: 14,
                          color: const Color(0xFF334155),
                          height: 1.4,
                        ),
                        children: const [
                          TextSpan(text: 'Mục tiêu của bạn là có chính xác một '),
                          TextSpan(text: '👑 ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: 'trong mỗi '),
                          TextSpan(text: 'hàng, cột ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                          TextSpan(text: 'và '),
                          TextSpan(text: 'vùng màu.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildRuleStep(
                    number: '2',
                    content: RichText(
                      text: TextSpan(
                        style: GoogleFonts.baloo2(
                          fontSize: 14,
                          color: const Color(0xFF334155),
                          height: 1.4,
                        ),
                        children: const [
                          TextSpan(text: 'Chạm một lần để đặt '),
                          TextSpan(text: 'X ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                          TextSpan(text: 'và chạm hai lần để đặt '),
                          TextSpan(text: '👑. ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: 'Sử dụng X để đánh dấu nơi không thể đặt 👑.'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildRuleStep(
                    number: '3',
                    content: RichText(
                      text: TextSpan(
                        style: GoogleFonts.baloo2(
                          fontSize: 14,
                          color: const Color(0xFF334155),
                          height: 1.4,
                        ),
                        children: const [
                          TextSpan(text: 'Hai '),
                          TextSpan(text: '👑 ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: 'không thể chạm vào nhau, thậm chí '),
                          TextSpan(text: 'không theo đường chéo.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRuleStep({required String number, required Widget content}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number. ',
          style: GoogleFonts.baloo2(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }
}
