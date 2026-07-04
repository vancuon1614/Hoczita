enum CrosswordDifficulty { easy, medium, hard }

class EnglishCrosswordWord {
  final String word;
  final String clue;
  final int row;
  final int col;
  final bool isAcross;

  const EnglishCrosswordWord({
    required this.word,
    required this.clue,
    required this.row,
    required this.col,
    required this.isAcross,
  });
}

class EnglishCrosswordLevel {
  final int id;
  final CrosswordDifficulty difficulty;
  final int rows;
  final int cols;
  final List<EnglishCrosswordWord> words;

  const EnglishCrosswordLevel({
    required this.id,
    required this.difficulty,
    required this.rows,
    required this.cols,
    required this.words,
  });

  static List<EnglishCrosswordLevel> getPredefinedLevels() {
    return [
      // ================= EASY LEVELS (5 WORDS: 3 Across, 2 Down, 7x7 Grid) =================
      EnglishCrosswordLevel(
        id: 1,
        difficulty: CrosswordDifficulty.easy,
        rows: 7,
        cols: 7,
        words: [
          const EnglishCrosswordWord(word: 'CAT', clue: 'Con mèo', row: 1, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'CAR', clue: 'Ô tô', row: 1, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'RABBIT', clue: 'Con thỏ', row: 3, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'BOAT', clue: 'Con thuyền', row: 3, col: 3, isAcross: false),
          const EnglishCrosswordWord(word: 'TOY', clue: 'Đồ chơi', row: 6, col: 3, isAcross: true),
        ],
      ),
      EnglishCrosswordLevel(
        id: 2,
        difficulty: CrosswordDifficulty.easy,
        rows: 7,
        cols: 7,
        words: [
          const EnglishCrosswordWord(word: 'DOG', clue: 'Con chó', row: 1, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'DOLL', clue: 'Búp bê', row: 1, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'LAMP', clue: 'Đèn ngủ', row: 3, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'MAP', clue: 'Bản đồ', row: 3, col: 3, isAcross: false),
          const EnglishCrosswordWord(word: 'PEN', clue: 'Bút viết', row: 5, col: 3, isAcross: true),
        ],
      ),
      EnglishCrosswordLevel(
        id: 3,
        difficulty: CrosswordDifficulty.easy,
        rows: 7,
        cols: 7,
        words: [
          const EnglishCrosswordWord(word: 'SUN', clue: 'Mặt trời', row: 0, col: 0, isAcross: true),
          const EnglishCrosswordWord(word: 'STAR', clue: 'Ngôi sao', row: 0, col: 0, isAcross: false),
          const EnglishCrosswordWord(word: 'RAIN', clue: 'Cơn mưa', row: 3, col: 0, isAcross: true),
          const EnglishCrosswordWord(word: 'NEST', clue: 'Tổ chim', row: 3, col: 3, isAcross: false),
          const EnglishCrosswordWord(word: 'TOY', clue: 'Đồ chơi', row: 6, col: 3, isAcross: true),
        ],
      ),

      // ================= MEDIUM/NORMAL LEVELS (10 WORDS: 5 Across, 5 Down, 11x11 Grid) =================
      EnglishCrosswordLevel(
        id: 4,
        difficulty: CrosswordDifficulty.medium,
        rows: 11,
        cols: 11,
        words: [
          const EnglishCrosswordWord(word: 'APPLE', clue: 'Quả táo', row: 1, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'PEACH', clue: 'Quả đào', row: 1, col: 2, isAcross: false),
          const EnglishCrosswordWord(word: 'BANANA', clue: 'Quả chuối', row: 3, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'MANGO', clue: 'Quả xoài', row: 2, col: 4, isAcross: false),
          const EnglishCrosswordWord(word: 'ORANGE', clue: 'Quả cam', row: 6, col: 4, isAcross: true),
          const EnglishCrosswordWord(word: 'GRAPE', clue: 'Quả nho', row: 6, col: 8, isAcross: false),
          const EnglishCrosswordWord(word: 'BEANS', clue: 'Hạt đậu', row: 8, col: 6, isAcross: true),
          const EnglishCrosswordWord(word: 'NUT', clue: 'Hạt dẻ', row: 8, col: 9, isAcross: false),
          const EnglishCrosswordWord(word: 'NET', clue: 'Cái lưới', row: 10, col: 7, isAcross: true),
          const EnglishCrosswordWord(word: 'THE', clue: 'Từ xác định (The)', row: 5, col: 1, isAcross: false),
        ],
      ),
      EnglishCrosswordLevel(
        id: 5,
        difficulty: CrosswordDifficulty.medium,
        rows: 11,
        cols: 11,
        words: [
          const EnglishCrosswordWord(word: 'SHIRT', clue: 'Áo sơ mi', row: 1, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'SHOES', clue: 'Đôi giày', row: 1, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'SOFA', clue: 'Ghế sofa', row: 5, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'FOR', clue: 'Cho/Dành cho', row: 5, col: 3, isAcross: false),
          const EnglishCrosswordWord(word: 'LAMP', clue: 'Đèn ngủ', row: 4, col: 4, isAcross: false),
          const EnglishCrosswordWord(word: 'PANTS', clue: 'Quần dài', row: 7, col: 4, isAcross: true),
          const EnglishCrosswordWord(word: 'TOLD', clue: 'Đã nói', row: 7, col: 7, isAcross: false),
          const EnglishCrosswordWord(word: 'ILL', clue: 'Bị ốm', row: 9, col: 6, isAcross: true),
          const EnglishCrosswordWord(word: 'ALL', clue: 'Tất cả', row: 8, col: 8, isAcross: false),
          const EnglishCrosswordWord(word: 'BED', clue: 'Cái giường', row: 10, col: 5, isAcross: true),
        ],
      ),
      EnglishCrosswordLevel(
        id: 6,
        difficulty: CrosswordDifficulty.medium,
        rows: 11,
        cols: 11,
        words: [
          const EnglishCrosswordWord(word: 'CARROT', clue: 'Củ cà rốt', row: 1, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'TOMATO', clue: 'Quả cà chua', row: 1, col: 6, isAcross: false),
          const EnglishCrosswordWord(word: 'POTATO', clue: 'Củ khoai tây', row: 5, col: 4, isAcross: true),
          const EnglishCrosswordWord(word: 'PEAS', clue: 'Đậu Hà Lan', row: 5, col: 4, isAcross: false),
          const EnglishCrosswordWord(word: 'STEP', clue: 'Bước chân', row: 8, col: 4, isAcross: true),
          const EnglishCrosswordWord(word: 'STOP', clue: 'Dừng lại', row: 7, col: 5, isAcross: false),
          const EnglishCrosswordWord(word: 'DOE', clue: 'Con nai cái', row: 9, col: 4, isAcross: true),
          const EnglishCrosswordWord(word: 'EEL', clue: 'Con lươn', row: 8, col: 6, isAcross: false),
          const EnglishCrosswordWord(word: 'MAP', clue: 'Bản đồ', row: 10, col: 3, isAcross: true),
          const EnglishCrosswordWord(word: 'NUT', clue: 'Hạt dẻ', row: 3, col: 3, isAcross: false),
        ],
      ),

      // ================= HARD LEVELS (20 WORDS: 10 Across, 10 Down, 14x14 Grid) =================
      EnglishCrosswordLevel(
        id: 7,
        difficulty: CrosswordDifficulty.hard,
        rows: 14,
        cols: 14,
        words: [
          const EnglishCrosswordWord(word: 'APPLE', clue: 'Quả táo', row: 1, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'PEACH', clue: 'Quả đào', row: 1, col: 2, isAcross: false),
          const EnglishCrosswordWord(word: 'BANANA', clue: 'Quả chuối', row: 3, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'MANGO', clue: 'Quả xoài', row: 2, col: 4, isAcross: false),
          const EnglishCrosswordWord(word: 'ORANGE', clue: 'Quả cam', row: 6, col: 4, isAcross: true),
          const EnglishCrosswordWord(word: 'GRAPE', clue: 'Quả nho', row: 6, col: 8, isAcross: false),
          const EnglishCrosswordWord(word: 'BEANS', clue: 'Hạt đậu', row: 8, col: 6, isAcross: true),
          const EnglishCrosswordWord(word: 'NUT', clue: 'Hạt dẻ', row: 8, col: 9, isAcross: false),
          const EnglishCrosswordWord(word: 'NET', clue: 'Cái lưới', row: 10, col: 7, isAcross: true),
          const EnglishCrosswordWord(word: 'THE', clue: 'Mạo từ xác định', row: 5, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'CAT', clue: 'Con mèo', row: 0, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'CUP', clue: 'Cái cốc', row: 0, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'BET', clue: 'Cá cược', row: 3, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'DOG', clue: 'Con chó', row: 9, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'GUM', clue: 'Kẹo cao su', row: 11, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'MAP', clue: 'Bản đồ', row: 11, col: 3, isAcross: false),
          const EnglishCrosswordWord(word: 'PEN', clue: 'Cái bút', row: 13, col: 3, isAcross: true),
          const EnglishCrosswordWord(word: 'SUN', clue: 'Mặt trời', row: 5, col: 6, isAcross: true),
          const EnglishCrosswordWord(word: 'BAG', clue: 'Cái túi', row: 6, col: 6, isAcross: true),
          const EnglishCrosswordWord(word: 'BOB', clue: 'Kiểu tóc ngắn', row: 6, col: 6, isAcross: false),
        ],
      ),
      EnglishCrosswordLevel(
        id: 8,
        difficulty: CrosswordDifficulty.hard,
        rows: 14,
        cols: 14,
        words: [
          const EnglishCrosswordWord(word: 'SHIRT', clue: 'Áo sơ mi', row: 1, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'SHOES', clue: 'Đôi giày', row: 1, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'SOFA', clue: 'Ghế sofa', row: 5, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'LAMP', clue: 'Đèn ngủ', row: 4, col: 4, isAcross: false),
          const EnglishCrosswordWord(word: 'PANTS', clue: 'Quần dài', row: 7, col: 4, isAcross: true),
          const EnglishCrosswordWord(word: 'SOCK', clue: 'Cái tất', row: 7, col: 7, isAcross: false),
          const EnglishCrosswordWord(word: 'HAT', clue: 'Cái mũ', row: 9, col: 6, isAcross: true),
          const EnglishCrosswordWord(word: 'TEA', clue: 'Trà', row: 9, col: 8, isAcross: false),
          const EnglishCrosswordWord(word: 'BAG', clue: 'Cái túi', row: 11, col: 5, isAcross: true),
          const EnglishCrosswordWord(word: 'BUS', clue: 'Xe buýt', row: 5, col: 3, isAcross: false),
          const EnglishCrosswordWord(word: 'CAR', clue: 'Ô tô', row: 0, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'CUP', clue: 'Cái cốc', row: 0, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'TOY', clue: 'Đồ chơi', row: 3, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'DOG', clue: 'Con chó', row: 9, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'GUM', clue: 'Kẹo cao su', row: 11, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'MAP', clue: 'Bản đồ', row: 11, col: 3, isAcross: false),
          const EnglishCrosswordWord(word: 'PEN', clue: 'Cái bút', row: 13, col: 3, isAcross: true),
          const EnglishCrosswordWord(word: 'SUN', clue: 'Mặt trời', row: 5, col: 6, isAcross: true),
          const EnglishCrosswordWord(word: 'BOX', clue: 'Cái hộp', row: 6, col: 6, isAcross: true),
          const EnglishCrosswordWord(word: 'BOY', clue: 'Cậu bé', row: 6, col: 6, isAcross: false),
        ],
      ),
      EnglishCrosswordLevel(
        id: 9,
        difficulty: CrosswordDifficulty.hard,
        rows: 14,
        cols: 14,
        words: [
          const EnglishCrosswordWord(word: 'CARROT', clue: 'Củ cà rốt', row: 1, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'TOMATO', clue: 'Quả cà chua', row: 1, col: 6, isAcross: false),
          const EnglishCrosswordWord(word: 'POTATO', clue: 'Củ khoai tây', row: 5, col: 4, isAcross: true),
          const EnglishCrosswordWord(word: 'PEAS', clue: 'Đậu Hà Lan', row: 5, col: 4, isAcross: false),
          const EnglishCrosswordWord(word: 'STEP', clue: 'Bước chân', row: 8, col: 4, isAcross: true),
          const EnglishCrosswordWord(word: 'STOP', clue: 'Dừng lại', row: 7, col: 5, isAcross: false),
          const EnglishCrosswordWord(word: 'DOE', clue: 'Con nai cái', row: 9, col: 4, isAcross: true),
          const EnglishCrosswordWord(word: 'EEL', clue: 'Con lươn', row: 8, col: 6, isAcross: false),
          const EnglishCrosswordWord(word: 'MAP', clue: 'Bản đồ', row: 10, col: 3, isAcross: true),
          const EnglishCrosswordWord(word: 'NUT', clue: 'Hạt dẻ', row: 3, col: 3, isAcross: false),
          const EnglishCrosswordWord(word: 'CAT', clue: 'Con mèo', row: 0, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'CUP', clue: 'Cái cốc', row: 0, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'BET', clue: 'Cá cược', row: 3, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'DOG', clue: 'Con chó', row: 9, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'GUM', clue: 'Kẹo cao su', row: 11, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'MAP', clue: 'Bản đồ', row: 11, col: 3, isAcross: false),
          const EnglishCrosswordWord(word: 'PEN', clue: 'Cái bút', row: 13, col: 3, isAcross: true),
          const EnglishCrosswordWord(word: 'SUN', clue: 'Mặt trời', row: 5, col: 6, isAcross: true),
          const EnglishCrosswordWord(word: 'BAG', clue: 'Cái túi', row: 6, col: 6, isAcross: true),
          const EnglishCrosswordWord(word: 'BOB', clue: 'Kiểu tóc ngắn', row: 6, col: 6, isAcross: false),
        ],
      ),
    ];
  }
}
