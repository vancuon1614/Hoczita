import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/game_strings.dart';
import '../../../core/providers/hint_quota_provider.dart';
import '../../../core/providers/chat_context_provider.dart';
import '../../../core/providers/game_interaction_provider.dart';

import 'package:hoczita_app/features/game/views/magic_words_report_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/game_score_sync_service.dart';
import '../models/word_completion_entry.dart';
import '../utils/wend_puzzle_generator.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../../../core/services/tts_service.dart';

class CompletedGridSnapshot {
  final List<List<LetterCell?>> grid;
  final PuzzleAnswer puzzle;
  final List<String> foundWords;

  CompletedGridSnapshot({
    required this.grid,
    required this.puzzle,
    required this.foundWords,
  });
}


extension FirstWhereOrNullExt<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class _DiagonalSlashPainter extends CustomPainter {
  final Color color;
  const _DiagonalSlashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    double strokeWidth = size.width < 22 ? 1.5 : 2.0;
    double offset = size.width < 22 ? 2.5 : 4.0;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw diagonal slash from bottom-left to top-right
    canvas.drawLine(
      Offset(offset, size.height - offset),
      Offset(size.width - offset, offset),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DiagonalSlashPainter oldDelegate) =>
      oldDelegate.color != color;
}

class TargetWord {
  final String id;
  final String word;
  bool isFilled = false;
  bool isSolved = false;
  int? slotOrder;              // MỚI: thứ tự trong nhóm cùng độ dài, gán khi giải đúng
  List<String?> displayCells;
  List<String> overflowDisplay;
  Color? assignedColor;
  List<LetterCell>? userPath;

  TargetWord(this.word)
      : id = word,
        displayCells = List.filled(word.length, null),
        overflowDisplay = [];

  void reset() {
    isFilled = false;
    isSolved = false;
    slotOrder = null;          // MỚI
    displayCells = List.filled(word.length, null);
    overflowDisplay = [];
    assignedColor = null;
    userPath = null;
  }
}

class LetterCell {
  final int row;
  final int col;
  final String letter;
  String?
  lockedWordId; // If null, it's not locked. If locked, stores the word string or ID.
  Color? lockedColor;

  LetterCell(this.row, this.col, this.letter);
}

class MagicWordsGameScreen extends ConsumerStatefulWidget {
  const MagicWordsGameScreen({super.key});

  @override
  ConsumerState<MagicWordsGameScreen> createState() => _MagicWordsGameScreenState();
}

class _MagicWordsGameScreenState extends ConsumerState<MagicWordsGameScreen> {
  bool _showHowToPlay = true;

  MagicWordsDifficulty? _selectedDifficulty;
  int _easyStars = 0;
  int _mediumStars = 0;
  int _hardStars = 0;
  int _easyHintsRemaining = 3;

  late List<List<LetterCell?>> _grid; // null means empty space (wall)
  late PuzzleAnswer _puzzle;

  final List<LetterCell> _currentSelection = [];
  List<TargetWord> _sortedWords = [];
  final List<WordCompletionEntry> _completionLog = [];
  List<String> get _foundWords => _sortedWords.where((w) => w.isSolved).map((w) => w.id).toList();

  final Map<int, int> _groupFillCounter = {};

  int _rows = 5;
  int _cols = 5;

  // Colors for locked words

  Offset? _lastLocalPosition;

  bool _isGameOver = false;
  bool _isGridDragging = false; // Fix scroll conflict

  Timer? _timer;
  int _secondsElapsed = 0;
  int _secondsRemaining = 0;
  int _undoCount = 0;
  int _hintCount = 0;
  int _errorCount = 0;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(isGameActiveProvider.notifier).state = true;
      }
    });
    _loadHighestStars();
  }

  Future<void> _loadHighestStars() async {
    final easy = await SupabaseService.instance.getHighestStarsForGame('magic_words_easy');
    final medium = await SupabaseService.instance.getHighestStarsForGame('magic_words_medium');
    final hard = await SupabaseService.instance.getHighestStarsForGame('magic_words_hard');
    if (mounted) {
      setState(() {
        _easyStars = easy;
        _mediumStars = medium;
        _hardStars = hard;
      });
    }
  }

  void _selectDifficulty(MagicWordsDifficulty diff) {
    setState(() {
      _selectedDifficulty = diff;
    });
    _loadPuzzle(diff);

    ref.read(isGameActiveProvider.notifier).state = true;
    ref.read(chatContextProvider.notifier).state = ChatContext(
      screenName: 'magic_words_game',
      data: {
        'difficulty': diff.name,
        'unsolved_word_lengths': _sortedWords.where((w) => !w.isSolved).map((w) => w.word.length).toList(),
      },
    );
  }

  @override
  void dispose() {
    ref.read(chatContextProvider.notifier).state = null;
    ref.read(isGameActiveProvider.notifier).state = false;
    ref.read(isGameDraggingProvider.notifier).state = false;
    _timer?.cancel();
    TtsService.instance.stopAll();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isGameOver || _selectedDifficulty == null) return;
      setState(() {
        _secondsElapsed++;
        if (_selectedDifficulty == MagicWordsDifficulty.medium ||
            _selectedDifficulty == MagicWordsDifficulty.hard) {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
            if (_secondsRemaining == 0) {
              _onTimeOut();
            }
          }
        }
      });
    });
  }

  void _onTimeOut() {
    _timer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.timer_off_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 8),
            Text(
              'Time\'s Up!',
              style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Time ran out for the ${_selectedDifficulty?.label ?? ''} challenge. Would you like to try again?',
          style: GoogleFonts.baloo2(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedDifficulty = null;
              });
              _loadHighestStars();
            },
            child: Text(
              'Choose Level',
              style: GoogleFonts.baloo2(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadPuzzle(_selectedDifficulty);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Try Again',
              style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Quit Game?',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to return to level selection? Current progress will not be saved.',
          style: GoogleFonts.baloo2(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Keep Playing',
              style: GoogleFonts.baloo2(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              _timer?.cancel();
              ref.read(isGameActiveProvider.notifier).state = false;
              Navigator.pop(context); // close dialog
              setState(() {
                _selectedDifficulty = null;
              });
              _loadHighestStars();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(
              'Quit',
              style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _loadPuzzle([MagicWordsDifficulty? diff]) {
    final difficulty = diff ?? _selectedDifficulty ?? MagicWordsDifficulty.easy;
    _isGameOver = false;
    _secondsElapsed = 0;
    _secondsRemaining = difficulty.countdownSeconds;
    _undoCount = 0;
    _hintCount = 0;
    _errorCount = 0;
    _easyHintsRemaining = 3;
    _currentlyHintingWordIndex = -1;
    _currentlyHintingCharIndex = 0;
    _groupFillCounter.clear();

    _puzzle = WendPuzzleGenerator.generate(difficulty: difficulty);
    _rows = _puzzle.rows;
    _cols = _puzzle.cols;
    
    List<String> tempWords = List<String>.from(_puzzle.targetWords);
    tempWords.sort((a, b) => a.length.compareTo(b.length));
    _sortedWords = tempWords.map((w) => TargetWord(w)).toList();
    _completionLog.clear();

    _grid = List.generate(
      _rows,
      (r) => List.generate(_cols, (c) {
        if (_puzzle.gridStr[r][c] == null) return null;
        return LetterCell(r, c, _puzzle.gridStr[r][c]!);
      }),
    );

    _foundWords.clear();
    _currentSelection.clear();
    _updateLiveFill();
    _startTimer();
  }

  void _handlePanStart(DragStartDetails details, BoxConstraints constraints) {
    if (_isGameOver) return;
    _lastLocalPosition = details.localPosition;
    _hitTestCell(details.localPosition, constraints);
  }

  void _handlePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_lastLocalPosition == null || _isGameOver) return;

    double dx = details.localPosition.dx - _lastLocalPosition!.dx;
    double dy = details.localPosition.dy - _lastLocalPosition!.dy;

    if (dx.abs() > dy.abs()) {
      if (dy.abs() / dx.abs() > 0.4) return;
    } else {
      if (dy.abs() == 0 || dx.abs() / dy.abs() > 0.4) return;
    }

    _lastLocalPosition = details.localPosition;
    _hitTestCell(details.localPosition, constraints);
  }

  void _hitTestCell(Offset localPosition, BoxConstraints constraints) {
    if (_isGameOver) return;
    double cellWidth = constraints.maxWidth / _cols;
    double cellHeight = constraints.maxHeight / _rows;

    int col = (localPosition.dx / cellWidth).floor();
    int row = (localPosition.dy / cellHeight).floor();

    if (row >= 0 && row < _rows && col >= 0 && col < _cols) {
      LetterCell? hovered = _grid[row][col];

      if (hovered == null) return; // Wall
      if (hovered.lockedWordId != null) return; // Already locked

      if (_currentSelection.isEmpty) {
        setState(() {
          _currentSelection.add(hovered);
          _updateLiveFill();
        });
      } else {
        LetterCell last = _currentSelection.last;

        // Allow backtracking (removing last letter)
        if (_currentSelection.length >= 2 &&
            _currentSelection[_currentSelection.length - 2] == hovered) {
          setState(() {
            _currentSelection.removeLast();
            _updateLiveFill();
          });
          return;
        }

        if (_currentSelection.contains(hovered)) return;

        bool isAdjacent =
            (last.row == row && (last.col - col).abs() == 1) ||
            (last.col == col && (last.row - row).abs() == 1);

        if (isAdjacent) {
          setState(() {
            _currentSelection.add(hovered);
            _updateLiveFill();
          });
        }
      }
    }
  }

  List<TargetWord> get _renderOrderWords {
    final groups = <int, List<TargetWord>>{};
    for (var w in _sortedWords) {
      groups.putIfAbsent(w.word.length, () => []).add(w);
    }
    final lengths = groups.keys.toList()..sort();
    final result = <TargetWord>[];
    for (var len in lengths) {
      final group = groups[len]!;
      final filled = group.where((w) => w.isFilled).toList()
        ..sort((a, b) => (a.slotOrder ?? 0).compareTo(b.slotOrder ?? 0));
      final unfilled = group.where((w) => !w.isFilled).toList();
      result.addAll(filled);
      result.addAll(unfilled);
    }
    return result;
  }

  TargetWord? _findTargetRowForSelection(int len) {
    var available = _renderOrderWords.where((w) => !w.isFilled).toList();
    if (available.isEmpty) return null;

    // 1. Khớp chính xác độ dài (ưu tiên hàng trên trước theo đúng _renderOrderWords)
    var exact = available.firstWhereOrNull((w) => w.word.length == len);
    if (exact != null) return exact;

    // 2. Nếu số ký tự dài hơn hoặc bằng mọi hàng trống còn lại, chọn hàng dài nhất
    var longest = available.last;
    if (len >= longest.word.length) {
      return longest;
    }

    // 3. Best fit: hàng trống đầu tiên có độ dài >= len (đẩy xuống các hàng bên dưới)
    var bestFit = available.firstWhereOrNull((w) => w.word.length >= len);
    return bestFit ?? available.first;
  }

  void _updateLiveFill() {
    // Clear live fill from any row that is not permanently committed
    for (var w in _sortedWords) {
      if (!w.isFilled) {
        w.displayCells.fillRange(0, w.displayCells.length, null);
        w.overflowDisplay.clear();
      }
    }

    if (_currentSelection.isEmpty) return;

    TargetWord? target = _findTargetRowForSelection(_currentSelection.length);
    if (target != null) {
      final selectedLetters = _currentSelection.map((c) => c.letter).toList();
      for (int i = 0; i < target.word.length; i++) {
        if (i < selectedLetters.length) {
          target.displayCells[i] = selectedLetters[i];
        } else {
          target.displayCells[i] = null;
        }
      }
      if (selectedLetters.length > target.word.length) {
        target.overflowDisplay = selectedLetters.sublist(target.word.length);
      } else {
        target.overflowDisplay = [];
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_currentSelection.isEmpty || _isGameOver) return;

    TargetWord? target = _findTargetRowForSelection(_currentSelection.length);
    if (target == null) {
      setState(() {
        _currentSelection.clear();
        _updateLiveFill();
      });
      return;
    }

    String wordForwards = _currentSelection.map((c) => c.letter).join('').toUpperCase();
    String wordBackwards = wordForwards.split('').reversed.join('');

    String? matchedWord;
    for (var w in _sortedWords) {
      if (!w.isSolved &&
          (wordForwards == w.word.toUpperCase() || wordBackwards == w.word.toUpperCase())) {
        matchedWord = w.word;
        break;
      }
    }

    setState(() {
      bool isMatch = matchedWord != null;
      TargetWord commitRow;

      if (isMatch) {
        // ĐÚNG: Gán thẳng vào TargetWord có word == matchedWord
        commitRow = _sortedWords.firstWhere((w) => w.word == matchedWord);
      } else {
        // SAI: Gán vào hàng tương ứng với độ dài/vị trí đang chọn (target)
        commitRow = target;
      }

      Color opColor = commitRow.assignedColor ??
          _puzzle.wordColors[_sortedWords.indexOf(commitRow) % _puzzle.wordColors.length];

      commitRow.isFilled = true;
      commitRow.isSolved = isMatch;
      commitRow.assignedColor = opColor;
      commitRow.userPath = List.from(_currentSelection);

      // Gán slotOrder theo thứ tự trong nhóm cùng độ dài
      final len = commitRow.word.length;
      if (commitRow.slotOrder == null) {
        commitRow.slotOrder = _groupFillCounter.putIfAbsent(len, () => 0);
        _groupFillCounter[len] = commitRow.slotOrder! + 1;
      }

      if (isMatch) {
        for (int i = 0; i < commitRow.word.length; i++) {
          commitRow.displayCells[i] = commitRow.word[i];
        }
        commitRow.overflowDisplay = [];
      } else {
        final selectedLetters = _currentSelection.map((c) => c.letter).toList();
        for (int i = 0; i < commitRow.word.length; i++) {
          if (i < selectedLetters.length) {
            commitRow.displayCells[i] = selectedLetters[i];
          } else {
            commitRow.displayCells[i] = null;
          }
        }
        if (selectedLetters.length > commitRow.word.length) {
          commitRow.overflowDisplay = selectedLetters.sublist(commitRow.word.length);
        } else {
          commitRow.overflowDisplay = [];
        }
      }

      // Lock cells on grid
      String lockId = isMatch ? commitRow.word : 'attempt_${commitRow.id}';
      for (var cell in _currentSelection) {
        cell.lockedWordId = lockId;
        cell.lockedColor = opColor;
      }

      if (isMatch) {
        _completionLog.add(WordCompletionEntry(
          word: commitRow.word,
          elapsedSeconds: _secondsElapsed,
          viaHint: false,
        ));
      } else {
        _completionLog.add(WordCompletionEntry(
          word: commitRow.id,
          elapsedSeconds: _secondsElapsed,
          viaHint: false,
        ));
        _errorCount++;
      }

      _currentSelection.clear();
      _updateLiveFill();

      if (isMatch) {
        _checkWinCondition();
      }
    });

    if (matchedWord != null) {
      TtsService.instance.speakEnglish(matchedWord);
    }
  }

  void _removeSolvedWord(String wordId) {
    setState(() {
      var target = _sortedWords.firstWhereOrNull((w) => w.id == wordId);
      if (target == null) return;

      String lockId1 = target.word;
      String lockId2 = 'attempt_${target.id}';
      for (int r = 0; r < _rows; r++) {
        for (int c = 0; c < _cols; c++) {
          if (_grid[r][c]?.lockedWordId == lockId1 ||
              _grid[r][c]?.lockedWordId == lockId2 ||
              _grid[r][c]?.lockedWordId == target.id) {
            _grid[r][c]!.lockedWordId = null;
            _grid[r][c]!.lockedColor = null;
          }
        }
      }

      final removedOrder = target.slotOrder;
      final len = target.word.length;
      if (removedOrder != null) {
        for (var w in _sortedWords) {
          if (w.word.length == len && w.isFilled && (w.slotOrder ?? -1) > removedOrder) {
            w.slotOrder = w.slotOrder! - 1;
          }
        }
        _groupFillCounter[len] = (_groupFillCounter[len] ?? 1) - 1;
        if ((_groupFillCounter[len] ?? 0) < 0) _groupFillCounter[len] = 0;
      }

      target.reset();
      _completionLog.removeWhere((e) => e.word == wordId);
      _updateLiveFill();
    });
  }

  void _undo() {
    if (_completionLog.isNotEmpty && !_isGameOver) {
      setState(() {
        _undoCount++;
        String lastWord = _completionLog.last.word;
        _removeSolvedWord(lastWord);
        _currentSelection.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedDifficulty == null) {
      return _buildDifficultySelection();
    }

    if (_isGameOver) {
      final duration = _selectedDifficulty == MagicWordsDifficulty.easy
          ? _secondsElapsed
          : max(1, _selectedDifficulty!.countdownSeconds - _secondsRemaining);
      return MagicWordsReportSheet(
        targetWords: _sortedWords.map((w) => w.word).toList(),
        secondsElapsed: duration,
        completionLog: _completionLog,
        score: _score,
        onReplay: () => _loadPuzzle(_selectedDifficulty),
        onGoHome: () {
          setState(() {
            _selectedDifficulty = null;
          });
          _loadHighestStars();
        },
      );
    }

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
              _buildAppBar(),
              // Subheader Row: Level/Badge + Reset on Left, Timer Pill on Right (Standard Layout)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedDifficulty != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFBAE6FD)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🎯', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedDifficulty!.label,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        TextButton.icon(
                          onPressed: _resetPuzzle,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            size: 15,
                            color: AppColors.textPrimary,
                          ),
                          label: Text(
                            GameStrings.reset,
                            style: GoogleFonts.baloo2(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: Colors.grey.shade200,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    _buildTimerWidget(),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: _isGridDragging
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    children: [
                      _buildGridWidget(),
                      _buildSelectionPreview(), // Thanh preview nằm ngay dưới lưới chữ
                      const SizedBox(height: 8),
                      _buildWordHints(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                      _buildHowToPlayCard(),
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

  Widget _buildDifficultySelection() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Magic Words',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: const Color(0xFF2C3E50),
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: GameSoundToggleButton(isPlayScreen: false),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0891B2), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0891B2).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'ENGLISH VOCABULARY',
                              style: GoogleFonts.baloo2(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFCFFAFE),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Magic Words',
                            style: GoogleFonts.baloo2(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Find and trace hidden words inside the magical letter grid!',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              color: const Color(0xFFCFFAFE),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'ImageFolder/magic_word.gif',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(
                              Icons.auto_stories_rounded,
                              size: 34,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Header: QUEST MAP + Magic Bonus Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'QUEST MAP',
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showBonusExplanationDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF1D4ED8)),
                          const SizedBox(width: 4),
                          Text(
                            'Magic Bonus',
                            style: GoogleFonts.baloo2(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // STAGE 3: EAGLE SIGHT (Eagle Vision - Mystic Fuchsia)
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: _buildTowerTierCard(
                  tierNumber: 3,
                  tierLabel: 'STAGE 3 • EAGLE SIGHT',
                  tagText: '8x8 Grid • 10 Mins',
                  title: 'Eagle Vision',
                  subtitle: 'Uncover words hidden in all directions: horizontal, vertical & diagonal',
                  emoji: '🦅',
                  primaryColor: const Color(0xFFC026D3),
                  lightBgColor: const Color(0xFFFDF4FF),
                  borderColor: const Color(0xFFF5D0FE),
                  gradientColors: const [Color(0xFFD946EF), Color(0xFFC026D3)],
                  difficultyText: 'Hard',
                  stars: _hardStars,
                  onTap: () => _selectDifficulty(MagicWordsDifficulty.hard),
                ),
              ),

              _buildCurvedPathConnector(curveToRight: true),

              // STAGE 2: SHARP FOCUS (Word Hunter - Electric Indigo)
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: _buildTowerTierCard(
                  tierNumber: 2,
                  tierLabel: 'STAGE 2 • SHARP FOCUS',
                  tagText: '6x6 Grid • 5 Mins',
                  title: 'Word Hunter',
                  subtitle: 'Trace horizontal and vertical hidden words swiftly',
                  emoji: '🧭',
                  primaryColor: const Color(0xFF4F46E5),
                  lightBgColor: const Color(0xFFEEF2FF),
                  borderColor: const Color(0xFFC7D2FE),
                  gradientColors: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  difficultyText: 'Medium',
                  stars: _mediumStars,
                  onTap: () => _selectDifficulty(MagicWordsDifficulty.medium),
                ),
              ),

              _buildCurvedPathConnector(curveToRight: false),

              // STAGE 1: OBSERVATION (Sharp Eye - Cyan Aqua)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildTowerTierCard(
                  tierNumber: 1,
                  tierLabel: 'STAGE 1 • OBSERVATION',
                  tagText: '4x4 Grid • Untimed',
                  title: 'Sharp Eye',
                  subtitle: 'Scan and spot hidden words in a cozy starter grid',
                  emoji: '👁️',
                  primaryColor: const Color(0xFF0891B2),
                  lightBgColor: const Color(0xFFECFEFF),
                  borderColor: const Color(0xFFA5F3FC),
                  gradientColors: const [Color(0xFF06B6D4), Color(0xFF0891B2)],
                  difficultyText: 'Easy',
                  stars: _easyStars,
                  onTap: () => _selectDifficulty(MagicWordsDifficulty.easy),
                ),
              ),

              const SizedBox(height: 28),

              // Footer Card: Round Standard & Reward Multiplier
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x06000000),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('🎯', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ROUND STANDARD',
                            style: GoogleFonts.baloo2(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            'Find all hidden target words',
                            style: GoogleFonts.baloo2(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                    const SizedBox(width: 12),
                    const Text('⚡', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REWARD MULTIPLIER',
                            style: GoogleFonts.baloo2(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            'Zero-Penalty & Time Bonus',
                            style: GoogleFonts.baloo2(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFC026D3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurvedPathConnector({
    required bool curveToRight,
  }) {
    return SizedBox(
      height: 38,
      child: CustomPaint(
        painter: _CurvedDashedPathPainter(curveToRight: curveToRight),
      ),
    );
  }

  Widget _buildTowerTierCard({
    required int tierNumber,
    required String tierLabel,
    required String tagText,
    required String title,
    required String subtitle,
    required String emoji,
    required Color primaryColor,
    required Color lightBgColor,
    required Color borderColor,
    required List<Color> gradientColors,
    required String difficultyText,
    required int stars,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Sub-badge top row: Stage number + Stage label + Tag pill
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$tierNumber',
                      style: GoogleFonts.baloo2(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tierLabel,
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: lightBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor.withValues(alpha: 0.6)),
                ),
                child: Text(
                  tagText,
                  style: GoogleFonts.baloo2(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // 2. Interactive Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0x06000000),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                child: Row(
                  children: [
                    // Squircle Pastel Toy Icon (Màu nhạt mềm mại như hình mẫu)
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: lightBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title, Subtitle and 3-step Difficulty Bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.baloo2(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: GoogleFonts.baloo2(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              for (int i = 1; i <= 3; i++) ...[
                                Container(
                                  width: 14,
                                  height: 4.5,
                                  decoration: BoxDecoration(
                                    color: i <= tierNumber ? primaryColor : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                if (i < 3) const SizedBox(width: 3),
                              ],
                              const SizedBox(width: 6),
                              Text(
                                difficultyText,
                                style: GoogleFonts.baloo2(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Arrow Icon
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: lightBgColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor.withValues(alpha: 0.8)),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showBonusExplanationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD946EF), Color(0xFFC026D3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC026D3).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('⚡', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Score & Bonus Rules',
                          style: GoogleFonts.baloo2(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Magic Words Mastery',
                          style: GoogleFonts.baloo2(
                            fontSize: 12.5,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildBonusInfoRow(
                      icon: '🦅',
                      title: 'Eagle Eye (Zero Penalty)',
                      desc: 'Trace words accurately without wrong swipes to keep full base points without deductions.',
                    ),
                    const Divider(height: 18, thickness: 0.8, color: Color(0xFFE2E8F0)),
                    _buildBonusInfoRow(
                      icon: '⏱️',
                      title: 'Time Left Bonus',
                      desc: 'In Medium and Hard modes, remaining time on the countdown clock converts directly into bonus points!',
                    ),
                    const Divider(height: 18, thickness: 0.8, color: Color(0xFFE2E8F0)),
                    _buildBonusInfoRow(
                      icon: '🌟',
                      title: 'Zero-Hint Mastery',
                      desc: 'Find all words without requesting hints to earn the ultimate bonus score on the stage map.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC026D3),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Got it, start adventure!',
                      style: GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBonusInfoRow({
    required String icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.baloo2(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: _showQuitConfirmation,
          ),
          Expanded(
            child: Center(
              child: Text(
                'Magic Words 🔠',
                style: GoogleFonts.baloo2(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const GameSoundToggleButton(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTimerWidget() {
    if (_selectedDifficulty == MagicWordsDifficulty.easy) {
      return GameCountUpTimer(elapsedSeconds: _secondsElapsed);
    }

    const Color bgColor = Color(0xFFFEE2E2);
    const Color textColor = Color(0xFFDC2626);
    const Color borderColor = Color(0xFFFCA5A5);

    final displayStr = GameCountUpTimer.formatSeconds(_secondsRemaining);

    return Container(
      width: 76,
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.timer_outlined,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 38,
            child: Text(
              displayStr,
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridWidget({bool readOnlyMode = false, CompletedGridSnapshot? snapshot}) {
    final gridData = snapshot?.grid ?? _grid;
    final puzzleData = snapshot?.puzzle ?? _puzzle;
    final foundWordsData = snapshot?.foundWords ?? _foundWords;
    final selectionData = readOnlyMode ? <LetterCell>[] : _currentSelection;

    Widget contentWidget = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // If constraints are infinite (e.g., inside FittedBox), fallback to 300
          double size = constraints.maxWidth == double.infinity ? 300 : constraints.maxWidth;
          double cellWidth = size / puzzleData.cols;
          double cellHeight = size / puzzleData.rows;

          final activeTarget = _findTargetRowForSelection(selectionData.length);
          final activeColor = activeTarget != null
              ? (activeTarget.assignedColor ??
                  puzzleData.wordColors[_sortedWords.indexOf(activeTarget) % puzzleData.wordColors.length])
              : const Color(0xFFFF6D00);

          Widget gridStack = SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: puzzleData.cols,
                    childAspectRatio: cellWidth / cellHeight,
                  ),
                  itemCount: puzzleData.rows * puzzleData.cols,
                  itemBuilder: (context, index) {
                    int r = index ~/ puzzleData.cols;
                    int c = index % puzzleData.cols;
                    LetterCell? cell = gridData[r][c];

                    if (cell == null) {
                      // Blocker: ô xám đặc bo góc — giống ảnh tham chiếu
                      return Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB4BDC8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }

                    final bool isSelected = selectionData.contains(cell);
                    final bool isLocked = cell.lockedColor != null;

                    Color bgColor = Colors.white;
                    if (isLocked) {
                      bgColor = cell.lockedColor!.withValues(alpha: 0.2);
                    } else if (isSelected) {
                      bgColor = activeColor.withValues(alpha: 0.18);
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(color: activeColor, width: 2.5)
                            : isLocked
                                ? Border.all(
                                    color: cell.lockedColor!.withValues(alpha: 0.6),
                                    width: 1.5,
                                  )
                                : null,
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? activeColor.withValues(alpha: 0.28)
                                : Colors.black.withValues(alpha: 0.09),
                            blurRadius: isSelected ? 8 : 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cell.letter,
                        style: GoogleFonts.baloo2(
                          fontSize: (cellWidth * 0.44).clamp(12.0, 24.0),
                          fontWeight: FontWeight.bold,
                          color: isLocked
                              ? (cell.lockedColor ?? AppColors.textPrimary)
                              : AppColors.textPrimary,
                        ),
                      ),
                    );
                  },
                ),
                // Draw Locked Paths
                if (readOnlyMode)
                  ...foundWordsData.map((word) {
                    return IgnorePointer(
                      child: CustomPaint(
                        size: Size(size, size),
                        painter: WendPathPainter(
                          path: puzzleData.wordPaths[word]!
                              .map((p) => gridData[p.row][p.col]!)
                              .toList(),
                          cellWidth: cellWidth,
                          cellHeight: cellHeight,
                          pathColor: puzzleData
                              .wordColors[puzzleData.targetWords.indexOf(word)],
                          isLocked: true,
                          isSolved: true,
                        ),
                      ),
                    );
                  })
                else
                  ..._sortedWords
                      .where((w) => w.isFilled && w.userPath != null && w.userPath!.isNotEmpty)
                      .map((targetWord) {
                    return IgnorePointer(
                      child: CustomPaint(
                        size: Size(size, size),
                        painter: WendPathPainter(
                          path: targetWord.userPath!,
                          cellWidth: cellWidth,
                          cellHeight: cellHeight,
                          pathColor: targetWord.assignedColor ??
                              puzzleData.wordColors[_sortedWords.indexOf(targetWord) % puzzleData.wordColors.length],
                          isLocked: true,
                          isSolved: targetWord.isSolved,
                        ),
                      ),
                    );
                  }),
                // Draw Selection Path
                if (selectionData.isNotEmpty)
                  IgnorePointer(
                    child: CustomPaint(
                      size: Size(size, size),
                      painter: WendPathPainter(
                        path: selectionData,
                        cellWidth: cellWidth,
                        cellHeight: cellHeight,
                        pathColor: activeColor,
                        isLocked: false,
                      ),
                    ),
                  ),
              ],
            ),
          );

          if (readOnlyMode) {
            return gridStack;
          }

          return Listener(
            onPointerDown: (_) {
              setState(() => _isGridDragging = true);
              ref.read(isGameDraggingProvider.notifier).state = true;
            },
            onPointerUp: (_) {
              setState(() => _isGridDragging = false);
              ref.read(isGameDraggingProvider.notifier).state = false;
            },
            onPointerCancel: (_) {
              setState(() => _isGridDragging = false);
              ref.read(isGameDraggingProvider.notifier).state = false;
            },
            child: GestureDetector(
              onPanStart: (d) => _handlePanStart(d, BoxConstraints.tightFor(width: size, height: size)),
              onPanUpdate: (d) => _handlePanUpdate(d, BoxConstraints.tightFor(width: size, height: size)),
              onPanEnd: _handlePanEnd,
              child: gridStack,
            ),
          );
        },
      ),
    );

    if (readOnlyMode) {
      // Return un-interactive grid with fixed aspect ratio
      return IgnorePointer(child: contentWidget);
    }
    return contentWidget;
  }



  Widget _buildSelectionPreview() {
    TargetWord? target = _findTargetRowForSelection(_currentSelection.length);
    Color barColor = target != null
        ? (target.assignedColor ??
            _puzzle.wordColors[_sortedWords.indexOf(target) % _puzzle.wordColors.length])
        : AppColors.primary;

    final int maxLettersInGame = _sortedWords.fold<int>(
      0,
      (prev, row) => max(prev, row.word.length + row.overflowDisplay.length),
    );
    final int count = max(_currentSelection.length, maxLettersInGame);
    double boxSize;
    double fontSize;
    double radius;
    double spacing;
    double runSpacing;

    if (count > 14) {
      boxSize = 18.0;
      fontSize = 10.5;
      radius = 4.0;
      spacing = 2.5;
      runSpacing = 3.0;
    } else if (count > 8) {
      boxSize = 24.0;
      fontSize = 12.5;
      radius = 5.0;
      spacing = 4.0;
      runSpacing = 4.0;
    } else {
      boxSize = 32.0;
      fontSize = 16.0;
      radius = 8.0;
      spacing = 6.0;
      runSpacing = 6.0;
    }

    return Container(
      height: 54, // Fixed height keeps result rows below completely stationary
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      alignment: Alignment.center,
      child: _currentSelection.isEmpty
          ? const SizedBox.shrink()
          : SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: spacing,
                runSpacing: runSpacing,
                children: _currentSelection.map((cell) {
                  return Container(
                    width: boxSize,
                    height: boxSize,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(radius),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cell.letter,
                      style: GoogleFonts.baloo2(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: fontSize,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildWordHints() {
    // Find the longest sequence across all rows in the puzzle to ensure UNIFORM box size across every row
    final int maxLettersInGame = _renderOrderWords.fold<int>(
      0,
      (prev, row) => max(prev, row.word.length + row.overflowDisplay.length),
    );

    final double boxSize;
    final double fontSize;
    final double radius;
    final double spacing;
    final double runSpacing;

    if (maxLettersInGame > 14) {
      boxSize = 18.0;
      fontSize = 10.5;
      radius = 4.0;
      spacing = 2.5;
      runSpacing = 3.0;
    } else if (maxLettersInGame > 8) {
      boxSize = 24.0;
      fontSize = 12.5;
      radius = 5.0;
      spacing = 4.0;
      runSpacing = 4.0;
    } else {
      boxSize = 32.0;
      fontSize = 16.0;
      radius = 8.0;
      spacing = 6.0;
      runSpacing = 6.0;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _renderOrderWords.map((targetRow) {
          bool isFilled = targetRow.isFilled;
          bool isSolved = targetRow.isSolved;

          Color rowColor = targetRow.assignedColor ??
              _puzzle.wordColors[_sortedWords.indexOf(targetRow) % _puzzle.wordColors.length];

          return GestureDetector(
            onTap: isFilled ? () => _removeSolvedWord(targetRow.id) : null,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: spacing,
                  runSpacing: runSpacing,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Normal target letter boxes
                    ...List.generate(targetRow.word.length, (i) {
                      String? char = targetRow.displayCells[i];
                      bool hasChar = char != null && char.isNotEmpty;

                      return Container(
                        width: boxSize,
                        height: boxSize,
                        decoration: BoxDecoration(
                          color: hasChar ? rowColor : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(radius),
                          border: Border.all(
                            color: hasChar ? rowColor : Colors.grey.shade300,
                            width: maxLettersInGame > 14 ? 1.0 : 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          char ?? '',
                          style: GoogleFonts.baloo2(
                            fontWeight: FontWeight.bold,
                            fontSize: fontSize,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    }),

                    // Overflow boxes with diagonal strikethrough matching rowColor
                    ...targetRow.overflowDisplay.map((char) {
                      return Container(
                        width: boxSize,
                        height: boxSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(radius),
                          border: Border.all(
                            color: rowColor,
                            width: maxLettersInGame > 14 ? 1.0 : 1.5,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              char,
                              style: GoogleFonts.baloo2(
                                fontWeight: FontWeight.bold,
                                fontSize: fontSize,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            CustomPaint(
                              size: Size(boxSize, boxSize),
                              painter: _DiagonalSlashPainter(color: rowColor),
                            ),
                          ],
                        ),
                      );
                    }),

                    // Solved checkmark
                    if (isSolved)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.check_rounded,
                          color: Colors.green,
                          size: boxSize * 0.75 > 18 ? boxSize * 0.75 : 18,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons() {
    final isEasy = _selectedDifficulty == MagicWordsDifficulty.easy;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _undo,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              GameStrings.undo,
              style: GoogleFonts.baloo2(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: isEasy
              ? ElevatedButton(
                  onPressed: _easyHintsRemaining > 0 ? _requestHintEasy : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "${GameStrings.hint} ($_easyHintsRemaining)",
                    style: GoogleFonts.baloo2(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Consumer(
                  builder: (context, ref, _) {
                    final quotaState = ref.watch(hintQuotaProvider);
                    final canHint = !quotaState.isLoading && quotaState.remaining > 0;
                    return ElevatedButton(
                      onPressed: canHint
                          ? () {
                              if (_selectedDifficulty == MagicWordsDifficulty.hard) {
                                _requestHintHard(ref);
                              } else {
                                _requestHint(ref);
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "${GameStrings.hint} (${quotaState.isLoading ? '-' : quotaState.remaining})",
                        style: GoogleFonts.baloo2(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _checkWinCondition() async {
    bool allSolved = _sortedWords.isNotEmpty && _sortedWords.every((w) => w.isSolved);
    if (allSolved && !_isGameOver) {
      _timer?.cancel();
      final diff = _selectedDifficulty ?? MagicWordsDifficulty.easy;
      int duration = diff == MagicWordsDifficulty.easy
          ? _secondsElapsed
          : max(1, diff.countdownSeconds - _secondsRemaining);

      int basePoints = diff.basePoints;
      int penalty = (_errorCount * 2) + (_hintCount * 3) + (_undoCount * 1);
      int score = max(5, basePoints - penalty);

      setState(() {
        _score = score;
        _isGameOver = true;
      });

      // Tạm thời không tính sao cho mini-games có chế độ
      try {
        final levelStr = diff == MagicWordsDifficulty.easy ? '1' : (diff == MagicWordsDifficulty.medium ? '2' : '3');
        await GameScoreSyncService.instance.saveScoreParallel(
          gameCodeOrName: 'E06',
          level: levelStr,
          score: score,
          stars: 0,
          durationSeconds: duration,
          completionLog: _completionLog.map((e) => e.toJson()).toList(),
        );
        _loadHighestStars();
      } catch (e) {
        debugPrint('Error saving magic_words score: $e');
      }
    }
  }

  void _resetPuzzle() {
    setState(() {
      _groupFillCounter.clear();
      for (int r = 0; r < _rows; r++) {
        for (int c = 0; c < _cols; c++) {
          if (_grid[r][c] != null) {
            _grid[r][c]!.lockedWordId = null;
            _grid[r][c]!.lockedColor = null;
          }
        }
      }
      for (var w in _sortedWords) {
        w.reset();
      }
      _completionLog.clear();
      _currentSelection.clear();
      _currentlyHintingWordIndex = -1;
      _currentlyHintingCharIndex = 0;
      _secondsElapsed = 0;
      if (_selectedDifficulty != null && _selectedDifficulty != MagicWordsDifficulty.easy) {
        _secondsRemaining = _selectedDifficulty!.countdownSeconds;
      }
      if (_selectedDifficulty == MagicWordsDifficulty.easy) {
        _easyHintsRemaining = 3;
      }
      _updateLiveFill();
    });
  }

  int _currentlyHintingWordIndex = -1;
  int _currentlyHintingCharIndex = 0;

  void _requestHintEasy() {
    if (_easyHintsRemaining <= 0) return;

    TargetWord? targetRow;
    try {
      if (_currentlyHintingWordIndex != -1) {
        targetRow = _sortedWords.firstWhere(
          (w) => w.id == _sortedWords[_currentlyHintingWordIndex].id && !w.isSolved,
          orElse: () => _sortedWords.firstWhere((w) => !w.isSolved),
        );
      } else {
        targetRow = _sortedWords.firstWhere((w) => !w.isSolved);
      }
    } catch (e) {
      return;
    }

    bool isNewWord = _currentlyHintingWordIndex == -1 || targetRow.id != _sortedWords[_currentlyHintingWordIndex].id;

    if (isNewWord) {
      _currentlyHintingWordIndex = _sortedWords.indexOf(targetRow);
      _currentlyHintingCharIndex = 0;
    }

    setState(() {
      _easyHintsRemaining--;
      _hintCount++;

      TargetWord w = _sortedWords[_currentlyHintingWordIndex];
      String wordStr = w.word;

      Color wordColor = _puzzle.wordColors[_puzzle.targetWords.indexOf(wordStr)];
      var path = _puzzle.wordPaths[wordStr]!;

      var cell = path[_currentlyHintingCharIndex];
      _grid[cell.row][cell.col]!.lockedWordId = wordStr;
      _grid[cell.row][cell.col]!.lockedColor = wordColor.withValues(alpha: 0.5);

      w.displayCells[_currentlyHintingCharIndex] = wordStr[_currentlyHintingCharIndex];
      _currentlyHintingCharIndex++;

      if (_currentlyHintingCharIndex >= wordStr.length) {
        w.isFilled = true;
        w.isSolved = true;
        w.assignedColor = wordColor;
        final len = w.word.length;
        if (w.slotOrder == null) {
          w.slotOrder = _groupFillCounter.putIfAbsent(len, () => 0);
          _groupFillCounter[len] = w.slotOrder! + 1;
        }
        _completionLog.add(WordCompletionEntry(
          word: wordStr,
          elapsedSeconds: _secondsElapsed,
          viaHint: true,
        ));
        for (var c in path) {
          _grid[c.row][c.col]!.lockedWordId = wordStr;
          _grid[c.row][c.col]!.lockedColor = wordColor;
        }
        _currentlyHintingWordIndex = -1;
        _currentlyHintingCharIndex = 0;
        _checkWinCondition();
        TtsService.instance.speakEnglish(wordStr);
      }
    });
  }

  Future<void> _requestHintHard(WidgetRef ref) async {
    TargetWord? targetRow;
    try {
      targetRow = _sortedWords.firstWhereOrNull((w) => !w.isSolved && (w.displayCells.isEmpty || w.displayCells[0] == null));
      targetRow ??= _sortedWords.firstWhereOrNull((w) => !w.isSolved);
    } catch (e) {
      return;
    }
    if (targetRow == null) return;

    try {
      final res = await SupabaseService.instance.client.rpc('request_hint_start');
      if (!mounted) return;
      if (res['allowed'] == false) {
        return;
      }
      if (res['allowed'] == 'needs_confirmation') {
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(GameStrings.hintWarningTitle),
            content: Text(GameStrings.hintWarningMessage.replaceAll('{remainingAfterUse}', '1')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(GameStrings.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(GameStrings.confirm),
              ),
            ],
          ),
        );
        if (confirm != true) return;

        final confirmRes = await SupabaseService.instance.client.rpc('confirm_hint_after_warning');
        if (confirmRes['allowed'] != true) return;
        ref.read(hintQuotaProvider.notifier).updateRemaining(confirmRes['remaining'] as int);
      } else {
        ref.read(hintQuotaProvider.notifier).updateRemaining(res['remaining'] as int);
      }
    } catch (e) {
      return;
    }

    setState(() {
      _hintCount++;
      String wordStr = targetRow!.word;
      targetRow.displayCells[0] = wordStr[0];

      Color wordColor = _puzzle.wordColors[_puzzle.targetWords.indexOf(wordStr)];
      var path = _puzzle.wordPaths[wordStr]!;
      var firstCell = path[0];

      _grid[firstCell.row][firstCell.col]!.lockedColor = wordColor.withValues(alpha: 0.35);

      _currentlyHintingWordIndex = -1;
      _currentlyHintingCharIndex = 0;
    });
  }

  Future<void> _requestHint(WidgetRef ref) async {
    // 1. Determine target
    TargetWord? targetRow;
    try {
      if (_currentlyHintingWordIndex != -1) {
         targetRow = _sortedWords.firstWhere((w) => w.id == _sortedWords[_currentlyHintingWordIndex].id && !w.isSolved, orElse: () => _sortedWords.firstWhere((w) => !w.isSolved));
      } else {
         targetRow = _sortedWords.firstWhere((w) => !w.isSolved);
      }
    } catch (e) {
      return;
    }
    
    // Check if new word
    bool isNewWord = _currentlyHintingWordIndex == -1 || targetRow.id != _sortedWords[_currentlyHintingWordIndex].id;

    if (isNewWord) {
       try {
         // Trừ quota NGAY TẠI THỜI ĐIỂM BẮT ĐẦU từ mới (ký tự đầu tiên)
         final res = await SupabaseService.instance.client.rpc('request_hint_start');
         if (!mounted) return;
         if (res['allowed'] == false) {
           return;
         }
         if (res['allowed'] == 'needs_confirmation') {
           // Modal cảnh báo chỉ hiện đúng 1 lần nhờ cờ warning_shown lưu phía server
           bool? confirm = await showDialog<bool>(
             context: context,
             builder: (ctx) => AlertDialog(
               title: Text(GameStrings.hintWarningTitle),
               content: Text(GameStrings.hintWarningMessage.replaceAll('{remainingAfterUse}', '1')),
               actions: [
                 TextButton(
                   onPressed: () => Navigator.pop(ctx, false),
                   child: Text(GameStrings.cancel)
                 ),
                 TextButton(
                   onPressed: () => Navigator.pop(ctx, true),
                   child: Text(GameStrings.confirm)
                 )
               ]
             )
           );
           if (confirm != true) return;
           
           final confirmRes = await SupabaseService.instance.client.rpc('confirm_hint_after_warning');
           if (confirmRes['allowed'] != true) return;
           ref.read(hintQuotaProvider.notifier).updateRemaining(confirmRes['remaining'] as int);
         } else {
           ref.read(hintQuotaProvider.notifier).updateRemaining(res['remaining'] as int);
         }
       } catch (e) {
         return; // Network error
       }
       _currentlyHintingWordIndex = _sortedWords.indexOf(targetRow);
       _currentlyHintingCharIndex = 0;
    }
    
    // Reveal one char
    setState(() {
      TargetWord w = _sortedWords[_currentlyHintingWordIndex];
      String wordStr = w.word;
      
      // We actually need to draw it on the grid
      Color wordColor = _puzzle.wordColors[_puzzle.targetWords.indexOf(wordStr)];
      var path = _puzzle.wordPaths[wordStr]!;
      
      var cell = path[_currentlyHintingCharIndex];
      _grid[cell.row][cell.col]!.lockedWordId = wordStr; // partial lock is fine
      _grid[cell.row][cell.col]!.lockedColor = wordColor.withValues(alpha: 0.5);
      
      w.displayCells[_currentlyHintingCharIndex] = wordStr[_currentlyHintingCharIndex];
      _currentlyHintingCharIndex++;
      
      if (_currentlyHintingCharIndex >= wordStr.length) {
         // Full word solved via hint
         w.isFilled = true;
         w.isSolved = true;
         w.assignedColor = wordColor;
         final len = w.word.length;
         if (w.slotOrder == null) {
           w.slotOrder = _groupFillCounter.putIfAbsent(len, () => 0);
           _groupFillCounter[len] = w.slotOrder! + 1;
         }
         _completionLog.add(WordCompletionEntry(
           word: wordStr,
           elapsedSeconds: _secondsElapsed,
           viaHint: true,
         ));
         for (var c in path) {
           _grid[c.row][c.col]!.lockedWordId = wordStr;
           _grid[c.row][c.col]!.lockedColor = wordColor;
         }
         _currentlyHintingWordIndex = -1;
         _currentlyHintingCharIndex = 0;
         _checkWinCondition();
         TtsService.instance.speakEnglish(wordStr);
      }
    });
  }


  Widget _buildHowToPlayCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _showHowToPlay,
          onExpansionChanged: (val) {
            setState(() {
              _showHowToPlay = val;
            });
          },
          title: Text(
            'How to Play',
            style: GoogleFonts.baloo2(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                bottom: 16.0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Find all hidden words. Use each letter tile to cover the entire board!',
                  style: GoogleFonts.baloo2(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WendPathPainter extends CustomPainter {
  final List<LetterCell> path;
  final double cellWidth;
  final double cellHeight;
  final Color pathColor;
  final bool isLocked;
  final bool isSolved;

  WendPathPainter({
    required this.path,
    required this.cellWidth,
    required this.cellHeight,
    required this.pathColor,
    this.isLocked = false,
    this.isSolved = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (path.isEmpty) return;

    final paint = Paint()
      ..color = pathColor.withValues(alpha: 0.5)
      ..strokeWidth = min(cellWidth, cellHeight) * 0.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final drawPath = Path();
    for (int i = 0; i < path.length; i++) {
      double cx = path[i].col * cellWidth + cellWidth / 2;
      double cy = path[i].row * cellHeight + cellHeight / 2;
      if (i == 0) {
        drawPath.moveTo(cx, cy);
      } else {
        drawPath.lineTo(cx, cy);
      }
    }

    if (path.length > 1) {
      canvas.drawPath(drawPath, paint);
    }

    if (isLocked && path.isNotEmpty) {
      // Draw arrows between cells
      final arrowPaint = Paint()
        ..color = pathColor
        ..strokeWidth = 2
        ..style = PaintingStyle.fill;

      for (int i = 0; i < path.length - 1; i++) {
        double px = path[i].col * cellWidth + cellWidth / 2;
        double py = path[i].row * cellHeight + cellHeight / 2;
        double cx = path[i + 1].col * cellWidth + cellWidth / 2;
        double cy = path[i + 1].row * cellHeight + cellHeight / 2;

        double midX = (px + cx) / 2;
        double midY = (py + cy) / 2;

        // Draw a small triangle pointing from p to c
        double angle = atan2(cy - py, cx - px);
        double arrowSize = min(cellWidth, cellHeight) * 0.15;

        Path arrowPath = Path();
        arrowPath.moveTo(
          midX + arrowSize * cos(angle),
          midY + arrowSize * sin(angle),
        );
        arrowPath.lineTo(
          midX + arrowSize * cos(angle + 2.5),
          midY + arrowSize * sin(angle + 2.5),
        );
        arrowPath.lineTo(
          midX + arrowSize * cos(angle - 2.5),
          midY + arrowSize * sin(angle - 2.5),
        );
        arrowPath.close();

        canvas.drawPath(arrowPath, arrowPaint);
      }

      // Draw checkmark on last cell only if solved
      if (isSolved) {
        double lastX = path.last.col * cellWidth + cellWidth / 2;
        double lastY = path.last.row * cellHeight + cellHeight / 2;

        // Position at top-right corner of the cell
        double badgeX = lastX + cellWidth * 0.35;
        double badgeY = lastY - cellHeight * 0.35;

        final badgePaint = Paint()
          ..color = pathColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(badgeX, badgeY),
          min(cellWidth, cellHeight) * 0.2,
          badgePaint,
        );

        // Draw a simple white checkmark
        final checkPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = min(cellWidth, cellHeight) * 0.08
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        Path checkPath = Path();
        checkPath.moveTo(badgeX - min(cellWidth, cellHeight) * 0.08, badgeY);
        checkPath.lineTo(
          badgeX - min(cellWidth, cellHeight) * 0.02,
          badgeY + min(cellWidth, cellHeight) * 0.06,
        );
        checkPath.lineTo(
          badgeX + min(cellWidth, cellHeight) * 0.1,
          badgeY - min(cellWidth, cellHeight) * 0.08,
        );

        canvas.drawPath(checkPath, checkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WendPathPainter oldDelegate) {
    return oldDelegate.path != path ||
        oldDelegate.pathColor != pathColor ||
        oldDelegate.isLocked != isLocked ||
        oldDelegate.isSolved != isSolved;
  }
}

class _CurvedDashedPathPainter extends CustomPainter {
  final bool curveToRight;

  const _CurvedDashedPathPainter({required this.curveToRight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (curveToRight) {
      // From top-left to bottom-right (Chặng 3 xuống Chặng 2)
      path.moveTo(size.width * 0.32, 0);
      path.cubicTo(
        size.width * 0.32,
        size.height * 0.55,
        size.width * 0.68,
        size.height * 0.45,
        size.width * 0.68,
        size.height,
      );
    } else {
      // From top-right to bottom-left (Chặng 2 xuống Chặng 1)
      path.moveTo(size.width * 0.68, 0);
      path.cubicTo(
        size.width * 0.68,
        size.height * 0.55,
        size.width * 0.32,
        size.height * 0.45,
        size.width * 0.32,
        size.height,
      );
    }

    // Vẽ nét đứt mềm mại
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      const dashLength = 6.0;
      const spaceLength = 5.0;
      while (distance < metric.length) {
        final len = (distance + dashLength < metric.length)
            ? dashLength
            : metric.length - distance;
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += dashLength + spaceLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CurvedDashedPathPainter oldDelegate) =>
      oldDelegate.curveToRight != curveToRight;
}
