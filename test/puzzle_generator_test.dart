import 'package:flutter_test/flutter_test.dart';
import 'package:hoczita_app/features/game/utils/wend_puzzle_generator.dart';

void main() {
  group('WendPuzzleGenerator Tests', () {
    test('Easy mode: 4x4, 3 words, 3-5 chars, blockers 2-4', () {
      for (int i = 0; i < 20; i++) {
        final puzzle = WendPuzzleGenerator.generate(difficulty: MagicWordsDifficulty.easy);
        expect(puzzle.rows, equals(4));
        expect(puzzle.cols, equals(4));
        expect(puzzle.targetWords.length, equals(3));

        int totalLetters = 0;
        for (var w in puzzle.targetWords) {
          expect(w.length >= 3 && w.length <= 5, isTrue);
          expect(puzzle.wordPaths.containsKey(w), isTrue);
          expect(puzzle.wordPaths[w]!.length, equals(w.length));
          totalLetters += w.length;
        }

        int blockerCount = 16 - totalLetters;
        expect(blockerCount >= 2 && blockerCount <= 4, isTrue,
            reason: 'Blocker count should be 2-4, got $blockerCount');
      }
    });

    test('Medium mode: 6x6, 4 words, 5-8 chars', () {
      for (int i = 0; i < 15; i++) {
        final puzzle = WendPuzzleGenerator.generate(difficulty: MagicWordsDifficulty.medium);
        expect(puzzle.rows, equals(6));
        expect(puzzle.cols, equals(6));
        expect(puzzle.targetWords.length, equals(4));
        for (var w in puzzle.targetWords) {
          expect(w.length >= 5 && w.length <= 8, isTrue);
          expect(puzzle.wordPaths.containsKey(w), isTrue);
          expect(puzzle.wordPaths[w]!.length, equals(w.length));
        }
      }
    });

    test('Hard mode: 8x8, 4-5 words, 8-11 chars', () {
      for (int i = 0; i < 10; i++) {
        final puzzle = WendPuzzleGenerator.generate(difficulty: MagicWordsDifficulty.hard);
        expect(puzzle.rows, equals(8));
        expect(puzzle.cols, equals(8));
        expect(puzzle.targetWords.length >= 4 && puzzle.targetWords.length <= 5, isTrue);
        for (var w in puzzle.targetWords) {
          expect(w.length >= 8 && w.length <= 11, isTrue);
          expect(puzzle.wordPaths.containsKey(w), isTrue);
          expect(puzzle.wordPaths[w]!.length, equals(w.length));
        }
      }
    });
  });
}
