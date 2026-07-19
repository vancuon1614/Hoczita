import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
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

class MathCrosswordGameScreen extends StatefulWidget {
  const MathCrosswordGameScreen({super.key});
  @override
  State<MathCrosswordGameScreen> createState() => _MathCrosswordGameScreenState();
}

class _MathCrosswordGameScreenState extends State<MathCrosswordGameScreen> {
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
  late Timer _timer;
  String _elapsedTimeString = '0.0';
  int _score = 0;
  int _stars = 0;
  
  int _easyStars = 0;
  int _mediumStars = 0;
  int _hardStars = 0;

  @override
  void initState() {
    super.initState();
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
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (_isPlaying) _timer.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _selectDifficulty(int difficulty) {
    if (difficulty == 10 || difficulty == 20) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    setState(() {
      _selectedDifficulty = difficulty;
      _isPlaying = true;
      _isGameOver = false;
      _isSavingScore = false;
      _selectedCellRow = null;
      _selectedCellCol = null;
    });
    _generatePuzzle(difficulty);
    _stopwatch.reset();
    _stopwatch.start();
    _startTimer();
  }

  String _formatTime(double seconds) {
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final int ts = seconds.round();
    if (ts < 3600) {
      return '${(ts ~/ 60).toString().padLeft(2, '0')}:${(ts % 60).toString().padLeft(2, '0')}';
    }
    final h = ts ~/ 3600; final m = (ts % 3600) ~/ 60; final s = ts % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_stopwatch.isRunning) {
        setState(() => _elapsedTimeString = _formatTime(_stopwatch.elapsedMilliseconds / 1000));
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
    _timer.cancel();

    final elapsedSeconds = _stopwatch.elapsedMilliseconds / 1000;
    
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

    setState(() {
      _stars = starRating;
      _score = finalScore;
      _isGameOver = true;
      _isSavingScore = true;
    });

    try {
      final diffName = _selectedDifficulty == 5 ? 'easy' : (_selectedDifficulty == 10 ? 'medium' : 'hard');
      await SupabaseService.instance.saveScore(
        gameName: 'math_crossword_$diffName',
        stars: _stars,
        score: _score,
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
          'Math Crossword 🔢',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded),
          onPressed: _showQuitConfirmation,
        ),
        actions: [
          Container(
            width: 76,
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 4),
                Icon(Icons.timer_outlined, size: 14, color: AppColors.primary),
                Expanded(
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
          setState(() {
            _selectedCellRow = null;
            _selectedCellCol = null;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: isLandscape
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left side: Instruction + Grid
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Text(
                              'Điền các chữ số còn thiếu sao cho các phép tính hàng ngang và hàng dọc đều đúng nhé!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.baloo2(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ),
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
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text(
                        'Điền các chữ số còn thiếu sao cho các phép tính hàng ngang và hàng dọc đều đúng nhé!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(child: _buildGridContainer()),
                    if (showKeypad) _buildInlineKeypadColumn(),
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
              'Math Crossword',
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
              child: Icon(Icons.grid_4x4_rounded, size: 20, color: Colors.blueGrey),
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
              // 3D Grid Icon
              Center(
                child: Image.asset(
                  'ImageFolder/mathcount.gif', 
                  height: 120,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.grid_on_rounded,
                    size: 80,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Chọn Số Lượng Phép Tính',
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
                subtitle: 'Làm quen nhẹ nhàng với 5 bài tập.',
                difficulty: 5,
                backgroundColor: const Color(0xFFE4F3E4),
                iconColor: const Color(0xFF4CAF50),
                stars: _easyStars,
              ),
              SizedBox(height: 16),
              _buildDifficultyButton(
                title: 'Tập trung',
                subtitle: 'Tăng cường thử thách với 10 bài tập.',
                difficulty: 10,
                backgroundColor: const Color(0xFFFDEBCE),
                iconColor: const Color(0xFFF59E0B),
                stars: _mediumStars,
              ),
              SizedBox(height: 16),
              _buildDifficultyButton(
                title: 'Thử thách',
                subtitle: 'Dành cho người chơi nâng cao với 20 bài tập.',
                difficulty: 20,
                backgroundColor: const Color(0xFFFFE5E5),
                iconColor: const Color(0xFFEF4444),
                stars: _hardStars,
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
    required int difficulty,
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
                // Circular play icon
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
                // Stars
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
              SizedBox(height: 32),

              // Stars Display
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
}
