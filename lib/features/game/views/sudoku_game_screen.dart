import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/providers/chat_context_provider.dart';
import '../utils/sudoku_generator.dart';
import '../services/sudoku_multiplayer_service.dart';

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

  Future<void> _saveScoreToSupabase() async {
    int stars = 3;
    if (_mistakesCount > 3 || _secondsElapsed > 300) stars = 2;
    if (_mistakesCount > 6 || _secondsElapsed > 600) stars = 1;

    int baseScore = switch (_difficulty) {
      SudokuDifficulty.easy => 150,
      SudokuDifficulty.medium => 250,
      SudokuDifficulty.hard => 400,
      SudokuDifficulty.expert => 600,
      SudokuDifficulty.master => 850,
      SudokuDifficulty.extreme => 1200,
    };

    int finalScore = (baseScore - (_secondsElapsed ~/ 2) - (_mistakesCount * 15)).clamp(50, 2000);

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
                  color: isWinner ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
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
                  color: const Color(0xFF475569),
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
              const SizedBox(height: 24),
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
                        backgroundColor: const Color(0xFF1D4ED8),
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
        Text(title, style: GoogleFonts.baloo2(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(val, style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
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

  @override
  Widget build(BuildContext context) {
    final isMultiplayer = widget.multiplayerService != null && widget.multiplayerService!.mode != MultiplayerMode.solo;
    final selectedNum = (_selectedRow != null && _selectedCol != null) ? _board[_selectedRow!][_selectedCol!].value : 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isMultiplayer ? 'Đấu Trường Sudoku' : 'Sudoku Trí Tuệ',
          style: GoogleFonts.baloo2(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF475569)),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(_secondsElapsed),
                  style: GoogleFonts.baloo2(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. THANH CHỌN ĐỘ KHÓ (CHÍNH XÁC THEO ẢNH MẪU)
            if (!isMultiplayer) _buildDifficultyBar() else _buildMultiplayerVsBar(),

            const SizedBox(height: 8),

            // 2. MA TRẬN BÀN CỜ 9x9 (THEO CHUẨN THIẾT KẾ ẢNH MẪU)
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
    );
  }

  /// 1. Thanh chọn độ khó chuẩn như ảnh mẫu:
  /// Độ khó: Dễ  Trung bình  Khó  Chuyên gia  Bậc thầy  Cực khó
  Widget _buildDifficultyBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          Text(
            'Độ khó:',
            style: GoogleFonts.baloo2(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          ...SudokuDifficulty.values.map((diff) {
            final isSelected = diff == _difficulty;
            return GestureDetector(
              onTap: () => _changeDifficulty(diff),
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  diff.label,
                  style: GoogleFonts.baloo2(
                    fontSize: 14.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            );
          }),
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Bạn: ${(myProgress * 100).toInt()}%',
                  style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8))),
              Text('${opponent?.name ?? "Đối thủ"}: ${(opProgress * 100).toInt()}%',
                  style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, color: const Color(0xFFEA580C))),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
              ),
              FractionallySizedBox(
                widthFactor: myProgress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(color: const Color(0xFF1D4ED8), borderRadius: BorderRadius.circular(4)),
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
        border: Border.all(color: const Color(0xFF1E293B), width: 2.5),
      ),
      child: Column(
        children: List.generate(9, (r) {
          final isThickBottom = (r % 3 == 2) && r != 8;
          return Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isThickBottom ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
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
                            color: isThickRight ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
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
      bgColor = const Color(0xFFFEE2E2); // Đỏ nhạt khi lỗi trùng
    } else if (isSelected) {
      bgColor = const Color(0xFFDCEAFB); // Xanh lam nhạt khi đang chọn
    } else if (isSameNumber) {
      bgColor = const Color(0xFFCFE2F9); // Xanh highlight chuẩn như ảnh mẫu
    } else if (isRelated) {
      bgColor = const Color(0xFFF8FAFC); // Rất nhạt cho hàng/cột/khối
    }

    Color textColor = const Color(0xFF0F172A); // Đen navy sâu cho đề bài
    if (hasConflict) {
      textColor = const Color(0xFFDC2626);
    } else if (!cell.isClue && cell.value != 0) {
      textColor = const Color(0xFF2563EB); // Xanh dương rực rỡ cho người chơi điền
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
                  color: const Color(0xFF64748B),
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
        ? const Color(0xFF1D4ED8)
        : (enabled ? const Color(0xFF334155) : Colors.grey.shade400);

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
                    color: isActive ? const Color(0xFFEFF6FF) : Colors.grey.shade100,
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
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                  height: 54,
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.grey.shade100 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCompleted ? Colors.transparent : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$num',
                    style: GoogleFonts.baloo2(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.grey.shade400 : const Color(0xFF1E293B),
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
