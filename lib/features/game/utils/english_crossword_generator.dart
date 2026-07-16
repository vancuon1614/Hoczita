import 'dart:math';
import '../models/english_crossword_level.dart';
import '../views/english_crossword_game_screen.dart'; // For WordClue definition

class PlacedWord {
  final String word;
  final String clue;
  final int row;
  final int col;
  final bool isAcross;

  PlacedWord({
    required this.word,
    required this.clue,
    required this.row,
    required this.col,
    required this.isAcross,
  });
}

class EnglishCrosswordGenerator {
  static final Random _rng = Random();

  static EnglishCrosswordLevel generate({
    required CrosswordDifficulty difficulty,
    required List<WordClue> vocabPool,
  }) {
    int targetCount = 5;
    int gridSize = 11;

    if (difficulty == CrosswordDifficulty.medium) {
      targetCount = 9;
      gridSize = 15;
    } else if (difficulty == CrosswordDifficulty.hard) {
      targetCount = 14;
      gridSize = 19;
    }

    for (int attempt = 0; attempt < 200; attempt++) {
      // Create empty working grid
      final grid = List<List<String>>.generate(
        gridSize,
        (_) => List<String>.generate(gridSize, (_) => ''),
      );

      final placedWords = <PlacedWord>[];
      final usedWordStrings = <String>{};

      // 1. Pick a random starting word
      final shuffledPool = List<WordClue>.from(vocabPool)..shuffle(_rng);
      final firstClue = shuffledPool.first;
      final firstWord = firstClue.word.toUpperCase();
      final firstIsAcross = _rng.nextBool();

      final mid = gridSize ~/ 2;
      final startR = firstIsAcross ? mid : mid - (firstWord.length ~/ 2);
      final startC = firstIsAcross ? mid - (firstWord.length ~/ 2) : mid;

      // Ensure start positions are inside grid boundaries
      final clampedStartR = startR.clamp(0, gridSize - 1);
      final clampedStartC = startC.clamp(0, gridSize - 1);

      // Verify first word fits
      final firstLength = firstWord.length;
      if (firstIsAcross) {
        if (clampedStartC + firstLength > gridSize) continue;
      } else {
        if (clampedStartR + firstLength > gridSize) continue;
      }

      // Write first word
      for (int i = 0; i < firstLength; i++) {
        final r = firstIsAcross ? clampedStartR : clampedStartR + i;
        final c = firstIsAcross ? clampedStartC + i : clampedStartC;
        grid[r][c] = firstWord[i];
      }

      placedWords.add(PlacedWord(
        word: firstWord,
        clue: firstClue.clue,
        row: clampedStartR,
        col: clampedStartC,
        isAcross: firstIsAcross,
      ));
      usedWordStrings.add(firstWord);

      // 2. Iteratively place remaining words using intersections
      int fails = 0;
      while (placedWords.length < targetCount && fails < 250) {
        // Collect all possible intersection cells on the grid
        final intersections = <Map<String, dynamic>>[];
        for (int r = 0; r < gridSize; r++) {
          for (int c = 0; c < gridSize; c++) {
            if (grid[r][c].isNotEmpty) {
              // Find which placed word covers this cell
              for (int wIdx = 0; wIdx < placedWords.length; wIdx++) {
                final pw = placedWords[wIdx];
                final int cellCharIdx = _getCellIndexInWord(pw, r, c);
                if (cellCharIdx != -1) {
                  intersections.add({
                    'r': r,
                    'c': c,
                    'char': grid[r][c],
                    'parentWordIdx': wIdx,
                    'isParentAcross': pw.isAcross,
                  });
                }
              }
            }
          }
        }

        intersections.shuffle(_rng);
        bool placedAny = false;

        for (final anchor in intersections) {
          final int r = anchor['r'];
          final int c = anchor['c'];
          final String char = anchor['char'];
          final bool isParentAcross = anchor['isParentAcross'];
          final bool newIsAcross = !isParentAcross; // Must be perpendicular

          // Search for a word from pool that contains this character
          final candidates = shuffledPool
              .where((wc) => !usedWordStrings.contains(wc.word.toUpperCase()))
              .toList();

          for (final wc in candidates) {
            final wordStr = wc.word.toUpperCase();
            final matches = _getAllIndicesOfChar(wordStr, char);

            for (final charIdx in matches) {
              final newStartR = newIsAcross ? r : r - charIdx;
              final newStartC = newIsAcross ? c - charIdx : c;

              // Check grid boundaries
              if (newStartR < 0 || newStartC < 0) continue;
              if (newIsAcross) {
                if (newStartC + wordStr.length > gridSize) continue;
              } else {
                if (newStartR + wordStr.length > gridSize) continue;
              }

              bool sharesStartCell = false;
              for (final pw in placedWords) {
                if (pw.row == newStartR && pw.col == newStartC) {
                  sharesStartCell = true;
                  break;
                }
              }
              if (sharesStartCell) continue;

              // Check layout constraints & adjacency rules
              if (_canPlaceWord(
                grid: grid,
                word: wordStr,
                startRow: newStartR,
                startCol: newStartC,
                isAcross: newIsAcross,
                intersectionRow: r,
                intersectionCol: c,
                gridSize: gridSize,
              )) {
                // Write word to grid
                for (int i = 0; i < wordStr.length; i++) {
                  final curR = newIsAcross ? newStartR : newStartR + i;
                  final curC = newIsAcross ? newStartC + i : newStartC;
                  grid[curR][curC] = wordStr[i];
                }

                placedWords.add(PlacedWord(
                  word: wordStr,
                  clue: wc.clue,
                  row: newStartR,
                  col: newStartC,
                  isAcross: newIsAcross,
                ));
                usedWordStrings.add(wordStr);
                placedAny = true;
                break;
              }
            }
            if (placedAny) break;
          }
          if (placedAny) break;
        }

        if (!placedAny) {
          fails++;
        } else {
          fails = 0; // reset failures on success
        }
      }

      // Check completeness against relaxed target count
      final minAcceptedCount = attempt > 150
          ? targetCount - 2
          : attempt > 80
              ? targetCount - 1
              : targetCount;

      if (placedWords.length >= minAcceptedCount) {
        // Calculate the bounding box of placed words to crop empty space and center the grid
        int minR = gridSize;
        int maxR = 0;
        int minC = gridSize;
        int maxC = 0;

        for (final pw in placedWords) {
          final len = pw.word.length;
          if (pw.isAcross) {
            minR = min(minR, pw.row);
            maxR = max(maxR, pw.row);
            minC = min(minC, pw.col);
            maxC = max(maxC, pw.col + len - 1);
          } else {
            minR = min(minR, pw.row);
            maxR = max(maxR, pw.row + len - 1);
            minC = min(minC, pw.col);
            maxC = max(maxC, pw.col);
          }
        }

        // Add 1 cell margin/padding for visual elegance
        const pad = 1;
        final croppedMinR = (minR - pad).clamp(0, gridSize - 1);
        final croppedMaxR = (maxR + pad).clamp(0, gridSize - 1);
        final croppedMinC = (minC - pad).clamp(0, gridSize - 1);
        final croppedMaxC = (maxC + pad).clamp(0, gridSize - 1);

        final croppedRows = croppedMaxR - croppedMinR + 1;
        final croppedCols = croppedMaxC - croppedMinC + 1;

        // Shift coordinates of all placed words to fit the cropped grid
        final finalWords = placedWords.map((pw) {
          return EnglishCrosswordWord(
            word: pw.word,
            clue: pw.clue,
            row: pw.row - croppedMinR,
            col: pw.col - croppedMinC,
            isAcross: pw.isAcross,
          );
        }).toList();

        return EnglishCrosswordLevel(
          id: _rng.nextInt(1000000),
          difficulty: difficulty,
          rows: croppedRows,
          cols: croppedCols,
          words: finalWords,
        );
      }
    }

    // Absolutely safe fallback if all attempts fail
    return EnglishCrosswordLevel(
      id: 0,
      difficulty: difficulty,
      rows: 5,
      cols: 5,
      words: const [
        EnglishCrosswordWord(word: 'CAT', clue: 'Con mèo', row: 1, col: 1, isAcross: true),
        EnglishCrosswordWord(word: 'CAR', clue: 'Ô tô', row: 1, col: 1, isAcross: false),
      ],
    );
  }

  static int _getCellIndexInWord(PlacedWord pw, int r, int c) {
    if (pw.isAcross) {
      if (r == pw.row && c >= pw.col && c < pw.col + pw.word.length) {
        return c - pw.col;
      }
    } else {
      if (c == pw.col && r >= pw.row && r < pw.row + pw.word.length) {
        return r - pw.row;
      }
    }
    return -1;
  }

  static List<int> _getAllIndicesOfChar(String word, String char) {
    final indices = <int>[];
    for (int i = 0; i < word.length; i++) {
      if (word[i] == char) {
        indices.add(i);
      }
    }
    return indices;
  }

  static bool _canPlaceWord({
    required List<List<String>> grid,
    required String word,
    required int startRow,
    required int startCol,
    required bool isAcross,
    required int intersectionRow,
    required int intersectionCol,
    required int gridSize,
  }) {
    // 1. Check surrounding spaces of the word terminals (ends)
    if (isAcross) {
      // Cell before the start of the word
      if (startCol - 1 >= 0) {
        if (grid[startRow][startCol - 1].isNotEmpty) return false;
      }
      // Cell after the end of the word
      if (startCol + word.length < gridSize) {
        if (grid[startRow][startCol + word.length].isNotEmpty) return false;
      }
    } else {
      // Cell above the start of the word
      if (startRow - 1 >= 0) {
        if (grid[startRow - 1][startCol].isNotEmpty) return false;
      }
      // Cell below the end of the word
      if (startRow + word.length < gridSize) {
        if (grid[startRow + word.length][startCol].isNotEmpty) return false;
      }
    }

    // 2. Verify each character position inside the word path
    for (int i = 0; i < word.length; i++) {
      final r = isAcross ? startRow : startRow + i;
      final c = isAcross ? startCol + i : startCol;

      // If it is the intersection cell
      if (r == intersectionRow && c == intersectionCol) {
        if (grid[r][c] != word[i]) return false;
        continue;
      }

      // If it is any other cell, it MUST be empty
      if (grid[r][c].isNotEmpty) return false;

      // Check parallel neighbors to ensure we don't place words side-by-side
      if (isAcross) {
        // Across word: check cells above and below
        if (r - 1 >= 0 && grid[r - 1][c].isNotEmpty) return false;
        if (r + 1 < gridSize && grid[r + 1][c].isNotEmpty) return false;
      } else {
        // Down word: check cells left and right
        if (c - 1 >= 0 && grid[r][c - 1].isNotEmpty) return false;
        if (c + 1 < gridSize && grid[r][c + 1].isNotEmpty) return false;
      }
    }

    return true;
  }
}
