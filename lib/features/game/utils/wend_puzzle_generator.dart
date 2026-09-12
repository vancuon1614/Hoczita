import 'dart:math';
import 'package:flutter/material.dart';

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

class PuzzleAnswer {
  final List<String> targetWords;
  final Map<String, List<CellPosition>> wordPaths;
  final List<Color> wordColors;
  final int rows;
  final int cols;
  final List<List<String?>> gridStr; // null for obstacle

  PuzzleAnswer({
    required this.targetWords,
    required this.wordPaths,
    required this.wordColors,
    required this.rows,
    required this.cols,
    required this.gridStr,
  });
}

class WendPuzzleGenerator {
  static const List<String> _wordBank = [
    // 3 letters
    "CAT",
    "DOG",
    "SUN",
    "SKY",
    "FOX",
    "OWL",
    "BAT",
    "ANT",
    "PIG",
    "COW",
    "ICE",
    "SEA",
    // 4 letters
    "BIRD",
    "FISH",
    "WOLF",
    "BEAR",
    "MOON",
    "STAR",
    "WIND",
    "RAIN",
    "SNOW",
    "FIRE",
    "TREE",
    "WOOD",
    "ROCK",
    "SAND",
    "DIRT",
    "GOLD",
    "BLUE",
    "PINK",
    "GREY",
    // 5 letters
    "APPLE",
    "GRAPE",
    "MANGO",
    "LEMON",
    "WATER",
    "EARTH",
    "BLACK",
    "WHITE",
    "GREEN",
    "TIGER",
    "SNAKE",
    "MOUSE",
    // 6 letters
    "RABBIT", "MONKEY", "BANANA", "ORANGE", "YELLOW", "PURPLE",
    // 7 letters
    "ELEPHANT", "GIRAFFE", "DOLPHIN", "PENGUIN",
  ];

  static PuzzleAnswer generate() {
    Map<int, List<String>> wordsByLength = {};
    for (String w in _wordBank) {
      wordsByLength.putIfAbsent(w.length, () => []).add(w);
    }

    Random rand = Random();
    int retries = 0;

    while (retries < 300) {
      retries++;

      int n = rand.nextInt(4) + 5; // 5 to 8
      int rows = n;
      int cols = n;
      int totalCells = rows * cols;

      int maxWords = min(6, totalCells ~/ 4);
      if (maxWords < 3) maxWords = 3;
      int wordCount = rand.nextInt(maxWords - 2) + 3; // min 3

      List<int> chosenLengths = [];
      int openCellsNeeded = 0;
      int obstacleCount = -1;

      int lengthRetries = 0;
      List<int> availableLengths = wordsByLength.keys.toList();
      while (lengthRetries < 50) {
        lengthRetries++;
        chosenLengths.clear();
        openCellsNeeded = 0;
        Map<int, int> usedCount = {};
        bool failed = false;

        for (int i = 0; i < wordCount; i++) {
          int len = availableLengths[rand.nextInt(availableLengths.length)];
          int used = usedCount[len] ?? 0;
          if (used >= wordsByLength[len]!.length) {
            failed = true;
            break;
          }
          usedCount[len] = used + 1;
          chosenLengths.add(len);
          openCellsNeeded += len;
        }
        if (failed) continue;

        obstacleCount = totalCells - openCellsNeeded;
        // Require at least 3 obstacles, up to 35% of the grid
        if (obstacleCount >= 3 && obstacleCount <= totalCells * 0.35) {
          break;
        }
      }

      if (obstacleCount < 3 || obstacleCount > totalCells * 0.35) continue;

      List<CellPosition> obstacles = _generateObstacles(
        rows,
        cols,
        obstacleCount,
        rand,
      );
      if (!_isConnected(rows, cols, obstacles, openCellsNeeded)) continue;

      List<CellPosition>? path = _findSnakePath(
        rows,
        cols,
        obstacles,
        openCellsNeeded,
        chosenLengths,
      );
      if (path == null) continue;

      List<String> targetWords = [];
      bool duplicationFailed = false;
      for (int len in chosenLengths) {
        List<String> pool = wordsByLength[len]!;
        String w = '';
        int safety = 0;
        do {
          w = pool[rand.nextInt(pool.length)];
          safety++;
        } while (targetWords.contains(w) && safety < 50);
        
        if (targetWords.contains(w)) {
          duplicationFailed = true;
          break;
        }
        targetWords.add(w);
      }
      
      if (duplicationFailed) continue;

      List<List<String?>> gridStr = List.generate(
        rows,
        (r) => List.generate(cols, (c) => null),
      );
      Map<String, List<CellPosition>> wordPaths = {};

      int pathIdx = 0;
      for (int i = 0; i < targetWords.length; i++) {
        String w = targetWords[i];
        List<CellPosition> wPath = [];
        for (int j = 0; j < w.length; j++) {
          CellPosition cp = path[pathIdx];
          gridStr[cp.row][cp.col] = w[j];
          wPath.add(cp);
          pathIdx++;
        }
        wordPaths[w] = wPath;
      }

      return PuzzleAnswer(
        targetWords: targetWords,
        wordPaths: wordPaths,
        wordColors: _generateColors(targetWords.length, rand),
        rows: rows,
        cols: cols,
        gridStr: gridStr,
      );
    }

    // Fallback if 300 retries fail (should rarely happen)
    return PuzzleAnswer(
      targetWords: ["CAT", "DOG", "PIG"],
      wordPaths: {
        "CAT": [
          const CellPosition(0, 0),
          const CellPosition(0, 1),
          const CellPosition(1, 1),
        ],
        "DOG": [
          const CellPosition(1, 0),
          const CellPosition(2, 0),
          const CellPosition(2, 1),
        ],
        "PIG": [
          const CellPosition(0, 2),
          const CellPosition(1, 2),
          const CellPosition(2, 2),
        ],
      },
      wordColors: [Colors.blue, Colors.green, Colors.purple],
      rows: 3,
      cols: 3,
      gridStr: [
        ['C', 'A', 'P'],
        ['D', 'T', 'I'],
        ['O', 'G', 'G'],
      ],
    );
  }

  static List<CellPosition> _generateObstacles(
    int rows,
    int cols,
    int count,
    Random rand,
  ) {
    List<CellPosition> obstacles = [];
    if (count <= 0) return obstacles;

    List<List<bool>> hasObs = List.generate(
      rows,
      (r) => List.generate(cols, (c) => false),
    );
    int placed = 0;
    int retries = 0;

    while (placed < count && retries < 100) {
      int r = rand.nextInt(rows);
      int c = rand.nextInt(cols);
      retries++;
      if (!hasObs[r][c]) {
        // Try to keep obstacles separated if possible
        bool tooClose = false;
        if (placed > 0 && retries < 50) {
          // Check neighbors
          List<List<int>> dirs = [[0, 1], [0, -1], [1, 0], [-1, 0], [1, 1], [1, -1], [-1, 1], [-1, -1]];
          for (var d in dirs) {
            int nr = r + d[0];
            int nc = c + d[1];
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && hasObs[nr][nc]) {
              tooClose = true;
              break;
            }
          }
        }
        
        if (tooClose) continue; // Try to find a more isolated spot

        hasObs[r][c] = true;
        obstacles.add(CellPosition(r, c));
        placed++;
      }
    }
    return obstacles;
  }

  static bool _isConnected(
    int rows,
    int cols,
    List<CellPosition> obstacles,
    int openCellsNeeded,
  ) {
    List<List<bool>> visited = List.generate(
      rows,
      (r) => List.generate(cols, (c) => false),
    );
    for (var o in obstacles) {
      visited[o.row][o.col] = true;
    }

    CellPosition? start;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!visited[r][c]) {
          start = CellPosition(r, c);
          break;
        }
      }
      if (start != null) break;
    }

    if (start == null) return false;

    int count = 0;
    List<CellPosition> queue = [start];
    visited[start.row][start.col] = true;

    int head = 0;
    while (head < queue.length) {
      CellPosition cur = queue[head++];
      count++;

      List<List<int>> dirs = [
        [0, 1],
        [0, -1],
        [1, 0],
        [-1, 0],
      ];
      for (var d in dirs) {
        int nr = cur.row + d[0];
        int nc = cur.col + d[1];
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !visited[nr][nc]) {
          visited[nr][nc] = true;
          queue.add(CellPosition(nr, nc));
        }
      }
    }

    return count == openCellsNeeded;
  }

  static bool isValidWordShape(List<CellPosition> wordCells) {
    if (wordCells.length < 3) return true;
    bool allSameRow = wordCells.every((c) => c.row == wordCells[0].row);
    bool allSameCol = wordCells.every((c) => c.col == wordCells[0].col);
    return !allSameRow && !allSameCol;
  }

  static List<CellPosition>? _findSnakePath(
    int rows,
    int cols,
    List<CellPosition> obstacles,
    int targetLen,
    List<int> wordLengths,
  ) {
    List<List<bool>> visited = List.generate(
      rows,
      (r) => List.generate(cols, (c) => false),
    );
    for (var o in obstacles) {
      visited[o.row][o.col] = true;
    }

    Set<int> boundaries = {};
    int cum = 0;
    for (int l in wordLengths) {
      cum += l;
      boundaries.add(cum);
    }

    List<CellPosition> currentPath = [];
    Random rand = Random();

    bool dfs(int r, int c) {
      currentPath.add(CellPosition(r, c));
      visited[r][c] = true;

      int curLen = currentPath.length;

      if (boundaries.contains(curLen)) {
        int startIdx = 0;
        int tempCum = 0;
        for (int l in wordLengths) {
          tempCum += l;
          if (tempCum == curLen) {
            startIdx = curLen - l;
            break;
          }
        }
        List<CellPosition> wordCells = currentPath.sublist(startIdx, curLen);
        if (!isValidWordShape(wordCells)) {
          visited[r][c] = false;
          currentPath.removeLast();
          return false;
        }
      }

      if (curLen == targetLen) {
        return true;
      }

      List<List<int>> dirs = [
        [0, 1],
        [0, -1],
        [1, 0],
        [-1, 0],
      ];
      dirs.shuffle(rand);

      for (var d in dirs) {
        int nr = r + d[0];
        int nc = c + d[1];
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !visited[nr][nc]) {
          if (dfs(nr, nc)) return true;
        }
      }

      visited[r][c] = false;
      currentPath.removeLast();
      return false;
    }

    List<CellPosition> startCells = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!visited[r][c]) startCells.add(CellPosition(r, c));
      }
    }
    startCells.shuffle(rand);

    for (var start in startCells) {
      if (dfs(start.row, start.col)) {
        return currentPath;
      }
    }

    return null;
  }

  static List<Color> _generateColors(int count, Random rand) {
    // LOẠI TRỪ MÀU ĐỎ (không dùng Colors.red/redAccent)
    List<Color> available = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.teal.shade400,
      Colors.pink.shade400,
      Colors.indigo.shade400,
      Colors.amber.shade400,
      Colors.cyan.shade400,
      Colors.lightGreen.shade400,
    ];
    List<Color> res = [];
    Color? lastColor;
    for (int i = 0; i < count; i++) {
      Color c;
      do {
        c = available[rand.nextInt(available.length)];
      } while (c == lastColor);
      res.add(c);
      lastColor = c;
    }
    return res;
  }
}
