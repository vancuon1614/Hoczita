import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/providers/chat_context_provider.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../../core/providers/game_interaction_provider.dart';
import '../utils/sudoku_generator.dart';
import '../services/sudoku_multiplayer_service.dart';
import 'common/mini_game_rank_banner.dart';

class SudokuGameScreen extends ConsumerStatefulWidget {
  final SudokuDifficulty initialDifficulty;
  final SudokuMultiplayerService? multiplayerService;

  const SudokuGameScreen({
    super.key,
    this.initialDifficulty = SudokuDifficulty.medium,
    this.multiplayerService,
  });

  @override
  ConsumerState<SudokuGameScreen> createState() => _SudokuGameScreenState();
}

class _CellState {
  int value;
  final bool isClue;
  final Set<int> notes = {};

  _CellState({required this.value, required this.isClue});
}

class _HistoryStep {
  final int row;
  final int col;
  final int prevValue;
  final Set<int> prevNotes;
  final int newValue;
  final Set<int> newNotes;

  _HistoryStep({
    required this.row,
    required this.col,
    required this.prevValue,
    required this.prevNotes,
    required this.newValue,
    required this.newNotes,
  });
}

class _SudokuGameScreenState extends ConsumerState<SudokuGameScreen> {
  late SudokuDifficulty _difficulty;
  late SudokuPuzzle _puzzle;
  late List<List<_CellState>> _board;

  int? _selectedRow;
  int? _selectedCol;
  bool _notesMode = false;
  int _hintsRemaining = 3;
  int _mistakesCount = 0;

  final List<_HistoryStep> _undoStack = [];
  Timer? _gameTimer;
  int _secondsElapsed = 0;
  bool _isGameOver = false;

  Set<int> _conflicts = {};

  @override
  void initState() {
    super.initState();
    _difficulty = widget.initialDifficulty;
    if (widget.multiplayerService != null && widget.multiplayerService!.currentPuzzle != null) {
      _puzzle = widget.multiplayerService!.currentPuzzle!;
      _difficulty = widget.multiplayerService!.selectedDifficulty;
    } else {
      _puzzle = SudokuGenerator.generate(_difficulty);
    }
    _initBoard();
    _startTimer();

    widget.multiplayerService?.addListener(_onMultiplayerUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(isGameActiveProvider.notifier).state = true;
      ref.read(chatContextProvider.notifier).state = ChatContext(
        screenName: 'sudoku_game',
        data: {
          'difficulty': _difficulty.label,
          'target_clues': _difficulty.targetClues,
        },
      );
    });
  }

  @override
  void dispose() {
    ref.read(chatContextProvider.notifier).state = null;
    ref.read(isGameActiveProvider.notifier).state = false;
    _gameTimer?.cancel();
    widget.multiplayerService?.removeListener(_onMultiplayerUpdate);
    super.dispose();
  }

  void _onMultiplayerUpdate() {
    if (mounted) {
      setState(() {});
      if (widget.multiplayerService?.opponent?.isFinished == true && !_isGameOver) {
        _showGameOverDialog(isWinner: false);
      }
    }
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _secondsElapsed = 0;
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isGameOver) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  void _initBoard() {
    _board = List.generate(9, (r) {
      return List.generate(9, (c) {
        final val = _puzzle.initialBoard[r][c];
        return _CellState(value: val, isClue: val != 0);
      });
    });
    _selectedRow = null;
    _selectedCol = null;
    _undoStack.clear();
    _conflicts.clear();
    _isGameOver = false;
    _mistakesCount = 0;
  }

  void _changeDifficulty(SudokuDifficulty newDiff) {
    if (widget.multiplayerService != null && widget.multiplayerService!.mode != MultiplayerMode.solo) {
      return; // Không đổi độ khó giữa trận multiplayer
    }

    setState(() {
      _difficulty = newDiff;
      _puzzle = SudokuGenerator.generate(_difficulty);
      _initBoard();
      _startTimer();
    });
  }

  void _selectCell(int r, int c) {
    setState(() {
      _selectedRow = r;
      _selectedCol = c;
    });
  }

  void _onNumberInput(int num) {
    if (_selectedRow == null || _selectedCol == null || _isGameOver) return;
    final r = _selectedRow!;
    final c = _selectedCol!;
    final cell = _board[r][c];

    if (cell.isClue) return; // Không được sửa ô đề bài

    if (_notesMode) {
      // Chế độ ghi chú
      setState(() {
        final prevNotes = Set<int>.from(cell.notes);
        if (cell.notes.contains(num)) {
          cell.notes.remove(num);
        } else {
          cell.notes.add(num);
        }
        _undoStack.add(_HistoryStep(
          row: r,
          col: c,
          prevValue: cell.value,
          prevNotes: prevNotes,
          newValue: cell.value,
          newNotes: Set<int>.from(cell.notes),
        ));
      });
      return;
    }

    // Chế độ điền số thật
    setState(() {
      final prevVal = cell.value;
      final prevNotes = Set<int>.from(cell.notes);

      if (cell.value == num) {
        cell.value = 0; // Bấm lại số đó để xóa
      } else {
        cell.value = num;
        cell.notes.clear();

        // Kiểm tra sai với đáp án giải
        if (num != _puzzle.solution[r][c]) {
          _mistakesCount++;
        }
      }

      _undoStack.add(_HistoryStep(
        row: r,
        col: c,
        prevValue: prevVal,
        prevNotes: prevNotes,
        newValue: cell.value,
        newNotes: Set<int>.from(cell.notes),
      ));

      _updateConflicts();
      _checkGameWin();
      _notifyMultiplayerProgress();
    });
  }

  void _eraseSelected() {
    if (_selectedRow == null || _selectedCol == null || _isGameOver) return;
    final r = _selectedRow!;
    final c = _selectedCol!;
    final cell = _board[r][c];

    if (cell.isClue) return;
    if (cell.value == 0 && cell.notes.isEmpty) return;

    setState(() {
      _undoStack.add(_HistoryStep(
        row: r,
        col: c,
        prevValue: cell.value,
        prevNotes: Set<int>.from(cell.notes),
        newValue: 0,
        newNotes: {},
      ));
      cell.value = 0;
      cell.notes.clear();
      _updateConflicts();
      _notifyMultiplayerProgress();
    });
  }

  void _undo() {
    if (_undoStack.isEmpty || _isGameOver) return;
    setState(() {
      final lastStep = _undoStack.removeLast();
      final cell = _board[lastStep.row][lastStep.col];
      cell.value = lastStep.prevValue;
      cell.notes.clear();
      cell.notes.addAll(lastStep.prevNotes);
      _updateConflicts();
      _notifyMultiplayerProgress();
    });
  }

  void _useHint() {
    if (_hintsRemaining <= 0 || _isGameOver) return;

    // Tìm một ô trống hoặc ô đang điền sai
    int? targetR, targetC;

    // Ưu tiên ô đang chọn
    if (_selectedRow != null && _selectedCol != null) {
      final cur = _board[_selectedRow!][_selectedCol!];
      if (!cur.isClue && cur.value != _puzzle.solution[_selectedRow!][_selectedCol!]) {
        targetR = _selectedRow;
        targetC = _selectedCol;
      }
    }

    if (targetR == null) {
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (!_board[r][c].isClue && _board[r][c].value != _puzzle.solution[r][c]) {
            targetR = r;
            targetC = c;
            break;
          }
        }
        if (targetR != null) break;
      }
    }

    if (targetR != null && targetC != null) {
      setState(() {
        _hintsRemaining--;
        final correctVal = _puzzle.solution[targetR!][targetC!];
        _board[targetR][targetC].value = correctVal;
        _board[targetR][targetC].notes.clear();
        _selectedRow = targetR;
        _selectedCol = targetC;
        _updateConflicts();
        _checkGameWin();
        _notifyMultiplayerProgress();
      });
    }
  }

  void _updateConflicts() {
    final matrix = List.generate(9, (r) => List.generate(9, (c) => _board[r][c].value));
    _conflicts = SudokuGenerator.findConflictingCells(matrix);
  }

  void _notifyMultiplayerProgress() {
    if (widget.multiplayerService == null) return;
    int filled = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (!_board[r][c].isClue && _board[r][c].value == _puzzle.solution[r][c]) {
          filled++;
        }
      }
    }
    widget.multiplayerService!.updatePlayerProgress(filled, _mistakesCount, _isGameOver);
  }

  void _checkGameWin() {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_board[r][c].value != _puzzle.solution[r][c]) {
          return; // Chưa xong
        }
      }
    }

    // Đã thắng!
    _isGameOver = true;
    _gameTimer?.cancel();
    _saveScoreToSupabase();
    _showGameOverDialog(isWinner: true);
  }

  int _calculateScore() {
    int baseScore = switch (_difficulty) {
      SudokuDifficulty.easy => 150,
      SudokuDifficulty.medium => 300,
      SudokuDifficulty.hard => 500,
    };

    return (baseScore - (_secondsElapsed ~/ 2) - (_mistakesCount * 15)).clamp(50, 2000);
  }

  Future<void> _saveScoreToSupabase() async {
    int stars = 3;
    if (_mistakesCount > 3 || _secondsElapsed > 300) stars = 2;
    if (_mistakesCount > 6 || _secondsElapsed > 600) stars = 1;

    int finalScore = _calculateScore();

    try {
      await SupabaseService.instance.saveScore(
        gameName: 'sudoku_${_difficulty.name}',
        stars: stars,
        score: finalScore,
        durationSeconds: _secondsElapsed,
      );
    } catch (e) {
      debugPrint('Error saving sudoku score: $e');
    }
  }

  void _showGameOverDialog({required bool isWinner}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isWinner ? '🎉 XUẤT SẮC!' : '💪 TIẾC QUÁ!',
                style: GoogleFonts.baloo2(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isWinner ? AppColors.success : AppColors.accent,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isWinner
                    ? 'Bạn đã hoàn thành bảng Sudoku ${_difficulty.label} trong ${_formatDuration(_secondsElapsed)}!'
                    : 'Đối thủ đã về đích trước! Đừng nản lòng, hãy thử lại nhé!',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatPill('Thời gian', _formatDuration(_secondsElapsed)),
                  _buildStatPill('Lỗi', '$_mistakesCount'),
                  _buildStatPill('Độ khó', _difficulty.label),
                ],
              ),
              const SizedBox(height: 16),
              MiniGameRankBanner(
                gameName: 'sudoku_${_difficulty.name}',
                gameTitle: 'Sudoku ${_difficulty.label}',
                currentScore: _calculateScore(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Trang Chủ', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _changeDifficulty(_difficulty);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Chơi Ván Mới', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold)),
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

  Widget _buildStatPill(String title, String val) {
    return Column(
      children: [
        Text(title, style: GoogleFonts.baloo2(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(val, style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  String _formatDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Đếm số lần xuất hiện của số `num` trên bảng
  int _countNumberPlaced(int num) {
    int count = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_board[r][c].value == num) count++;
      }
    }
    return count;
  }

  void _showQuitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tạm dừng ván Sudoku?', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold)),
        content: Text(
          'Tiến trình ván chơi hiện tại sẽ không được lưu.',
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

  void _resetGame() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Làm lại ván mới?', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold)),
        content: Text(
          'Tiến trình hiện tại sẽ bị xóa và tạo đề bài mới.',
          style: GoogleFonts.baloo2(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _changeDifficulty(_difficulty);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: Text('Làm lại', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMultiplayer = widget.multiplayerService != null && widget.multiplayerService!.mode != MultiplayerMode.solo;
    final selectedNum = (_selectedRow != null && _selectedCol != null) ? _board[_selectedRow!][_selectedCol!].value : 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showQuitConfirmation();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // 1. TOP BAR chuẩn đồng bộ với các game khác
              _buildTopBar(isMultiplayer),

              // Thanh đối kháng (chỉ hiển thị khi multiplayer)
              if (isMultiplayer) ...[
                const SizedBox(height: 4),
                _buildMultiplayerVsBar(),
              ],

              const SizedBox(height: 8),

              // 2. MA TRẬN BÀN CỜ 9x9
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: _buildSudokuGrid(selectedNum),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 3. THANH ĐIỀU KHIỂN (Undo, Erase, Notes, Hint)
              _buildControlBar(),

              const SizedBox(height: 10),

              // 4. BÀN PHÍM SỐ 1 - 9
              _buildNumberKeypad(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isMultiplayer) {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Tiêu đề căn chính giữa màn hình
          Center(
            child: Text(
              isMultiplayer ? 'Đấu Trường Sudoku' : 'Sudoku Trí Tuệ',
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

          // 3. Reset ván + Đồng hồ đếm thời gian (góc phải)
          Positioned(
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMultiplayer)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary, size: 24),
                    tooltip: 'Làm lại',
                    onPressed: _resetGame,
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

  /// Thanh tiến độ thi đấu 2 người trong chế độ đối kháng
  Widget _buildMultiplayerVsBar() {
    final opponent = widget.multiplayerService?.opponent;
    int myFilled = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (!_board[r][c].isClue && _board[r][c].value == _puzzle.solution[r][c]) myFilled++;
      }
    }
    final totalToFill = 81 - _puzzle.clueCount;
    final myProgress = totalToFill == 0 ? 0.0 : (myFilled / totalToFill).clamp(0.0, 1.0);
    final opProgress = opponent?.progressPercent ?? 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Bạn: ${(myProgress * 100).toInt()}%',
                  style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text('${opponent?.name ?? "Đối thủ"}: ${(opProgress * 100).toInt()}%',
                  style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
              ),
              FractionallySizedBox(
                widthFactor: myProgress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Bàn cờ Sudoku 9x9 theo đúng thiết kế ảnh mẫu:
  /// - Viền 3x3 và viền bao ngoài đậm màu `#1E293B`
  /// - Viền ô con 1x1 thanh mảnh `#CBD5E1`
  /// - Highlight ô được chọn, highlight các ô có CÙNG SỐ (`#CFE2F9`), highlight nhẹ hàng/cột
  Widget _buildSudokuGrid(int selectedNum) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.textPrimary, width: 2.5),
      ),
      child: Column(
        children: List.generate(9, (r) {
          final isThickBottom = (r % 3 == 2) && r != 8;
          return Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isThickBottom ? AppColors.textPrimary : AppColors.border,
                    width: isThickBottom ? 2.5 : 1.0,
                  ),
                ),
              ),
              child: Row(
                children: List.generate(9, (c) {
                  final isThickRight = (c % 3 == 2) && c != 8;
                  return Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: isThickRight ? AppColors.textPrimary : AppColors.border,
                            width: isThickRight ? 2.5 : 1.0,
                          ),
                        ),
                      ),
                      child: _buildCell(r, c, selectedNum),
                    ),
                  );
                }),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCell(int r, int c, int selectedNum) {
    final cell = _board[r][c];
    final isSelected = (_selectedRow == r && _selectedCol == c);
    final isSameNumber = (selectedNum != 0 && cell.value == selectedNum);
    final isRelated = (_selectedRow == r || _selectedCol == c ||
        (_selectedRow != null && _selectedCol != null && (_selectedRow! ~/ 3 == r ~/ 3) && (_selectedCol! ~/ 3 == c ~/ 3)));
    final hasConflict = _conflicts.contains(r * 9 + c);

    Color bgColor = Colors.white;
    if (hasConflict) {
      bgColor = AppColors.error.withValues(alpha: 0.12); // Đỏ nhạt khi lỗi trùng
    } else if (isSelected) {
      bgColor = AppColors.primaryLight; // Xanh lam nhạt khi đang chọn
    } else if (isSameNumber) {
      bgColor = AppColors.primary.withValues(alpha: 0.12); // Xanh highlight cùng số
    } else if (isRelated) {
      bgColor = AppColors.background; // Rất nhạt cho hàng/cột/khối
    }

    Color textColor = AppColors.textPrimary; // Đen navy sâu cho đề bài
    if (hasConflict) {
      textColor = AppColors.error;
    } else if (!cell.isClue && cell.value != 0) {
      textColor = AppColors.secondary; // Xanh dương cho người chơi điền
    }

    return InkWell(
      onTap: () => _selectCell(r, c),
      child: Container(
        color: bgColor,
        alignment: Alignment.center,
        child: cell.value != 0
            ? Text(
                '${cell.value}',
                style: GoogleFonts.baloo2(
                  fontSize: 24,
                  fontWeight: cell.isClue ? FontWeight.w600 : FontWeight.w700,
                  color: textColor,
                ),
              )
            : (cell.notes.isNotEmpty ? _buildNotesGrid(cell.notes) : const SizedBox.shrink()),
      ),
    );
  }

  /// Hiển thị ghi chú mini 3x3 trong ô
  Widget _buildNotesGrid(Set<int> notes) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (rowIdx) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (colIdx) {
              final n = rowIdx * 3 + colIdx + 1;
              return Text(
                notes.contains(n) ? '$n' : ' ',
                style: GoogleFonts.baloo2(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  /// 3. Thanh điều khiển: Undo, Erase, Notes, Hint
  Widget _buildControlBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            icon: Icons.undo_rounded,
            label: 'Hoàn tác',
            onTap: _undoStack.isNotEmpty ? _undo : null,
          ),
          _buildActionButton(
            icon: Icons.backspace_outlined,
            label: 'Xóa',
            onTap: _eraseSelected,
          ),
          _buildActionButton(
            icon: Icons.edit_note_rounded,
            label: 'Ghi chú',
            isActive: _notesMode,
            onTap: () {
              setState(() {
                _notesMode = !_notesMode;
              });
            },
          ),
          _buildActionButton(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Gợi ý',
            badge: '$_hintsRemaining',
            onTap: _hintsRemaining > 0 ? _useHint : null,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isActive = false,
    String? badge,
  }) {
    final enabled = onTap != null;
    final color = isActive
        ? AppColors.primary
        : (enabled ? AppColors.textPrimary : Colors.grey.shade400);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primaryLight : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.baloo2(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.baloo2(
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 4. Bàn phím số 1-9
  Widget _buildNumberKeypad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(9, (idx) {
          final num = idx + 1;
          final count = _countNumberPlaced(num);
          final isCompleted = count >= 9;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: InkWell(
                onTap: isCompleted ? null : () => _onNumberInput(num),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.black.withValues(alpha: 0.04) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCompleted ? Colors.transparent : AppColors.border,
                      width: 1.2,
                    ),
                    boxShadow: isCompleted
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$num',
                    style: GoogleFonts.baloo2(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isCompleted
                          ? AppColors.textSecondary.withValues(alpha: 0.4)
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
