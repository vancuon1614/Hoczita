import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../../core/providers/game_interaction_provider.dart';
import 'common/mini_game_lobby_screen.dart';
import 'common/mini_game_how_to_play_sheet.dart';
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
    ref.read(isGameActiveProvider.notifier).state = false;
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (_isPlaying) _timer.cancel();
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

    ref.read(isGameActiveProvider.notifier).state = false;
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
          GameCountUpTimer(timeString: _elapsedTimeString),
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
    return MiniGameLobbyScreen(
      gameTitle: 'Math Crossword',
      categoryBadge: 'Toán Học 🔢',
      welcomeTitle: 'Chào mừng bạn đến với Math Crossword!',
      welcomeSubtitle: 'Thử tài tính toán và tư duy logic qua ma trận ô chữ phép tính',
      starsCount: _easyStars + _mediumStars + _hardStars,
      difficulties: [
        GameDifficultyOption(
          id: 'easy',
          tabLabel: 'Khởi Động',
          modeTitle: 'Chế độ Khởi Động (5 phép tính)',
          modeSubtitle: 'Làm quen nhẹ nhàng với 5 phép tính cơ bản',
          timerTag: '3 Phút',
          wordLimitInfo: 'Lưới 5 phép tính cộng, trừ cơ bản',
          timeInfo: '3 phút tính nhẩm thư thái',
          hintInfo: 'Mở sẵn các ô dấu và một số số gợi ý ban đầu',
          rewardInfo: '+10 Điểm ⭐️',
          tipFromHocDi: 'Hãy tìm các phép tính chỉ còn thiếu đúng 1 số để tính ra kết quả trước nhé!',
          themeColor: const Color(0xFF006D38),
          interactivePreview: _buildMathCrosswordPreviewBox(
            equation: '3 + 5 = 8',
            color: const Color(0xFF00B460),
          ),
        ),
        GameDifficultyOption(
          id: 'medium',
          tabLabel: 'Tập Trung',
          modeTitle: 'Chế độ Tập Trung (10 phép tính)',
          modeSubtitle: 'Tăng cường thử thách với 10 phép tính đan xen',
          timerTag: '5 Phút',
          wordLimitInfo: '10 phép tính cộng, trừ, nhân đan xen liên hoàn',
          timeInfo: '5 phút thi đấu tính nhanh',
          hintInfo: 'Ít gợi ý hơn, cần tính nhẩm hai chiều ngang dọc',
          rewardInfo: '+20 Điểm ⭐️',
          tipFromHocDi: 'Quan sát các ô giao nhau giữa hàng ngang và cột dọc để suy luận số chính xác!',
          themeColor: const Color(0xFF00629D),
          interactivePreview: _buildMathCrosswordPreviewBox(
            equation: '4 x 3 = 12',
            color: const Color(0xFF0047AB),
          ),
        ),
        GameDifficultyOption(
          id: 'hard',
          tabLabel: 'Thử Thách',
          modeTitle: 'Chế độ Thử Thách (20 phép tính)',
          modeSubtitle: 'Dành cho cao thủ toán học với ma trận 20 phép tính phức tạp',
          timerTag: '8 Phút',
          wordLimitInfo: '20 phép tính bao gồm cả nhân chia đa tầng',
          timeInfo: '8 phút thử thách cân não',
          hintInfo: 'Ma trận lớn đòi hỏi chiến thuật tính toán tuần tự',
          rewardInfo: '+35 Điểm ⭐️',
          tipFromHocDi: 'Giải quyết các phép nhân chia trước để thu hẹp phạm vi số có thể xuất hiện!',
          themeColor: const Color(0xFF885200),
          interactivePreview: _buildMathCrosswordPreviewBox(
            equation: '15 - 7 = 8',
            color: const Color(0xFF885200),
          ),
        ),
      ],
      tutorialSteps: [
        const GameTutorialStep(
          stepNumber: 1,
          icon: Icons.touch_app_rounded,
          themeColor: Color(0xFF00629D),
          title: 'Chọn ô số còn thiếu',
          description: 'Chạm vào các ô vuông trống trên ma trận phép tính để kích hoạt bàn phím số bên dưới.',
        ),
        const GameTutorialStep(
          stepNumber: 2,
          icon: Icons.calculate_rounded,
          themeColor: Color(0xFF885200),
          title: 'Tính nhẩm & điền số',
          description: 'Tính toán giá trị còn thiếu của phép tính hàng ngang hoặc cột dọc rồi chọn con số chính xác.',
        ),
        const GameTutorialStep(
          stepNumber: 3,
          icon: Icons.military_tech_rounded,
          themeColor: Color(0xFF006D38),
          title: 'Hoàn thành ma trận phép tính',
          description: 'Điền đúng tất cả các ô số để các phép tính ngang và dọc đều thỏa mãn, giành trọn 3 Sao!',
        ),
      ],
      onPlay: (diff) {
        if (diff.id == 'hard') {
          _selectDifficulty(20);
        } else if (diff.id == 'medium') {
          _selectDifficulty(10);
        } else {
          _selectDifficulty(5);
        }
      },
    );
  }

  Widget _buildMathCrosswordPreviewBox({
    required String equation,
    required Color color,
  }) {
    final parts = equation.split(' ');
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'MINH HỌA: PHÉP TÍNH GIAO NHAU',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.calculate_rounded, size: 16, color: AppColors.primary),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: parts.map((token) {
            final isOp = token == '+' || token == '-' || token == '*' || token == '/' || token == 'x' || token == '=';
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isOp ? const Color(0xFFF1F5F9) : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isOp ? const Color(0xFFCBD5E1) : color,
                  width: 1.5,
                ),
              ),
              child: Text(
                token,
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isOp ? const Color(0xFF475569) : color,
                ),
              ),
            );
          }).toList(),
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
              const SizedBox(height: 24),
              MiniGameRankBanner(
                gameName: 'math_crossword_${_selectedDifficulty == 5 ? 'easy' : (_selectedDifficulty == 10 ? 'medium' : 'hard')}',
                gameTitle: 'Math Crossword',
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
