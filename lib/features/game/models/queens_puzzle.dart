import 'dart:math';

enum QueensCellMark {
  empty,
  cross,
  queen,
}

class QueensCell {
  final int row;
  final int col;
  final int region;
  QueensCellMark mark;
  bool isConflict;

  QueensCell({
    required this.row,
    required this.col,
    required this.region,
    this.mark = QueensCellMark.empty,
    this.isConflict = false,
  });

  bool get isQueen => mark == QueensCellMark.queen;
  bool get isCross => mark == QueensCellMark.cross;
  bool get isEmpty => mark == QueensCellMark.empty;
}

class QueensPuzzle {
  final int size;
  final DateTime date;
  final List<Point<int>> solutionQueens; // Exactly size queens (row, col)
  final List<List<int>> regionMap;      // size x size region indices (0..size-1)

  QueensPuzzle({
    required this.size,
    required this.date,
    required this.solutionQueens,
    required this.regionMap,
  });
}
