import 'package:flutter_test/flutter_test.dart';
import 'package:hoczita_app/features/game/utils/wend_puzzle_generator.dart';

void main() {
  group('WendPuzzleGenerator Tests', () {
    test('Easy difficulty generates 5x5 grid with 3 words', () {
      for (int i = 0; i < 20; i++) {
        final puzzle = WendPuzzleGenerator.generate(difficulty: MagicWordsDifficulty.easy);
        expect(puzzle.rows, equals(5));
        expect(puzzle.cols, equals(5));
        expect(puzzle.targetWords.length, equals(3));
        expect(puzzle.gridStr.length, equals(5));
        expect(puzzle.gridStr[0].length, equals(5));

        // Check word lengths
        for (var w in puzzle.targetWords) {
          expect(w.length >= 3 && w.length <= 4, isTrue);
          expect(puzzle.wordPaths.containsKey(w), isTrue);
          expect(puzzle.wordPaths[w]!.length, equals(w.length));
        }
      }
    });

    test('Medium difficulty generates 6x6 grid with 4 words', () {
      for (int i = 0; i < 20; i++) {
        final puzzle = WendPuzzleGenerator.generate(difficulty: MagicWordsDifficulty.medium);
        expect(puzzle.rows, equals(6));
        expect(puzzle.cols, equals(6));
        expect(puzzle.targetWords.length, equals(4));
        expect(puzzle.gridStr.length, equals(6));
        expect(puzzle.gridStr[0].length, equals(6));

        for (var w in puzzle.targetWords) {
          expect(w.length >= 3 && w.length <= 5, isTrue);
          expect(puzzle.wordPaths.containsKey(w), isTrue);
          expect(puzzle.wordPaths[w]!.length, equals(w.length));
        }
      }
    });

    test('Hard difficulty generates 7x7 or 8x8 grid with 5 or 6 words', () {
      for (int i = 0; i < 20; i++) {
        final puzzle = WendPuzzleGenerator.generate(difficulty: MagicWordsDifficulty.hard);
        expect(puzzle.rows >= 7 && puzzle.rows <= 8, isTrue);
        expect(puzzle.cols, equals(puzzle.rows));
        expect(puzzle.targetWords.length >= 5 && puzzle.targetWords.length <= 6, isTrue);

        for (var w in puzzle.targetWords) {
          expect(w.length >= 4 && w.length <= 7, isTrue);
          expect(puzzle.wordPaths.containsKey(w), isTrue);
          expect(puzzle.wordPaths[w]!.length, equals(w.length));
        }
      }
    });
  });
}
