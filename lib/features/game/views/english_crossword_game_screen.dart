import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../models/english_crossword_level.dart';

class EnglishCrosswordCell {
  final int row;
  final int col;
  String correctLetter; // A-Z character
  String userLetter;    // Letter typed by user
  bool isBlocked;       // True if this cell is empty/wall in crossword

  EnglishCrosswordCell({
    required this.row,
    required this.col,
    this.correctLetter = '',
    this.userLetter = '',
    this.isBlocked = true,
  });

  bool get isCorrect => isBlocked || userLetter.toUpperCase() == correctLetter.toUpperCase();
}

class EnglishCrosswordGameScreen extends StatefulWidget {
  const EnglishCrosswordGameScreen({super.key});

  @override
  State<EnglishCrosswordGameScreen> createState() => _EnglishCrosswordGameScreenState();
}

class _EnglishCrosswordGameScreenState extends State<EnglishCrosswordGameScreen> {
  final SupabaseService _db = SupabaseService.instance;
  final FocusNode _keyboardFocusNode = FocusNode();

  CrosswordDifficulty? _selectedDifficulty;
  EnglishCrosswordLevel? _activeLevel;
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isSavingScore = false;

  int _gridRows = 0;
  int _gridCols = 0;
  List<List<EnglishCrosswordCell>> _grid = [];

  int? _selectedCellRow;
  int? _selectedCellCol;
  EnglishCrosswordWord? _selectedWord;

  final Stopwatch _stopwatch = Stopwatch();
  late Timer _timer;
  String _elapsedTimeString = '0.0';
  int _score = 0;
  int _stars = 0;

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    if (_isPlaying && !_isGameOver) {
      _timer.cancel();
    }
    _stopwatch.stop();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _selectDifficulty(CrosswordDifficulty diff) {
    if (diff == CrosswordDifficulty.medium || diff == CrosswordDifficulty.hard) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }

    final levels = EnglishCrosswordLevel.getPredefinedLevels()
        .where((l) => l.difficulty == diff)
        .toList();
    final randLevel = levels[Random().nextInt(levels.length)];

    setState(() {
      _selectedDifficulty = diff;
      _activeLevel = randLevel;
      _isPlaying = true;
      _isGameOver = false;
      _isSavingScore = false;
      _selectedCellRow = null;
      _selectedCellCol = null;
      _selectedWord = null;
    });

    _initializeGrid(randLevel);
    _stopwatch.reset();
    _stopwatch.start();
    _startTimer();



    // Request keyboard focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
    });
  }

  void _initializeGrid(EnglishCrosswordLevel level) {
    _gridRows = level.rows;
    _gridCols = level.cols;

    // Create blank blocked grid
    _grid = List.generate(_gridRows, (r) {
      return List.generate(_gridCols, (c) {
        return EnglishCrosswordCell(row: r, col: c);
      });
    });

    // Populate active cells and correct letters from level word lists
    for (final w in level.words) {
      for (int i = 0; i < w.word.length; i++) {
        final r = w.isAcross ? w.row : w.row + i;
        final c = w.isAcross ? w.col + i : w.col;

        if (r < _gridRows && c < _gridCols) {
          _grid[r][c].isBlocked = false;
          _grid[r][c].correctLetter = w.word[i].toUpperCase();
        }
      }
    }
  }

  String _formatTime(double seconds) {
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(1)}s';
    }
    final int totalSeconds = seconds.round();
    if (totalSeconds < 3600) {
      final int minutes = totalSeconds ~/ 60;
      final int remainingSeconds = totalSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      final int hours = totalSeconds ~/ 3600;
      final int minutes = (totalSeconds % 3600) ~/ 60;
      final int remainingSeconds = totalSeconds % 60;
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsedTimeString = _formatTime(_stopwatch.elapsedMilliseconds / 1000);
      });
    });
  }

  void _selectCell(int r, int c) {
    if (r < 0 || r >= _gridRows || c < 0 || c >= _gridCols) return;
    final cell = _grid[r][c];
    if (cell.isBlocked) return;

    final level = _activeLevel;
    if (level == null) return;

    // Find words that contain this cell
    final matchingWords = level.words.where((w) {
      final idx = _getCellIndexInWord(w, r, c);
      return idx != -1;
    }).toList();

    if (matchingWords.isEmpty) return;

    setState(() {
      _selectedCellRow = r;
      _selectedCellCol = c;

      // Toggle direction if tapping the current cell and it is an intersection
      if (_selectedWord != null &&
          matchingWords.contains(_selectedWord) &&
          matchingWords.length > 1 &&
          _selectedCellRow == r &&
          _selectedCellCol == c) {
        _selectedWord = matchingWords.firstWhere((w) => w != _selectedWord);
      } else {
        // Otherwise, prefer current word's direction or just pick the first match
        _selectedWord = matchingWords.first;
      }
    });

    _keyboardFocusNode.requestFocus();
  }

  int _getCellIndexInWord(EnglishCrosswordWord w, int r, int c) {
    if (w.isAcross) {
      if (r == w.row && c >= w.col && c < w.col + w.word.length) {
        return c - w.col;
      }
    } else {
      if (c == w.col && r >= w.row && r < w.row + w.word.length) {
        return r - w.row;
      }
    }
    return -1;
  }

  void _inputLetter(String key) {
    if (_isGameOver) return;
    if (_selectedCellRow == null || _selectedCellCol == null || _selectedWord == null) return;

    final cell = _grid[_selectedCellRow!][_selectedCellCol!];
    final word = _selectedWord!;

    setState(() {
      if (key == 'backspace') {
        cell.userLetter = '';
        // Move selection back
        final currentIdx = _getCellIndexInWord(word, _selectedCellRow!, _selectedCellCol!);
        if (currentIdx > 0) {
          final prevR = word.isAcross ? word.row : word.row + currentIdx - 1;
          final prevC = word.isAcross ? word.col + currentIdx - 1 : word.col;
          _selectedCellRow = prevR;
          _selectedCellCol = prevC;
        }
      } else {
        // Set value
        cell.userLetter = key.toUpperCase();
        
        // Move selection forward
        final currentIdx = _getCellIndexInWord(word, _selectedCellRow!, _selectedCellCol!);
        if (currentIdx < word.word.length - 1) {
          final nextR = word.isAcross ? word.row : word.row + currentIdx + 1;
          final nextC = word.isAcross ? word.col + currentIdx + 1 : word.col;
          _selectedCellRow = nextR;
          _selectedCellCol = nextC;
        }
      }
    });

    _checkWinState();
  }

  bool _checkAllCorrect() {
    for (int r = 0; r < _gridRows; r++) {
      for (int c = 0; c < _gridCols; c++) {
        if (!_grid[r][c].isCorrect) {
          return false;
        }
      }
    }
    return true;
  }

  void _checkWinState() {
    if (_checkAllCorrect()) {
      _endGameAndSaveScore();
    }
  }

  void _endGameAndSaveScore() async {
    _stopwatch.stop();
    _timer.cancel();

    final elapsedSeconds = _stopwatch.elapsedMilliseconds / 1000;
    
    // Scale stars based on difficulty & completion time
    final diff = _selectedDifficulty ?? CrosswordDifficulty.easy;
    if (diff == CrosswordDifficulty.easy) {
      if (elapsedSeconds <= 40) {
        _stars = 3;
      } else if (elapsedSeconds <= 80) {
        _stars = 2;
      } else {
        _stars = 1;
      }
    } else if (diff == CrosswordDifficulty.medium) {
      if (elapsedSeconds <= 80) {
        _stars = 3;
      } else if (elapsedSeconds <= 150) {
        _stars = 2;
      } else {
        _stars = 1;
      }
    } else {
      if (elapsedSeconds <= 120) {
        _stars = 3;
      } else if (elapsedSeconds <= 240) {
        _stars = 2;
      } else {
        _stars = 1;
      }
    }

    int baseScore = 0;
    if (_stars == 3) {
      baseScore = 30;
    } else if (_stars == 2) {
      baseScore = 20;
    } else if (_stars == 1) {
      baseScore = 10;
    }

    // Multiply score based on difficulty tier
    final multiplier = diff == CrosswordDifficulty.easy ? 1 : (diff == CrosswordDifficulty.medium ? 2 : 3);
    _score = baseScore * multiplier;

    setState(() {
      _isGameOver = true;
      _isSavingScore = true;
    });

    try {
      await _db.saveScore(
        gameName: 'english_crossword',
        stars: _stars,
        score: _score,
      );
    } catch (e) {
      debugPrint('Error saving score: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingScore = false;
        });
      }
    }
  }

  void _showQuitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thoát trò chơi?'),
        content: const Text('Bé có chắc muốn thoát không? Điểm số lượt chơi này sẽ không được lưu lại đâu nhé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chơi tiếp'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // quit game screen
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
  }

  // Handle physical keyboard inputs
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final logicalKey = event.logicalKey;
      if (logicalKey == LogicalKeyboardKey.backspace) {
        _inputLetter('backspace');
      } else {
        final char = event.character;
        if (char != null && RegExp(r'^[a-zA-Z]$').hasMatch(char)) {
          _inputLetter(char.toUpperCase());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlaying) {
      return _buildDifficultySelection();
    }
    if (_isGameOver) {
      return _buildSummaryView();
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final showKeypad = _selectedCellRow != null && _selectedCellCol != null;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'English Crossword 🇬🇧',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _showQuitConfirmation,
          ),
          actions: [
            Container(
              width: 85,
              margin: const EdgeInsets.only(right: 20),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    _elapsedTimeString,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () {
            setState(() {
              _selectedCellRow = null;
              _selectedCellCol = null;
              _selectedWord = null;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: isLandscape
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left side: Clue + Grid
                      Expanded(
                        child: Column(
                          children: [
                            _buildClueHeader(),
                            Expanded(child: _buildGridContainer()),
                          ],
                        ),
                      ),
                      // Right side: Keyboard
                      if (showKeypad) _buildInlineKeypadColumn(),
                    ],
                  )
                : Column(
                    children: [
                      _buildClueHeader(),
                      Expanded(child: _buildGridContainer()),
                      if (showKeypad) _buildInlineKeypadColumn(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildClueHeader() {
    final word = _selectedWord;
    final level = _activeLevel;
    String clueText = 'Bấm chọn một ô chữ để xem gợi ý...';
    
    if (word != null && level != null) {
      final index = level.words.indexOf(word) + 1;
      final dir = word.isAcross ? 'Hàng ngang' : 'Hàng dọc';
      clueText = '$index. $dir: ${word.clue} (${word.word.length} chữ cái)';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.help_outline_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              clueText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridContainer() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    // Scale cell sizes slightly based on difficulty
    final cellSize = (_selectedDifficulty == CrosswordDifficulty.hard) 
        ? (isLandscape ? 32.0 : 36.0) 
        : 42.0;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        maxScale: 2.5,
        minScale: 0.8,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FittedBox(
              fit: BoxFit.contain,
              child: _buildCrosswordGrid(cellSize),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCrosswordGrid(double cellSize) {
    return Table(
      defaultColumnWidth: FixedColumnWidth(cellSize + 4),
      children: List.generate(_gridRows, (r) {
        return TableRow(
          children: List.generate(_gridCols, (c) {
            final cell = _grid[r][c];
            return SizedBox(
              height: cellSize + 4,
              child: _buildCellItem(cell, cellSize),
            );
          }),
        );
      }),
    );
  }

  Widget _buildCellItem(EnglishCrosswordCell cell, double cellSize) {
    if (cell.isBlocked) {
      return const SizedBox.shrink();
    }

    final isSelected = cell.row == _selectedCellRow && cell.col == _selectedCellCol;
    
    // Check if cell is part of the selected word
    bool isInSelectedWord = false;
    final activeWord = _selectedWord;
    if (activeWord != null) {
      final index = _getCellIndexInWord(activeWord, cell.row, cell.col);
      if (index != -1) {
        isInSelectedWord = true;
      }
    }

    // Determine start number label (e.g. "1", "2")
    int? wordStartIndex;
    final level = _activeLevel;
    if (level != null) {
      for (int i = 0; i < level.words.length; i++) {
        if (level.words[i].row == cell.row && level.words[i].col == cell.col) {
          wordStartIndex = i + 1;
          break;
        }
      }
    }

    Color backColor = Colors.white;
    Color borderColor = AppColors.border;
    Color textColor = AppColors.textPrimary;
    double borderWidth = 1.0;

    if (isSelected) {
      backColor = AppColors.primaryLight;
      borderColor = AppColors.primary;
      textColor = AppColors.primary;
      borderWidth = 2.5;
    } else if (isInSelectedWord) {
      backColor = AppColors.primary.withValues(alpha: 0.08);
      borderColor = AppColors.primary.withValues(alpha: 0.3);
      textColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: () => _selectCell(cell.row, cell.col),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: backColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Stack(
          children: [
            if (wordStartIndex != null)
              Positioned(
                top: 2,
                left: 3,
                child: Text(
                  '$wordStartIndex',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            Center(
              child: Text(
                cell.userLetter,
                style: TextStyle(
                  fontSize: cellSize * 0.45,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineKeypadColumn() {
    final keyboardRows = [
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
      ['Z', 'X', 'C', 'V', 'B', 'N', 'M', 'backspace'],
    ];

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: isLandscape ? 360 : double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: isLandscape ? BorderSide.none : const BorderSide(color: AppColors.border, width: 1.5),
            left: isLandscape ? const BorderSide(color: AppColors.border, width: 1.5) : BorderSide.none,
          ),
        ),
        padding: EdgeInsets.fromLTRB(10, 10, 10, isLandscape ? 10 : MediaQuery.of(context).padding.bottom + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Bàn phím nhập chữ:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ...keyboardRows.map((row) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((key) {
                  final isBack = key == 'backspace';
                  return Expanded(
                    flex: isBack ? 2 : 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        onTap: () => _inputLetter(key),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: isLandscape ? 38 : 42,
                          decoration: BoxDecoration(
                            color: isBack ? Colors.grey[200] : AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: isBack
                              ? const Icon(Icons.backspace_outlined, color: AppColors.textPrimary, size: 16)
                              : Text(
                                  key,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    ),
  );
}

  Widget _buildDifficultySelection() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'English Crossword 🇬🇧',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.translate_rounded,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn Cấp Độ Ô Chữ',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Giải các ô chữ tiếng Anh bằng cách điền từ tương ứng với gợi ý tiếng Việt nhé.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              _buildDifficultyButton(
                title: 'Dễ (Easy)',
                subtitle: 'Ô chữ 3-4 từ ngắn - Thích hợp cho bé làm quen',
                difficulty: CrosswordDifficulty.easy,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              _buildDifficultyButton(
                title: 'Trung Bình (Medium)',
                subtitle: 'Ô chữ 5 từ vừa - Rèn luyện ghi nhớ từ vựng tốt hơn',
                difficulty: CrosswordDifficulty.medium,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              _buildDifficultyButton(
                title: 'Khó (Hard)',
                subtitle: 'Ô chữ 4-5 từ dài - Thử thách trí tuệ siêu việt của bé',
                difficulty: CrosswordDifficulty.hard,
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyButton({
    required String title,
    required String subtitle,
    required CrosswordDifficulty difficulty,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectDifficulty(difficulty),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(Icons.star_rounded, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.border),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryView() {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF9E6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.amber,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Xuất Sắc! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bé đã giải thành công toàn bộ ô chữ Tiếng Anh trong $_elapsedTimeString!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final active = index < _stars;
                  return AnimatedScale(
                    scale: active ? 1.3 : 1.0,
                    duration: Duration(milliseconds: 300 + (index * 150)),
                    curve: Curves.elasticOut,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.star_rounded,
                        size: 48,
                        color: active ? Colors.amber : AppColors.border,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Thời gian',
                            style: TextStyle(fontSize: 13, color: AppColors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _elapsedTimeString,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Điểm cộng',
                            style: TextStyle(fontSize: 13, color: AppColors.success),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+$_score',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _isSavingScore
                    ? null
                    : () {
                        Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSavingScore
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Quay lại danh mục',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
