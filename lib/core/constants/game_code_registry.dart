/// Bảng quy chuẩn mã định danh trò chơi (Game Code Registry)
/// Đồng bộ thống nhất giữa NKS SCRMAI API và Supabase Database theo đặc tả App Queen (Basic)
class GameCodeRegistry {
  // --- MÃ TOÁN HỌC (M01 - M06) ---
  /// Đếm số nhanh (Mini Game)
  static const String mathCounting = 'M01';

  /// Tính nhanh / Phép tính toán học (Mini Game)
  static const String mathOperations = 'M02';

  /// So sánh trái phải (Mini Game)
  static const String mathComparison = 'M03';

  /// Ô chữ toán học (Main Game)
  static const String mathCrossword = 'M04';

  /// Sudoku (Main Game)
  static const String mathSudoku = 'M05';

  /// Zip / Đường đi con số (Main Game)
  static const String mathNumberPath = 'M06';

  // --- MÃ TIẾNG ANH (E01 - E06) ---
  /// Flashcard : Học qua thẻ từ (Mini Game)
  static const String englishFlashcard = 'E01';

  /// Memory Match : Lật hình trí nhớ (Mini Game)
  static const String englishMemoryMatch = 'E02';

  /// Picture Game : Đoán hình (Mini Game)
  static const String englishPictureGame = 'E03';

  /// Crossword : Ô chữ Tiếng Anh (Main Game)
  static const String englishCrossword = 'E04';

  /// Scramble : Xếp từ xáo trộn (Main Game)
  static const String englishWordScramble = 'E05';

  /// Magic : Từ ngữ kỳ diệu (Main Game)
  static const String englishMagicWords = 'E06';

  /// Ánh xạ từ tên nội bộ (internal identifier) sang mã game chuẩn
  static String getCodeFromInternalName(String internalName) {
    final clean = internalName.trim().toLowerCase();

    // Hỗ trợ bóc tách mã game nếu chuỗi có kèm level (ví dụ: "E01 - 1", "M02 - 2", "E01-1", "E01", v.v.)
    final match = RegExp(r'^(m0[1-6]|e0[1-6])\b', caseSensitive: false).firstMatch(clean);
    if (match != null) {
      return match.group(1)!.toUpperCase();
    }

    if (clean.startsWith('multiplication_table')) return mathOperations;
    if (clean.startsWith('math_ops')) return mathOperations;
    if (clean.startsWith('counting') || clean.startsWith('dem_so')) return mathCounting;
    if (clean.startsWith('comparison') || clean.startsWith('so_sanh')) return mathComparison;
    if (clean.startsWith('math_crossword')) return mathCrossword;
    if (clean.startsWith('sudoku')) return mathSudoku;
    if (clean.startsWith('magic_number_path') || clean.startsWith('number_path') || clean.startsWith('zip')) return mathNumberPath;
    if (clean.startsWith('flashcard')) return englishFlashcard;
    if (clean.startsWith('memory_match')) return englishMemoryMatch;
    if (clean.startsWith('picture_')) return englishPictureGame;
    if (clean.startsWith('english_crossword')) return englishCrossword;
    if (clean.startsWith('word_scramble') || clean.startsWith('scramble')) return englishWordScramble;
    if (clean.startsWith('magic_words')) return englishMagicWords;

    switch (clean) {
      // --- Toán (M) ---
      case 'counting':
      case 'dem_so_nhanh':
      case 'm01':
        return mathCounting; // M01

      case 'math_ops':
      case 'fast_calc':
      case 'tinh_nhanh':
      case 'multiplication_table':
      case 'm02':
        return mathOperations; // M02

      case 'comparison':
      case 'so_sanh_trai_phai':
      case 'so_sanh':
      case 'm03':
        return mathComparison; // M03

      case 'math_crossword':
      case 'math_crossword_easy':
      case 'math_crossword_medium':
      case 'math_crossword_hard':
      case 'm04':
        return mathCrossword; // M04

      case 'sudoku':
      case 'sudoku_easy':
      case 'sudoku_medium':
      case 'sudoku_hard':
      case 'm05':
        return mathSudoku; // M05

      case 'magic_number_path':
      case 'zip':
      case 'number_path':
      case 'm06':
        return mathNumberPath; // M06

      // --- Tiếng Anh (E) ---
      case 'flashcard':
      case 'flashcard_speed':
      case 'flashcard_study':
      case 'e01':
        return englishFlashcard; // E01

      case 'memory_match':
      case 'e02':
        return englishMemoryMatch; // E02

      case 'picture_guess':
      case 'picture_game':
      case 'e03':
        return englishPictureGame; // E03

      case 'english_crossword':
      case 'english_crossword_easy':
      case 'english_crossword_medium':
      case 'english_crossword_hard':
      case 'crossword':
      case 'e04':
        return englishCrossword; // E04

      case 'word_scramble':
      case 'scramble':
      case 'e05':
        return englishWordScramble; // E05

      case 'magic_words':
      case 'magic_words_easy':
      case 'magic_words_medium':
      case 'magic_words_hard':
      case 'magic':
      case 'e06':
        return englishMagicWords; // E06

      default:
        final upper = internalName.trim().toUpperCase();
        if (upper == 'M01' || upper == 'M02' || upper == 'M03' ||
            upper == 'M04' || upper == 'M05' || upper == 'M06' ||
            upper == 'E01' || upper == 'E02' || upper == 'E03' ||
            upper == 'E04' || upper == 'E05' || upper == 'E06') {
          return upper;
        }
        return internalName;
    }
  }

  /// Ánh xạ từ mode/difficulty (easy, medium, hard, ...) sang level (1, 2, 3)
  /// Nếu không có mode hoặc không xác định thì mặc định là '1'
  static String resolveLevel(dynamic modeOrLevel) {
    if (modeOrLevel == null) return '1';
    final s = modeOrLevel.toString().trim().toLowerCase();
    if (s == '1' || s == 'easy' || s == 'de' || s == 'dễ') return '1';
    if (s == '2' || s == 'medium' || s == 'vua' || s == 'vừa' || s == 'trung bình') return '2';
    if (s == '3' || s == 'hard' || s == 'kho' || s == 'khó') return '3';
    return '1';
  }

  /// Ánh xạ từ mã chuẩn sang tên tiếng Việt hiển thị
  static String getDisplayName(String gameCode) {
    switch (gameCode.toUpperCase()) {
      case mathCounting:
        return 'Đếm số nhanh';
      case mathOperations:
        return 'Tính nhanh';
      case mathComparison:
        return 'So sánh trái phải';
      case mathCrossword:
        return 'Ô chữ toán học';
      case mathSudoku:
        return 'Sudoku';
      case mathNumberPath:
        return 'Zip (Đường đi số)';
      case englishFlashcard:
        return 'Flashcard';
      case englishMemoryMatch:
        return 'Lật hình trí nhớ';
      case englishPictureGame:
        return 'Nhìn hình đoán chữ';
      case englishCrossword:
        return 'Ô chữ Tiếng Anh';
      case englishWordScramble:
        return 'Xếp từ đảo chữ';
      case englishMagicWords:
        return 'Từ ngữ kỳ diệu';
      default:
        return gameCode;
    }
  }

  /// Kiểm tra xem một trò chơi có phải là môn Tiếng Anh hay không (dựa trên mã E01..E06 hoặc tên)
  static bool isEnglishGame(String gameCodeOrName) {
    final cleanCode = getCodeFromInternalName(gameCodeOrName).toUpperCase();
    if (cleanCode.startsWith('E')) return true;
    final clean = gameCodeOrName.trim().toLowerCase();
    return clean.contains('english') ||
        clean.contains('flashcard') ||
        clean.contains('picture') ||
        clean.contains('memory') ||
        clean.contains('scramble') ||
        clean.contains('magic_words');
  }

  /// Tên tiếng Anh chuẩn cho các game
  static String getEnglishDisplayName(String gameCodeOrName) {
    final cleanCode = getCodeFromInternalName(gameCodeOrName).toUpperCase();
    switch (cleanCode) {
      case englishFlashcard:
        return 'Flashcard Speed Run';
      case englishMemoryMatch:
        return 'Memory Match';
      case englishPictureGame:
        return 'Picture Guess';
      case englishCrossword:
        return 'English Crossword';
      case englishWordScramble:
        return 'Word Scramble';
      case englishMagicWords:
        return 'Magic Words';
      default:
        return gameCodeOrName;
    }
  }
}
