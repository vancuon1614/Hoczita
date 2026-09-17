import 'package:flutter/material.dart';
import 'package:hoczita_app/features/game/views/result_report_sheet.dart';
import 'package:hoczita_app/features/game/utils/game_rating_logic.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/constants/game_strings.dart';

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

typedef GridPos = CellPosition;

class _DifficultyRange {
  final int minMarkers, maxMarkers, minWalls, maxWalls;
  final int minGap; // MỚI - khoảng cách tối thiểu (số bước path) giữa 2 marker liên tiếp
  const _DifficultyRange({
    required this.minMarkers,
    required this.maxMarkers,
    required this.minWalls,
    required this.maxWalls,
    required this.minGap,
  });
}

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

class PathColorPalette {
  final String name;
  final Color startColor;
  final Color midColor;
  final Color endColor;
  final Color primaryColor;

  const PathColorPalette({
    required this.name,
    required this.startColor,
    required this.midColor,
    required this.endColor,
    required this.primaryColor,
  });
}

const List<PathColorPalette> _kPathPalettes = [
  // 1. Neon Purple - Magenta - Coral Red (Default)
  PathColorPalette(
    name: 'Purple-Red',
    startColor: Color(0xFF7B1FA2),
    midColor: Color(0xFFE91E63),
    endColor: Color(0xFFE53935),
    primaryColor: Color(0xFFE91E63),
  ),
  // 2. Electric Cyan - Royal Blue - Deep Violet
  PathColorPalette(
    name: 'Cyan-Blue',
    startColor: Color(0xFF00E5FF),
    midColor: Color(0xFF2979FF),
    endColor: Color(0xFF651FFF),
    primaryColor: Color(0xFF2979FF),
  ),
  // 3. Sunset Crimson - Orange - Golden Yellow
  PathColorPalette(
    name: 'Sunset-Gold',
    startColor: Color(0xFFFF1744),
    midColor: Color(0xFFFF6D00),
    endColor: Color(0xFFFFD600),
    primaryColor: Color(0xFFFF6D00),
  ),
  // 4. Emerald Green - Teal - Electric Mint
  PathColorPalette(
    name: 'Emerald-Mint',
    startColor: Color(0xFF00BFA5),
    midColor: Color(0xFF00C853),
    endColor: Color(0xFFAEEA00),
    primaryColor: Color(0xFF00BFA5),
  ),
  // 5. Electric Pink - Fuchsia - Deep Indigo
  PathColorPalette(
    name: 'Pink-Indigo',
    startColor: Color(0xFFFF4081),
    midColor: Color(0xFFD500F9),
    endColor: Color(0xFF3D5AFE),
    primaryColor: Color(0xFFD500F9),
  ),
  // 6. Amber Orange - Coral Pink - Deep Berry
  PathColorPalette(
    name: 'Amber-Berry',
    startColor: Color(0xFFFFAB00),
    midColor: Color(0xFFFF4081),
    endColor: Color(0xFF880E4F),
    primaryColor: Color(0xFFFF4081),
  ),
];

class _MagicNumberPathGameScreenState extends State<MagicNumberPathGameScreen> {
  bool _showHowToPlay = true;

  late List<List<GridCell>> _grid;
  final List<GridCell> _currentPath = [];
  int _rows = 5;
  int _cols = 5;
  int _maxCheckpoint = 0;
  int _openCellsCount = 0;
  PathColorPalette _currentPalette = _kPathPalettes[0];

  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isGameOver = false;
  int _undoCount = 0;
  int _hintCount = 0;
  
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
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isGameOver) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  static final Random _rand = Random();

  static const Map<int, _DifficultyRange> _ranges = {
    5: _DifficultyRange(minMarkers: 4, maxMarkers: 6, minWalls: 2, maxWalls: 4, minGap: 3),
    6: _DifficultyRange(minMarkers: 6, maxMarkers: 12, minWalls: 2, maxWalls: 14, minGap: 3),
    7: _DifficultyRange(minMarkers: 7, maxMarkers: 16, minWalls: 6, maxWalls: 18, minGap: 2),
    8: _DifficultyRange(minMarkers: 8, maxMarkers: 18, minWalls: 8, maxWalls: 20, minGap: 2),
  };

  static List<GridPos> _pickMarkers(List<GridPos> path, int count, int minGap) {
    final total = path.length;

    // Giới hạn lại count cho THỰC TẾ khả thi với minGap đã cho, tránh vòng lặp
    // chạy vô ích hoặc chọn thiếu marker so với dự kiến mà không ai biết
    final maxFeasible = (total / minGap).floor();
    final actualCount = count.clamp(2, maxFeasible);

    final chosen = <int>{0}; // luôn có ô đầu tiên = số 1

    final candidates = List<int>.generate(total, (i) => i)
      ..removeWhere((i) => i == 0 || i == total - 1)
      ..shuffle(_rand);

    for (final idx in candidates) {
      if (chosen.length >= actualCount - 1) break; // chừa 1 suất cho ô cuối
      bool farEnoughFromAll = chosen.every((c) => (idx - c).abs() >= minGap) &&
          (total - 1 - idx).abs() >= minGap;
      if (farEnoughFromAll) chosen.add(idx);
    }

    chosen.add(total - 1); // luôn có ô cuối = số lớn nhất
    final sorted = chosen.toList()..sort();
    return sorted.map((i) => path[i]).toList();
  }

  void _generatePuzzle() {
    int roll = _rand.nextInt(100);
    int size = 5;
    if (roll < 65) {
      size = 5; // 65%
    } else if (roll < 85) {
      size = 6; // 20%
    } else if (roll < 95) {
      size = 7; // 10%
    } else {
      size = 8; // 5%
    }

    _rows = size;
    _cols = size;
    _grid = List.generate(_rows, (r) => List.generate(_cols, (c) => GridCell(row: r, col: c)));
    _currentPalette = _kPathPalettes[_rand.nextInt(_kPathPalettes.length)];

    final range = _ranges[size] ?? _ranges[5]!;
    final wallCount = range.minWalls + _rand.nextInt(range.maxWalls - range.minWalls + 1);
    final markerCount = range.minMarkers + _rand.nextInt(range.maxMarkers - range.minMarkers + 1);

    List<CellPosition> walls = [];
    int targetLen = (_rows * _cols) - wallCount;
    List<CellPosition> path = _generateRandomPath(_rows, _cols, targetLen, _rand);

    // Mark walls
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        if (!path.any((p) => p.row == r && p.col == c)) {
          _grid[r][c].isWall = true;
          walls.add(CellPosition(r, c));
        }
      }
    }

    // Assign checkpoints with minGap constraint
    final markers = _pickMarkers(path, markerCount, range.minGap);

    for (int i = 0; i < markers.length; i++) {
      final pos = markers[i];
      _grid[pos.row][pos.col].checkpointNumber = i + 1;
    }

    _maxCheckpoint = markers.length;
    _openCellsCount = path.length;
    _currentPath.clear();
    _secondsElapsed = 0;
    _isGameOver = false;
    _undoCount = 0;
    _hintCount = 0;
  }

  // Warnsdorff-heuristic DFS to find a path covering targetLen quickly
  List<CellPosition> _generateRandomPath(int r, int c, int targetLen, Random rand) {
    List<CellPosition> bestPath = [];

    int countFreeNeighbors(int cr, int cc, List<List<bool>> visited) {
      int count = 0;
      for (var d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        int nr = cr + d[0];
        int nc = cc + d[1];
        if (nr >= 0 && nr < r && nc >= 0 && nc < c && !visited[nr][nc]) {
          count++;
        }
      }
      return count;
    }

    for (int attempt = 0; attempt < 50; attempt++) {
      List<CellPosition> path = [CellPosition(rand.nextInt(r), rand.nextInt(c))];
      List<List<bool>> visited = List.generate(r, (_) => List.generate(c, (_) => false));
      visited[path[0].row][path[0].col] = true;
      int steps = 0;

      void dfs(int cr, int cc) {
        if (++steps > 600) return;
        if (path.length > bestPath.length) {
          bestPath = List.from(path);
        }
        if (bestPath.length >= targetLen) return;

        List<CellPosition> candidates = [];
        for (var d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
          int nr = cr + d[0];
          int nc = cc + d[1];
          if (nr >= 0 && nr < r && nc >= 0 && nc < c && !visited[nr][nc]) {
            candidates.add(CellPosition(nr, nc));
          }
        }
        candidates.shuffle(rand);
        candidates.sort((a, b) => countFreeNeighbors(a.row, a.col, visited)
            .compareTo(countFreeNeighbors(b.row, b.col, visited)));

        for (var cand in candidates) {
          visited[cand.row][cand.col] = true;
          path.add(cand);
          dfs(cand.row, cand.col);
          if (bestPath.length >= targetLen) return;
          path.removeLast();
          visited[cand.row][cand.col] = false;
        }
      }

      dfs(path[0].row, path[0].col);
      if (bestPath.length >= targetLen) break;
    }

    return bestPath;
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

  void _checkWinCondition() async {
    // a) Path covers all open cells
    if (_currentPath.length != _openCellsCount) return;
    
    // b) Checkpoints are in order
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
    _timer?.cancel();
    setState(() {
      _isGameOver = true;
      });

    // Score logic for Zip
    int baseScore = 100;
    int score = baseScore - (_secondsElapsed * 2) - (_hintCount * 10) - (_undoCount * 2);
    if (score < 10) score = 10;
    
    int stars = 3;
    if (_secondsElapsed > 30) stars = 2;
    if (_secondsElapsed > 60) stars = 1;

    try {
      await SupabaseService.instance.saveScore(
        gameName: 'magic_number_path',
        stars: stars,
        score: score,
        durationSeconds: _secondsElapsed,
      );
    } catch (e) {
      debugPrint('Error saving magic_number_path score: $e');
    }
  }

  void _undo() {
    if (_currentPath.length > 1 && !_isGameOver) {
      setState(() {
        _undoCount++;
        _currentPath.removeLast();
      });
    }
  }

  void _replay() {
    setState(() {
      _generatePuzzle();
      _startTimer();
    });
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
    if (_isGameOver) {
      int stars = resolveZipStarRating(Duration(seconds: _secondsElapsed), Duration(seconds: _openCellsCount * 2), 0);
      return ResultReportSheet(
        gameType: GameType.zip,
        starCount: stars,
        elapsedTime: Duration(seconds: _secondsElapsed),
        showStars: false,
        onReplay: _replay,
        onGoHome: () {
          Navigator.of(context).pop();
        },
        accentColor: _currentPalette.primaryColor,
        customMiddleWidget: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 250),
          child: FittedBox(
            child: _buildGridWidget(readOnlyMode: true),
          ),
        ),
      );
    }
    
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
                'Đường Số Diệu Kỳ',
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
              GameStrings.reset,
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

  Widget _buildGridWidget({bool readOnlyMode = false}) {
    Widget content = Container(
      padding: readOnlyMode ? EdgeInsets.zero : const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: readOnlyMode ? Colors.transparent : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: readOnlyMode ? null : Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double size = constraints.maxWidth == double.infinity ? 300 : constraints.maxWidth;
          double cellWidth = size / _cols;
          double cellHeight = size / _rows;

          Widget boardContent = SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                // 1. Draw grid cells (background & walls) - only in game mode, NOT in report mode
                if (!readOnlyMode)
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

                      Color cellBg = Colors.transparent;
                      if (cell.isWall) {
                        cellBg = Colors.grey.shade300;
                      } else if (cell.checkpointNumber == 1) {
                        cellBg = const Color(0xFFBAE6FD); // Sky blue start cell highlight
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: cellBg,
                          border: Border.all(color: Colors.grey.shade200, width: 1),
                        ),
                      );
                    },
                  ),

                // 2. Draw Path Overlay (thick glossy gradient path)
                if (_currentPath.isNotEmpty)
                  IgnorePointer(
                    child: CustomPaint(
                      size: Size(size, size),
                      painter: ZipPathPainter(
                        path: _currentPath,
                        cellWidth: cellWidth,
                        cellHeight: cellHeight,
                        palette: _currentPalette,
                        isCompleted: _isGameOver || readOnlyMode,
                      ),
                    ),
                  ),

                // 3. Draw Checkpoints ON TOP of the Path
                ...[
                  for (int r = 0; r < _rows; r++)
                    for (int c = 0; c < _cols; c++)
                      if (_grid[r][c].checkpointNumber != null)
                        Positioned(
                          left: c * cellWidth,
                          top: r * cellHeight,
                          width: cellWidth,
                          height: cellHeight,
                          child: Center(
                            child: Container(
                              width: cellWidth * 0.62,
                              height: cellHeight * 0.62,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _grid[r][c].checkpointNumber.toString(),
                                style: GoogleFonts.baloo2(
                                  fontSize: (_grid[r][c].checkpointNumber ?? 0) >= 10
                                      ? cellWidth * 0.26
                                      : cellWidth * 0.32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                ],
              ],
            ),
          );

          if (readOnlyMode) {
            return boardContent;
          }

          return GestureDetector(
            onPanStart: (d) => _handlePanStart(d, BoxConstraints.tightFor(width: size, height: size)),
            onPanUpdate: (d) => _handlePanUpdate(d, BoxConstraints.tightFor(width: size, height: size)),
            child: boardContent,
          );
        },
      ),
    );

    if (readOnlyMode) {
      return IgnorePointer(child: content);
    }
    return content;
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
              GameStrings.undo,
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
              GameStrings.hint,
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
  final PathColorPalette palette;
  final bool isCompleted;

  ZipPathPainter({
    required this.path,
    required this.cellWidth,
    required this.cellHeight,
    required this.palette,
    this.isCompleted = false,
  });

  Color _getPathColor(double t) {
    if (t < 0.5) {
      return Color.lerp(palette.startColor, palette.midColor, t * 2)!;
    } else {
      return Color.lerp(palette.midColor, palette.endColor, (t - 0.5) * 2)!;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (path.isEmpty) return;

    double strokeW = min(cellWidth, cellHeight) * 0.55;

    if (path.length == 1) {
      double cx = path[0].col * cellWidth + cellWidth / 2;
      double cy = path[0].row * cellHeight + cellHeight / 2;
      canvas.drawCircle(
        Offset(cx, cy),
        strokeW / 2,
        Paint()..color = _getPathColor(0)..style = PaintingStyle.fill,
      );
      return;
    }

    // 1. Draw segment by segment with vibrant smooth gradient
    for (int i = 0; i < path.length - 1; i++) {
      double t1 = i / max(1, path.length - 1);
      double t2 = (i + 1) / max(1, path.length - 1);

      Color c1 = _getPathColor(t1);
      Color c2 = _getPathColor(t2);

      double x1 = path[i].col * cellWidth + cellWidth / 2;
      double y1 = path[i].row * cellHeight + cellHeight / 2;
      double x2 = path[i + 1].col * cellWidth + cellWidth / 2;
      double y2 = path[i + 1].row * cellHeight + cellHeight / 2;

      final segmentPaint = Paint()
        ..shader = LinearGradient(
          colors: [c1, c2],
        ).createShader(Rect.fromPoints(Offset(x1, y1), Offset(x2, y2)))
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), segmentPaint);
    }

    // 2. Draw circle joints at cell centers for round smooth corners (clean, no dots)
    for (int i = 0; i < path.length; i++) {
      double t = i / max(1, path.length - 1);
      Color c = _getPathColor(t);
      double cx = path[i].col * cellWidth + cellWidth / 2;
      double cy = path[i].row * cellHeight + cellHeight / 2;
      canvas.drawCircle(
        Offset(cx, cy),
        strokeW / 2,
        Paint()..color = c..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ZipPathPainter oldDelegate) {
    return oldDelegate.path != path ||
        oldDelegate.cellWidth != cellWidth ||
        oldDelegate.cellHeight != cellHeight ||
        oldDelegate.palette != palette ||
        oldDelegate.isCompleted != isCompleted;
  }
}
