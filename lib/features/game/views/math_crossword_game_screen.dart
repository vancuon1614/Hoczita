import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/game_score_sync_service.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../../../core/providers/game_interaction_provider.dart';
import 'common/mini_game_rank_banner.dart';
import '../utils/math_crossword_generator.dart' as gen;

enum CellType { empty, number, operator, equals }

class CrosswordCell {
  final int row;
  final int col;
  final CellType type;
  final String correctVal;
  String userVal;
  bool isHint;

  CrosswordCell({
    required this.row,
    required this.col,
    required this.type,
    required this.correctVal,
    this.userVal = '',
    this.isHint = false,
  });

  bool get isCorrect => type != CellType.number || isHint || userVal == correctVal;
}

class CrosswordEquation {
  final List<CrosswordCell> cells;
  CrosswordEquation({required this.cells});

  bool get isSatisfied {
    if (cells.length != 5) return false;
    for (var c in cells) {
      if (c.type == CellType.number && !c.isHint && c.userVal.isEmpty) return false;
    }
    try {
      final isRev = cells[1].correctVal == '=';
      final aVal = cells[isRev ? 2 : 0];
      final bVal = cells[isRev ? 4 : 2];
      final resVal = cells[isRev ? 0 : 4];
      final opVal = cells[isRev ? 3 : 1];

      final a   = int.parse(aVal.isHint ? aVal.correctVal : aVal.userVal);
      final op  = opVal.correctVal;
      final b   = int.parse(bVal.isHint ? bVal.correctVal : bVal.userVal);
      final res = int.parse(resVal.isHint ? resVal.correctVal : resVal.userVal);
      int calc;
      switch (op) {
        case '+': calc = a + b; break;
        case '-': calc = a - b; break;
        case '*': case 'x': calc = a * b; break;
        case '/':
          if (b == 0) return false;
          calc = a ~/ b;
          if (a % b != 0) return false;
          break;
        default: return false;
      }
      return calc == res;
    } catch (_) { return false; }
  }
}

class MathCrosswordGameScreen extends ConsumerStatefulWidget {
  const MathCrosswordGameScreen({super.key});
  @override
  ConsumerState<MathCrosswordGameScreen> createState() => _MathCrosswordGameScreenState();
}

class _MathCrosswordGameScreenState extends ConsumerState<MathCrosswordGameScreen> {
  int? _selectedDifficulty;
  List<List<CrosswordCell>> _grid = [];
  final List<CrosswordEquation> _equations = [];

  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isSavingScore = false;

  int _gridRows = 0;
  int _gridCols = 0;

  int? _selectedCellRow;
  int? _selectedCellCol;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  int _secondsElapsed = 0;
  String _elapsedTimeString = '00:00';
  int _score = 0;
  
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
  }

  Future<void> _loadHighestStars() async {
    final easy = await SupabaseService.instance.getHighestStarsForGame('math_crossword_easy');
    final medium = await SupabaseService.instance.getHighestStarsForGame('math_crossword_medium');
    final hard = await SupabaseService.instance.getHighestStarsForGame('math_crossword_hard');
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
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (_isPlaying) _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _selectDifficulty(int difficulty) {
    ref.read(isGameActiveProvider.notifier).state = true;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    setState(() {
      _selectedDifficulty = difficulty;
      _isPlaying = true;
      _isGameOver = false;
      _isSavingScore = false;
      _selectedCellRow = null;
      _selectedCellCol = null;
      _secondsElapsed = 0;
      _elapsedTimeString = '00:00';
    });
    _generatePuzzle(difficulty);
    _stopwatch.reset();
    _stopwatch.start();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_stopwatch.isRunning) {
        setState(() {
          _secondsElapsed = _stopwatch.elapsed.inSeconds;
          _elapsedTimeString = GameCountUpTimer.formatSeconds(_secondsElapsed);
        });
      }
    });
  }



  void _generatePuzzle(int difficulty) {
    _equations.clear();
    
    gen.Difficulty genDifficulty;
    switch (difficulty) {
      case 5:
        genDifficulty = gen.Difficulty.easy;
        break;
      case 10:
        genDifficulty = gen.Difficulty.medium;
        break;
      default:
        genDifficulty = gen.Difficulty.hard;
    }

    final puzzle = gen.generatePuzzle(genDifficulty);
    _gridRows = puzzle.gridSize;
    _gridCols = puzzle.gridSize;

    // Build the grid of CrosswordCell
    _grid = List.generate(
      _gridRows,
      (r) => List.generate(_gridCols, (c) {
        final cell = puzzle.grid[r][c];
        
        // Map PuzzleCellType to CellType
        CellType mappedType;
        switch (cell.type) {
          case gen.PuzzleCellType.number:
            mappedType = CellType.number;
            break;
          case gen.PuzzleCellType.operator:
            mappedType = CellType.operator;
            break;
          case gen.PuzzleCellType.equals:
            mappedType = CellType.equals;
            break;
          default:
            mappedType = CellType.empty;
        }

        return CrosswordCell(
          row: r,
          col: c,
          type: mappedType,
          correctVal: cell.value,
          userVal: cell.userValue,
          isHint: cell.isLocked,
        );
      }),
    );

    // Build the equations
    for (final eq in puzzle.equations) {
      final cells = <CrosswordCell>[];
      for (int i = 0; i < 5; i++) {
        final r = eq.orientation == gen.CrosswordOrientation.horizontal ? eq.r : eq.r + i;
        final c = eq.orientation == gen.CrosswordOrientation.horizontal ? eq.c + i : eq.c;
        cells.add(_grid[r][c]);
      }
      _equations.add(CrosswordEquation(cells: cells));
    }
  }



  bool _checkAllEquationsSatisfied() {
    // 1. Check if all number cells are filled
    for (int r = 0; r < _gridRows; r++) {
      for (int c = 0; c < _gridCols; c++) {
        final cell = _grid[r][c];
        if (cell.type == CellType.number && !cell.isHint) {
          if (cell.userVal.isEmpty) {
            return false;
          }
        }
      }
    }

    // 2. Check if all equations are satisfied
    for (final eq in _equations) {
      if (!eq.isSatisfied) {
        return false;
      }
    }

    return true;
  }

  void _checkWinState() {
    if (_checkAllEquationsSatisfied()) {
      _endGameAndSaveScore();
    }
  }

  void _selectCell(int r, int c) {
    if (_grid[r][c].type != CellType.number || _grid[r][c].isHint) return;
    setState(() {
      _selectedCellRow = r;
      _selectedCellCol = c;
    });
  }

  void _inputDigit(String key) {
    if (_selectedCellRow == null || _selectedCellCol == null) return;
    final cell = _grid[_selectedCellRow!][_selectedCellCol!];
    setState(() {
      if (key == 'backspace') {
        if (cell.userVal.isNotEmpty) {
          cell.userVal = cell.userVal.substring(0, cell.userVal.length - 1);
        }
      } else if (key == '-') {
        if (cell.userVal.startsWith('-')) {
          cell.userVal = cell.userVal.substring(1);
        } else {
          cell.userVal = '-${cell.userVal}';
        }
      } else {
        final digitsOnly = cell.userVal.replaceAll('-', '');
        if (digitsOnly.length < 3) {
          cell.userVal += key;
        }
      }
    });
    _checkWinState();
  }

  void _endGameAndSaveScore() async {
    _stopwatch.stop();
    _timer?.cancel();
    _secondsElapsed = _stopwatch.elapsed.inSeconds;
    _elapsedTimeString = GameCountUpTimer.formatSeconds(_secondsElapsed);

    final elapsedSeconds = _secondsElapsed;
    
    // Scale stars based on difficulty & time limit
    int starRating = 0;
    int baseScore = 0;
    final diff = _selectedDifficulty ?? 5;

    if (diff == 5) {
      if (elapsedSeconds <= 30) {
        starRating = 3;
      } else if (elapsedSeconds <= 60) {
        starRating = 2;
      } else {
        starRating = 1;
      }
    } else if (diff == 10) {
      if (elapsedSeconds <= 60) {
        starRating = 3;
      } else if (elapsedSeconds <= 120) {
        starRating = 2;
      } else {
        starRating = 1;
      }
    } else {
      if (elapsedSeconds <= 90) {
        starRating = 3;
      } else if (elapsedSeconds <= 180) {
        starRating = 2;
      } else {
        starRating = 1;
      }
    }

    if (starRating == 3) {
      baseScore = 30;
    } else if (starRating == 2) {
      baseScore = 20;
    } else {
      baseScore = 10;
    }

    // Larger grids reward more score points
    final multiplier = (diff == 5) ? 1 : (diff == 10 ? 2 : 3);
    final finalScore = baseScore * multiplier;

    ref.read(isGameActiveProvider.notifier).state = false;
    setState(() {
      _score = finalScore;
      _isGameOver = true;
      _isSavingScore = true;
    });

    try {
      final levelStr = _selectedDifficulty == 5 ? '1' : (_selectedDifficulty == 10 ? '2' : '3');
      await GameScoreSyncService.instance.saveScoreParallel(
        gameCodeOrName: 'M04',
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
    _stopwatch.stop();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Thoát Trò Chơi?'),
        content: Text('Tiến trình chơi hiện tại của bạn sẽ không được lưu lại.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopwatch.start();
            },
            child: Text('Chơi tiếp'),
          ),
          TextButton(
            onPressed: () {
              ref.read(isGameActiveProvider.notifier).state = false;
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

  String get _difficultyLabel {
    if (_selectedDifficulty == 5) return 'Cấp độ: Dễ';
    if (_selectedDifficulty == 10) return 'Cấp độ: Vừa';
    return 'Cấp độ: Khó';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ô Chữ Toán Học 🔢',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: _showQuitConfirmation,
        ),
        actions: const [
          GameSoundToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCellRow = null;
            _selectedCellCol = null;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Column(
            children: [
              // 1. Subheader Row: Level/Progress on Left, Timer Pill on Right (Standard Math layout)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Text(
                        _difficultyLabel,
                        style: GoogleFonts.baloo2(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ),
                    GameCountUpTimer(
                      elapsedSeconds: _secondsElapsed,
                      margin: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              // 2. Instruction Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  'Điền các chữ số còn thiếu sao cho các phép tính hàng ngang và hàng dọc đều đúng nhé!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),

              // 3. Grid + Keypad Area
              Expanded(
                child: isLandscape
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildGridContainer()),
                          if (showKeypad) _buildInlineKeypadColumn(),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: _buildGridContainer()),
                          if (showKeypad) _buildInlineKeypadColumn(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridContainer() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        maxScale: 2.5,
        minScale: 0.8,
        boundaryMargin: const EdgeInsets.all(80),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FittedBox(
              fit: isLandscape ? BoxFit.contain : BoxFit.fitWidth,
              child: _buildCrosswordGrid(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineKeypadColumn() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['-', '0', 'backspace'],
    ];

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    String currentValue = '';
    if (_selectedCellRow != null && _selectedCellCol != null) {
      currentValue = _grid[_selectedCellRow!][_selectedCellCol!].userVal;
    }

    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: isLandscape ? 240 : double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: isLandscape ? BorderSide.none : const BorderSide(color: AppColors.border, width: 1.5),
            left: isLandscape ? const BorderSide(color: AppColors.border, width: 1.5) : BorderSide.none,
          ),
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, isLandscape ? 12 : MediaQuery.of(context).padding.bottom + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Nhập số:',
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  width: 60,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    currentValue.isEmpty ? '-' : currentValue,
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          SizedBox(height: 10),
          ...keys.map((row) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: row.map((key) {
                  final isSpecial = key == '-' || key == 'backspace';
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () => _inputDigit(key),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: isLandscape ? 38 : 44,
                          decoration: BoxDecoration(
                            color: isSpecial ? Colors.grey[100] : AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: key == 'backspace'
                              ? Icon(Icons.backspace_outlined, color: AppColors.textPrimary, size: 18)
                              : Text(
                                  key,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 16,
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
          'Ô Chữ Toán Học',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 20,
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
                    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
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
                              'TOÁN TIỂU HỌC',
                              style: GoogleFonts.baloo2(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFF3E8FF),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ô Chữ Số Học',
                            style: GoogleFonts.baloo2(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Giải ô chữ bằng các con số sao cho các phép tính ngang dọc đều chuẩn xác!',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              color: const Color(0xFFF3E8FF),
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
                              '➕',
                              style: TextStyle(fontSize: 34),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Header: BẢN ĐỒ VƯỢT ẢI + Nút Thưởng Giao Điểm Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BẢN ĐỒ VƯỢT ẢI',
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
                            'Thưởng Giao Điểm',
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

              // TẦNG 3: BỨT PHÁ (Đỉnh Cao Ô Số - Tím Tinh Anh)
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: _buildTowerTierCard(
                  tierNumber: 3,
                  tierLabel: 'CHẶNG 3 • BỨT PHÁ',
                  tagText: 'Lưới Đa Phép Tính',
                  title: 'Đỉnh Cao Ô Số',
                  subtitle: 'Phối hợp nhịp nhàng cả 4 phép tính tại các giao điểm hóc búa',
                  emoji: '🏆',
                  primaryColor: const Color(0xFF7C3AED),
                  lightBgColor: const Color(0xFFF5F3FF),
                  borderColor: const Color(0xFFDDD6FE),
                  gradientColors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                  difficultyText: 'Khó',
                  stars: _hardStars,
                  onTap: () => _selectDifficulty(20),
                ),
              ),

              _buildCurvedPathConnector(curveToRight: true),

              // TẦNG 2: SUY LUẬN (Mê Cung Phép Tính - Cam Ấm)
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: _buildTowerTierCard(
                  tierNumber: 2,
                  tierLabel: 'CHẶNG 2 • SUY LUẬN',
                  tagText: 'Lưới 6–8 phép tính',
                  title: 'Mê Cung Phép Tính',
                  subtitle: 'Tính toán 2 chiều để số điền khớp hoàn hảo cả hàng và cột',
                  emoji: '🧩',
                  primaryColor: const Color(0xFFD97706),
                  lightBgColor: const Color(0xFFFFF7ED),
                  borderColor: const Color(0xFFFED7AA),
                  gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                  difficultyText: 'Trung bình',
                  stars: _mediumStars,
                  onTap: () => _selectDifficulty(10),
                ),
              ),

              _buildCurvedPathConnector(curveToRight: false),

              // TẦNG 1: KHỞI ĐỘNG (Giao Điểm Đầu Tiên - Xanh Ngọc)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildTowerTierCard(
                  tierNumber: 1,
                  tierLabel: 'CHẶNG 1 • KHỞI ĐỘNG',
                  tagText: 'Lưới 3–4 phép tính',
                  title: 'Giao Điểm Đầu Tiên',
                  subtitle: 'Làm quen điền số với các phép cộng, trừ đơn giản trên lưới',
                  emoji: '🌱',
                  primaryColor: const Color(0xFF059669),
                  lightBgColor: const Color(0xFFF0FDF4),
                  borderColor: const Color(0xFFA7F3D0),
                  gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
                  difficultyText: 'Dễ',
                  stars: _easyStars,
                  onTap: () => _selectDifficulty(5),
                ),
              ),

              const SizedBox(height: 28),

              // Footer Card quy chuẩn & phần thưởng
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
                            'QUY CHUẨN VÒNG CHƠI',
                            style: GoogleFonts.baloo2(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            'Giải trọn vẹn toàn bộ lưới',
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
                            'HỆ SỐ PHẦN THƯỞNG',
                            style: GoogleFonts.baloo2(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            'Thưởng Giao Điểm Kép',
                            style: GoogleFonts.baloo2(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF7C3AED),
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
        // 1. Sub-badge hàng trên: Số tầng + Tên chặng + Tag
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

        // 2. Thẻ Pastel Toy Card tương tác
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

                    // Tiêu đề, mô tả và vạch tiến độ 3 nấc
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

                    // Mũi tên điều hướng
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
                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.bolt_rounded, size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cơ Chế Thưởng Điểm',
                          style: GoogleFonts.baloo2(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Bí kíp chinh phục Ô Chữ Toán Học',
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
                      icon: '🎯',
                      title: 'Giao Điểm Kép',
                      desc: 'Điền 1 con số hoàn thành chính xác cả hàng ngang lẫn cột dọc để nhận thêm điểm thưởng!',
                    ),
                    const Divider(height: 18, thickness: 0.8, color: Color(0xFFE2E8F0)),
                    _buildBonusInfoRow(
                      icon: '⏱️',
                      title: 'Thời Gian Vàng',
                      desc: 'Giải xong lưới càng nhanh (dưới 30s/60s/90s) sẽ nhận trọn vẹn 3 Sao vàng và điểm nhân theo cấp độ.',
                    ),
                    const Divider(height: 18, thickness: 0.8, color: Color(0xFFE2E8F0)),
                    _buildBonusInfoRow(
                      icon: '✨',
                      title: 'Tư Duy Chuẩn Xác',
                      desc: 'Điền liền mạch không cần xóa sửa để giữ vững phong độ điểm tối đa của ván đấu.',
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
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Đã hiểu, thử thách ngay!',
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

  Widget _buildCrosswordGrid() {
    // Pre-calculate satisfied equations once per rebuild to prevent O(N*M) heavy string parses
    final satisfiedEquations = <CrosswordEquation>{};
    for (final eq in _equations) {
      if (eq.isSatisfied) {
        satisfiedEquations.add(eq);
      }
    }

    int minRow = _gridRows;
    int maxRow = -1;
    int minCol = _gridCols;
    int maxCol = -1;

    for (int r = 0; r < _gridRows; r++) {
      for (int c = 0; c < _gridCols; c++) {
        if (_grid[r][c].type != CellType.empty) {
          if (r < minRow) minRow = r;
          if (r > maxRow) maxRow = r;
          if (c < minCol) minCol = c;
          if (c > maxCol) maxCol = c;
        }
      }
    }

    // Fallback if no active cells found
    if (maxRow == -1) {
      minRow = 0;
      maxRow = _gridRows - 1;
      minCol = 0;
      maxCol = _gridCols - 1;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRow - minRow + 1, (index) {
        final r = minRow + index;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(maxCol - minCol + 1, (indexCol) {
            final c = minCol + indexCol;
            return _buildCellItem(_grid[r][c], satisfiedEquations);
          }),
        );
      }),
    );
  }

  Widget _buildCellItem(CrosswordCell cell, Set<CrosswordEquation> satisfiedEquations) {
    if (cell.type == CellType.empty) {
      return SizedBox(width: 45, height: 45);
    }

    // Check if this cell is part of any fully satisfied/correct equations
    bool isCellPartofCorrectEquation = false;
    for (var eq in satisfiedEquations) {
      if (eq.cells.contains(cell)) {
        isCellPartofCorrectEquation = true;
        break;
      }
    }

    Color backColor = Colors.white;
    Color borderColor = Colors.black;
    Color textColor = AppColors.textPrimary;
    double borderWidth = 2.0;

    final isSelected = cell.row == _selectedCellRow && cell.col == _selectedCellCol;

    if (isCellPartofCorrectEquation) {
      backColor = Colors.green[50]!;
      borderColor = AppColors.success;
      textColor = AppColors.success;
      borderWidth = 2.5;
    } else if (cell.type == CellType.number) {
      if (cell.isHint) {
        backColor = Colors.white;
        textColor = AppColors.textPrimary;
      } else {
        if (isSelected) {
          backColor = AppColors.primaryLight;
          borderColor = AppColors.primary;
          textColor = AppColors.primary;
          borderWidth = 3.0;
        }
      }
    } else {
      // Operators & equals
      textColor = AppColors.textPrimary;
    }

    if (cell.type == CellType.number && !cell.isHint) {
      return GestureDetector(
        onTap: () => _selectCell(cell.row, cell.col),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 42,
          height: 42,
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
          alignment: Alignment.center,
          child: Text(
            cell.userVal,
            style: GoogleFonts.baloo2(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      );
    }

    String displayText = '';
    if (cell.type == CellType.number) {
      displayText = cell.correctVal;
    } else {
      displayText = cell.correctVal;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 42,
      height: 42,
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: backColor,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      alignment: Alignment.center,
      child: Text(
        displayText,
        style: GoogleFonts.baloo2(
          fontSize: cell.type == CellType.number ? 16 : 18,
          fontWeight: cell.type == CellType.number ? FontWeight.bold : FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  // Removed unused keypad method

  Widget _buildSummaryView() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Trophy Icon
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
              const Spacer(),
              Text(
                'Giải Ô Chữ Hoàn Tất! 🎉',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              
              Text(
                'Chúc mừng! Bạn đã giải thành công toàn bộ ô chữ toán học trong $_elapsedTimeString.',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Time & Score Cards
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
              const SizedBox(height: 24),
              MiniGameRankBanner(
                gameName: 'math_crossword_${_selectedDifficulty == 5 ? 'easy' : (_selectedDifficulty == 10 ? 'medium' : 'hard')}',
                gameTitle: 'Ô Chữ Toán Học',
                currentScore: _score,
              ),
              const Spacer(),
              
              // Action Button
              Center(
                child: SizedBox(
                  width: 220,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSavingScore
                        ? null
                        : () {
                            Navigator.pop(context); // Go back to GameTab
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
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Quay lại danh mục',
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
