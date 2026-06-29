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
      // ================= EASY LEVELS =================
      EnglishCrosswordLevel(
        id: 1,
        difficulty: CrosswordDifficulty.easy,
        rows: 8,
        cols: 8,
        words: [
          const EnglishCrosswordWord(word: 'CAT', clue: 'Con mèo 🐱', row: 1, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'CAR', clue: 'Ô tô 🚗', row: 1, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'RABBIT', clue: 'Con thỏ 🐰', row: 3, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'BALL', clue: 'Quả bóng ⚽', row: 3, col: 3, isAcross: false),
        ],
      ),
      EnglishCrosswordLevel(
        id: 2,
        difficulty: CrosswordDifficulty.easy,
        rows: 10,
        cols: 6,
        words: [
          const EnglishCrosswordWord(word: 'SUN', clue: 'Mặt trời ☀️', row: 1, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'STAR', clue: 'Ngôi sao ⭐️', row: 1, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'RAIN', clue: 'Cơn mưa 🌧️', row: 4, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'NATURE', clue: 'Tự nhiên 🌱', row: 4, col: 4, isAcross: false),
        ],
      ),
      EnglishCrosswordLevel(
        id: 3,
        difficulty: CrosswordDifficulty.easy,
        rows: 6,
        cols: 6,
        words: [
          const EnglishCrosswordWord(word: 'DOG', clue: 'Con chó 🐶', row: 1, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'DOLL', clue: 'Búp bê 🧸', row: 1, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'LAMP', clue: 'Đèn ngủ 💡', row: 3, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'MAP', clue: 'Bản đồ 🗺️', row: 3, col: 3, isAcross: false),
        ],
      ),

      // ================= MEDIUM LEVELS =================
      EnglishCrosswordLevel(
        id: 4,
        difficulty: CrosswordDifficulty.medium,
        rows: 8,
        cols: 10,
        words: [
          const EnglishCrosswordWord(word: 'APPLE', clue: 'Quả táo 🍎', row: 1, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'PEACH', clue: 'Quả đào 🍑', row: 1, col: 2, isAcross: false),
          const EnglishCrosswordWord(word: 'BANANA', clue: 'Quả chuối 🍌', row: 3, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'MANGO', clue: 'Quả xoài 🥭', row: 2, col: 4, isAcross: false),
          const EnglishCrosswordWord(word: 'ORANGE', clue: 'Quả cam 🍊', row: 6, col: 4, isAcross: true),
        ],
      ),
      EnglishCrosswordLevel(
        id: 5,
        difficulty: CrosswordDifficulty.medium,
        rows: 9,
        cols: 9,
        words: [
          const EnglishCrosswordWord(word: 'SHIRT', clue: 'Áo thun 👕', row: 1, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'SHOES', clue: 'Đôi giày 👟', row: 1, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'SOFA', clue: 'Ghế sô-fa 🛋️', row: 5, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'LAMP', clue: 'Đèn ngủ 💡', row: 4, col: 4, isAcross: false),
          const EnglishCrosswordWord(word: 'PANTS', clue: 'Quần dài 👖', row: 7, col: 4, isAcross: true),
        ],
      ),
      EnglishCrosswordLevel(
        id: 6,
        difficulty: CrosswordDifficulty.medium,
        rows: 12,
        cols: 10,
        words: [
          const EnglishCrosswordWord(word: 'CARROT', clue: 'Củ cà rốt 🥕', row: 1, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'TOMATO', clue: 'Quả cà chua 🍅', row: 1, col: 6, isAcross: false),
          const EnglishCrosswordWord(word: 'POTATO', clue: 'Củ khoai tây 🥔', row: 5, col: 4, isAcross: true),
          const EnglishCrosswordWord(word: 'PUMPKIN', clue: 'Quả bí ngô 🎃', row: 5, col: 4, isAcross: false),
        ],
      ),

      // ================= HARD LEVELS =================
      EnglishCrosswordLevel(
        id: 7,
        difficulty: CrosswordDifficulty.hard,
        rows: 12,
        cols: 10,
        words: [
          const EnglishCrosswordWord(word: 'SPACESHIP', clue: 'Tàu vũ trụ 🚀', row: 2, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'ASTRONAUT', clue: 'Phi hành gia 👨‍🚀', row: 2, col: 3, isAcross: false),
          const EnglishCrosswordWord(word: 'RAINBOW', clue: 'Cầu vồng 🌈', row: 5, col: 3, isAcross: true),
          const EnglishCrosswordWord(word: 'OCTOPUS', clue: 'Con bạch tuộc 🐙', row: 6, col: 3, isAcross: true),
          const EnglishCrosswordWord(word: 'TURTLE', clue: 'Con rùa biển 🐢', row: 6, col: 5, isAcross: false),
        ],
      ),
      EnglishCrosswordLevel(
        id: 8,
        difficulty: CrosswordDifficulty.hard,
        rows: 11,
        cols: 13,
        words: [
          const EnglishCrosswordWord(word: 'HELICOPTER', clue: 'Máy bay trực thăng 🚁', row: 2, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'ELEPHANT', clue: 'Con voi 🐘', row: 2, col: 8, isAcross: false),
          const EnglishCrosswordWord(word: 'MOTORBIKE', clue: 'Xe máy 🏍️', row: 1, col: 6, isAcross: false),
          const EnglishCrosswordWord(word: 'TIGER', clue: 'Con hổ 🐯', row: 9, col: 8, isAcross: true),
        ],
      ),
      EnglishCrosswordLevel(
        id: 9,
        difficulty: CrosswordDifficulty.hard,
        rows: 11,
        cols: 10,
        words: [
          const EnglishCrosswordWord(word: 'STARFISH', clue: 'Sao biển ⭐', row: 2, col: 1, isAcross: true),
          const EnglishCrosswordWord(word: 'SEAHORSE', clue: 'Cá ngựa 🦄', row: 2, col: 1, isAcross: false),
          const EnglishCrosswordWord(word: 'JELLYFISH', clue: 'Con sứa biển 🪼', row: 9, col: 0, isAcross: true),
          const EnglishCrosswordWord(word: 'SHARK', clue: 'Cá mập 🦈', row: 2, col: 7, isAcross: false),
        ],
      ),
    ];
  }
}
