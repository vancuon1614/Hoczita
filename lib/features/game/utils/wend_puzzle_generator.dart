import 'dart:math';
import 'package:flutter/material.dart';

enum MagicWordsDifficulty {
  easy,
  medium,
  hard;

  String get label {
    switch (this) {
      case MagicWordsDifficulty.easy:
        return 'Dễ';
      case MagicWordsDifficulty.medium:
        return 'Trung bình';
      case MagicWordsDifficulty.hard:
        return 'Cao thủ';
    }
  }

  String get englishLabel {
    switch (this) {
      case MagicWordsDifficulty.easy:
        return 'Easy';
      case MagicWordsDifficulty.medium:
        return 'Medium';
      case MagicWordsDifficulty.hard:
        return 'Hard';
    }
  }

  String get storageKey {
    switch (this) {
      case MagicWordsDifficulty.easy:
        return 'magic_words_easy';
      case MagicWordsDifficulty.medium:
        return 'magic_words_medium';
      case MagicWordsDifficulty.hard:
        return 'magic_words_hard';
    }
  }

  int get basePoints {
    switch (this) {
      case MagicWordsDifficulty.easy:
        return 10;
      case MagicWordsDifficulty.medium:
        return 25;
      case MagicWordsDifficulty.hard:
        return 50;
    }
  }

  /// Thời gian tính bằng giây: 0 = tự do đếm lên, > 0 = đếm ngược
  int get countdownSeconds {
    switch (this) {
      case MagicWordsDifficulty.easy:
        return 0; // Tự do (đếm lên)
      case MagicWordsDifficulty.medium:
        return 300; // 5 phút (300 giây)
      case MagicWordsDifficulty.hard:
        return 600; // 10 phút (600 giây) — từ rất dài cần nhiều thời gian hơn
    }
  }
}

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
  final List<List<String?>> gridStr; // null for obstacle / spacer
  final MagicWordsDifficulty difficulty;

  PuzzleAnswer({
    required this.targetWords,
    required this.wordPaths,
    required this.wordColors,
    required this.rows,
    required this.cols,
    required this.gridStr,
    this.difficulty = MagicWordsDifficulty.easy,
  });
}

class WendPuzzleGenerator {
  static const List<String> _wordBank = [
    // 3 letters
    "CAT", "DOG", "SUN", "SKY", "FOX", "OWL", "BAT", "ANT", "PIG", "COW", "ICE", "SEA", "HAT", "CUP", "BUS",
    "CAR", "BED", "EGG", "PEN", "BOX", "KEY", "BAG", "BOY", "TOY", "MAP", "RED", "RUN", "JAM", "FLY", "BEE",
    // 4 letters
    "BIRD", "FISH", "WOLF", "BEAR", "MOON", "STAR", "WIND", "RAIN", "SNOW", "FIRE", "TREE", "WOOD", "ROCK", "SAND",
    "DIRT", "GOLD", "BLUE", "PINK", "GREY", "BOOK", "LION", "DUCK", "FROG", "LEAF", "ROSE", "MILK", "CAKE", "BALL",
    "SHIP", "BOAT", "BELL", "KING", "DEER", "DOOR", "RING", "SONG", "BABY", "KITE", "FARM", "PARK", "COAT", "JUMP",
    // 5 letters
    "APPLE", "GRAPE", "MANGO", "LEMON", "WATER", "EARTH", "BLACK", "WHITE", "GREEN", "TIGER", "SNAKE", "MOUSE",
    "HORSE", "ZEBRA", "PANDA", "CLOUD", "STORM", "PLANT", "SHARK", "WHALE", "TRAIN", "PLANE", "BREAD", "RIVER",
    "HOUSE", "CLOCK", "CHAIR", "TABLE", "SWEET", "SMILE", "LIGHT", "DREAM", "MUSIC", "QUEEN", "SUNNY", "PIZZA",
    // 6 letters
    "RABBIT", "MONKEY", "BANANA", "ORANGE", "YELLOW", "PURPLE", "FOREST", "FLOWER", "SPRING", "SUMMER", "WINTER",
    "GARDEN", "CASTLE", "GUITAR", "PENCIL", "SCHOOL", "BRIDGE", "ROCKET", "PLANET", "SILVER", "CHEESE", "DOCTOR",
    // 7 letters
    "GIRAFFE", "DOLPHIN", "PENGUIN", "RAINBOW", "CHICKEN", "DIAMOND", "HOLIDAY", "MORNING", "KITCHEN", "STATION",
    "PICTURE", "WEATHER", "BLANKET", "COOKIES", "HAMSTER", "PAINTER",
    // 8 letters
    "ELEPHANT", "DINOSAUR", "AIRPLANE", "FOOTBALL", "HOSPITAL", "MOUNTAIN", "SANDWICH", "SUNSHINE", "STARFISH",
    "NOTEBOOK", "UMBRELLA", "BIRTHDAY", "BACKPACK", "SWIMMING",
    // 9 letters — dùng cho Hard
    "BUTTERFLY", "ADVENTURE", "CHOCOLATE", "CROCODILE", "DRAGONFLY", "FANTASTIC",
    "GEOGRAPHY", "HURRICANE", "PINEAPPLE", "SCIENTIST", "TELESCOPE", "DANGEROUS",
    "FORGOTTEN", "KNOWLEDGE", "LANGUAGES", "ORCHESTRA", "PASSENGER", "SUBMARINE",
    // 10 letters — dùng cho Hard
    "STRAWBERRY", "WATERMELON", "BASKETBALL", "EARTHQUAKE", "SMARTPHONE", "TELEVISION",
    "VOLLEYBALL", "GYMNASTICS", "SKATEBOARD", "WILDERNESS", "ACCOMPLICE", "APPRECIATE",
    "ATMOSPHERE", "BACKGROUND", "CELEBRATED", "CONFIDENCE",
    // 11 letters — dùng cho Hard
    "CATERPILLAR", "QUARTERBACK", "FASCINATING", "BUTTERFLIES", "COMFORTABLE",
    "RESPONSIBLE", "SUPERMARKET", "UNDERGROUND", "UNFORGOTTEN", "SPECTACULAR",
  ];

  static PuzzleAnswer generate({MagicWordsDifficulty difficulty = MagicWordsDifficulty.easy}) {
    final Map<int, List<String>> wordsByLength = {};
    for (String w in _wordBank) {
      wordsByLength.putIfAbsent(w.length, () => []).add(w);
    }

    final rand = Random();

    // Cấu hình theo 3 cấp độ
    int rows;
    int cols;
    int wordCount;
    List<int> allowedLengths;

    switch (difficulty) {
      case MagicWordsDifficulty.easy:
        // Dễ: 4×4, 3 từ, độ dài 3–5 ký tự, nhắm blocker tầm 2-3
        rows = 4;
        cols = 4;
        wordCount = 3;
        allowedLengths = [3, 4, 5];
        break;
      case MagicWordsDifficulty.medium:
        // Trung bình: 6×6, 4 từ, độ dài 5–8 ký tự (trung bình đến dài)
        rows = 6;
        cols = 6;
        wordCount = 4;
        allowedLengths = [5, 6, 7, 8];
        break;
      case MagicWordsDifficulty.hard:
        // Khó: 8×8, 4–5 từ, độ dài 8–11 ký tự (rất dài)
        rows = 8;
        cols = 8;
        wordCount = rand.nextBool() ? 4 : 5;
        allowedLengths = [8, 9, 10, 11];
        break;
    }

    int retries = 0;
    while (retries < 150) {
      retries++;

      // Chọn danh sách từ ngẫu nhiên không trùng lặp
      List<String> chosenWords = [];
      Set<String> chosenSet = {};
      bool pickFailed = false;

      // Chọn độ dài cho từng từ
      List<int> chosenLengths = [];
      if (difficulty == MagicWordsDifficulty.easy) {
        // Tổ hợp độ dài 3 từ trên lưới 4×4 để số lượng blocker từ 2 đến 3 ô (tổng chữ 13-14 / 16 ô)
        const easyCombos = [
          [5, 4, 4], // tổng 13 chữ -> 3 blocker
          [5, 5, 3], // tổng 13 chữ -> 3 blocker
          [5, 5, 4], // tổng 14 chữ -> 2 blocker
          [4, 4, 4], // tổng 12 chữ -> 4 blocker
        ];
        chosenLengths = List<int>.from(easyCombos[rand.nextInt(easyCombos.length)]);
      } else {
        for (int i = 0; i < wordCount; i++) {
          chosenLengths.add(allowedLengths[rand.nextInt(allowedLengths.length)]);
        }
      }
      // Ưu tiên xếp từ dài trước (Bin Packing heuristic)
      chosenLengths.sort((a, b) => b.compareTo(a));

      for (int len in chosenLengths) {
        List<String> pool = wordsByLength[len]!;
        String candidate = '';
        int attempts = 0;
        do {
          candidate = pool[rand.nextInt(pool.length)];
          attempts++;
        } while (chosenSet.contains(candidate) && attempts < 50);

        if (chosenSet.contains(candidate)) {
          pickFailed = true;
          break;
        }
        chosenSet.add(candidate);
        chosenWords.add(candidate);
      }

      if (pickFailed) continue;

      // Đặt từng từ vào ma trận
      final List<List<String?>> grid = List.generate(
        rows,
        (_) => List<String?>.filled(cols, null),
      );
      final Map<String, List<CellPosition>> wordPaths = {};
      bool placementFailed = false;

      for (String word in chosenWords) {
        List<CellPosition>? path = _placeWordInGrid(grid, word, rand);
        if (path == null) {
          placementFailed = true;
          break;
        }
        wordPaths[word] = path;
        for (int i = 0; i < word.length; i++) {
          grid[path[i].row][path[i].col] = word[i];
        }
      }

      if (placementFailed) continue;

      final colors = _generateColors(chosenWords.length, rand);

      return PuzzleAnswer(
        targetWords: chosenWords,
        wordPaths: wordPaths,
        wordColors: colors,
        rows: rows,
        cols: cols,
        gridStr: grid,
        difficulty: difficulty,
      );
    }

    // Fallback
    return _buildFallback(difficulty, rand);
  }

  static List<CellPosition>? _placeWordInGrid(
    List<List<String?>> grid,
    String word,
    Random rand,
  ) {
    int rows = grid.length;
    int cols = grid[0].length;
    int wordLen = word.length;

    List<CellPosition> freeCells = [];
    List<CellPosition> occupiedNeighbors = [];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] == null) {
          freeCells.add(CellPosition(r, c));
          bool hasOccupiedNeighbor = false;
          for (var d in [
            [0, 1],
            [0, -1],
            [1, 0],
            [-1, 0],
          ]) {
            int nr = r + d[0];
            int nc = c + d[1];
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && grid[nr][nc] != null) {
              hasOccupiedNeighbor = true;
              break;
            }
          }
          if (hasOccupiedNeighbor) {
            occupiedNeighbors.add(CellPosition(r, c));
          }
        }
      }
    }

    if (freeCells.length < wordLen) return null;

    List<CellPosition> candidateStarts = occupiedNeighbors.isNotEmpty
        ? (occupiedNeighbors..shuffle(rand))
        : (freeCells..shuffle(rand));

    for (var start in candidateStarts) {
      List<CellPosition>? path = _growWordPath(grid, start, wordLen, rand);
      if (path != null) {
        return path;
      }
    }

    freeCells.shuffle(rand);
    for (var start in freeCells) {
      List<CellPosition>? path = _growWordPath(grid, start, wordLen, rand);
      if (path != null) {
        return path;
      }
    }

    return null;
  }

  static List<CellPosition>? _growWordPath(
    List<List<String?>> grid,
    CellPosition start,
    int targetLen,
    Random rand,
  ) {
    int rows = grid.length;
    int cols = grid[0].length;
    List<CellPosition> currentPath = [start];
    Set<CellPosition> visited = {start};

    bool dfs(CellPosition current) {
      if (currentPath.length == targetLen) {
        if (targetLen >= 4) {
          bool allSameRow = currentPath.every((p) => p.row == currentPath[0].row);
          bool allSameCol = currentPath.every((p) => p.col == currentPath[0].col);
          if (allSameRow || allSameCol) return false;
        }
        return true;
      }

      List<List<int>> dirs = [
        [0, 1],
        [0, -1],
        [1, 0],
        [-1, 0],
      ]..shuffle(rand);

      for (var d in dirs) {
        int nr = current.row + d[0];
        int nc = current.col + d[1];
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
          CellPosition next = CellPosition(nr, nc);
          if (grid[nr][nc] == null && !visited.contains(next)) {
            currentPath.add(next);
            visited.add(next);
            if (dfs(next)) return true;
            visited.remove(next);
            currentPath.removeLast();
          }
        }
      }
      return false;
    }

    if (dfs(start)) {
      return currentPath;
    }
    return null;
  }

  static PuzzleAnswer _buildFallback(MagicWordsDifficulty difficulty, Random rand) {
    switch (difficulty) {
      case MagicWordsDifficulty.easy:
        final words = ["BIRD", "FISH", "APPLE"];
        final paths = {
          "BIRD": [const CellPosition(0, 0), const CellPosition(0, 1), const CellPosition(0, 2), const CellPosition(1, 2)],
          "FISH": [const CellPosition(1, 1), const CellPosition(2, 1), const CellPosition(2, 0), const CellPosition(3, 0)],
          "APPLE": [const CellPosition(1, 3), const CellPosition(2, 3), const CellPosition(3, 3), const CellPosition(3, 2), const CellPosition(3, 1)],
        };
        final grid = List.generate(4, (_) => List<String?>.filled(4, null));
        for (var entry in paths.entries) {
          for (int i = 0; i < entry.key.length; i++) {
            var p = entry.value[i];
            grid[p.row][p.col] = entry.key[i];
          }
        }
        return PuzzleAnswer(
          targetWords: words,
          wordPaths: paths,
          wordColors: _generateColors(words.length, rand),
          rows: 4,
          cols: 4,
          gridStr: grid,
          difficulty: difficulty,
        );

      case MagicWordsDifficulty.medium:
        final words = ["BOOK", "LION", "APPLE", "WATER"];
        final paths = {
          "BOOK": [const CellPosition(0, 0), const CellPosition(0, 1), const CellPosition(1, 1), const CellPosition(1, 2)],
          "LION": [const CellPosition(0, 3), const CellPosition(0, 4), const CellPosition(1, 4), const CellPosition(1, 3)],
          "APPLE": [const CellPosition(2, 1), const CellPosition(2, 2), const CellPosition(3, 2), const CellPosition(3, 1), const CellPosition(4, 1)],
          "WATER": [const CellPosition(3, 3), const CellPosition(3, 4), const CellPosition(4, 4), const CellPosition(4, 3), const CellPosition(5, 3)],
        };
        final grid = List.generate(6, (_) => List<String?>.filled(6, null));
        for (var entry in paths.entries) {
          for (int i = 0; i < entry.key.length; i++) {
            var p = entry.value[i];
            grid[p.row][p.col] = entry.key[i];
          }
        }
        return PuzzleAnswer(
          targetWords: words,
          wordPaths: paths,
          wordColors: _generateColors(words.length, rand),
          rows: 6,
          cols: 6,
          gridStr: grid,
          difficulty: difficulty,
        );

      case MagicWordsDifficulty.hard:
        // Fallback: 4 từ dài trên lưới 8×8
        final words = ["ELEPHANT", "MOUNTAIN", "ADVENTURE", "BUTTERFLY"];
        final paths = {
          "ELEPHANT": [
            const CellPosition(0, 0), const CellPosition(0, 1), const CellPosition(0, 2), const CellPosition(0, 3),
            const CellPosition(1, 3), const CellPosition(1, 2), const CellPosition(1, 1), const CellPosition(1, 0),
          ],
          "MOUNTAIN": [
            const CellPosition(2, 0), const CellPosition(2, 1), const CellPosition(2, 2), const CellPosition(2, 3),
            const CellPosition(3, 3), const CellPosition(3, 2), const CellPosition(3, 1), const CellPosition(3, 0),
          ],
          "ADVENTURE": [
            const CellPosition(0, 5), const CellPosition(0, 6), const CellPosition(1, 6), const CellPosition(1, 5),
            const CellPosition(2, 5), const CellPosition(2, 6), const CellPosition(3, 6), const CellPosition(3, 5), const CellPosition(4, 5),
          ],
          "BUTTERFLY": [
            const CellPosition(5, 0), const CellPosition(5, 1), const CellPosition(5, 2), const CellPosition(6, 2),
            const CellPosition(6, 1), const CellPosition(6, 0), const CellPosition(7, 0), const CellPosition(7, 1), const CellPosition(7, 2),
          ],
        };
        final grid = List.generate(8, (_) => List<String?>.filled(8, null));
        for (var entry in paths.entries) {
          for (int i = 0; i < entry.key.length; i++) {
            var p = entry.value[i];
            grid[p.row][p.col] = entry.key[i];
          }
        }
        return PuzzleAnswer(
          targetWords: words,
          wordPaths: paths,
          wordColors: _generateColors(words.length, rand),
          rows: 8,
          cols: 8,
          gridStr: grid,
          difficulty: difficulty,
        );
    }
  }

  static List<Color> _generateColors(int count, Random rand) {
    const List<Color> palette = [
      Color(0xFFFF6D00), // Sunset Orange
      Color(0xFF2979FF), // Electric Royal Blue
      Color(0xFF00C853), // Emerald Green
      Color(0xFFD500F9), // Electric Fuchsia / Magenta
      Color(0xFF00BFA5), // Deep Teal / Mint
      Color(0xFF7B1FA2), // Vivid Purple
      Color(0xFFFFAB00), // Amber Gold
      Color(0xFF00E5FF), // Electric Cyan
      Color(0xFFE91E63), // Pink Coral
      Color(0xFF3D5AFE), // Deep Indigo
    ];
    List<Color> shuffled = List<Color>.from(palette)..shuffle(rand);
    return List<Color>.generate(count, (i) => shuffled[i % shuffled.length]);
  }
}
