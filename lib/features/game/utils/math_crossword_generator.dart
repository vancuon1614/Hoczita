import 'dart:math';

enum PuzzleCellType { empty, number, operator, equals }
enum CrosswordOrientation { horizontal, vertical }
enum Difficulty { easy, medium, hard }

class WorkingCell {
  final PuzzleCellType type;
  final String value;
  final List<String> equationIds;

  WorkingCell({
    this.type = PuzzleCellType.empty,
    this.value = '',
    List<String>? equationIds,
  }) : equationIds = equationIds ?? [];
}

class Equation {
  final String id;
  final CrosswordOrientation orientation;
  final int r;
  final int c;
  final int num1;
  final String op;
  final int num2;
  final int num3;
  final bool isReversed;

  Equation({
    required this.id,
    required this.orientation,
    required this.r,
    required this.c,
    required this.num1,
    required this.op,
    required this.num2,
    required this.num3,
    required this.isReversed,
  });
}

class Cell {
  final int r;
  final int c;
  final PuzzleCellType type;
  final String value;
  String userValue;
  bool isLocked;
  final List<String> equationIds;

  Cell({
    required this.r,
    required this.c,
    required this.type,
    required this.value,
    required this.userValue,
    required this.isLocked,
    required this.equationIds,
  });
}

class Puzzle {
  final Difficulty difficulty;
  final int gridSize;
  final List<List<Cell>> grid;
  final List<Equation> equations;

  Puzzle({
    required this.difficulty,
    required this.gridSize,
    required this.grid,
    required this.equations,
  });
}

final Random _rng = Random();

List<T> _shuffle<T>(List<T> array) {
  final arr = List<T>.from(array);
  for (int i = arr.length - 1; i > 0; i--) {
    final j = _rng.nextInt(i + 1);
    final tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

class _MathEq {
  final int num1;
  final String op;
  final int num2;
  final int num3;
  _MathEq(this.num1, this.op, this.num2, this.num3);
}

_MathEq? _generateMathEquation(
  int fixedValue,
  int fixedIndex, // 0, 2, or 4
  List<String> allowedOps,
) {
  final ops = _shuffle(List<String>.from(allowedOps));

  for (final op in ops) {
    if (fixedIndex == 0) {
      final num1 = fixedValue;
      if (op == '+') {
        final num2 = _rng.nextInt(101 - num1);
        final num3 = num1 + num2;
        if (num3 <= 100) return _MathEq(num1, op, num2, num3);
      } else if (op == '-') {
        final num2 = _rng.nextInt(num1 + 1);
        final num3 = num1 - num2;
        if (num3 >= 0) return _MathEq(num1, op, num2, num3);
      } else if (op == 'x' || op == '*') {
        if (num1 == 0) {
          final num2 = _rng.nextInt(101);
          return _MathEq(num1, op, num2, 0);
        }
        final maxNum2 = (100 / num1).floor();
        if (maxNum2 >= 0) {
          final num2 = _rng.nextInt(maxNum2 + 1);
          final num3 = num1 * num2;
          if (num3 <= 100) return _MathEq(num1, op, num2, num3);
        }
      } else if (op == '/') {
        final factors = <int>[];
        for (int i = 1; i <= num1; i++) {
          if (num1 % i == 0) factors.add(i);
        }
        if (factors.isNotEmpty) {
          final num2 = factors[_rng.nextInt(factors.length)];
          final num3 = num1 ~/ num2;
          return _MathEq(num1, op, num2, num3);
        }
      }
    } else if (fixedIndex == 2) {
      final num2 = fixedValue;
      if (op == '+') {
        final num1 = _rng.nextInt(101 - num2);
        final num3 = num1 + num2;
        if (num3 <= 100) return _MathEq(num1, op, num2, num3);
      } else if (op == '-') {
        final num1 = num2 + _rng.nextInt(101 - num2);
        final num3 = num1 - num2;
        if (num3 >= 0 && num3 <= 100) return _MathEq(num1, op, num2, num3);
      } else if (op == 'x' || op == '*') {
        if (num2 == 0) {
          final num1 = _rng.nextInt(101);
          return _MathEq(num1, op, num2, 0);
        }
        final maxNum1 = (100 / num2).floor();
        if (maxNum1 >= 0) {
          final num1 = _rng.nextInt(maxNum1 + 1);
          final num3 = num1 * num2;
          if (num3 <= 100) return _MathEq(num1, op, num2, num3);
        }
      } else if (op == '/') {
        if (num2 > 0) {
          final maxNum3 = (100 / num2).floor();
          if (maxNum3 >= 0) {
            final num3 = _rng.nextInt(maxNum3 + 1);
            final num1 = num3 * num2;
            if (num1 <= 100) return _MathEq(num1, op, num2, num3);
          }
        }
      }
    } else if (fixedIndex == 4) {
      final num3 = fixedValue;
      if (op == '+') {
        final num1 = _rng.nextInt(num3 + 1);
        final num2 = num3 - num1;
        return _MathEq(num1, op, num2, num3);
      } else if (op == '-') {
        final num1 = num3 + _rng.nextInt(101 - num3);
        final num2 = num1 - num3;
        if (num2 >= 0 && num2 <= 100) return _MathEq(num1, op, num2, num3);
      } else if (op == 'x' || op == '*') {
        if (num3 == 0) {
          final num1 = _rng.nextInt(101);
          return _MathEq(num1, op, 0, num3);
        }
        final pairs = <List<int>>[];
        for (int i = 1; i <= sqrt(num3).floor(); i++) {
          if (num3 % i == 0) {
            pairs.add([i, num3 ~/ i]);
            if (i != num3 ~/ i) {
              pairs.add([num3 ~/ i, i]);
            }
          }
        }
        if (pairs.isNotEmpty) {
          final pair = pairs[_rng.nextInt(pairs.length)];
          return _MathEq(pair[0], op, pair[1], num3);
        }
      } else if (op == '/') {
        if (num3 == 0) {
          final num2 = _rng.nextInt(100) + 1;
          return _MathEq(0, op, num2, num3);
        }
        final maxNum2 = (100 / num3).floor();
        if (maxNum2 >= 1) {
          final num2 = _rng.nextInt(maxNum2) + 1;
          final num1 = num2 * num3;
          if (num1 <= 100) return _MathEq(num1, op, num2, num3);
        }
      }
    }
  }

  return null;
}

_MathEq _generateRandomEquation(List<String> allowedOps) {
  while (true) {
    final op = allowedOps[_rng.nextInt(allowedOps.length)];
    if (op == '+') {
      final num1 = _rng.nextInt(90) + 1;
      final num2 = _rng.nextInt(100 - num1) + 1;
      final num3 = num1 + num2;
      return _MathEq(num1, op, num2, num3);
    } else if (op == '-') {
      final num1 = _rng.nextInt(90) + 10;
      final num2 = _rng.nextInt(num1 - 2) + 1;
      final num3 = num1 - num2;
      return _MathEq(num1, op, num2, num3);
    } else if (op == 'x' || op == '*') {
      final num1 = _rng.nextInt(10) + 2;
      final num2 = _rng.nextInt((100 / num1).floor()) + 1;
      final num3 = num1 * num2;
      return _MathEq(num1, op, num2, num3);
    } else if (op == '/') {
      final num2 = _rng.nextInt(10) + 2;
      final num3 = _rng.nextInt(10) + 2;
      final num1 = num2 * num3;
      if (num1 <= 100) {
        return _MathEq(num1, op, num2, num3);
      }
    }
  }
}

class _EqLayout {
  final List<String> values;
  final List<PuzzleCellType> types;
  _EqLayout(this.values, this.types);
}

_EqLayout _layoutFor(_MathEq eq, bool isReversed) {
  final values = isReversed
      ? [
          eq.num3.toString(),
          '=',
          eq.num1.toString(),
          eq.op,
          eq.num2.toString(),
        ]
      : [
          eq.num1.toString(),
          eq.op,
          eq.num2.toString(),
          '=',
          eq.num3.toString(),
        ];

  final types = isReversed
      ? [
          PuzzleCellType.number,
          PuzzleCellType.equals,
          PuzzleCellType.number,
          PuzzleCellType.operator,
          PuzzleCellType.number,
        ]
      : [
          PuzzleCellType.number,
          PuzzleCellType.operator,
          PuzzleCellType.number,
          PuzzleCellType.equals,
          PuzzleCellType.number,
        ];

  return _EqLayout(values, types);
}

class _OpenCell {
  final int r;
  final int c;
  final int value;
  final String parentEqId;
  _OpenCell(this.r, this.c, this.value, this.parentEqId);
}

Puzzle generatePuzzle(Difficulty difficulty) {
  int targetCount = 6;
  int gridSize = 9; 
  List<String> allowedOps = ['+', '-'];

  if (difficulty == Difficulty.medium) {
    targetCount = 12;
    gridSize = 13; 
    allowedOps = ['+', '-', 'x'];
  } else if (difficulty == Difficulty.hard) {
    targetCount = 20;
    gridSize = 17; 
    allowedOps = ['+', '-', 'x', '/'];
  }

  // Attempt generation multiple times (crossword fitting is stochastic).
  for (int attempt = 0; attempt < 500; attempt++) {
    // Create an empty working grid.
    final cellGrid = List<List<WorkingCell>>.generate(
      gridSize,
      (_) => List<WorkingCell>.generate(gridSize, (_) => WorkingCell()),
    );

    final equations = <Equation>[];

    // Place the first equation in the middle.
    final startEq = _generateRandomEquation(allowedOps);
    final startOrientation =
        _rng.nextDouble() > 0.5 ? CrosswordOrientation.horizontal : CrosswordOrientation.vertical;
    final midR = gridSize ~/ 2;
    final midC = gridSize ~/ 2;

    const eqId0 = 'eq_0';
    final startR =
        startOrientation == CrosswordOrientation.horizontal ? midR : midR - 2;
    final startC =
        startOrientation == CrosswordOrientation.horizontal ? midC - 2 : midC;

    // Is reversed? Sometimes write C = A op B instead of A op B = C.
    final isReversed = _rng.nextDouble() > 0.7;
    final startLayout = _layoutFor(startEq, isReversed);

    // Write first equation.
    for (int idx = 0; idx < 5; idx++) {
      final curR = startOrientation == CrosswordOrientation.horizontal ? startR : startR + idx;
      final curC = startOrientation == CrosswordOrientation.horizontal ? startC + idx : startC;

      cellGrid[curR][curC] = WorkingCell(
        type: startLayout.types[idx],
        value: startLayout.values[idx],
        equationIds: [eqId0],
      );
    }

    equations.add(Equation(
      id: eqId0,
      orientation: startOrientation,
      r: startR,
      c: startC,
      num1: startEq.num1,
      op: startEq.op,
      num2: startEq.num2,
      num3: startEq.num3,
      isReversed: isReversed,
    ));

    // We will keep a list of open cells we can branch from.
    List<_OpenCell> openNumberCells = [];

    void updateOpenCells() {
      openNumberCells = [];
      for (final eq in equations) {
        // Number cells are indices 0, 2, 4 in standard/reversed equations.
        const indices = [0, 2, 4];
        for (final idx in indices) {
          final cellR = eq.orientation == CrosswordOrientation.horizontal ? eq.r : eq.r + idx;
          final cellC = eq.orientation == CrosswordOrientation.horizontal ? eq.c + idx : eq.c;

          int numVal = eq.num1;
          if (idx == 2) numVal = eq.num2;
          if (idx == 4) numVal = eq.num3;

          openNumberCells.add(_OpenCell(cellR, cellC, numVal, eq.id));
        }
      }
    }

    updateOpenCells();

    int fails = 0;
    while (equations.length < targetCount && fails < 300) {
      updateOpenCells();
      if (openNumberCells.isEmpty) break;

      // Pick a random open cell.
      final anchor = openNumberCells[_rng.nextInt(openNumberCells.length)];
      final parentEq = equations.firstWhere((e) => e.id == anchor.parentEqId);

      // Orthogonal growth.
      final newOrientation = parentEq.orientation == CrosswordOrientation.horizontal
          ? CrosswordOrientation.vertical
          : CrosswordOrientation.horizontal;

      // The anchor cell will be one of the number indices in the new
      // equation: 0 (num1), 2 (num2), or 4 (num3).
      const possibleIndices = [0, 2, 4];
      final newIndex = possibleIndices[_rng.nextInt(possibleIndices.length)];

      final newIsReversed = _rng.nextDouble() > 0.7;

      // Translate the math variable index (num1=0, num2=2, num3=4) to the
      // physical cell index in the 5-cell sequence.
      // Standard: num1 (cell 0), num2 (cell 2), num3 (cell 4)
      // Reversed: num3 (cell 0), num1 (cell 2), num2 (cell 4)
      int mathFixedIndex = 0;
      if (newIndex == 0) {
        mathFixedIndex = newIsReversed ? 4 : 0;
      } else if (newIndex == 2) {
        mathFixedIndex = newIsReversed ? 0 : 2;
      } else if (newIndex == 4) {
        mathFixedIndex = newIsReversed ? 2 : 4;
      }

      // Generate math values.
      final mathEq = _generateMathEquation(anchor.value, mathFixedIndex, allowedOps);
      if (mathEq == null) {
        fails++;
        continue;
      }

      // Start position of the new equation.
      final newR = newOrientation == CrosswordOrientation.horizontal ? anchor.r : anchor.r - newIndex;
      final newC = newOrientation == CrosswordOrientation.horizontal ? anchor.c - newIndex : anchor.c;

      // Boundary check.
      if (newR < 1 ||
          newC < 1 ||
          (newOrientation == CrosswordOrientation.horizontal && newC + 4 >= gridSize - 1) ||
          (newOrientation == CrosswordOrientation.vertical && newR + 4 >= gridSize - 1)) {
        fails++;
        continue;
      }

      // Rule 1: No two equations of the same orientation should share the
      // same row/column. This completely prevents equations from being
      // inline/sequential on the same row/column.
      if (newOrientation == CrosswordOrientation.horizontal) {
        final hasSameRow =
            equations.any((eq) => eq.orientation == CrosswordOrientation.horizontal && eq.r == newR);
        if (hasSameRow) {
          fails++;
          continue;
        }
      } else {
        final hasSameCol =
            equations.any((eq) => eq.orientation == CrosswordOrientation.vertical && eq.c == newC);
        if (hasSameCol) {
          fails++;
          continue;
        }
      }

      // Rule 2: Check head-to-tail spacing (avoid placing equations
      // directly touching others at ends).
      bool headTailOk = true;
      if (newOrientation == CrosswordOrientation.horizontal) {
        if (newC - 1 >= 0 && cellGrid[newR][newC - 1].type != PuzzleCellType.empty) {
          headTailOk = false;
        }
        if (newC + 5 < gridSize && cellGrid[newR][newC + 5].type != PuzzleCellType.empty) {
          headTailOk = false;
        }
      } else {
        if (newR - 1 >= 0 && cellGrid[newR - 1][newC].type != PuzzleCellType.empty) {
          headTailOk = false;
        }
        if (newR + 5 < gridSize && cellGrid[newR + 5][newC].type != PuzzleCellType.empty) {
          headTailOk = false;
        }
      }

      if (!headTailOk) {
        fails++;
        continue;
      }

      // Check for clumping & overlaps.
      bool ok = true;
      final newLayout = _layoutFor(mathEq, newIsReversed);
      final newValues = newLayout.values;
      final newTypes = newLayout.types;

      // Evaluate each cell.
      for (int idx = 0; idx < 5; idx++) {
        final r = newOrientation == CrosswordOrientation.horizontal ? newR : newR + idx;
        final c = newOrientation == CrosswordOrientation.horizontal ? newC + idx : newC;

        final currentCell = cellGrid[r][c];

        // 1. If the cell is the anchor, it's allowed and must match value.
        if (r == anchor.r && c == anchor.c) {
          if (currentCell.type != PuzzleCellType.number || currentCell.value != newValues[idx]) {
            ok = false;
            break;
          }
          continue;
        }

        // 2. If it is already occupied, it must match type and value perfectly.
        if (currentCell.type != PuzzleCellType.empty) {
          if (currentCell.type != newTypes[idx] || currentCell.value != newValues[idx]) {
            ok = false;
            break;
          }
          continue;
        }

        // 3. Prevent clumping: adjacent cells (orthogonal to direction)
        // should not be filled, except where they are part of intersecting
        // equations that intersect cleanly.
        if (newOrientation == CrosswordOrientation.horizontal) {
          final neighbors = [
            [r - 1, c],
            [r + 1, c],
          ];
          for (final n in neighbors) {
            final nr = n[0], nc = n[1];
            if (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
              if (cellGrid[nr][nc].type != PuzzleCellType.empty) {
                ok = false;
                break;
              }
            }
          }
        } else {
          final neighbors = [
            [r, c - 1],
            [r, c + 1],
          ];
          for (final n in neighbors) {
            final nr = n[0], nc = n[1];
            if (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
              if (cellGrid[nr][nc].type != PuzzleCellType.empty) {
                ok = false;
                break;
              }
            }
          }
        }

        if (!ok) break;
      }

      if (ok) {
        // Write the equation cells to the grid.
        final nextEqId = 'eq_${equations.length}';
        for (int idx = 0; idx < 5; idx++) {
          final r = newOrientation == CrosswordOrientation.horizontal ? newR : newR + idx;
          final c = newOrientation == CrosswordOrientation.horizontal ? newC + idx : newC;

          if (r == anchor.r && c == anchor.c) {
            // Overlap cell: append this equation ID to the existing list.
            cellGrid[r][c].equationIds.add(nextEqId);
          } else {
            cellGrid[r][c] = WorkingCell(
              type: newTypes[idx],
              value: newValues[idx],
              equationIds: [nextEqId],
            );
          }
        }

        equations.add(Equation(
          id: nextEqId,
          orientation: newOrientation,
          r: newR,
          c: newC,
          num1: mathEq.num1,
          op: mathEq.op,
          num2: mathEq.num2,
          num3: mathEq.num3,
          isReversed: newIsReversed,
        ));

        fails = 0; // reset failures on success
      } else {
        fails++;
      }
    }

    final minAcceptedCount = attempt > 200
        ? targetCount - 2
        : attempt > 100
            ? targetCount - 1
            : targetCount;

    if (equations.length >= minAcceptedCount) {
      // Build final Cell[][] structure with userValue and isLocked properties.
      final finalGrid = List<List<Cell>>.generate(
        gridSize,
        (r) => List<Cell>.generate(gridSize, (c) {
          final srcCell = cellGrid[r][c];
          return Cell(
            r: r,
            c: c,
            type: srcCell.type,
            value: srcCell.value,
            userValue: '',
            isLocked: true, // we'll unlock some number cells next
            equationIds: List<String>.from(srcCell.equationIds),
          );
        }),
      );

      // We need to choose which number cells to unlock (hide from the player).
      final numberCells = <Cell>[];
      for (int r = 0; r < gridSize; r++) {
        for (int c = 0; c < gridSize; c++) {
          if (finalGrid[r][c].type == PuzzleCellType.number) {
            numberCells.add(finalGrid[r][c]);
          }
        }
      }

      // Hide a percentage of numbers based on difficulty.
      // Easy: hide 45%, Medium: hide 55%, Hard: hide 65%.
      final hidePercent = difficulty == Difficulty.easy
          ? 0.45
          : difficulty == Difficulty.medium
              ? 0.55
              : 0.65;
      final cellsToHideCount = (numberCells.length * hidePercent).floor();
      final shuffledNumCells = _shuffle(numberCells);

      for (int i = 0; i < cellsToHideCount; i++) {
        shuffledNumCells[i].isLocked = false;
        shuffledNumCells[i].userValue = '';
      }

      // For any locked number cells, make sure userValue is pre-filled
      // with the correct value.
      for (int r = 0; r < gridSize; r++) {
        for (int c = 0; c < gridSize; c++) {
          if (finalGrid[r][c].type == PuzzleCellType.number && finalGrid[r][c].isLocked) {
            finalGrid[r][c].userValue = finalGrid[r][c].value;
          }
        }
      }

      return Puzzle(
        difficulty: difficulty,
        gridSize: gridSize,
        grid: finalGrid,
        equations: equations,
      );
    }
  }

  // Fallback: if stochastic fit didn't reach the target after 500 tries,
  // just retry recursively.
  return generatePuzzle(difficulty);
}
