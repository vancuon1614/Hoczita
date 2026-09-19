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
import '../models/word_completion_entry.dart';
import '../utils/wend_puzzle_generator.dart';

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
  int _undoCount = 0;
  int _hintCount = 0;
  int _errorCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPuzzle();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatContextProvider.notifier).state = ChatContext(
        screenName: 'magic_words_game',
        data: {
          'unsolved_word_lengths': _sortedWords.where((w) => !w.isSolved).map((w) => w.word.length).toList(),
        },
      );
    });
  }

  @override
  void dispose() {
    ref.read(chatContextProvider.notifier).state = null;
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isGameOver) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  void _loadPuzzle() {
    _isGameOver = false;
    _secondsElapsed = 0;
    _undoCount = 0;
    _hintCount = 0;
    _errorCount = 0;
    _groupFillCounter.clear();

    _puzzle = WendPuzzleGenerator.generate();
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
    if (_isGameOver) {
      return MagicWordsReportSheet(
        targetWords: _sortedWords.map((w) => w.word).toList(),
        secondsElapsed: _secondsElapsed,
        completionLog: _completionLog,
        onReplay: _loadPuzzle,
        onGoHome: () {
          Navigator.of(context).pop();
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
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
    );
  }

  Widget _buildAppBar() {
    int mins = _secondsElapsed ~/ 60;
    int secs = _secondsElapsed % 60;
    String timeStr = '$mins:${secs.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Icon(
            Icons.access_time_rounded,
            size: 20,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            timeStr,
            style: GoogleFonts.baloo2(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Magic Words',
                style: GoogleFonts.baloo2(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _resetPuzzle,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
              color: AppColors.textPrimary,
            ),
            label: Text(
              GameStrings.reset,
              style: GoogleFonts.baloo2(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              backgroundColor: Colors.grey.shade200,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 2),
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
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    }

                    bool isSelected = selectionData.contains(cell);
                    Color bgColor = Colors.white;
                    if (cell.lockedColor != null) {
                      bgColor = cell.lockedColor!.withValues(alpha: 0.3);
                    } else if (isSelected) {
                      bgColor = activeColor.withValues(alpha: 0.3);
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cell.letter,
                        style: GoogleFonts.baloo2(
                          fontSize: cellWidth * 0.4,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
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

    final int count = _currentSelection.length;
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _renderOrderWords.map((targetRow) {
          bool isFilled = targetRow.isFilled;
          bool isSolved = targetRow.isSolved;

          Color rowColor = targetRow.assignedColor ??
              _puzzle.wordColors[_sortedWords.indexOf(targetRow) % _puzzle.wordColors.length];

          // Dynamic sizing for this row: scales down if the row has a very long sequence
          final int totalLetters = targetRow.word.length + targetRow.overflowDisplay.length;
          double boxSize;
          double fontSize;
          double radius;
          double spacing;
          double runSpacing;

          if (totalLetters > 14) {
            boxSize = 18.0;
            fontSize = 10.5;
            radius = 4.0;
            spacing = 2.5;
            runSpacing = 3.0;
          } else if (totalLetters > 8) {
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
                            width: totalLetters > 14 ? 1.0 : 1.5,
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
                            width: totalLetters > 14 ? 1.0 : 1.5,
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
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final quotaState = ref.watch(hintQuotaProvider);
              final canHint = !quotaState.isLoading && quotaState.remaining > 0;
              return ElevatedButton(
                onPressed: canHint ? () => _requestHint(ref) : null,
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
                  style: GoogleFonts.nunito(
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
    bool allSolved = _sortedWords.every((w) => w.isSolved);
    if (allSolved) {
      _timer?.cancel();
      setState(() {
        _isGameOver = true;
      });

      int basePoints = _sortedWords.length * 50;
      int score = basePoints - (_errorCount * 5) - (_hintCount * 15) - (_undoCount * 2);
      if (_secondsElapsed < 30) score += 50;
      if (score < 10) score = 10;

      int stars = 3;
      if (_secondsElapsed > 30) stars = 2;
      if (_secondsElapsed > 60) stars = 1;

      try {
        await SupabaseService.instance.saveScore(
          gameName: 'magic_words',
          stars: stars,
          score: score,
          durationSeconds: _secondsElapsed,
          completionLog: _completionLog.map((e) => e.toJson()).toList(),
        );
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
      _updateLiveFill();
    });
  }

  int _currentlyHintingWordIndex = -1;
  int _currentlyHintingCharIndex = 0;

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
            'Cách chơi',
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
                  'Tìm tất cả các từ ẩn. Dùng mỗi ô chữ đúng một lần để phủ kín toàn bộ bảng!',
                  style: GoogleFonts.nunito(
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
