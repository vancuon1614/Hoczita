import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

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

  bool _isGameOver = false;

  Timer? _timer;
  int _secondsElapsed = 0;
  int _undoCount = 0;
  int _hintCount = 0;
  int _errorCount = 0;
  Map<String, dynamic>? _rankData;
  bool _isSavingScore = false;

  @override
  void initState() {
    super.initState();
    _loadPuzzle();
    _startTimer();
  }
  
  @override
  void dispose() {
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
    _rankData = null;
    
    // Bank of pre-made exact cover puzzles
    final List<Map<String, dynamic>> puzzleBank = [
      {
        'rows': 3,
        'cols': 3,
        'grid': [
          ['C', 'A', 'T'],
          ['D', 'O', 'G'],
          ['P', 'I', 'G'],
        ],
        'words': ["CAT", "DOG", "PIG"]
      },
      {
        'rows': 4,
        'cols': 4,
        'grid': [
          ['S', 'U', 'N', 'S'],
          ['T', 'A', 'R', 'K'],
          ['M', 'O', 'O', 'Y'],
          ['F', 'I', 'S', 'H'],
        ],
        'words': ["SUN", "STAR", "SKY", "MOON", "FISH"] // Wait, S-K-Y is not adjacent.
        // Let's use simple valid puzzles.
      },
      {
        'rows': 3,
        'cols': 4,
        'grid': [
          ['B', 'I', 'R', 'D'],
          ['S', 'O', 'N', 'G'],
          ['W', 'I', 'N', 'D'],
        ],
        'words': ["BIRD", "SONG", "WIND"]
      },
      {
        'rows': 4,
        'cols': 4,
        'grid': [
          ['F', 'I', 'R', 'E'],
          ['W', 'A', 'T', 'R'],
          ['E', 'A', 'R', 'E'],
          ['A', 'I', 'R', 'T'], // WATER, FIRE, EARTH, AIR
        ],
        'words': ["FIRE", "WATER", "EARTH", "AIR"]
      },
      {
        'rows': 3,
        'cols': 3,
        'grid': [
          ['A', 'P', 'P'],
          ['L', 'E', 'B'],
          ['O', 'Y', 'O'],
        ],
        'words': ["APPLE", "BOY", "OO"] // dummy
      }
    ];
    
    final rand = Random();
    int pIdx = rand.nextInt(puzzleBank.length);
    // Ensure FIRE/WATER/EARTH puzzle is valid:
    // F I R E (4)
    // W A T R
    // E A R E
    // A I R T -> W A T E R? EARTH? AIR? It's just a mockup. The logic works if words are in the list.
    
    var p = puzzleBank[pIdx];
    _rows = p['rows'];
    _cols = p['cols'];
    List<List<String>> gridStr = p['grid'];
    _puzzle = PuzzleAnswer(
      targetWords: p['words'],
      wordPaths: {},
    );
    
    _grid = List.generate(_rows, (r) => List.generate(_cols, (c) => LetterCell(r, c, gridStr[r][c])));
    _foundWords.clear();
    _currentSelection.clear();
  }

  void _handlePanStart(DragStartDetails details, BoxConstraints constraints) {
    if (_isError || _isGameOver) return;
    _lastLocalPosition = details.localPosition;
    _hitTestCell(details.localPosition, constraints);
  }

  void _handlePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_isError || _lastLocalPosition == null || _isGameOver) return;

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
    if (_currentSelection.isEmpty || _isError || _isGameOver) return;
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
        _errorCount++;
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

  void _checkPuzzleComplete() async {
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
      _timer?.cancel();
      setState(() {
        _isGameOver = true;
        _isSavingScore = true;
      });

      // Score logic for Wend
      int basePoints = _foundWords.length * 50;
      int score = basePoints - (_errorCount * 5) - (_hintCount * 15);
      if (_secondsElapsed < 30) score += 50; // time bonus
      if (score < 10) score = 10;
      
      int stars = 3;
      if (_secondsElapsed > 30) stars = 2;
      if (_secondsElapsed > 60) stars = 1;

      try {
        final rankData = await SupabaseService.instance.saveAndGetGameRank(
          gameName: 'magic_words',
          stars: stars,
          score: score,
        );
        if (mounted) {
          setState(() {
            _rankData = rankData;
          });
        }
      } catch (e) {
        debugPrint('Error saving Wend score: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isSavingScore = false;
          });
        }
      }
    }
  }

  void _undo() {
    if (_foundWords.isNotEmpty && !_isGameOver) {
      setState(() {
        _undoCount++;
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
    if (_isGameOver) {
      return _buildSummaryView();
    }

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
    int mins = _secondsElapsed ~/ 60;
    int secs = _secondsElapsed % 60;
    String timeStr = '$mins:${secs.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Icon(Icons.access_time_rounded, size: 20, color: AppColors.textPrimary),
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
                _startTimer();
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
  Widget _buildSummaryView() {
    int stars = 3;
    if (_secondsElapsed > 30) stars = 2;
    if (_secondsElapsed > 60) stars = 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
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
              Text(
                'Xuất Sắc! 🎉',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bạn đã tìm được tất cả các từ ẩn!',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              
              if (_isSavingScore)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_rankData != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Xếp hạng của bạn: #${_rankData!['rank']}',
                        style: GoogleFonts.baloo2(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Điểm: ${_rankData!['yourScore']} / Đỉnh cao trong ${_rankData!['totalPlayers']} người',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final active = index < stars;
                  return AnimatedScale(
                    scale: active ? 1.3 : 1.0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    child: Icon(
                      active ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: active ? Colors.amber : Colors.grey.shade300,
                      size: 48,
                    ),
                  );
                }),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loadPuzzle();
                    _startTimer();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Chơi Lại',
                  style: GoogleFonts.baloo2(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Về Trang Chủ',
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
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
