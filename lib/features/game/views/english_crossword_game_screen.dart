import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/game_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/game_score_sync_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../../../core/providers/game_interaction_provider.dart';
import 'common/mini_game_rank_banner.dart';
import '../models/english_crossword_level.dart';
import '../utils/english_crossword_generator.dart';
import 'common/game_video_demo_dialog.dart';

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

class EnglishCrosswordGameScreen extends ConsumerStatefulWidget {
  const EnglishCrosswordGameScreen({super.key});

  @override
  ConsumerState<EnglishCrosswordGameScreen> createState() => _EnglishCrosswordGameScreenState();
}

class _EnglishCrosswordGameScreenState extends ConsumerState<EnglishCrosswordGameScreen> {
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
  Timer? _timer;
  int _secondsElapsed = 0;
  String _elapsedTimeString = '00:00';
  int _score = 0;

  final Set<EnglishCrosswordWord> _correctWords = {};
  final Set<String> _hintCells = {};
  final Map<EnglishCrosswordWord, int> _wordNumbers = {};
  int _activeClueTab = 0; // 0 for Across, 1 for Down

  int _easyStars = 0;
  int _mediumStars = 0;
  int _hardStars = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(isGameActiveProvider.notifier).state = true;
      }
    });
    _loadHighestStars();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _loadHighestStars() async {
    final easy = await _db.getHighestStarsForGame('english_crossword_easy');
    final medium = await _db.getHighestStarsForGame('english_crossword_medium');
    final hard = await _db.getHighestStarsForGame('english_crossword_hard');
    if (mounted) {
      setState(() {
        _easyStars = easy;
        _mediumStars = medium;
        _hardStars = hard;
      });
    }
  }

  @override
  void dispose() {
    ref.read(isGameActiveProvider.notifier).state = false;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _timer?.cancel();
    _stopwatch.stop();
    _keyboardFocusNode.dispose();
    TtsService.instance.stopAll();
    super.dispose();
  }

  void _selectDifficulty(CrosswordDifficulty diff) {
    ref.read(isGameActiveProvider.notifier).state = true;
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

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsElapsed = _stopwatch.elapsed.inSeconds;
        _elapsedTimeString = GameCountUpTimer.formatSeconds(_secondsElapsed);
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
    final newlySolved = <EnglishCrosswordWord>[];
    for (final w in level.words) {
      if (!_correctWords.contains(w) && _isWordCorrect(w)) {
        newlySolved.add(w);
      }
    }
    if (newlySolved.isNotEmpty) {
      setState(() {
        _correctWords.addAll(newlySolved);
      });
      for (final w in newlySolved) {
        TtsService.instance.speakEnglish(w.word);
      }
    }
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
    _timer?.cancel();
    _secondsElapsed = _stopwatch.elapsed.inSeconds;
    _elapsedTimeString = GameCountUpTimer.formatSeconds(_secondsElapsed);

    final elapsedSeconds = _secondsElapsed;
    
    // Base score based on completion time
    final diff = _selectedDifficulty ?? CrosswordDifficulty.easy;
    int baseScore = 10;
    if (diff == CrosswordDifficulty.easy) {
      if (elapsedSeconds <= 40) {
        baseScore = 30;
      } else if (elapsedSeconds <= 80) {
        baseScore = 20;
      } else {
        baseScore = 10;
      }
    } else if (diff == CrosswordDifficulty.medium) {
      if (elapsedSeconds <= 80) {
        baseScore = 30;
      } else if (elapsedSeconds <= 150) {
        baseScore = 20;
      } else {
        baseScore = 10;
      }
    } else {
      if (elapsedSeconds <= 120) {
        baseScore = 30;
      } else if (elapsedSeconds <= 240) {
        baseScore = 20;
      } else {
        baseScore = 10;
      }
    }

    // Multiply score based on difficulty tier
    final multiplier = diff == CrosswordDifficulty.easy ? 1 : (diff == CrosswordDifficulty.medium ? 2 : 3);
    _score = baseScore * multiplier;

    setState(() {
      _isGameOver = true;
      _isSavingScore = true;
    });

    try {
      final diffName = _selectedDifficulty?.name ?? 'easy';
      final levelStr = diffName == 'easy' ? '1' : (diffName == 'medium' ? '2' : '3');
      await GameScoreSyncService.instance.saveScoreParallel(
        gameCodeOrName: 'E04',
        level: levelStr,
        score: _score,
        stars: 0,
        durationSeconds: _secondsElapsed,
      );
      _loadHighestStars();
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
        title: const Text('Quit Game?'),
        content: const Text('Are you sure you want to quit? Current game progress and score will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Playing'),
          ),
          TextButton(
            onPressed: () {
              ref.read(isGameActiveProvider.notifier).state = false;
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // quit game screen
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Quit'),
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

  void _resetCrossword() {
    setState(() {
      _selectedCellRow = null;
      _selectedCellCol = null;
      _selectedWord = null;
      _correctWords.clear();
      for (int r = 0; r < _gridRows; r++) {
        for (int c = 0; c < _gridCols; c++) {
          final cell = _grid[r][c];
          if (!cell.isBlocked && !_hintCells.contains('$r,$c')) {
            cell.userLetter = '';
          }
        }
      }
      _secondsElapsed = 0;
      _elapsedTimeString = '00:00';
      _stopwatch.reset();
      _stopwatch.start();
      TtsService.instance.stopAll();
    });
  }

  String get _difficultyLabel {
    switch (_selectedDifficulty) {
      case CrosswordDifficulty.easy:
        return 'Easy';
      case CrosswordDifficulty.medium:
        return 'Medium';
      case CrosswordDifficulty.hard:
        return 'Hard';
      default:
        return 'Crossword';
    }
  }

  Widget _buildTopBar() {
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
                'English Crossword 🇬🇧',
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

  @override
  Widget build(BuildContext context) {
    if (!_isPlaying) {
      return _buildDifficultySelection();
    }
    if (_isGameOver) {
      return _buildSummaryView();
    }

    final showKeypad = _selectedCellRow != null && _selectedCellCol != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showQuitConfirmation();
      },
      child: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                // Subheader Row: Level/Badge + Reset on Left, Timer Pill on Right (Standard Layout)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFBAE6FD)),
                            ),
                            child: Text(
                              _difficultyLabel,
                              style: GoogleFonts.baloo2(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0284C7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _resetCrossword,
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
                      GameCountUpTimer(
                        elapsedSeconds: _secondsElapsed,
                        margin: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // Dismiss keyboard when tapping on blank areas
                      setState(() {
                        _selectedCellRow = null;
                        _selectedCellCol = null;
                        _selectedWord = null;
                      });
                    },
                    behavior: HitTestBehavior.opaque,
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
    String clueText = 'Tap a crossword cell to start!';

    if (word != null && level != null) {
      final index = _wordNumbers[word] ?? 1;
      final dir = word.isAcross ? 'Across' : 'Down';
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
              const SizedBox(height: 24),
              Text(
                'Awesome! 🎉',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Congratulations! You solved all crossword clues in $_elapsedTimeString!',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
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
                            'Time',
                            style: GoogleFonts.baloo2(fontSize: 11, color: AppColors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _elapsedTimeString,
                            style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
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
                          Text(
                            'Score Earned',
                            style: GoogleFonts.baloo2(fontSize: 11, color: AppColors.success),
                          ),
                          const SizedBox(height: 4),
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
              const SizedBox(height: 24),
              MiniGameRankBanner(
                gameName: 'english_crossword_${_selectedDifficulty?.name ?? 'easy'}',
                gameTitle: 'English Crossword',
                currentScore: _score,
                isEnglish: true,
              ),
              const SizedBox(height: 32),
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
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isSavingScore
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Back to Menu',
                            style: GoogleFonts.baloo2(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
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
                        'ACROSS',
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
                        'DOWN',
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
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'English Crossword',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 20,
          ),
        ),
        actions: [
          const GameSoundToggleButton(isPlayScreen: false),
          IconButton(
            tooltip: 'Watch demo video',
            icon: const Icon(Icons.ondemand_video_rounded, color: AppColors.primary, size: 26),
            onPressed: () {
              GameVideoDemoDialog.show(
                context,
                assetPath: 'ImageFolder/demo_crossword.webm',
                title: 'How to Play - English Crossword',
              );
            },
          ),
          const SizedBox(width: 4),
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
                    colors: [Color(0xFF0D9488), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.25),
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
                                color: const Color(0xFFCCFBF1),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Crossword Quest',
                            style: GoogleFonts.baloo2(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Solve English crossword puzzles with picture clues and word hints!',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              color: const Color(0xFFCCFBF1),
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
                          'ImageFolder/crossword.gif',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Text(
                              '🔠',
                              style: TextStyle(fontSize: 34),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Watch Demo Tutorial Button
              Center(
                child: InkWell(
                  onTap: () {
                    GameVideoDemoDialog.show(
                      context,
                      assetPath: 'ImageFolder/demo_crossword.webm',
                      title: 'Demo Tutorial - English Crossword',
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Color(0xFF0D9488),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Watch demo tutorial',
                          style: GoogleFonts.baloo2(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Header: QUEST MAP + Word Streak Info
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
                            'Word Streak',
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

              // STAGE 3: MASTERY (Master Linguist - Deep Amethyst)
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: _buildTowerTierCard(
                  tierNumber: 3,
                  tierLabel: 'STAGE 3 • MASTERY',
                  tagText: '9x9 Grid • 14 Words',
                  title: 'Master Linguist',
                  subtitle: 'Conquer large grid challenges with your entire vocabulary',
                  emoji: '🎓',
                  primaryColor: const Color(0xFF6D28D9),
                  lightBgColor: const Color(0xFFF5F3FF),
                  borderColor: const Color(0xFFDDD6FE),
                  gradientColors: const [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                  difficultyText: 'Hard',
                  stars: _hardStars,
                  onTap: () => _selectDifficulty(CrosswordDifficulty.hard),
                ),
              ),

              _buildCurvedPathConnector(curveToRight: true),

              // STAGE 2: EXPANSION (Crossword Detective - Royal Cobalt)
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: _buildTowerTierCard(
                  tierNumber: 2,
                  tierLabel: 'STAGE 2 • EXPANSION',
                  tagText: '7x7 Grid • 9 Words',
                  title: 'Crossword Detective',
                  subtitle: 'Connect intersecting letters to unlock tricky words',
                  emoji: '🔍',
                  primaryColor: const Color(0xFF2563EB),
                  lightBgColor: const Color(0xFFEFF6FF),
                  borderColor: const Color(0xFFBFDBFE),
                  gradientColors: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  difficultyText: 'Medium',
                  stars: _mediumStars,
                  onTap: () => _selectDifficulty(CrosswordDifficulty.medium),
                ),
              ),

              _buildCurvedPathConnector(curveToRight: false),

              // STAGE 1: DISCOVERY (Word Explorer - Ocean Teal)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildTowerTierCard(
                  tierNumber: 1,
                  tierLabel: 'STAGE 1 • DISCOVERY',
                  tagText: '5x5 Grid • 5 Words',
                  title: 'Word Explorer',
                  subtitle: 'Solve easy crosswords with familiar picture clues',
                  emoji: '🔤',
                  primaryColor: const Color(0xFF0D9488),
                  lightBgColor: const Color(0xFFE6FFFA),
                  borderColor: const Color(0xFF99F6E4),
                  gradientColors: const [Color(0xFF14B8A6), Color(0xFF0D9488)],
                  difficultyText: 'Easy',
                  stars: _easyStars,
                  onTap: () => _selectDifficulty(CrosswordDifficulty.easy),
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
                            'Clear all intersecting words',
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
                            'Zero-Hint & Speed Bonus',
                            style: GoogleFonts.baloo2(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6D28D9),
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
                        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6D28D9).withValues(alpha: 0.3),
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
                          'Score & Speed Rules',
                          style: GoogleFonts.baloo2(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Mastering English Crosswords',
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
                      icon: '💡',
                      title: 'Zero-Hint Bonus',
                      desc: 'Complete the entire crossword without using letter hints to unlock maximum reward points!',
                    ),
                    const Divider(height: 18, thickness: 0.8, color: Color(0xFFE2E8F0)),
                    _buildBonusInfoRow(
                      icon: '⏱️',
                      title: 'Speed Clearance',
                      desc: 'Clear the board under the target time limit (40s / 80s / 120s) to earn maximum reward points.',
                    ),
                    const Divider(height: 18, thickness: 0.8, color: Color(0xFFE2E8F0)),
                    _buildBonusInfoRow(
                      icon: '🔗',
                      title: 'Word Chain',
                      desc: 'Solve intersecting words back-to-back accurately to demonstrate true vocabulary mastery.',
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
                    backgroundColor: const Color(0xFF6D28D9),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Got it, let\'s play!',
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
    _secondsElapsed = 0;
    _elapsedTimeString = '00:00';
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
