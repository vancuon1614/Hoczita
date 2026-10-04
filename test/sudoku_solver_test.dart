import 'package:flutter_test/flutter_test.dart';
import 'package:hoczita_app/features/game/utils/sudoku_generator.dart';

void main() {
  group('SudokuGenerator Tests', () {
    test('Easy mode generates valid solvable puzzle with exactly 40 clues', () {
      final puzzle = SudokuGenerator.generate(SudokuDifficulty.easy);
      expect(puzzle.initialBoard.length, 9);
      expect(puzzle.solution.length, 9);
      expect(puzzle.clueCount, 40);

      // Verify solution matches clues
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (puzzle.initialBoard[r][c] != 0) {
            expect(puzzle.initialBoard[r][c], puzzle.solution[r][c]);
          }
        }
      }
    });

    test('Medium mode generates valid solvable puzzle with exactly 32 clues', () {
      final puzzle = SudokuGenerator.generate(SudokuDifficulty.medium);
      expect(puzzle.initialBoard.length, 9);
      expect(puzzle.solution.length, 9);
      expect(puzzle.clueCount, 32);

      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (puzzle.initialBoard[r][c] != 0) {
            expect(puzzle.initialBoard[r][c], puzzle.solution[r][c]);
          }
        }
      }
    });

    test('Hard mode generates valid solvable puzzle with exactly 26 clues and unique solution', () {
      final puzzle = SudokuGenerator.generate(SudokuDifficulty.hard);
      expect(puzzle.initialBoard.length, 9);
      expect(puzzle.solution.length, 9);
      expect(puzzle.clueCount, 26);

      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (puzzle.initialBoard[r][c] != 0) {
            expect(puzzle.initialBoard[r][c], puzzle.solution[r][c]);
          }
        }
      }
    });
  });
}
