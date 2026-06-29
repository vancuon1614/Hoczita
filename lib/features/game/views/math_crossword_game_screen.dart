import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

enum CellType { empty, number, operator, equals }

class CrosswordCell {
  final int row;
  final int col;
  final CellType type;
  final String correctVal; // e.g., "5", "+", "="
  String userVal; // empty string initially for input numbers
  bool isHint; // true if pre-filled, false if input needed

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
  final List<CrosswordCell> numberCells; // 3 cells (num1, num2, result)
  final CrosswordCell opCell;
  final CrosswordCell eqCell;
  final String opType; // "+" or "-"

  CrosswordEquation({
    required this.numberCells,
    required this.opCell,
    required this.eqCell,
    required this.opType,
  });

  bool get isSatisfied {
    if (numberCells.any((c) => c.type == CellType.number && !c.isHint && c.userVal.isEmpty)) {
      return false;
    }
    final val1Str = numberCells[0].isHint ? numberCells[0].correctVal : numberCells[0].userVal;
    final val2Str = numberCells[1].isHint ? numberCells[1].correctVal : numberCells[1].userVal;
    final resStr = numberCells[2].isHint ? numberCells[2].correctVal : numberCells[2].userVal;

    final n1 = int.tryParse(val1Str) ?? -999;
    final n2 = int.tryParse(val2Str) ?? -999;
    final res = int.tryParse(resStr) ?? -999;

    if (opType == '+') {
      return n1 + n2 == res;
    } else {
      return n1 - n2 == res;
    }
  }

  bool get isFullyCorrect {
    return numberCells.every((c) => c.isCorrect);
  }
}

class MathCrosswordGameScreen extends StatefulWidget {
  const MathCrosswordGameScreen({super.key});

  @override
  State<MathCrosswordGameScreen> createState() => _MathCrosswordGameScreenState();
}

class _MathCrosswordGameScreenState extends State<MathCrosswordGameScreen> {
  int? _selectedDifficulty; // 5, 10, or 20 equations
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isSavingScore = false;

  int _gridRows = 0;
  int _gridCols = 0;
  List<List<CrosswordCell>> _grid = [];
  final List<CrosswordEquation> _equations = [];

  int? _selectedCellRow;
  int? _selectedCellCol;

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
    if (_isPlaying) {
      _timer.cancel();
    }
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
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
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

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_stopwatch.isRunning) {
        setState(() {
          _elapsedTimeString = (_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1);
        });
      }
    });
  }

  void _generatePuzzle(int difficulty) {
    final rand = Random();
    _equations.clear();

    if (difficulty == 5) {
      _gridRows = 5;
      _gridCols = 5;
      _grid = List.generate(
        _gridRows,
        (r) => List.generate(
          _gridCols,
          (c) => CrosswordCell(row: r, col: c, type: CellType.empty, correctVal: ''),
        ),
      );

      // Generate consistent values for 5x5 layout
      final a = rand.nextInt(7) + 2; // 2..8
      final b = rand.nextInt(5) + 4; // 4..8
      final c = rand.nextInt(5) + 4; // 4..8
      final d = rand.nextInt(min(b, c) - 2) + 1; // 1..(min-2) to avoid negative/zero

      final values = {
        '0,0': a,
        '0,2': b,
        '0,4': a + b,
        '2,0': c,
        '2,2': d,
        '2,4': c - d,
        '4,0': a + c,
        '4,2': b - d,
        '4,4': (a + c) + (b - d),
      };

      // Fill grid
      for (int r = 0; r < 5; r++) {
        for (int c = 0; c < 5; c++) {
          if (r % 2 == 0 && c % 2 == 0) {
            final val = values['$r,$c']!;
            _grid[r][c] = CrosswordCell(
              row: r,
              col: c,
              type: CellType.number,
              correctVal: val.toString(),
            );
          } else if (r % 2 == 0 && c % 2 != 0) {
            final val = (c == 1) ? (r == 2 ? '-' : '+') : (c == 3 ? '=' : '');
            _grid[r][c] = CrosswordCell(
              row: r,
              col: c,
              type: (c == 3) ? CellType.equals : CellType.operator,
              correctVal: val,
            );
          } else if (r % 2 != 0 && c % 2 == 0) {
            final val = (r == 1) ? (c == 2 ? '-' : '+') : (r == 3 ? '=' : '');
            _grid[r][c] = CrosswordCell(
              row: r,
              col: c,
              type: (r == 3) ? CellType.equals : CellType.operator,
              correctVal: val,
            );
          }
        }
      }

      _equations.addAll([
        // Horizontal
        CrosswordEquation(
          numberCells: [_grid[0][0], _grid[0][2], _grid[0][4]],
          opCell: _grid[0][1],
          eqCell: _grid[0][3],
          opType: '+',
        ),
        CrosswordEquation(
          numberCells: [_grid[2][0], _grid[2][2], _grid[2][4]],
          opCell: _grid[2][1],
          eqCell: _grid[2][3],
          opType: '-',
        ),
        CrosswordEquation(
          numberCells: [_grid[4][0], _grid[4][2], _grid[4][4]],
          opCell: _grid[4][1],
          eqCell: _grid[4][3],
          opType: '+',
        ),
        // Vertical
        CrosswordEquation(
          numberCells: [_grid[0][0], _grid[2][0], _grid[4][0]],
          opCell: _grid[1][0],
          eqCell: _grid[3][0],
          opType: '+',
        ),
        CrosswordEquation(
          numberCells: [_grid[0][2], _grid[2][2], _grid[4][2]],
          opCell: _grid[1][2],
          eqCell: _grid[3][2],
          opType: '-',
        ),
        CrosswordEquation(
          numberCells: [_grid[0][4], _grid[2][4], _grid[4][4]],
          opCell: _grid[1][4],
          eqCell: _grid[3][4],
          opType: '+',
        ),
      ]);

      // Assign hints (about 4 out of 9 number cells)
      final numberCellList = <CrosswordCell>[];
      for (var r in [0, 2, 4]) {
        for (var c in [0, 2, 4]) {
          numberCellList.add(_grid[r][c]);
        }
      }
      numberCellList.shuffle(rand);
      for (int i = 0; i < 4; i++) {
        numberCellList[i].isHint = true;
      }
    } else if (difficulty == 10) {
      _gridRows = 9;
      _gridCols = 5;
      _grid = List.generate(
        _gridRows,
        (r) => List.generate(
          _gridCols,
          (c) => CrosswordCell(row: r, col: c, type: CellType.empty, correctVal: ''),
        ),
      );

      final a = rand.nextInt(4) + 1; // 1..4
      final b = rand.nextInt(4) + 1; // 1..4
      final c = rand.nextInt(4) + 1; // 1..4
      final d = rand.nextInt(4) + 1; // 1..4
      final g = rand.nextInt(4) + 1; // 1..4
      final h = rand.nextInt(4) + 1; // 1..4

      final values = {
        '0,0': a,
        '0,2': b,
        '0,4': a + b,
        '2,0': c,
        '2,2': d,
        '2,4': c + d,
        '4,0': a + c,
        '4,2': b + d,
        '4,4': a + b + c + d,
        '6,0': g,
        '6,2': h,
        '6,4': g + h,
        '8,0': a + c + g,
        '8,2': b + d + h,
        '8,4': a + b + c + d + g + h,
      };

      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 5; c++) {
          if (r % 2 == 0 && c % 2 == 0) {
            _grid[r][c] = CrosswordCell(
              row: r,
              col: c,
              type: CellType.number,
              correctVal: values['$r,$c']!.toString(),
            );
          } else if (r % 2 == 0 && c % 2 != 0) {
            _grid[r][c] = CrosswordCell(
              row: r,
              col: c,
              type: (c == 3) ? CellType.equals : CellType.operator,
              correctVal: (c == 3) ? '=' : '+',
            );
          } else if (r % 2 != 0 && c % 2 == 0) {
            _grid[r][c] = CrosswordCell(
              row: r,
              col: c,
              type: (r == 3 || r == 7) ? CellType.equals : CellType.operator,
              correctVal: (r == 3 || r == 7) ? '=' : '+',
            );
          }
        }
      }

      // Add equations
      _equations.addAll([
        // Horizontal
        CrosswordEquation(numberCells: [_grid[0][0], _grid[0][2], _grid[0][4]], opCell: _grid[0][1], eqCell: _grid[0][3], opType: '+'),
        CrosswordEquation(numberCells: [_grid[2][0], _grid[2][2], _grid[2][4]], opCell: _grid[2][1], eqCell: _grid[2][3], opType: '+'),
        CrosswordEquation(numberCells: [_grid[4][0], _grid[4][2], _grid[4][4]], opCell: _grid[4][1], eqCell: _grid[4][3], opType: '+'),
        CrosswordEquation(numberCells: [_grid[6][0], _grid[6][2], _grid[6][4]], opCell: _grid[6][1], eqCell: _grid[6][3], opType: '+'),
        CrosswordEquation(numberCells: [_grid[8][0], _grid[8][2], _grid[8][4]], opCell: _grid[8][1], eqCell: _grid[8][3], opType: '+'),
        // Vertical
        CrosswordEquation(numberCells: [_grid[0][0], _grid[2][0], _grid[4][0]], opCell: _grid[1][0], eqCell: _grid[3][0], opType: '+'),
        CrosswordEquation(numberCells: [_grid[4][0], _grid[6][0], _grid[8][0]], opCell: _grid[5][0], eqCell: _grid[7][0], opType: '+'),
        CrosswordEquation(numberCells: [_grid[0][2], _grid[2][2], _grid[4][2]], opCell: _grid[1][2], eqCell: _grid[3][2], opType: '+'),
        CrosswordEquation(numberCells: [_grid[4][2], _grid[6][2], _grid[8][2]], opCell: _grid[5][2], eqCell: _grid[7][2], opType: '+'),
        CrosswordEquation(numberCells: [_grid[0][4], _grid[2][4], _grid[4][4]], opCell: _grid[1][4], eqCell: _grid[3][4], opType: '+'),
        CrosswordEquation(numberCells: [_grid[4][4], _grid[6][4], _grid[8][4]], opCell: _grid[5][4], eqCell: _grid[7][4], opType: '+'),
      ]);

      // Assign hints (about 7 out of 15 number cells)
      final numberCellList = <CrosswordCell>[];
      for (var r in [0, 2, 4, 6, 8]) {
        for (var c in [0, 2, 4]) {
          numberCellList.add(_grid[r][c]);
        }
      }
      numberCellList.shuffle(rand);
      for (int i = 0; i < 7; i++) {
        numberCellList[i].isHint = true;
      }
    } else {
      // Large layout (20 equations, 9x9 grid)
      _gridRows = 9;
      _gridCols = 9;
      _grid = List.generate(
        _gridRows,
        (r) => List.generate(
          _gridCols,
          (c) => CrosswordCell(row: r, col: c, type: CellType.empty, correctVal: ''),
        ),
      );

      final a = rand.nextInt(3) + 1; // 1..3
      final b = rand.nextInt(3) + 1;
      final c = rand.nextInt(3) + 1;
      final d = rand.nextInt(3) + 1;
      final e = rand.nextInt(3) + 1;
      final f = rand.nextInt(3) + 1;
      final g = rand.nextInt(3) + 1;
      final h = rand.nextInt(3) + 1;
      final i = rand.nextInt(3) + 1;

      final values = {
        '0,0': a, '0,2': b, '0,4': a + b, '0,6': c, '0,8': a + b + c,
        '2,0': d, '2,2': e, '2,4': d + e, '2,6': f, '2,8': d + e + f,
        '4,0': a + d, '4,2': b + e, '4,4': a + b + d + e, '4,6': c + f, '4,8': a + b + c + d + e + f,
        '6,0': g, '6,2': h, '6,4': g + h, '6,6': i, '6,8': g + h + i,
        '8,0': a + d + g, '8,2': b + e + h, '8,4': a + b + d + e + g + h, '8,6': c + f + i, '8,8': a + b + c + d + e + f + g + h + i,
      };

      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (r % 2 == 0 && c % 2 == 0) {
            _grid[r][c] = CrosswordCell(
              row: r,
              col: c,
              type: CellType.number,
              correctVal: values['$r,$c']!.toString(),
            );
          } else if (r % 2 == 0 && c % 2 != 0) {
            _grid[r][c] = CrosswordCell(
              row: r,
              col: c,
              type: (c == 3 || c == 7) ? CellType.equals : CellType.operator,
              correctVal: (c == 3 || c == 7) ? '=' : '+',
            );
          } else if (r % 2 != 0 && c % 2 == 0) {
            _grid[r][c] = CrosswordCell(
              row: r,
              col: c,
              type: (r == 3 || r == 7) ? CellType.equals : CellType.operator,
              correctVal: (r == 3 || r == 7) ? '=' : '+',
            );
          }
        }
      }

      // Add equations
      for (int r = 0; r < 9; r += 2) {
        _equations.add(CrosswordEquation(numberCells: [_grid[r][0], _grid[r][2], _grid[r][4]], opCell: _grid[r][1], eqCell: _grid[r][3], opType: '+'));
        _equations.add(CrosswordEquation(numberCells: [_grid[r][4], _grid[r][6], _grid[r][8]], opCell: _grid[r][5], eqCell: _grid[r][7], opType: '+'));
      }
      for (int c = 0; c < 9; c += 2) {
        _equations.add(CrosswordEquation(numberCells: [_grid[0][c], _grid[2][c], _grid[4][c]], opCell: _grid[1][c], eqCell: _grid[3][c], opType: '+'));
        _equations.add(CrosswordEquation(numberCells: [_grid[4][c], _grid[6][c], _grid[8][c]], opCell: _grid[5][c], eqCell: _grid[7][c], opType: '+'));
      }

      // Assign hints (about 12 out of 25 number cells)
      final numberCellList = <CrosswordCell>[];
      for (var r in [0, 2, 4, 6, 8]) {
        for (var c in [0, 2, 4, 6, 8]) {
          numberCellList.add(_grid[r][c]);
        }
      }
      numberCellList.shuffle(rand);
      for (int i = 0; i < 12; i++) {
        numberCellList[i].isHint = true;
      }
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
      await SupabaseService.instance.saveScore(
        gameName: 'math_crossword',
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
    _stopwatch.stop();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thoát Trò Chơi?'),
        content: const Text('Tiến trình chơi hiện tại của bé sẽ không được lưu lại.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopwatch.start();
            },
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
        title: const Text(
          'Math Crossword 🔢',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _showQuitConfirmation,
        ),
        actions: [
          Container(
            width: 85, // Fixed width to prevent shifting layout
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
                  '${_elapsedTimeString}s',
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
      body: SafeArea(
        child: isLandscape
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left side: Instruction + Grid
                  Expanded(
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Text(
                            'Điền các chữ số còn thiếu sao cho các phép tính hàng ngang và hàng dọc đều đúng nhé!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text(
                      'Điền các chữ số còn thiếu sao cho các phép tính hàng ngang và hàng dọc đều đúng nhé!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(child: _buildGridContainer()),
                  if (showKeypad) _buildInlineKeypadColumn(),
                ],
              ),
      ),
    );
  }

  Widget _buildGridContainer() {
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

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nhập số:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedCellRow = null;
                    _selectedCellCol = null;
                  });
                },
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text(
                  'Xong',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                              ? const Icon(Icons.backspace_outlined, color: AppColors.textPrimary, size: 18)
                              : Text(
                                  key,
                                  style: const TextStyle(
                                    fontSize: 18,
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
    );
  }

  Widget _buildDifficultySelection() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Math Crossword 🔢',
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
                Icons.grid_on_rounded,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn Số Lượng Phép Tính',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kích thước lưới ô chữ sẽ thay đổi theo số lượng phép tính bé chọn.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              _buildDifficultyButton(
                title: 'Dễ (5 Phép Tính)',
                subtitle: 'Lưới ô chữ 5x5 - Phù hợp cho bé mới bắt đầu',
                difficulty: 5,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              _buildDifficultyButton(
                title: 'Trung Bình (10 Phép Tính)',
                subtitle: 'Lưới ô chữ 9x5 - Thách thức tư duy tính toán nhanh',
                difficulty: 10,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              _buildDifficultyButton(
                title: 'Khó (20 Phép Tính)',
                subtitle: 'Lưới ô chữ 9x9 - Đỉnh cao toán học crossword',
                difficulty: 20,
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
    required int difficulty,
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
            offset: const Offset(0, 3),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: color, size: 28),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCrosswordGrid() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_gridRows, (r) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_gridCols, (c) {
            return _buildCellItem(_grid[r][c]);
          }),
        );
      }),
    );
  }

  Widget _buildCellItem(CrosswordCell cell) {
    if (cell.type == CellType.empty) {
      return const SizedBox(width: 44, height: 44);
    }

    // Check if this cell is part of any fully satisfied/correct equations
    bool isCellPartofCorrectEquation = false;
    for (var eq in _equations) {
      if (eq.isSatisfied) {
        if (eq.numberCells.contains(cell) || eq.opCell == cell || eq.eqCell == cell) {
          isCellPartofCorrectEquation = true;
        }
      }
    }

    Color backColor = Colors.white;
    Color borderColor = AppColors.border;
    Color textColor = AppColors.textPrimary;
    double borderWidth = 1.0;

    final isSelected = cell.row == _selectedCellRow && cell.col == _selectedCellCol;

    if (cell.type == CellType.number) {
      if (cell.isHint) {
        backColor = AppColors.border.withValues(alpha: 0.3);
        textColor = AppColors.textSecondary;
      } else {
        if (isCellPartofCorrectEquation) {
          backColor = AppColors.success.withValues(alpha: 0.15);
          borderColor = AppColors.success;
          textColor = AppColors.success;
          borderWidth = 2.0;
        } else if (isSelected) {
          backColor = AppColors.primaryLight;
          borderColor = AppColors.primary;
          textColor = AppColors.primary;
          borderWidth = 2.5;
        }
      }
    } else {
      // Operators & equals
      textColor = AppColors.textSecondary;
      if (isCellPartofCorrectEquation) {
        textColor = AppColors.success;
      }
    }

    if (cell.type == CellType.number && !cell.isHint) {
      return GestureDetector(
        onTap: () => _selectCell(cell.row, cell.col),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 42,
          height: 42,
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
          alignment: Alignment.center,
          child: Text(
            cell.userVal,
            style: TextStyle(
              fontSize: 16,
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
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: backColor,
        borderRadius: BorderRadius.circular(10),
        border: cell.type == CellType.number ? Border.all(color: borderColor, width: borderWidth) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        displayText,
        style: TextStyle(
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
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.amber,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Giải Ô Chữ Hoàn Tất! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                'Bé đã giải thành công toàn bộ ô chữ toán học trong $_elapsedTimeString giây.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

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
              const SizedBox(height: 40),

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
                          const Text(
                            'Thời gian',
                            style: TextStyle(fontSize: 13, color: AppColors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_elapsedTimeString}s',
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

              const Spacer(),
              
              // Action Button
              ElevatedButton(
                onPressed: _isSavingScore
                    ? null
                    : () {
                        Navigator.pop(context); // Go back to GameTab
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
