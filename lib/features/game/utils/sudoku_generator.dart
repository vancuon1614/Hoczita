import 'dart:math';

enum SudokuDifficulty {
  easy('Dễ', 42),
  medium('Trung bình', 34),
  hard('Khó', 29),
  expert('Chuyên gia', 25),
  master('Bậc thầy', 22),
  extreme('Cực khó', 19);

  final String label;
  final int targetClues;
  const SudokuDifficulty(this.label, this.targetClues);
}

class SudokuPuzzle {
  final List<List<int>> initialBoard; // 0 for empty, 1-9 for clues
  final List<List<int>> solution;     // 1-9 complete solved board
  final SudokuDifficulty difficulty;

  const SudokuPuzzle({
    required this.initialBoard,
    required this.solution,
    required this.difficulty,
  });

  int get clueCount {
    int count = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (initialBoard[r][c] != 0) count++;
      }
    }
    return count;
  }
}

class SudokuGenerator {
  static final Random _rand = Random();

  /// Sinh một đề Sudoku hoàn chỉnh theo cấp độ khó được chọn
  static SudokuPuzzle generate(SudokuDifficulty difficulty) {
    // 1. Sinh một bảng Sudoku hoàn chỉnh ngẫu nhiên hợp lệ
    final solution = _generateSolvedBoard();

    // 2. Tạo bản sao để đục lỗ (remove clues)
    final board = List.generate(9, (r) => List<int>.from(solution[r]));

    // 3. Đục lỗ có kiểm tra nghiệm duy nhất để đạt số clue mục tiêu
    _removeNumbersToTarget(board, difficulty.targetClues);

    return SudokuPuzzle(
      initialBoard: board,
      solution: solution,
      difficulty: difficulty,
    );
  }

  /// Sinh bảng 9x9 đã giải đầy đủ hợp lệ
  static List<List<int>> _generateSolvedBoard() {
    final board = List.generate(9, (_) => List.filled(9, 0));
    _fillBoard(board);
    return board;
  }

  /// Đệ quy điền các số ngẫu nhiên vào bảng trống
  static bool _fillBoard(List<List<int>> board) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] == 0) {
          final numbers = List<int>.generate(9, (i) => i + 1)..shuffle(_rand);
          for (final num in numbers) {
            if (_isValidPlacement(board, r, c, num)) {
              board[r][c] = num;
              if (_fillBoard(board)) return true;
              board[r][c] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  /// Kiểm tra tính hợp lệ khi đặt `num` vào `(row, col)`
  static bool _isValidPlacement(List<List<int>> board, int row, int col, int num) {
    // Kiểm tra hàng
    for (int c = 0; c < 9; c++) {
      if (board[row][c] == num) return false;
    }
    // Kiểm tra cột
    for (int r = 0; r < 9; r++) {
      if (board[r][col] == num) return false;
    }
    // Kiểm tra khối 3x3
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (board[boxRow + r][boxCol + c] == num) return false;
      }
    }
    return true;
  }

  /// Đục lỗ dần từ 81 ô xuống mục tiêu, đảm bảo luôn có duy nhất 1 nghiệm
  static void _removeNumbersToTarget(List<List<int>> board, int targetClues) {
    // Danh sách tất cả các tọa độ ô (0..80) xáo trộn ngẫu nhiên
    final positions = List<int>.generate(81, (i) => i)..shuffle(_rand);

    int currentClues = 81;

    for (final pos in positions) {
      if (currentClues <= targetClues) break;

      final r = pos ~/ 9;
      final c = pos % 9;

      final backup = board[r][c];
      board[r][c] = 0;

      // Đếm số nghiệm: nếu nghiệm duy nhất == 1 thì giữ lại việc xóa ô này
      final solutions = _countSolutions(board, limit: 2);
      if (solutions == 1) {
        currentClues--;
      } else {
        // Có nhiều hơn 1 nghiệm -> khôi phục lại ô
        board[r][c] = backup;
      }
    }
  }

  /// Đếm số nghiệm của bảng hiện tại (dừng lại khi đếm tới `limit`)
  static int _countSolutions(List<List<int>> board, {int limit = 2}) {
    int count = 0;

    void solve(int r, int c) {
      if (count >= limit) return;

      if (r == 9) {
        count++;
        return;
      }

      final nextR = (c == 8) ? r + 1 : r;
      final nextC = (c == 8) ? 0 : c + 1;

      if (board[r][c] != 0) {
        solve(nextR, nextC);
      } else {
        for (int num = 1; num <= 9; num++) {
          if (_isValidPlacement(board, r, c, num)) {
            board[r][c] = num;
            solve(nextR, nextC);
            board[r][c] = 0;
            if (count >= limit) return;
          }
        }
      }
    }

    solve(0, 0);
    return count;
  }

  /// Kiểm tra xem một nước đi có hợp lệ với tình trạng bàn cờ hiện tại không
  static bool isValidMove(List<List<int>> board, int row, int col, int num) {
    return _isValidPlacement(board, row, col, num);
  }

  /// Tìm tất cả các ô xung đột (trùng hàng, cột hoặc khối 3x3)
  static Set<int> findConflictingCells(List<List<int>> currentBoard) {
    final conflicts = <int>{};

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final val = currentBoard[r][c];
        if (val == 0) continue;

        // Check hàng
        for (int otherC = 0; otherC < 9; otherC++) {
          if (otherC != c && currentBoard[r][otherC] == val) {
            conflicts.add(r * 9 + c);
            conflicts.add(r * 9 + otherC);
          }
        }

        // Check cột
        for (int otherR = 0; otherR < 9; otherR++) {
          if (otherR != r && currentBoard[otherR][c] == val) {
            conflicts.add(r * 9 + c);
            conflicts.add(otherR * 9 + c);
          }
        }

        // Check khối 3x3
        final boxR = (r ~/ 3) * 3;
        final boxC = (c ~/ 3) * 3;
        for (int br = 0; br < 3; br++) {
          for (int bc = 0; bc < 3; bc++) {
            final cr = boxR + br;
            final cc = boxC + bc;
            if ((cr != r || cc != c) && currentBoard[cr][cc] == val) {
              conflicts.add(r * 9 + c);
              conflicts.add(cr * 9 + cc);
            }
          }
        }
      }
    }

    return conflicts;
  }
}
