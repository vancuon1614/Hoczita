import 'dart:math';
import 'package:flutter/material.dart';
import '../models/queens_puzzle.dart';

class QueensColors {
  // 11 distinct pastel colors matching LinkedIn Queens / Star Battle style
  static const List<Color> palette = [
    Color(0xFFC5B4E3), // Pastel Purple (Tím nhạt)
    Color(0xFF93B7F4), // Pastel Sky Blue (Xanh dương)
    Color(0xFFB3DE9F), // Pastel Green (Xanh lá nhạt)
    Color(0xFFFA7D60), // Pastel Coral / Orange-Red (Cam san hô)
    Color(0xFFEBF18B), // Pastel Yellow (Vàng tươi)
    Color(0xFFAEA692), // Pastel Beige / Taupe (Be / Xám be)
    Color(0xFFDCDCDC), // Pastel Grey (Xám bạc)
    Color(0xFFDB9CB8), // Pastel Pink (Hồng phấn)
    Color(0xFFFFC68A), // Pastel Orange (Cam đào)
    Color(0xFFA8E6CF), // Pastel Mint (Xanh bạc hà)
    Color(0xFFD6A2E8), // Pastel Lavender (Tím hoa cà)
  ];

  static Color getRegionColor(int regionIndex) {
    return palette[regionIndex % palette.length];
  }
}

class QueensGenerator {
  /// Sinh ma trận Queens đồng nhất cho một ngày cụ thể
  static QueensPuzzle generateDailyPuzzle(DateTime date, {int? customSize}) {
    // Thứ 7 (6) hoặc Chủ nhật (7): 9x9 (hoặc customSize)
    // Ngày thường (1..5): 7x7
    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final size = customSize ?? (isWeekend ? 9 : 7);

    // Seed dựa trên ngày tháng năm để mọi người chơi đều nhận cùng 1 đề
    final seed = date.year * 10000 + date.month * 100 + date.day;
    return generate(size: size, date: date, seed: seed);
  }

  /// Sinh ma trận kích thước bất kỳ với seed cụ thể
  static QueensPuzzle generate({
    required int size,
    required DateTime date,
    required int seed,
  }) {
    final rand = Random(seed);

    // 1. Sinh vị trí N quân Queen hợp lệ (không chạm nhau kể cả đường chéo)
    final queens = _generateValidQueens(size, rand);

    // 2. Phát triển N vùng màu liên thông, mỗi vùng chứa đúng 1 Queen
    final regions = _generateRegions(size, queens, rand);

    return QueensPuzzle(
      size: size,
      date: date,
      solutionQueens: queens,
      regionMap: regions,
    );
  }

  static List<Point<int>> _generateValidQueens(int size, Random rand) {
    while (true) {
      final colOrder = List<int>.generate(size, (i) => i)..shuffle(rand);
      final placement = <int>[];
      if (_backtrackQueens(0, size, placement, colOrder, rand)) {
        final queens = <Point<int>>[];
        for (int r = 0; r < size; r++) {
          queens.add(Point(r, placement[r]));
        }
        return queens;
      }
    }
  }

  static bool _backtrackQueens(
    int row,
    int size,
    List<int> placement,
    List<int> colOrder,
    Random rand,
  ) {
    if (row == size) return true;

    final shuffledCols = List<int>.from(colOrder)..shuffle(rand);
    for (final col in shuffledCols) {
      if (placement.contains(col)) continue;
      // Không được chạm quân ở hàng liền trước (kể cả đường chéo)
      if (row > 0 && (col - placement[row - 1]).abs() <= 1) continue;

      placement.add(col);
      if (_backtrackQueens(row + 1, size, placement, colOrder, rand)) {
        return true;
      }
      placement.removeLast();
    }
    return false;
  }

  static List<List<int>> _generateRegions(
    int size,
    List<Point<int>> queens,
    Random rand,
  ) {
    final grid = List.generate(size, (_) => List.filled(size, -1));
    final regionCells = List.generate(size, (_) => <Point<int>>[]);

    // Đặt hạt giống cho mỗi vùng màu từ vị trí của Queen tương ứng
    for (int i = 0; i < size; i++) {
      final q = queens[i];
      grid[q.x][q.y] = i;
      regionCells[i].add(q);
    }

    final frontiers = List.generate(size, (_) => <Point<int>>[]);
    const deltas = [Point(-1, 0), Point(1, 0), Point(0, -1), Point(0, 1)];

    void addNeighborsToFrontier(int reg, Point<int> p) {
      for (final d in deltas) {
        final nr = p.x + d.x;
        final nc = p.y + d.y;
        if (nr >= 0 && nr < size && nc >= 0 && nc < size && grid[nr][nc] == -1) {
          final np = Point(nr, nc);
          if (!frontiers[reg].contains(np)) {
            frontiers[reg].add(np);
          }
        }
      }
    }

    for (int i = 0; i < size; i++) {
      addNeighborsToFrontier(i, queens[i]);
    }

    int remaining = size * size - size;

    while (remaining > 0) {
      int minSize = 999999;
      for (int i = 0; i < size; i++) {
        frontiers[i].removeWhere((p) => grid[p.x][p.y] != -1);
        if (frontiers[i].isNotEmpty && regionCells[i].length < minSize) {
          minSize = regionCells[i].length;
        }
      }

      final availableRegions = <int>[];
      for (int i = 0; i < size; i++) {
        if (frontiers[i].isNotEmpty) {
          if (regionCells[i].length <= minSize + (rand.nextBool() ? 1 : 0)) {
            availableRegions.add(i);
          }
        }
      }

      if (availableRegions.isEmpty) {
        // Fallback mở rộng bất kỳ ô trống nào còn sót lại
        bool assignedAny = false;
        for (int r = 0; r < size && !assignedAny; r++) {
          for (int c = 0; c < size && !assignedAny; c++) {
            if (grid[r][c] == -1) {
              for (final d in deltas) {
                final nr = r + d.x;
                final nc = c + d.y;
                if (nr >= 0 && nr < size && nc >= 0 && nc < size && grid[nr][nc] != -1) {
                  final reg = grid[nr][nc];
                  grid[r][c] = reg;
                  regionCells[reg].add(Point(r, c));
                  addNeighborsToFrontier(reg, Point(r, c));
                  remaining--;
                  assignedAny = true;
                  break;
                }
              }
            }
          }
        }
        if (!assignedAny) break;
        continue;
      }

      final chosenReg = availableRegions[rand.nextInt(availableRegions.length)];
      final cellIdx = rand.nextInt(frontiers[chosenReg].length);
      final cell = frontiers[chosenReg].removeAt(cellIdx);

      if (grid[cell.x][cell.y] == -1) {
        grid[cell.x][cell.y] = chosenReg;
        regionCells[chosenReg].add(cell);
        addNeighborsToFrontier(chosenReg, cell);
        remaining--;
      }
    }

    return grid;
  }
}
