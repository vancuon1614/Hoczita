import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import 'daily_checkin_report_dialog.dart';

class Cell {
  final int row;
  final int col;
  int value;
  bool matched;

  Cell(this.row, this.col, this.value, {this.matched = false});
}

enum Direction { up, down, left, right }

class DailyCheckinGameScreen extends StatefulWidget {
  const DailyCheckinGameScreen({super.key});

  @override
  State<DailyCheckinGameScreen> createState() => _DailyCheckinGameScreenState();
}

class _DailyCheckinGameScreenState extends State<DailyCheckinGameScreen> {
  late int _targetSum;
  List<List<Cell>> _grid = [];
  List<Cell> _path = [];
  int _score = 0;
  
  Timer? _timer;
  int _timeLeft = 88; // 1:28
  
  bool _isRefilling = false;
  bool _isWrong = false;

  final Random _random = Random();
  final int _rows = 4;
  final int _cols = 4;

  @override
  void initState() {
    super.initState();
    _targetSum = _random.nextInt(28 - 12 + 1) + 12; // [12, 28]
    _generateSolvableGrid();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        _onTimeUp();
      }
    });
  }

  void _onTimeUp() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const DailyCheckinReportDialog(),
    );
  }

  void _generateSolvableGrid() {
    while (true) {
      _grid = List.generate(_rows, (r) => List.generate(_cols, (c) => Cell(r, c, _random.nextInt(9) + 1)));
      if (_hasValidPath()) {
        break;
      }
    }
  }

  bool _hasValidPath() {
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        Set<String> visited = {};
        if (_dfs(r, c, 0, visited)) return true;
      }
    }
    return false;
  }

  bool _dfs(int r, int c, int currentSum, Set<String> visited) {
    if (r < 0 || r >= _rows || c < 0 || c >= _cols) return false;
    String key = '$r,$c';
    if (visited.contains(key)) return false;

    currentSum += _grid[r][c].value;
    if (currentSum == _targetSum) return true;
    if (currentSum > _targetSum) return false;

    visited.add(key);
    
    // Check neighbors
    if (_dfs(r - 1, c, currentSum, visited)) return true;
    if (_dfs(r + 1, c, currentSum, visited)) return true;
    if (_dfs(r, c - 1, currentSum, visited)) return true;
    if (_dfs(r, c + 1, currentSum, visited)) return true;

    visited.remove(key);
    return false;
  }

  Offset? _lastLocalPosition;

  void _handlePanStart(DragStartDetails details, BoxConstraints constraints) {
    if (_isRefilling || _isWrong) return;
    _lastLocalPosition = details.localPosition;
    _hitTestCell(details.localPosition, constraints);
  }

  void _handlePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_isRefilling || _isWrong || _lastLocalPosition == null) return;

    double dx = details.localPosition.dx - _lastLocalPosition!.dx;
    double dy = details.localPosition.dy - _lastLocalPosition!.dy;

    // Check diagonal gesture like the requirement
    if (dx.abs() > dy.abs()) {
      if (dy.abs() / dx.abs() > 0.4) return; // ignore diagonal
    } else {
      if (dy.abs() == 0 || dx.abs() / dy.abs() > 0.4) return; // ignore diagonal
    }

    _lastLocalPosition = details.localPosition;
    _hitTestCell(details.localPosition, constraints);
  }

  void _hitTestCell(Offset localPosition, [BoxConstraints? constraints]) {
    double cellWidth = constraints?.maxWidth != null ? constraints!.maxWidth / _cols : localPosition.dx / _cols; // simple fallback
    if (constraints != null) {
      cellWidth = constraints.maxWidth / _cols;
    } else {
      // If no constraints, we can't reliably calculate width, but this is handled by LayoutBuilder
      return;
    }
    double cellHeight = constraints.maxHeight / _rows;

    int col = (localPosition.dx / cellWidth).floor();
    int row = (localPosition.dy / cellHeight).floor();

    if (row >= 0 && row < _rows && col >= 0 && col < _cols) {
      Cell hovered = _grid[row][col];
      
      if (_path.isEmpty) {
        setState(() => _path.add(hovered));
      } else {
        Cell last = _path.last;
        if (_path.contains(hovered)) return; // no popping backward

        // strictly adjacent (no diagonals)
        bool isAdjacent = (last.row == row && (last.col - col).abs() == 1) ||
                          (last.col == col && (last.row - row).abs() == 1);
        
        if (isAdjacent) {
          setState(() {
            _path.add(hovered);
          });
        }
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_path.isEmpty || _isRefilling || _isWrong) return;

    int sum = _path.fold(0, (prev, cell) => prev + cell.value);

    if (sum == _targetSum) {
      _processMatch();
    } else {
      _processWrong();
    }
  }

  void _processWrong() async {
    setState(() {
      _isWrong = true;
    });
    // Vibrate/red effect
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _isWrong = false;
        _path.clear();
      });
    }
  }

  void _processMatch() async {
    setState(() {
      _isRefilling = true;
      for (var c in _path) {
        c.matched = true;
      }
    });

    await Future.delayed(const Duration(milliseconds: 300)); // wait for fade out
    
    setState(() {
      // Gravity refill by column
      for (int c = 0; c < _cols; c++) {
        List<Cell> remaining = [];
        for (int r = 0; r < _rows; r++) {
          if (!_grid[r][c].matched) {
            remaining.add(_grid[r][c]);
          }
        }

        int missing = _rows - remaining.length;
        
        // Fill top with new
        List<Cell> newCol = [];
        for (int i = 0; i < missing; i++) {
          newCol.add(Cell(i, c, _random.nextInt(9) + 1));
        }
        
        // Shift old down
        for (int i = 0; i < remaining.length; i++) {
          Cell cell = remaining[i];
          newCol.add(Cell(missing + i, c, cell.value));
        }

        for (int r = 0; r < _rows; r++) {
          _grid[r][c] = newCol[r];
        }
      }
      
      _path.clear();
      _score++;
      _isRefilling = false;
    });

    // If board becomes unsolvable, we could just randomly replace a cell until it is.
    // For simplicity, we just generate a whole new board if it's completely stuck.
    if (!_hasValidPath()) {
      _generateSolvableGrid();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            const SizedBox(height: 20),
            _buildTargetInstruction(),
            const SizedBox(height: 40),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double size = min(constraints.maxWidth, constraints.maxHeight);
                    return Center(
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: GestureDetector(
                          onPanStart: (d) => _handlePanStart(d, BoxConstraints.tightFor(width: size, height: size)),
                          onPanUpdate: (d) => _handlePanUpdate(d, BoxConstraints.tightFor(width: size, height: size)),
                          onPanEnd: _handlePanEnd,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Cells
                              for (int r = 0; r < _rows; r++)
                                for (int c = 0; c < _cols; c++)
                                  _buildCellWidget(_grid[r][c], size / _cols),
                              
                              // Path overlay
                              if (_path.isNotEmpty)
                                CustomPaint(
                                  size: Size(size, size),
                                  painter: PathPainter(
                                    path: _path,
                                    cellSize: size / _cols,
                                    isWrong: _isWrong,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCellWidget(Cell cell, double cellSize) {
    bool inPath = _path.contains(cell);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.bounceOut,
      left: cell.col * cellSize,
      top: cell.row * cellSize,
      width: cellSize,
      height: cellSize,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: cell.matched ? 0.0 : 1.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: cell.matched ? 0.0 : 1.0,
          child: Padding(
            padding: EdgeInsets.all(cellSize * 0.1),
            child: Container(
              decoration: BoxDecoration(
                color: inPath ? (_isWrong ? AppColors.error : AppColors.primary) : AppColors.primaryLight.withOpacity(0.5),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(2, 4), // outer shadow
                  ),
                ],
                border: Border.all(
                  color: inPath ? Colors.white : AppColors.primaryLight,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${cell.value}',
                style: GoogleFonts.baloo2(
                  fontSize: cellSize * 0.4,
                  fontWeight: FontWeight.bold,
                  color: inPath ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetInstruction() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.baloo2(
            fontSize: 22,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          children: [
            const TextSpan(text: 'Tìm các cách nối số để tạo tổng là '),
            TextSpan(
              text: '$_targetSum',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    int mins = _timeLeft ~/ 60;
    int secs = _timeLeft % 60;
    String timeStr = '$mins:${secs.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          Row(
            children: [
              _buildBadge(Icons.account_tree_rounded, '$_score', AppColors.primary),
              const SizedBox(width: 12),
              _buildBadge(Icons.timer_rounded, timeStr, AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.baloo2(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class PathPainter extends CustomPainter {
  final List<Cell> path;
  final double cellSize;
  final bool isWrong;

  PathPainter({required this.path, required this.cellSize, required this.isWrong});

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;

    final paint = Paint()
      ..color = isWrong ? AppColors.error : AppColors.primary
      ..strokeWidth = cellSize * 0.15
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final pathObj = Path();
    for (int i = 0; i < path.length; i++) {
      double cx = path[i].col * cellSize + cellSize / 2;
      double cy = path[i].row * cellSize + cellSize / 2;
      if (i == 0) {
        pathObj.moveTo(cx, cy);
      } else {
        pathObj.lineTo(cx, cy);
      }
    }

    canvas.drawPath(pathObj, paint);
  }

  @override
  bool shouldRepaint(covariant PathPainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.isWrong != isWrong;
  }
}
