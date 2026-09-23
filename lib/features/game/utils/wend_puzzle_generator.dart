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

enum MagicWordsDifficulty { easy, medium, hard }

class WendPuzzleGenerator {
  // Kho từ vựng tiếng Anh phong phú 200+ từ phân chia theo độ dài
  static const List<String> _wordBank = [
    // 3 chữ cái (50 từ)
    "CAT", "DOG", "SUN", "SKY", "FOX", "OWL", "BAT", "ANT", "PIG", "COW",
    "ICE", "SEA", "BEE", "BUS", "HAT", "CUP", "PEN", "CAR", "BOY", "KEY",
    "BOX", "FLY", "JAM", "MAP", "PIE", "TOY", "BED", "BAG", "ARM", "EAR",
    "EYE", "LIP", "LEG", "RED", "HOT", "RUN", "FAN", "PAN", "TOP", "NUT",
    "EGG", "ZIP", "ZOO", "HEN", "RAT", "LOG", "MUG", "NET", "POT", "WIN",

    // 4 chữ cái (60 từ)
    "BIRD", "FISH", "WOLF", "BEAR", "LION", "DEER", "DUCK", "FROG", "CRAB", "GOAT",
    "MOON", "STAR", "WIND", "RAIN", "SNOW", "FIRE", "TREE", "WOOD", "ROCK", "SAND",
    "DIRT", "GOLD", "BLUE", "PINK", "GREY", "ROSE", "LEAF", "SEED", "CAKE", "MILK",
    "SOUP", "RICE", "CORN", "BOOK", "DOOR", "BOAT", "SHIP", "PARK", "CITY", "FARM",
    "HOME", "ROOF", "WALL", "RING", "BALL", "GAME", "COLD", "WARM", "FAST", "SLOW",
    "JUMP", "WALK", "READ", "DRAW", "SING", "SWIM", "BABY", "KITE", "LAKE", "HILL",

    // 5 chữ cái (50 từ)
    "APPLE", "GRAPE", "MANGO", "LEMON", "PEACH", "MELON", "WATER", "EARTH", "BLACK", "WHITE",
    "GREEN", "BROWN", "TIGER", "SNAKE", "MOUSE", "HORSE", "ZEBRA", "PANDA", "KOALA", "SHEEP",
    "PLANT", "CLOUD", "RIVER", "OCEAN", "BEACH", "HOUSE", "CLOCK", "CHAIR", "TABLE", "BREAD",
    "PIZZA", "SWEET", "MUSIC", "LIGHT", "STORM", "TRAIN", "TRUCK", "PLANE", "SMILE", "DANCE",
    "CLEAN", "HAPPY", "FRESH", "SUGAR", "CANDY", "GRASS", "STONE", "SHARK", "WHALE", "EAGLE",

    // 6 chữ cái (35 từ)
    "RABBIT", "MONKEY", "BANANA", "ORANGE", "YELLOW", "PURPLE", "FOREST", "FLOWER", "STREAM", "VALLEY",
    "ISLAND", "BRIDGE", "CASTLE", "SCHOOL", "FRIEND", "FAMILY", "PENCIL", "CAMERA", "GUITAR", "WINDOW",
    "SUMMER", "WINTER", "SPRING", "AUTUMN", "SILVER", "GOLDEN", "PLANET", "ROCKET", "GARDEN", "DOCTOR",
    "FARMER", "TURTLE", "LIZARD", "CHERRY", "CARROT",

    // 7 chữ cái (25 từ)
    "ELEPHANT", "GIRAFFE", "DOLPHIN", "PENGUIN", "OCTOPUS", "HAMSTER", "SPARROW", "RAINBOW", "SUNSHINE", "VOLCANO",
    "MORNING", "EVENING", "HOLIDAY", "STATION", "AIRPORT", "PICTURE", "JOURNEY", "VILLAGE", "KITCHEN", "BEDROOM",
    "CHICKEN", "BLANKET", "WEATHER", "DIAMOND", "FEATHER",

    // 8 chữ cái (15 từ)
    "HOSPITAL", "MOUNTAIN", "BUTTERFLY", "KANGAROO", "BUILDING", "COMPUTER", "UMBRELLA", "SANDWICH", "NOTEBOOK", "FOOTBALL",
    "DINOSAUR", "SUNLIGHT", "SQUIRREL", "HEDGEHOG", "PINEAPPLE",
  ];

  // Lưu lịch sử các từ gần đây để không bị lặp từ quá nhiều
  static final List<String> _recentWords = [];

  static bool isValidWordShape(List<CellPosition> wordCells) {
    if (wordCells.length < 3) return true;
    bool allSameRow = wordCells.every((c) => c.row == wordCells[0].row);
    bool allSameCol = wordCells.every((c) => c.col == wordCells[0].col);
    // Yêu cầu từ không được thẳng đuột 1 hàng hoặc 1 cột (phải có đường uốn ziczac)
    return !allSameRow && !allSameCol;
  }

  static PuzzleAnswer generate({MagicWordsDifficulty? difficulty}) {
    Map<int, List<String>> wordsByLength = {};
    for (String w in _wordBank) {
      wordsByLength.putIfAbsent(w.length, () => []).add(w);
    }

    final rand = Random();

    // 1. Xác định kích thước lưới và quy cách từ theo độ khó
    int rows;
    int cols;
    int wordCount;
    List<int> allowedLengths;

    if (difficulty == MagicWordsDifficulty.easy) {
      rows = 5;
      cols = 5;
      wordCount = 3;
      allowedLengths = [3, 4];
    } else if (difficulty == MagicWordsDifficulty.medium) {
      rows = 6;
      cols = 6;
      wordCount = 4;
      allowedLengths = [3, 4, 5];
    } else if (difficulty == MagicWordsDifficulty.hard) {
      rows = rand.nextBool() ? 7 : 8;
      cols = rows;
      wordCount = rows == 7 ? 5 : 6;
      allowedLengths = [4, 5, 6, 7];
    } else {
      rows = 5;
      cols = 5;
      wordCount = 3;
      allowedLengths = [3, 4];
    }

    // 2. Thử đặt các từ vào lưới (tối đa 60 lần thử)
    for (int retry = 0; retry < 60; retry++) {
      // Chọn danh sách từ ngẫu nhiên không trùng lặp và ưu tiên từ chưa xuất hiện gần đây
      List<String> targetWords = _pickTargetWords(
        wordCount: wordCount,
        allowedLengths: allowedLengths,
        wordsByLength: wordsByLength,
        rand: rand,
      );

      if (targetWords.length < wordCount) continue;

      // Khởi tạo bảng rỗng
      List<List<String?>> grid = List.generate(
        rows,
        (_) => List.generate(cols, (_) => null),
      );
      Map<String, List<CellPosition>> wordPaths = {};
      bool allPlaced = true;

      // Sắp xếp thử đặt từ dài trước để dễ tìm đường hơn
      List<String> placeOrder = List.from(targetWords)
        ..sort((a, b) => b.length.compareTo(a.length));

      for (String word in placeOrder) {
        List<CellPosition>? path = _placeWord(grid, rows, cols, word, rand);
        if (path != null) {
          wordPaths[word] = path;
          for (int i = 0; i < word.length; i++) {
            grid[path[i].row][path[i].col] = word[i];
          }
        } else {
          allPlaced = false;
          break;
        }
      }

      if (allPlaced) {
        // Cập nhật các từ gần đây
        for (String w in targetWords) {
          _recentWords.remove(w);
          _recentWords.insert(0, w);
        }
        if (_recentWords.length > 50) {
          _recentWords.removeRange(50, _recentWords.length);
        }

        return PuzzleAnswer(
          targetWords: targetWords,
          wordPaths: wordPaths,
          wordColors: _generateColors(targetWords.length, rand),
          rows: rows,
          cols: cols,
          gridStr: grid,
        );
      }
    }

    // Fallback an toàn nếu thuật toán ngẫu nhiên gặp trường hợp hy hữu:
    // Tuyệt đối fallback theo ĐÚNG kích thước rows x cols của độ khó đã chọn, không fallback 3x3!
    return _buildDeterministicFallback(rows, cols, difficulty, rand);
  }

  /// Chọn danh sách từ ngẫu nhiên, ưu tiên các từ chưa xuất hiện gần đây
  static List<String> _pickTargetWords({
    required int wordCount,
    required List<int> allowedLengths,
    required Map<int, List<String>> wordsByLength,
    required Random rand,
  }) {
    List<String> chosen = [];
    int attempts = 0;

    while (chosen.length < wordCount && attempts < 100) {
      attempts++;
      int len = allowedLengths[rand.nextInt(allowedLengths.length)];
      List<String> pool = wordsByLength[len] ?? [];
      if (pool.isEmpty) continue;

      // Ưu tiên các từ chưa có trong _recentWords
      List<String> fresh = pool.where((w) => !_recentWords.contains(w) && !chosen.contains(w)).toList();
      String picked;
      if (fresh.isNotEmpty) {
        picked = fresh[rand.nextInt(fresh.length)];
      } else {
        List<String> unused = pool.where((w) => !chosen.contains(w)).toList();
        if (unused.isEmpty) continue;
        picked = unused[rand.nextInt(unused.length)];
      }

      chosen.add(picked);
    }

    return chosen;
  }

  /// Tìm đường đi uốn lượn ziczac trên các ô trống cho 1 từ
  static List<CellPosition>? _placeWord(
    List<List<String?>> grid,
    int rows,
    int cols,
    String word,
    Random rand,
  ) {
    List<CellPosition> emptyCells = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] == null) {
          emptyCells.add(CellPosition(r, c));
        }
      }
    }
    emptyCells.shuffle(rand);

    for (var startCell in emptyCells) {
      List<CellPosition> currentPath = [startCell];
      List<List<bool>> visited = List.generate(
        rows,
        (r) => List.generate(cols, (c) => grid[r][c] != null),
      );
      visited[startCell.row][startCell.col] = true;

      List<CellPosition>? result = _dfsPlace(
        grid,
        rows,
        cols,
        word,
        1,
        startCell.row,
        startCell.col,
        currentPath,
        visited,
        rand,
      );

      if (result != null) {
        return result;
      }
    }
    return null;
  }

  static List<CellPosition>? _dfsPlace(
    List<List<String?>> grid,
    int rows,
    int cols,
    String word,
    int charIdx,
    int curR,
    int curC,
    List<CellPosition> path,
    List<List<bool>> visited,
    Random rand,
  ) {
    if (charIdx == word.length) {
      if (isValidWordShape(path)) {
        return List.from(path);
      }
      return null;
    }

    List<List<int>> dirs = [
      [0, 1],
      [0, -1],
      [1, 0],
      [-1, 0],
    ];
    dirs.shuffle(rand);

    for (var d in dirs) {
      int nr = curR + d[0];
      int nc = curC + d[1];

      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !visited[nr][nc]) {
        visited[nr][nc] = true;
        path.add(CellPosition(nr, nc));

        var res = _dfsPlace(grid, rows, cols, word, charIdx + 1, nr, nc, path, visited, rand);
        if (res != null) return res;

        path.removeLast();
        visited[nr][nc] = false;
      }
    }

    return null;
  }

  /// Fallback theo đúng kích thước lưới đã chọn, không bao giờ dùng 3x3 khi chọn Dễ/Trung Bình/Cao Thủ
  static PuzzleAnswer _buildDeterministicFallback(
    int rows,
    int cols,
    MagicWordsDifficulty? difficulty,
    Random rand,
  ) {
    if (rows == 5) {
      // 5x5: CAT (3), BIRD (4), STAR (4)
      final words = ["CAT", "BIRD", "STAR"];
      final paths = {
        "CAT": [
          const CellPosition(0, 0),
          const CellPosition(0, 1),
          const CellPosition(1, 1),
        ],
        "BIRD": [
          const CellPosition(2, 0),
          const CellPosition(3, 0),
          const CellPosition(3, 1),
          const CellPosition(4, 1),
        ],
        "STAR": [
          const CellPosition(1, 3),
          const CellPosition(2, 3),
          const CellPosition(2, 4),
          const CellPosition(3, 4),
        ],
      };
      final grid = List.generate(5, (_) => List<String?>.filled(5, null));
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
        rows: 5,
        cols: 5,
        gridStr: grid,
      );
    } else if (rows == 6) {
      // 6x6: FISH (4), MOON (4), WATER (5), TIGER (5)
      final words = ["FISH", "MOON", "WATER", "TIGER"];
      final paths = {
        "FISH": [
          const CellPosition(0, 0),
          const CellPosition(0, 1),
          const CellPosition(1, 1),
          const CellPosition(2, 1),
        ],
        "MOON": [
          const CellPosition(0, 3),
          const CellPosition(0, 4),
          const CellPosition(1, 4),
          const CellPosition(2, 4),
        ],
        "WATER": [
          const CellPosition(3, 0),
          const CellPosition(4, 0),
          const CellPosition(4, 1),
          const CellPosition(5, 1),
          const CellPosition(5, 2),
        ],
        "TIGER": [
          const CellPosition(3, 3),
          const CellPosition(3, 4),
          const CellPosition(4, 4),
          const CellPosition(5, 4),
          const CellPosition(5, 5),
        ],
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
      );
    } else {
      // 7x7: LION (4), APPLE (5), ZEBRA (5), FOREST (6), YELLOW (6)
      final words = ["LION", "APPLE", "ZEBRA", "FOREST", "YELLOW"];
      final paths = {
        "LION": [
          const CellPosition(0, 0),
          const CellPosition(0, 1),
          const CellPosition(1, 1),
          const CellPosition(2, 1),
        ],
        "APPLE": [
          const CellPosition(0, 3),
          const CellPosition(0, 4),
          const CellPosition(1, 4),
          const CellPosition(2, 4),
          const CellPosition(2, 5),
        ],
        "ZEBRA": [
          const CellPosition(3, 0),
          const CellPosition(4, 0),
          const CellPosition(4, 1),
          const CellPosition(5, 1),
          const CellPosition(5, 2),
        ],
        "FOREST": [
          const CellPosition(3, 3),
          const CellPosition(3, 4),
          const CellPosition(4, 4),
          const CellPosition(4, 5),
          const CellPosition(5, 5),
          const CellPosition(6, 5),
        ],
        "YELLOW": [
          const CellPosition(1, 6),
          const CellPosition(2, 6),
          const CellPosition(3, 6),
          const CellPosition(4, 6),
          const CellPosition(5, 6),
          const CellPosition(6, 6),
        ],
      };
      final grid = List.generate(rows, (_) => List<String?>.filled(cols, null));
      for (var entry in paths.entries) {
        for (int i = 0; i < entry.key.length; i++) {
          var p = entry.value[i];
          if (p.row < rows && p.col < cols) {
            grid[p.row][p.col] = entry.key[i];
          }
        }
      }
      return PuzzleAnswer(
        targetWords: words,
        wordPaths: paths,
        wordColors: _generateColors(words.length, rand),
        rows: rows,
        cols: cols,
        gridStr: grid,
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
