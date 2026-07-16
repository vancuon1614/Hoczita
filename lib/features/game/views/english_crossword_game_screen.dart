import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../models/english_crossword_level.dart';
import '../utils/english_crossword_generator.dart';

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

  final Set<EnglishCrosswordWord> _correctWords = {};
  final Set<String> _hintCells = {};
  final Map<EnglishCrosswordWord, int> _wordNumbers = {};
  int _activeClueTab = 0; // 0 for Across, 1 for Down

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _generateCrossword(diff);
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

    // Pre-fill letters for Easy mode
    if (level.difficulty == CrosswordDifficulty.easy) {
      final rand = Random();
      for (final w in level.words) {
        final numToFill = w.word.length > 4 ? 2 : 1;
        final filledIndices = <int>{};
        while (filledIndices.length < numToFill) {
          filledIndices.add(rand.nextInt(w.word.length));
        }
        for (final idx in filledIndices) {
          final r = w.isAcross ? w.row : w.row + idx;
          final c = w.isAcross ? w.col + idx : w.col;
          if (r < _gridRows && c < _gridCols) {
            _grid[r][c].userLetter = w.word[idx].toUpperCase();
            _hintCells.add('$r,$c');
          }
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

  bool _isCellLocked(int r, int c) {
    if (_selectedDifficulty == CrosswordDifficulty.hard) return false;
    if (_hintCells.contains('$r,$c')) return true;
    for (final cw in _correctWords) {
      if (_getCellIndexInWord(cw, r, c) != -1) {
        return true;
      }
    }
    return false;
  }

  bool _isWordCorrect(EnglishCrosswordWord word) {
    for (int i = 0; i < word.word.length; i++) {
      final r = word.isAcross ? word.row : word.row + i;
      final c = word.isAcross ? word.col + i : word.col;
      if (_grid[r][c].userLetter.toUpperCase() != word.word[i].toUpperCase()) {
        return false;
      }
    }
    return true;
  }

  void _checkCompletedWords() {
    if (_selectedDifficulty == CrosswordDifficulty.hard) return;
    final level = _activeLevel;
    if (level == null) return;
    setState(() {
      for (final w in level.words) {
        if (!_correctWords.contains(w) && _isWordCorrect(w)) {
          _correctWords.add(w);
        }
      }
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
      if (_selectedCellRow == r && _selectedCellCol == c) {
        // Tap 2: toggle direction if intersection
        if (matchingWords.length > 1 && _selectedWord != null) {
          _selectedWord = matchingWords.firstWhere((w) => w != _selectedWord);
        }
      } else {
        // Tap 1: new cell -> default to Across if available
        _selectedCellRow = r;
        _selectedCellCol = c;
        final acrossWord = matchingWords.firstWhere(
          (w) => w.isAcross,
          orElse: () => matchingWords.first,
        );
        _selectedWord = acrossWord;
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

    final word = _selectedWord!;

    setState(() {
      if (key == 'backspace') {
        // Only clear if not locked
        if (!_isCellLocked(_selectedCellRow!, _selectedCellCol!)) {
          _grid[_selectedCellRow!][_selectedCellCol!].userLetter = '';
        }
        
        // Move selection back
        final currentIdx = _getCellIndexInWord(word, _selectedCellRow!, _selectedCellCol!);
        if (currentIdx > 0) {
          final prevR = word.isAcross ? word.row : word.row + currentIdx - 1;
          final prevC = word.isAcross ? word.col + currentIdx - 1 : word.col;
          _selectedCellRow = prevR;
          _selectedCellCol = prevC;
        }
      } else {
        // Set value if not locked
        if (!_isCellLocked(_selectedCellRow!, _selectedCellCol!)) {
          _grid[_selectedCellRow!][_selectedCellCol!].userLetter = key.toUpperCase();
        }
        
        // Check if any words got completed and corrected
        _checkCompletedWords();

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
        title: Text('Thoát trò chơi?'),
        content: Text('Bạn có chắc muốn thoát không? Điểm số lượt chơi này sẽ không được lưu lại đâu nhé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Chơi tiếp'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // quit game screen
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('Thoát'),
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

  void _navigateClue(bool goNext) {
    final level = _activeLevel;
    if (level == null || _selectedWord == null) return;
    final words = level.words;
    int idx = words.indexOf(_selectedWord!);
    if (idx == -1) return;

    if (goNext) {
      idx = (idx + 1) % words.length;
    } else {
      idx = (idx - 1 + words.length) % words.length;
    }

    final nextWord = words[idx];
    setState(() {
      _selectedWord = nextWord;
      _selectedCellRow = nextWord.row;
      _selectedCellCol = nextWord.col;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlaying) {
      return _buildDifficultySelection();
    }
    if (_isGameOver) {
      return _buildSummaryView();
    }

    final showKeypad = _selectedCellRow != null && _selectedCellCol != null;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'English Crossword 🇬🇧',
            style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: Icon(Icons.close_rounded),
            onPressed: _showQuitConfirmation,
          ),
          actions: [
            Container(
              width: 90, // Fixed width to prevent shifting layout
              margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  SizedBox(
                    width: 50, // Fixed width for text area to prevent any shaking/shifting
                    child: Text(
                      _elapsedTimeString,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () {
            // Dismiss keyboard when tapping on blank areas
            setState(() {
              _selectedCellRow = null;
              _selectedCellCol = null;
              _selectedWord = null;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  flex: 55,
                  child: Container(
                    color: Colors.white,
                    child: ClipRect(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 2.5,
                        boundaryMargin: const EdgeInsets.all(80),
                        child: Center(
                          child: _buildGridContainer(),
                        ),
                      ),
                    ),
                  ),
                ),
                if (showKeypad) ...[
                  _buildClueBar(),
                  _buildInlineKeypadColumn(),
                ] else ...[
                  _buildClueLists(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClueBar() {
    final word = _selectedWord;
    final level = _activeLevel;
    String clueText = 'Bấm chọn một ô chữ để bắt đầu!';

    if (word != null && level != null) {
      final index = _wordNumbers[word] ?? 1;
      final dir = word.isAcross ? 'Ngang' : 'Dọc';
      clueText = '$index. $dir: ${word.clue}';
    }

    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1.5),
          bottom: BorderSide(color: AppColors.border, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary, size: 20),
            onPressed: () => _navigateClue(false),
          ),
          Expanded(
            child: Text(
              clueText,
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 20),
            onPressed: () => _navigateClue(true),
          ),
        ],
      ),
    );
  }

  Widget _buildGridContainer() {
    final cellSize = (_selectedDifficulty == CrosswordDifficulty.hard) 
        ? 26.0 
        : ((_selectedDifficulty == CrosswordDifficulty.medium) ? 32.0 : 40.0);

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: FittedBox(
        fit: isLandscape ? BoxFit.contain : BoxFit.fitWidth,
        child: _buildCrosswordGrid(cellSize),
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

    // Check if cell is correct and locked (except in Hard mode)
    bool isCellCorrectAndLocked = false;
    if (_selectedDifficulty != CrosswordDifficulty.hard) {
      if (_hintCells.contains('${cell.row},${cell.col}')) {
        isCellCorrectAndLocked = true;
      } else {
        for (final cw in _correctWords) {
          if (_getCellIndexInWord(cw, cell.row, cell.col) != -1) {
            isCellCorrectAndLocked = true;
            break;
          }
        }
      }
    }

    // Determine start number label (e.g. "1", "2")
    int? wordStartIndex;
    final level = _activeLevel;
    if (level != null) {
      // Find the first word that starts at this cell
      for (final w in level.words) {
        if (w.row == cell.row && w.col == cell.col) {
          wordStartIndex = _wordNumbers[w];
          break;
        }
      }
    }

    Color backColor = Colors.white;
    Color borderColor = Colors.black;
    Color textColor = AppColors.textPrimary;
    double borderWidth = 2.0;

    if (isCellCorrectAndLocked) {
      backColor = AppColors.success.withValues(alpha: 0.15);
      borderColor = AppColors.success;
      textColor = AppColors.success;
      borderWidth = 2.0;
    } else if (isSelected) {
      backColor = AppColors.primaryLight;
      borderColor = AppColors.primary;
      textColor = AppColors.primary;
      borderWidth = 3.0;
    } else if (isInSelectedWord) {
      backColor = AppColors.primary.withValues(alpha: 0.1);
      borderColor = AppColors.primary;
      textColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: () => _selectCell(cell.row, cell.col),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: backColor,
          borderRadius: BorderRadius.zero,
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
                  style: GoogleFonts.baloo2(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            Center(
              child: Text(
                cell.userLetter,
                style: GoogleFonts.baloo2(
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

    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1.5),
          ),
        ),
        padding: EdgeInsets.fromLTRB(10, 10, 10, MediaQuery.of(context).padding.bottom + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: keyboardRows.map((row) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: row.map((key) {
                  final isBackspace = key == 'backspace';
                  return Expanded(
                    flex: isBackspace ? 2 : 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        onTap: () => _inputLetter(key),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isBackspace ? Colors.grey[200] : AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: isBackspace
                              ? Icon(Icons.backspace_outlined, color: AppColors.textPrimary, size: 18)
                              : Text(
                                  key,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 14,
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
          }).toList(),
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
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.amber,
                    size: 80,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Xuất Sắc! 🎉',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Chúc mừng! Bạn đã giải thành công toàn bộ ô chữ Tiếng Anh trong $_elapsedTimeString!',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 32),
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
              SizedBox(height: 40),
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
                          Text(
                            'Thời gian',
                            style: GoogleFonts.baloo2(fontSize: 11, color: AppColors.primary),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _elapsedTimeString,
                            style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Điểm cộng',
                            style: GoogleFonts.baloo2(fontSize: 11, color: AppColors.success),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '+$_score',
                            style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 48),
              Center(
                child: SizedBox(
                  width: 220,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSavingScore
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isSavingScore
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Quay lại danh mục',
                            style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, fontSize: 14),
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

  Widget _buildClueLists() {
    final level = _activeLevel;
    if (level == null) return const SizedBox.shrink();
    
    // Sort words by assigned crossword number
    final acrossWords = level.words.where((w) => w.isAcross).toList()
      ..sort((a, b) => (_wordNumbers[a] ?? 0).compareTo(_wordNumbers[b] ?? 0));
    final downWords = level.words.where((w) => !w.isAcross).toList()
      ..sort((a, b) => (_wordNumbers[a] ?? 0).compareTo(_wordNumbers[b] ?? 0));

    return Expanded(
      flex: 35,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1.5),
          ),
        ),
        child: Column(
          children: [
            // Tabs for Horizontal/Vertical
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeClueTab = 0),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _activeClueTab == 0 ? AppColors.primary : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'HÀNG NGANG (ACROSS)',
                        style: GoogleFonts.baloo2(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: _activeClueTab == 0 ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeClueTab = 1),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _activeClueTab == 1 ? AppColors.primary : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'HÀNG DỌC (DOWN)',
                        style: GoogleFonts.baloo2(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: _activeClueTab == 1 ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            // Scrollable Clue List
            Expanded(
              child: ListView.builder(
                itemCount: _activeClueTab == 0 ? acrossWords.length : downWords.length,
                itemBuilder: (context, idx) {
                  final w = _activeClueTab == 0 ? acrossWords[idx] : downWords[idx];
                  final wordNum = _wordNumbers[w] ?? 1;
                  final isSelectedWord = _selectedWord == w;
                  
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedWord = w;
                        _selectedCellRow = w.row;
                        _selectedCellCol = w.col;
                      });
                      _keyboardFocusNode.requestFocus();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelectedWord ? AppColors.primary.withValues(alpha: 0.08) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelectedWord ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: isSelectedWord ? AppColors.primary : Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$wordNum',
                              style: GoogleFonts.baloo2(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelectedWord ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              w.clue,
                              style: GoogleFonts.baloo2(
                                fontSize: 12,
                                fontWeight: isSelectedWord ? FontWeight.bold : FontWeight.normal,
                                color: isSelectedWord ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isSelectedWord)
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultySelection() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light bluish-white background like the image
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'English Crossword',
              style: GoogleFonts.baloo2(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: const Color(0xFF2C3E50),
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.translate_rounded, size: 20, color: Colors.blueGrey),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: Image.asset(
                  'ImageFolder/crossword.gif', 
                  height: 120,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.translate_rounded,
                    size: 80,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Chọn Cấp Độ Ô Chữ',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 22, 
                  fontWeight: FontWeight.w600, 
                  color: const Color(0xFF2C3E50),
                ),
              ),
              SizedBox(height: 32),
              _buildDifficultyButton(
                title: 'Khởi động',
                subtitle: 'Làm quen nhẹ nhàng với 5 từ vựng.',
                difficulty: CrosswordDifficulty.easy,
                backgroundColor: const Color(0xFFE4F3E4),
                iconColor: const Color(0xFF4CAF50),
                stars: 1,
              ),
              const SizedBox(height: 16),
              _buildDifficultyButton(
                title: 'Tập trung',
                subtitle: 'Tăng cường thử thách với 9 từ vựng.',
                difficulty: CrosswordDifficulty.medium,
                backgroundColor: const Color(0xFFFDEBCE),
                iconColor: const Color(0xFFF59E0B),
                stars: 2,
              ),
              const SizedBox(height: 16),
              _buildDifficultyButton(
                title: 'Thử thách',
                subtitle: 'Dành cho người chơi nâng cao với 14 từ vựng.',
                difficulty: CrosswordDifficulty.hard,
                backgroundColor: const Color(0xFFFFE5E5),
                iconColor: const Color(0xFFEF4444),
                stars: 3,
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
    required Color backgroundColor,
    required Color iconColor,
    required int stars,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.baloo2(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B), // Dark text
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.baloo2(
                          fontSize: 10,
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(
                        Icons.star_rounded,
                        color: index < stars ? iconColor.withValues(alpha: 0.6) : Colors.transparent,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── DYNAMIC CROSSWORD GENERATOR ───────────────────────────────────────────
  static const List<WordClue> _vocabPool = [
    // Animals
    WordClue('DOG', 'Con chó'),
    WordClue('CAT', 'Con mèo'),
    WordClue('LION', 'Sư tử'),
    WordClue('ELEPHANT', 'Con voi'),
    WordClue('MONKEY', 'Con khỉ'),
    WordClue('RABBIT', 'Con thỏ'),
    WordClue('BEAR', 'Con gấu'),
    WordClue('TIGER', 'Con hổ'),
    WordClue('SHEEP', 'Con cừu'),
    WordClue('PIG', 'Con lợn'),
    // Fruits
    WordClue('APPLE', 'Quả táo'),
    WordClue('BANANA', 'Quả chuối'),
    WordClue('ORANGE', 'Quả cam'),
    WordClue('WATERMELON', 'Dưa hấu'),
    WordClue('STRAWBERRY', 'Dâu tây'),
    WordClue('GRAPE', 'Quả nho'),
    WordClue('MANGO', 'Quả xoài'),
    WordClue('PINEAPPLE', 'Quả dứa'),
    WordClue('PEACH', 'Quả đào'),
    WordClue('CHERRY', 'Quả anh đào'),
    // Vegetables
    WordClue('CARROT', 'Củ cà rốt'),
    WordClue('TOMATO', 'Quả cà chua'),
    WordClue('POTATO', 'Củ khoai tây'),
    WordClue('CORN', 'Bắp ngô'),
    WordClue('BROCCOLI', 'Súp lơ xanh'),
    WordClue('PUMPKIN', 'Quả bí ngô'),
    WordClue('ONION', 'Củ hành tây'),
    WordClue('CUCUMBER', 'Quả dưa chuột'),
    WordClue('MUSHROOM', 'Cây nấm'),
    WordClue('PEA', 'Hạt đậu Hà Lan'),
    // Transportation
    WordClue('CAR', 'Ô tô'),
    WordClue('AIRPLANE', 'Máy bay'),
    WordClue('TRAIN', 'Tàu hỏa'),
    WordClue('BICYCLE', 'Xe đạp'),
    WordClue('SHIP', 'Tàu thủy'),
    WordClue('HELICOPTER', 'Trực thăng'),
    WordClue('BUS', 'Xe buýt'),
    WordClue('TRUCK', 'Xe tải'),
    WordClue('ROCKET', 'Tên lửa'),
    WordClue('MOTORBIKE', 'Xe máy'),
    // School
    WordClue('BOOK', 'Quyển sách'),
    WordClue('PEN', 'Bút mực'),
    WordClue('PENCIL', 'Bút chì'),
    WordClue('BACKPACK', 'Balo'),
    WordClue('ERASER', 'Cục tẩy'),
    WordClue('RULER', 'Thước kẻ'),
    WordClue('SCISSORS', 'Kéo thủ công'),
    WordClue('GLOBE', 'Quả địa cầu'),
    WordClue('DESK', 'Bàn học'),
    WordClue('CHAIR', 'Ghế ngồi'),
    // Home
    WordClue('SOFA', 'Ghế sofa'),
    WordClue('BED', 'Giường ngủ'),
    WordClue('TABLE', 'Bàn tròn'),
    WordClue('LAMP', 'Đèn ngủ'),
    WordClue('CLOCK', 'Đồng hồ'),
    WordClue('KEY', 'Chìa khóa'),
    WordClue('CUP', 'Cốc nước'),
    WordClue('DOOR', 'Cửa ra vào'),
    WordClue('WINDOW', 'Cửa sổ'),
    WordClue('MIRROR', 'Cái gương'),
    // Nature
    WordClue('SUN', 'Mặt trời'),
    WordClue('MOON', 'Mặt trăng'),
    WordClue('STAR', 'Ngôi sao'),
    WordClue('CLOUD', 'Đám mây'),
    WordClue('RAINBOW', 'Cầu vồng'),
    WordClue('TREE', 'Cây xanh'),
    WordClue('FLOWER', 'Bông hoa'),
    WordClue('RAIN', 'Mưa'),
    WordClue('SNOW', 'Tuyết'),
    WordClue('WIND', 'Gió'),
    // Space
    WordClue('ASTRONAUT', 'Phi hành gia'),
    WordClue('SPACESHIP', 'Tàu vũ trụ'),
    WordClue('EARTH', 'Trái Đất'),
    WordClue('MARS', 'Sao Hỏa'),
    WordClue('ROVER', 'Xe tự hành vũ trụ'),
    WordClue('UFO', 'Đĩa bay'),
    WordClue('TELESCOPE', 'Kính thiên văn'),
    WordClue('SATELLITE', 'Vệ tinh'),
    WordClue('METEOR', 'Sao băng'),
    WordClue('SPACESUIT', 'Bộ đồ phi hành'),
    // Sea Creatures
    WordClue('FISH', 'Con cá'),
    WordClue('SHARK', 'Cá mập'),
    WordClue('WHALE', 'Cá voi'),
    WordClue('DOLPHIN', 'Cá heo'),
    WordClue('OCTOPUS', 'Bạch tuộc'),
    WordClue('CRAB', 'Con cua'),
    WordClue('STARFISH', 'Sao biển'),
    WordClue('TURTLE', 'Rùa biển'),
    WordClue('SEAHORSE', 'Cá ngựa'),
    WordClue('JELLYFISH', 'Con sứa'),
    // Toys
    WordClue('SOCCER', 'Bóng đá'),
    WordClue('BASKETBALL', 'Bóng rổ'),
    WordClue('KITE', 'Cánh diều'),
    WordClue('SLIDE', 'Cầu trượt'),
    WordClue('BALLOON', 'Bóng bay'),
    WordClue('DOLL', 'Búp bê'),
    WordClue('TEDDY', 'Gấu bông'),
    WordClue('ROBOT', 'Rô bốt đồ chơi'),
    WordClue('YOYO', 'Đồ chơi yo-yo'),
    WordClue('SWING', 'Xích đu'),
    // Clothing
    WordClue('SHIRT', 'Áo thun'),
    WordClue('PANTS', 'Quần dài'),
    WordClue('DRESS', 'Váy liền'),
    WordClue('HAT', 'Mũ'),
    WordClue('SHOES', 'Giày'),
    WordClue('SOCKS', 'Tất/Vớ'),
    WordClue('JACKET', 'Áo khoác'),
    WordClue('GLASSES', 'Kính mắt'),
    WordClue('SCARF', 'Khăn quàng'),
    WordClue('BOOTS', 'Ủng'),
    // Food
    WordClue('BREAD', 'Bánh mì'),
    WordClue('MILK', 'Sữa'),
    WordClue('ICECREAM', 'Kem'),
    WordClue('LOLLIPOP', 'Kẹo mút'),
    WordClue('CAKE', 'Bánh ngọt'),
    WordClue('PIZZA', 'Bánh pizza'),
    WordClue('EGG', 'Quả trứng'),
    WordClue('CHEESE', 'Phô mai'),
    WordClue('BURGER', 'Hamburger'),
    WordClue('JUICE', 'Nước ép'),
  ];



  void _generateCrossword(CrosswordDifficulty diff) {
    // Generate crossword organically using the dynamic generator
    final generatedLevel = EnglishCrosswordGenerator.generate(
      difficulty: diff,
      vocabPool: _vocabPool,
    );

    _gridRows = generatedLevel.rows;
    _gridCols = generatedLevel.cols;

    setState(() {
      _selectedDifficulty = diff;
      _activeLevel = generatedLevel;
      _isPlaying = true;
      _isGameOver = false;
      _isSavingScore = false;
      _selectedCellRow = null;
      _selectedCellCol = null;
      _selectedWord = null;
      _correctWords.clear();
      _hintCells.clear();
    });

    _calculateWordNumbers(generatedLevel);
    _initializeGrid(generatedLevel);
    _stopwatch.reset();
    _stopwatch.start();
    _startTimer();

    if (generatedLevel.words.isNotEmpty) {
      final firstWord = generatedLevel.words.first;
      setState(() {
        _selectedWord = firstWord;
        _selectedCellRow = firstWord.row;
        _selectedCellCol = firstWord.col;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
    });
  }

  void _calculateWordNumbers(EnglishCrosswordLevel level) {
    _wordNumbers.clear();
    
    final startCells = <String>{};
    for (final w in level.words) {
      startCells.add('${w.row},${w.col}');
    }
    
    final sortedStarts = startCells.toList()..sort((a, b) {
      final partsA = a.split(',').map(int.parse).toList();
      final partsB = b.split(',').map(int.parse).toList();
      if (partsA[0] != partsB[0]) {
        return partsA[0].compareTo(partsB[0]);
      }
      return partsA[1].compareTo(partsB[1]);
    });
    
    final cellNumbers = <String, int>{};
    for (int i = 0; i < sortedStarts.length; i++) {
      cellNumbers[sortedStarts[i]] = i + 1;
    }
    
    for (final w in level.words) {
      _wordNumbers[w] = cellNumbers['${w.row},${w.col}'] ?? 1;
    }
  }

}

class WordClue {
  final String word;
  final String clue;
  const WordClue(this.word, this.clue);
}
