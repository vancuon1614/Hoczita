import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../../../core/theme/app_theme.dart';
import 'daily_checkin_report_dialog.dart';

class CellPosition {
  final int row;
  final int col;
  const CellPosition(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellPosition &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

class LetterCell {
  final int row;
  final int col;
  final String letter;
  String? lockedWordId; // If null, it's not locked. If locked, stores the word string or ID.
  Color? lockedColor;

  LetterCell(this.row, this.col, this.letter);
}

class PuzzleAnswer {
  final List<String> targetWords;
  final Map<String, List<CellPosition>> wordPaths;

  PuzzleAnswer({required this.targetWords, required this.wordPaths});
}

class MagicWordsGameScreen extends StatefulWidget {
  const MagicWordsGameScreen({super.key});

  @override
  State<MagicWordsGameScreen> createState() => _MagicWordsGameScreenState();
}

class _MagicWordsGameScreenState extends State<MagicWordsGameScreen> {
  bool _showHowToPlay = true;

  late List<List<LetterCell?>> _grid; // null means empty space (wall)
  late PuzzleAnswer _puzzle;
  
  List<LetterCell> _currentSelection = [];
  List<String> _foundWords = [];
  
  int _rows = 5;
  int _cols = 5;

  // Colors for locked words
  final List<Color> _wordColors = [
    Colors.red.shade400,
    Colors.blue.shade400,
    Colors.green.shade400,
    Colors.orange.shade400,
    Colors.purple.shade400,
    Colors.teal.shade400,
  ];
  
  Offset? _lastLocalPosition;
  bool _isError = false; // For red flash on wrong word

  @override
  void initState() {
    super.initState();
    _loadPuzzle();
  }

  void _loadPuzzle() {
    // Hardcoded puzzle for demonstration.
    // Let's create a small exact cover puzzle.
    // Grid:
    // C A T
    // O B S
    // W G O
    // Target words: CAT, DOG, COWS (wait: C-O-W-S? O-B-S -> B is extra)
    // Let's make a real 3x3 exact cover:
    // S U N
    // H O T
    // D O G
    // Words: SUN, HOT, DOG.
    
    _rows = 5;
    _cols = 5;
    
    // A classic wordbrain style puzzle
    // L E . U R
    // . F T N .
    // . H T H .
    // . T G G .
    // L E N I R
    
    final List<List<String>> gridData = [
      ['L', 'E', '', 'U', 'R'],
      ['', 'F', 'T', 'N', ''],
      ['', 'H', 'T', 'H', ''],
      ['', 'T', 'G', 'G', ''],
      ['L', 'E', 'N', 'I', 'R'],
    ];
    
    _grid = List.generate(_rows, (r) => List.generate(_cols, (c) {
      if (gridData[r][c].isEmpty) return null;
      return LetterCell(r, c, gridData[r][c]);
    }));

    // Expected words: LEFT, RIGHT, THING, LUNG, THEREN?
    // Let's just define a simple valid exact cover for testing.
    // L E U R
    // F T N 
    // H T H
    // T G G
    // L E N I R
    // To avoid logic errors with my fake puzzle, I'll allow "LEFT", "RIGHT", "THEN", "GUNG" etc., 
    // but honestly any exact cover puzzle will do. Let's make the targets simple.
    
    _puzzle = PuzzleAnswer(
      targetWords: ["LEFT", "RIGHT", "THING", "LUNG", "HERO"], // just mocking
      wordPaths: {
        "LEFT": [const CellPosition(0,0), const CellPosition(0,1), const CellPosition(1,1), const CellPosition(2,1)],
      },
    );
    
    // Actually, let's redefine the puzzle to be perfectly solvable:
    // 3x3 grid
    // C A T
    // D O G
    // P I G
    _rows = 3;
    _cols = 3;
    final List<List<String>> simpleGrid = [
      ['C', 'A', 'T'],
      ['D', 'O', 'G'],
      ['P', 'I', 'G'],
    ];
    _grid = List.generate(_rows, (r) => List.generate(_cols, (c) => LetterCell(r, c, simpleGrid[r][c])));
    _puzzle = PuzzleAnswer(
      targetWords: ["CAT", "DOG", "PIG"],
      wordPaths: {},
    );
    
    _foundWords.clear();
    _currentSelection.clear();
  }

  void _handlePanStart(DragStartDetails details, BoxConstraints constraints) {
    if (_isError) return;
    _lastLocalPosition = details.localPosition;
    _hitTestCell(details.localPosition, constraints);
  }

  void _handlePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_isError || _lastLocalPosition == null) return;

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
    double cellWidth = constraints.maxWidth / _cols;
    double cellHeight = constraints.maxHeight / _rows;

    int col = (localPosition.dx / cellWidth).floor();
    int row = (localPosition.dy / cellHeight).floor();

    if (row >= 0 && row < _rows && col >= 0 && col < _cols) {
      LetterCell? hovered = _grid[row][col];
      
      if (hovered == null) return; // Wall
      if (hovered.lockedWordId != null) return; // Already locked

      if (_currentSelection.isEmpty) {
        setState(() => _currentSelection.add(hovered));
      } else {
        LetterCell last = _currentSelection.last;
        
        // Allow backtracking (removing last letter)
        if (_currentSelection.length >= 2 && _currentSelection[_currentSelection.length - 2] == hovered) {
          setState(() {
            _currentSelection.removeLast();
          });
          return;
        }

        if (_currentSelection.contains(hovered)) return;

        bool isAdjacent = (last.row == row && (last.col - col).abs() == 1) ||
                          (last.col == col && (last.row - row).abs() == 1);
        
        if (isAdjacent) {
          setState(() {
            _currentSelection.add(hovered);
          });
        }
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_currentSelection.isEmpty || _isError) return;
    _validateSelection();
  }

  void _validateSelection() async {
    String wordForwards = _currentSelection.map((c) => c.letter).join('').toUpperCase();
    String wordBackwards = wordForwards.split('').reversed.join('');

    String? matchedWord;
    
    // Check forwards and backwards against remaining words
    for (String target in _puzzle.targetWords) {
      if (!_foundWords.contains(target)) {
        if (wordForwards == target.toUpperCase() || wordBackwards == target.toUpperCase()) {
          matchedWord = target;
          break;
        }
      }
    }

    if (matchedWord != null) {
      // Success
      setState(() {
        _foundWords.add(matchedWord!);
        Color c = _wordColors[(_foundWords.length - 1) % _wordColors.length];
        for (var cell in _currentSelection) {
          cell.lockedWordId = matchedWord;
          cell.lockedColor = c;
        }
        _currentSelection.clear();
      });
      _checkPuzzleComplete();
    } else {
      // Fail
      setState(() {
        _isError = true;
      });
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _isError = false;
          _currentSelection.clear();
        });
      }
    }
  }

  void _checkPuzzleComplete() {
    int totalLetters = 0;
    int lockedLetters = 0;
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        if (_grid[r][c] != null) {
          totalLetters++;
          if (_grid[r][c]!.lockedWordId != null) {
            lockedLetters++;
          }
        }
      }
    }

    if (lockedLetters == totalLetters && _foundWords.length == _puzzle.targetWords.length) {
      // WIN
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => DailyCheckinReportDialog(
          foundPaths: _foundWords.length,
          pointsEarned: 30,
          currentStreak: 1,
          onPlayAgain: () {
            Navigator.pop(context);
            setState(() {
              _loadPuzzle();
            });
          },
          onGoHome: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
        ),
      );
    }
  }

  void _undo() {
    if (_foundWords.isNotEmpty) {
      setState(() {
        String lastWord = _foundWords.removeLast();
        for (int r = 0; r < _rows; r++) {
          for (int c = 0; c < _cols; c++) {
            if (_grid[r][c]?.lockedWordId == lastWord) {
              _grid[r][c]!.lockedWordId = null;
              _grid[r][c]!.lockedColor = null;
            }
          }
        }
        _currentSelection.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool showAlmostThere = _foundWords.isNotEmpty && _foundWords.length < _puzzle.targetWords.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            if (showAlmostThere)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.orange.shade100,
                child: Text(
                  "Almost there! You haven't found all the correct hidden words.",
                  style: GoogleFonts.nunito(color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    _buildGridWidget(),
                    const SizedBox(height: 24),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Magic Words 🔤',
                style: GoogleFonts.baloo2(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () {
              setState(() {
                _loadPuzzle();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGridWidget() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double size = constraints.maxWidth;
          double cellWidth = size / _cols;
          double cellHeight = size / _rows;

          return GestureDetector(
            onPanStart: (d) => _handlePanStart(d, BoxConstraints.tightFor(width: size, height: size)),
            onPanUpdate: (d) => _handlePanUpdate(d, BoxConstraints.tightFor(width: size, height: size)),
            onPanEnd: _handlePanEnd,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _cols,
                      childAspectRatio: cellWidth / cellHeight,
                    ),
                    itemCount: _rows * _cols,
                    itemBuilder: (context, index) {
                      int r = index ~/ _cols;
                      int c = index % _cols;
                      LetterCell? cell = _grid[r][c];
                      
                      if (cell == null) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }
                      
                      bool isSelected = _currentSelection.contains(cell);
                      Color bgColor = Colors.white;
                      if (cell.lockedColor != null) {
                        bgColor = cell.lockedColor!.withValues(alpha: 0.3);
                      } else if (isSelected) {
                        bgColor = _isError ? AppColors.error.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.3);
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
                  
                  // Draw Selection Path
                  if (_currentSelection.isNotEmpty)
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size(size, size),
                        painter: WendPathPainter(
                          path: _currentSelection,
                          cellWidth: cellWidth,
                          cellHeight: cellHeight,
                          pathColor: _isError ? AppColors.error : AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWordHints() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _puzzle.targetWords.map((word) {
        bool isFound = _foundWords.contains(word);
        Color wordColor = isFound 
            ? _wordColors[_foundWords.indexOf(word) % _wordColors.length] 
            : Colors.grey.shade300;
            
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              ...word.split('').map((char) => Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: isFound ? wordColor.withValues(alpha: 0.3) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isFound ? wordColor : Colors.grey.shade300),
                ),
                alignment: Alignment.center,
                child: Text(
                  isFound ? char : '',
                  style: GoogleFonts.baloo2(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              )),
              if (isFound)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.check_circle_rounded, color: wordColor, size: 24),
                )
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _foundWords.isNotEmpty ? _undo : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade300,
              disabledBackgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Hoàn Tác',
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _foundWords.isNotEmpty ? AppColors.textPrimary : Colors.grey.shade500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppColors.primary, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Gợi Ý 💡',
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
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
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
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

  WendPathPainter({
    required this.path,
    required this.cellWidth,
    required this.cellHeight,
    required this.pathColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;

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

    canvas.drawPath(drawPath, paint);
  }

  @override
  bool shouldRepaint(covariant WendPathPainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.pathColor != pathColor;
  }
}
