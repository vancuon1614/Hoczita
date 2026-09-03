import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';
import '../../../core/theme/app_theme.dart';
import 'daily_checkin_report_dialog.dart'; // Re-use report dialog

class GridCell {
  final int row;
  final int col;
  int? checkpointNumber;
  bool isWall;

  GridCell({
    required this.row,
    required this.col,
    this.checkpointNumber,
    this.isWall = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridCell &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

class MagicNumberPathGameScreen extends StatefulWidget {
  const MagicNumberPathGameScreen({super.key});

  @override
  State<MagicNumberPathGameScreen> createState() => _MagicNumberPathGameScreenState();
}

class _MagicNumberPathGameScreenState extends State<MagicNumberPathGameScreen> {
  bool _showHowToPlay = true;

  late List<List<GridCell>> _grid;
  List<GridCell> _currentPath = [];
  int _rows = 5;
  int _cols = 5;
  int _maxCheckpoint = 0;
  int _openCellsCount = 0;

  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isGameOver = false;
  
  Offset? _lastLocalPosition;

  @override
  void initState() {
    super.initState();
    _generatePuzzle();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isGameOver) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  void _generatePuzzle() {
    // Generate a solvable puzzle with a Hamiltonian path.
    // For simplicity, we hardcode a sample puzzle here. In production, this should be an algorithm.
    // Let's create a 5x5 grid with some walls.
    _rows = 5;
    _cols = 5;
    _grid = List.generate(_rows, (r) => List.generate(_cols, (c) => GridCell(row: r, col: c)));

    // Define some walls
    _grid[1][1].isWall = true;
    _grid[3][3].isWall = true;
    _grid[1][3].isWall = true;
    _grid[3][1].isWall = true;

    // A valid path covering all open cells:
    // (0,0)->(0,1)->(0,2)->(0,3)->(0,4)->(1,4)->(2,4)->(3,4)->(4,4)
    // ->(4,3)->(4,2)->(4,1)->(4,0)->(3,0)->(2,0)->(1,0)
    // ->(2,1)->(2,2)->(1,2)->(2,3)->(3,2) -> wait, making a valid path dynamically is better or hardcode a known one.
    // Let's hardcode a known valid Hamiltonian path for 5x5 with those 4 walls:
    // (0,0)->(1,0)->(2,0)->(3,0)->(4,0)->(4,1)->(4,2)->(3,2)->(2,2)->(1,2)->(0,2)->(0,1)->(0,3)->(0,4)->(1,4)->(2,4)->(3,4)->(4,4)->(4,3)->(2,3) -> not adjacent.
    // Actually, creating a simple snake path is safest for a guaranteed puzzle:
    _grid = List.generate(_rows, (r) => List.generate(_cols, (c) => GridCell(row: r, col: c)));
    // No walls, pure snake:
    List<GridCell> path = [];
    for (int r = 0; r < _rows; r++) {
      if (r % 2 == 0) {
        for (int c = 0; c < _cols; c++) path.add(_grid[r][c]);
      } else {
        for (int c = _cols - 1; c >= 0; c--) path.add(_grid[r][c]);
      }
    }
    
    // Add checkpoints along this path
    path[0].checkpointNumber = 1;
    path[5].checkpointNumber = 2;
    path[12].checkpointNumber = 3;
    path[18].checkpointNumber = 4;
    path[24].checkpointNumber = 5;
    _maxCheckpoint = 5;
    
    // Add some visual walls that are not part of the path? Since snake covers 25 cells, no walls.
    // Let's modify grid to 5x5 with 1 wall at (2,2).
    // Path: 0,0 > 0,1 > 0,2 > 0,3 > 0,4 > 1,4 > 2,4 > 3,4 > 4,4 > 4,3 > 4,2 > 4,1 > 4,0 > 3,0 > 2,0 > 1,0 > 1,1 > 2,1 > 3,1 > 3,2 > 3,3 > 2,3 > 1,3 > 1,2
    _grid = List.generate(_rows, (r) => List.generate(_cols, (c) => GridCell(row: r, col: c)));
    _grid[2][2].isWall = true;
    
    _grid[0][0].checkpointNumber = 1;
    _grid[4][4].checkpointNumber = 2;
    _grid[1][1].checkpointNumber = 3;
    _grid[1][2].checkpointNumber = 4;
    _maxCheckpoint = 4;
    
    _openCellsCount = (_rows * _cols) - 1;
    _currentPath.clear();
    _secondsElapsed = 0;
    _isGameOver = false;
  }

  void _handlePanStart(DragStartDetails details, BoxConstraints constraints) {
    if (_isGameOver) return;
    _lastLocalPosition = details.localPosition;
    _hitTestCell(details.localPosition, constraints);
  }

  void _handlePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_isGameOver || _lastLocalPosition == null) return;

    double dx = details.localPosition.dx - _lastLocalPosition!.dx;
    double dy = details.localPosition.dy - _lastLocalPosition!.dy;

    // Anti-diagonal filter
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
      GridCell hovered = _grid[row][col];
      
      if (hovered.isWall) return;

      if (_currentPath.isEmpty) {
        if (hovered.checkpointNumber == 1) {
          setState(() {
            _currentPath.add(hovered);
          });
        }
      } else {
        GridCell last = _currentPath.last;
        
        // BACKTRACK: if dragging to the previous cell
        if (_currentPath.length >= 2 && _currentPath[_currentPath.length - 2] == hovered) {
          setState(() {
            _currentPath.removeLast();
          });
          return;
        }
        
        if (_currentPath.contains(hovered)) return; // Already in path but not a valid backtrack

        bool isAdjacent = (last.row == row && (last.col - col).abs() == 1) ||
                          (last.col == col && (last.row - row).abs() == 1);
        
        if (isAdjacent) {
          // Check if dragging to a checkpoint out of order
          if (!_validateCheckpointOrder(hovered)) {
            // Block move
            return;
          }
          
          setState(() {
            _currentPath.add(hovered);
          });
          
          _checkWinCondition();
        }
      }
    }
  }
  
  bool _validateCheckpointOrder(GridCell newCell) {
    if (newCell.checkpointNumber == null) return true; // Empty cell is fine
    
    // Find the max checkpoint we have visited so far in the current path
    int currentMaxCp = 0;
    for (var cell in _currentPath) {
      if (cell.checkpointNumber != null) {
        if (cell.checkpointNumber! > currentMaxCp) {
          currentMaxCp = cell.checkpointNumber!;
        }
      }
    }
    
    // The next checkpoint must be exactly currentMaxCp + 1
    if (newCell.checkpointNumber == currentMaxCp + 1) {
      return true;
    }
    
    return false;
  }

  void _checkWinCondition() {
    // a) Path covers all open cells
    if (_currentPath.length != _openCellsCount) return;
    
    // b) Checkpoints are in order (implicitly handled by _validateCheckpointOrder, but we double check)
    int cpExpected = 1;
    for (var cell in _currentPath) {
      if (cell.checkpointNumber != null) {
        if (cell.checkpointNumber != cpExpected) return;
        cpExpected++;
      }
    }
    
    // c) Last cell is K
    if (_currentPath.last.checkpointNumber != _maxCheckpoint) return;
    
    // WIN!
    setState(() {
      _isGameOver = true;
    });
    _timer?.cancel();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DailyCheckinReportDialog(
        foundPaths: _currentPath.length,
        pointsEarned: 20,
        currentStreak: 1, // Mock
        onPlayAgain: () {
          Navigator.pop(context);
          setState(() {
            _generatePuzzle();
          });
        },
        onGoHome: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _undo() {
    if (_currentPath.length > 1 && !_isGameOver) {
      setState(() {
        _currentPath.removeLast();
      });
    }
  }

  void _reset() {
    if (!_isGameOver) {
      setState(() {
        _currentPath.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    _buildGridWidget(),
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
                'Đường Số Diệu Kỳ 🔢',
                style: GoogleFonts.baloo2(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: _reset,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
            child: Text(
              'Đặt lại',
              style: GoogleFonts.baloo2(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildGridWidget() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double size = constraints.maxWidth;
          double cellWidth = size / _cols;
          double cellHeight = size / _rows;

          return GestureDetector(
            onPanStart: (d) => _handlePanStart(d, BoxConstraints.tightFor(width: size, height: size)),
            onPanUpdate: (d) => _handlePanUpdate(d, BoxConstraints.tightFor(width: size, height: size)),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                children: [
                  // Draw grid cells
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
                      GridCell cell = _grid[r][c];
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: cell.isWall ? Colors.grey.shade300 : Colors.transparent,
                          border: Border.all(color: Colors.grey.shade200, width: 1),
                        ),
                        alignment: Alignment.center,
                        child: cell.checkpointNumber != null
                            ? Container(
                                width: cellWidth * 0.6,
                                height: cellHeight * 0.6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0F172A),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  cell.checkpointNumber.toString(),
                                  style: GoogleFonts.baloo2(
                                    fontSize: cellWidth * 0.3,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                  
                  // Draw Path Overlay
                  if (_currentPath.isNotEmpty)
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size(size, size),
                        painter: ZipPathPainter(
                          path: _currentPath,
                          cellWidth: cellWidth,
                          cellHeight: cellHeight,
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

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _currentPath.length > 1 && !_isGameOver ? _undo : null,
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
                color: _currentPath.length > 1 && !_isGameOver ? AppColors.textPrimary : Colors.grey.shade500,
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
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildMiniCircle('1', Colors.purple),
                            Container(width: 12, height: 4, color: Colors.purple.withValues(alpha: 0.5)),
                            _buildMiniCircle('2', Colors.pink),
                            Container(width: 12, height: 4, color: Colors.pink.withValues(alpha: 0.5)),
                            _buildMiniCircle('3', Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Kết nối các số\ntheo thứ tự',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.grid_on_rounded, size: 40, color: Colors.pink.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'Điền kín tất cả\ncác ô trống',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCircle(String text, Color color) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.black87,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.baloo2(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class ZipPathPainter extends CustomPainter {
  final List<GridCell> path;
  final double cellWidth;
  final double cellHeight;

  ZipPathPainter({
    required this.path,
    required this.cellWidth,
    required this.cellHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (path.isEmpty) return;

    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.4)
      ..strokeWidth = min(cellWidth, cellHeight) * 0.4
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
    
    // Draw circles at cell centers for a unified trail look
    final circlePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
      
    for (int i = 0; i < path.length; i++) {
      double cx = path[i].col * cellWidth + cellWidth / 2;
      double cy = path[i].row * cellHeight + cellHeight / 2;
      canvas.drawCircle(Offset(cx, cy), min(cellWidth, cellHeight) * 0.2, circlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant ZipPathPainter oldDelegate) {
    return oldDelegate.path != path || 
           oldDelegate.cellWidth != cellWidth || 
           oldDelegate.cellHeight != cellHeight;
  }
}
