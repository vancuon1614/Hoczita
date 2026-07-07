import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

enum CellType { empty, number, operator, equals }

class CrosswordCell {
  final int row;
  final int col;
  final CellType type;
  final String correctVal;
  String userVal;
  bool isHint;

  CrosswordCell({
    required this.row,
    required this.col,
    required this.type,
    required this.correctVal,
    this.userVal = '',
    this.isHint = false,
  });

  bool get isCorrect => type != CellType.number || isHint || userVal == correctVal;
}

class CrosswordEquation {
  final List<CrosswordCell> cells;
  CrosswordEquation({required this.cells});

  bool get isSatisfied {
    if (cells.length != 5) return false;
    for (var c in cells) {
      if (c.type == CellType.number && !c.isHint && c.userVal.isEmpty) return false;
    }
    try {
      final a   = int.parse(cells[0].isHint ? cells[0].correctVal : cells[0].userVal);
      final op  = cells[1].correctVal;
      final b   = int.parse(cells[2].isHint ? cells[2].correctVal : cells[2].userVal);
      final res = int.parse(cells[4].isHint ? cells[4].correctVal : cells[4].userVal);
      int calc;
      switch (op) {
        case '+': calc = a + b; break;
        case '-': calc = a - b; break;
        case '*': calc = a * b; break;
        case '/':
          if (b == 0) return false;
          calc = a ~/ b;
          if (a % b != 0) return false;
          break;
        default: return false;
      }
      return calc == res;
    } catch (_) { return false; }
  }

  bool get isFullyCorrect => cells.every((c) => c.isCorrect);
}

class _EqSlot {
  final bool isHorizontal;
  final int row;
  final int col;
  const _EqSlot({required this.isHorizontal, required this.row, required this.col});
}

class MathCrosswordGameScreen extends StatefulWidget {
  const MathCrosswordGameScreen({super.key});
  @override
  State<MathCrosswordGameScreen> createState() => _MathCrosswordGameScreenState();
}

class _MathCrosswordGameScreenState extends State<MathCrosswordGameScreen> {
  int? _selectedDifficulty;
  List<List<CrosswordCell>> _grid = [];
  final List<CrosswordEquation> _equations = [];

  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isSavingScore = false;

  int _gridRows = 0;
  int _gridCols = 0;

  int? _selectedCellRow;
  int? _selectedCellCol;

  final Stopwatch _stopwatch = Stopwatch();
  late Timer _timer;
  String _elapsedTimeString = '0.0';
  int _score = 0;
  int _stars = 0;

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (_isPlaying) _timer.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _selectDifficulty(int difficulty) {
    if (difficulty == 10 || difficulty == 20) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    setState(() {
      _selectedDifficulty = difficulty;
      _isPlaying = true;
      _isGameOver = false;
      _isSavingScore = false;
      _selectedCellRow = null;
      _selectedCellCol = null;
    });
    _generatePuzzle(difficulty);
    _stopwatch.reset();
    _stopwatch.start();
    _startTimer();
  }

  String _formatTime(double seconds) {
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final int ts = seconds.round();
    if (ts < 3600) {
      return '${(ts ~/ 60).toString().padLeft(2, '0')}:${(ts % 60).toString().padLeft(2, '0')}';
    }
    final h = ts ~/ 3600; final m = (ts % 3600) ~/ 60; final s = ts % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_stopwatch.isRunning) {
        setState(() => _elapsedTimeString = _formatTime(_stopwatch.elapsedMilliseconds / 1000));
      }
    });
  }

  // ─── TEMPLATES ──────────────────────────────────────────────────────────────
  static const _easyTemplates = <List<_EqSlot>>[
    [
      _EqSlot(isHorizontal: true,  row: 0, col: 0),
      _EqSlot(isHorizontal: true,  row: 4, col: 2),
      _EqSlot(isHorizontal: true,  row: 8, col: 4),
      _EqSlot(isHorizontal: false, row: 0, col: 2),
      _EqSlot(isHorizontal: false, row: 2, col: 6),
      _EqSlot(isHorizontal: false, row: 4, col: 0),
    ],
    [
      _EqSlot(isHorizontal: true,  row: 0, col: 0),
      _EqSlot(isHorizontal: true,  row: 4, col: 0),
      _EqSlot(isHorizontal: true,  row: 8, col: 4),
      _EqSlot(isHorizontal: false, row: 0, col: 4),
      _EqSlot(isHorizontal: false, row: 2, col: 0),
      _EqSlot(isHorizontal: false, row: 4, col: 8),
    ],
    [
      _EqSlot(isHorizontal: true,  row: 0, col: 0),
      _EqSlot(isHorizontal: true,  row: 8, col: 0),
      _EqSlot(isHorizontal: false, row: 0, col: 0),
      _EqSlot(isHorizontal: false, row: 0, col: 2),
      _EqSlot(isHorizontal: false, row: 0, col: 6),
      _EqSlot(isHorizontal: false, row: 0, col: 8),
    ],
    [
      _EqSlot(isHorizontal: true,  row: 0, col: 2),
      _EqSlot(isHorizontal: true,  row: 4, col: 0),
      _EqSlot(isHorizontal: true,  row: 8, col: 4),
      _EqSlot(isHorizontal: false, row: 0, col: 2),
      _EqSlot(isHorizontal: false, row: 2, col: 6),
      _EqSlot(isHorizontal: false, row: 4, col: 0),
    ],
    [
      _EqSlot(isHorizontal: true,  row: 0, col: 0),
      _EqSlot(isHorizontal: true,  row: 4, col: 2),
      _EqSlot(isHorizontal: true,  row: 8, col: 4),
      _EqSlot(isHorizontal: false, row: 0, col: 4),
      _EqSlot(isHorizontal: false, row: 2, col: 2),
      _EqSlot(isHorizontal: false, row: 4, col: 6),
    ],
  ];

  static const _mediumTemplates = <List<_EqSlot>>[
    [
      _EqSlot(isHorizontal: true,  row: 0,  col: 0),
      _EqSlot(isHorizontal: true,  row: 2,  col: 4),
      _EqSlot(isHorizontal: true,  row: 6,  col: 0),
      _EqSlot(isHorizontal: true,  row: 8,  col: 6),
      _EqSlot(isHorizontal: true,  row: 12, col: 2),
      _EqSlot(isHorizontal: false, row: 0,  col: 0),
      _EqSlot(isHorizontal: false, row: 0,  col: 4),
      _EqSlot(isHorizontal: false, row: 4,  col: 8),
      _EqSlot(isHorizontal: false, row: 2,  col: 6),
      _EqSlot(isHorizontal: false, row: 8,  col: 12),
    ],
    [
      _EqSlot(isHorizontal: true,  row: 0,  col: 0),
      _EqSlot(isHorizontal: true,  row: 4,  col: 8),
      _EqSlot(isHorizontal: true,  row: 6,  col: 4),
      _EqSlot(isHorizontal: true,  row: 10, col: 0),
      _EqSlot(isHorizontal: true,  row: 12, col: 6),
      _EqSlot(isHorizontal: false, row: 0,  col: 0),
      _EqSlot(isHorizontal: false, row: 0,  col: 4),
      _EqSlot(isHorizontal: false, row: 0,  col: 8),
      _EqSlot(isHorizontal: false, row: 0,  col: 12),
      _EqSlot(isHorizontal: false, row: 4,  col: 6),
    ],
    [
      _EqSlot(isHorizontal: true,  row: 0,  col: 0),
      _EqSlot(isHorizontal: true,  row: 2,  col: 0),
      _EqSlot(isHorizontal: true,  row: 4,  col: 4),
      _EqSlot(isHorizontal: true,  row: 8,  col: 6),
      _EqSlot(isHorizontal: true,  row: 12, col: 8),
      _EqSlot(isHorizontal: false, row: 0,  col: 0),
      _EqSlot(isHorizontal: false, row: 0,  col: 4),
      _EqSlot(isHorizontal: false, row: 0,  col: 8),
      _EqSlot(isHorizontal: false, row: 4,  col: 10),
      _EqSlot(isHorizontal: false, row: 8,  col: 12),
    ],
    [
      _EqSlot(isHorizontal: true,  row: 0,  col: 4),
      _EqSlot(isHorizontal: true,  row: 4,  col: 0),
      _EqSlot(isHorizontal: true,  row: 6,  col: 8),
      _EqSlot(isHorizontal: true,  row: 8,  col: 2),
      _EqSlot(isHorizontal: true,  row: 12, col: 4),
      _EqSlot(isHorizontal: false, row: 0,  col: 4),
      _EqSlot(isHorizontal: false, row: 0,  col: 8),
      _EqSlot(isHorizontal: false, row: 4,  col: 0),
      _EqSlot(isHorizontal: false, row: 4,  col: 12),
      _EqSlot(isHorizontal: false, row: 8,  col: 6),
    ],
    [
      _EqSlot(isHorizontal: true,  row: 0,  col: 0),
      _EqSlot(isHorizontal: true,  row: 4,  col: 6),
      _EqSlot(isHorizontal: true,  row: 8,  col: 4),
      _EqSlot(isHorizontal: true,  row: 10, col: 0),
      _EqSlot(isHorizontal: true,  row: 12, col: 8),
      _EqSlot(isHorizontal: false, row: 0,  col: 0),
      _EqSlot(isHorizontal: false, row: 0,  col: 4),
      _EqSlot(isHorizontal: false, row: 2,  col: 8),
      _EqSlot(isHorizontal: false, row: 6,  col: 12),
      _EqSlot(isHorizontal: false, row: 8,  col: 2),
    ],
  ];

  static const _hardTemplates = <List<_EqSlot>>[
    [
      _EqSlot(isHorizontal: true,  row: 0,  col: 0),
      _EqSlot(isHorizontal: true,  row: 2,  col: 4),
      _EqSlot(isHorizontal: true,  row: 4,  col: 8),
      _EqSlot(isHorizontal: true,  row: 8,  col: 0),
      _EqSlot(isHorizontal: true,  row: 10, col: 6),
      _EqSlot(isHorizontal: true,  row: 14, col: 2),
      _EqSlot(isHorizontal: true,  row: 16, col: 10),
      _EqSlot(isHorizontal: false, row: 0,  col: 0),
      _EqSlot(isHorizontal: false, row: 0,  col: 4),
      _EqSlot(isHorizontal: false, row: 0,  col: 8),
      _EqSlot(isHorizontal: false, row: 0,  col: 12),
      _EqSlot(isHorizontal: false, row: 4,  col: 16),
      _EqSlot(isHorizontal: false, row: 8,  col: 2),
      _EqSlot(isHorizontal: false, row: 12, col: 6),
    ],
    [
      _EqSlot(isHorizontal: true,  row: 0,  col: 0),
      _EqSlot(isHorizontal: true,  row: 0,  col: 8),
      _EqSlot(isHorizontal: true,  row: 4,  col: 4),
      _EqSlot(isHorizontal: true,  row: 8,  col: 0),
      _EqSlot(isHorizontal: true,  row: 8,  col: 10),
      _EqSlot(isHorizontal: true,  row: 12, col: 6),
      _EqSlot(isHorizontal: true,  row: 16, col: 8),
      _EqSlot(isHorizontal: false, row: 0,  col: 0),
      _EqSlot(isHorizontal: false, row: 0,  col: 8),
      _EqSlot(isHorizontal: false, row: 0,  col: 16),
      _EqSlot(isHorizontal: false, row: 4,  col: 4),
      _EqSlot(isHorizontal: false, row: 4,  col: 12),
      _EqSlot(isHorizontal: false, row: 8,  col: 2),
      _EqSlot(isHorizontal: false, row: 12, col: 10),
    ],
    [
      _EqSlot(isHorizontal: true,  row: 0,  col: 0),
      _EqSlot(isHorizontal: true,  row: 2,  col: 0),
      _EqSlot(isHorizontal: true,  row: 4,  col: 4),
      _EqSlot(isHorizontal: true,  row: 6,  col: 8),
      _EqSlot(isHorizontal: true,  row: 10, col: 4),
      _EqSlot(isHorizontal: true,  row: 14, col: 0),
      _EqSlot(isHorizontal: true,  row: 16, col: 8),
      _EqSlot(isHorizontal: false, row: 0,  col: 0),
      _EqSlot(isHorizontal: false, row: 0,  col: 4),
      _EqSlot(isHorizontal: false, row: 0,  col: 8),
      _EqSlot(isHorizontal: false, row: 4,  col: 12),
      _EqSlot(isHorizontal: false, row: 6,  col: 16),
      _EqSlot(isHorizontal: false, row: 10, col: 2),
      _EqSlot(isHorizontal: false, row: 12, col: 6),
    ],
    [
      _EqSlot(isHorizontal: true,  row: 0,  col: 4),
      _EqSlot(isHorizontal: true,  row: 4,  col: 0),
      _EqSlot(isHorizontal: true,  row: 6,  col: 8),
      _EqSlot(isHorizontal: true,  row: 10, col: 0),
      _EqSlot(isHorizontal: true,  row: 12, col: 6),
      _EqSlot(isHorizontal: true,  row: 14, col: 12),
      _EqSlot(isHorizontal: true,  row: 16, col: 2),
      _EqSlot(isHorizontal: false, row: 0,  col: 0),
      _EqSlot(isHorizontal: false, row: 0,  col: 4),
      _EqSlot(isHorizontal: false, row: 0,  col: 8),
      _EqSlot(isHorizontal: false, row: 0,  col: 12),
      _EqSlot(isHorizontal: false, row: 0,  col: 16),
      _EqSlot(isHorizontal: false, row: 4,  col: 2),
      _EqSlot(isHorizontal: false, row: 8,  col: 10),
    ],
    [
      _EqSlot(isHorizontal: true,  row: 0,  col: 0),
      _EqSlot(isHorizontal: true,  row: 2,  col: 8),
      _EqSlot(isHorizontal: true,  row: 6,  col: 4),
      _EqSlot(isHorizontal: true,  row: 8,  col: 0),
      _EqSlot(isHorizontal: true,  row: 10, col: 10),
      _EqSlot(isHorizontal: true,  row: 14, col: 4),
      _EqSlot(isHorizontal: true,  row: 16, col: 0),
      _EqSlot(isHorizontal: false, row: 0,  col: 0),
      _EqSlot(isHorizontal: false, row: 0,  col: 4),
      _EqSlot(isHorizontal: false, row: 0,  col: 8),
      _EqSlot(isHorizontal: false, row: 2,  col: 12),
      _EqSlot(isHorizontal: false, row: 4,  col: 16),
      _EqSlot(isHorizontal: false, row: 6,  col: 2),
      _EqSlot(isHorizontal: false, row: 12, col: 6),
    ],
    [
      _EqSlot(isHorizontal: true,  row: 0,  col: 0),
      _EqSlot(isHorizontal: true,  row: 4,  col: 6),
      _EqSlot(isHorizontal: true,  row: 6,  col: 0),
      _EqSlot(isHorizontal: true,  row: 8,  col: 10),
      _EqSlot(isHorizontal: true,  row: 10, col: 2),
      _EqSlot(isHorizontal: true,  row: 12, col: 8),
      _EqSlot(isHorizontal: true,  row: 16, col: 4),
      _EqSlot(isHorizontal: false, row: 0,  col: 2),
      _EqSlot(isHorizontal: false, row: 0,  col: 6),
      _EqSlot(isHorizontal: false, row: 0,  col: 10),
      _EqSlot(isHorizontal: false, row: 4,  col: 0),
      _EqSlot(isHorizontal: false, row: 2,  col: 14),
      _EqSlot(isHorizontal: false, row: 8,  col: 4),
      _EqSlot(isHorizontal: false, row: 12, col: 12),
    ],
  ];

  // ─── GENERATE PUZZLE ────────────────────────────────────────────────────────
  void _generatePuzzle(int difficulty) {
    final rand = Random();
    _equations.clear();
    final List<List<_EqSlot>> pool;
    final int gs;
    switch (difficulty) {
      case 5:  gs = 9;  pool = _easyTemplates;   break;
      case 10: gs = 13; pool = _mediumTemplates;  break;
      default: gs = 17; pool = _hardTemplates;
    }
    _gridRows = gs; _gridCols = gs;

    for (int attempt = 0; attempt < 30; attempt++) {
      _grid = List.generate(gs, (r) => List.generate(gs,
          (c) => CrosswordCell(row: r, col: c, type: CellType.empty, correctVal: '')));
      _equations.clear();
      if (_fillSlots(pool[rand.nextInt(pool.length)], rand, difficulty)) {
        _assignHints(rand, difficulty);
        return;
      }
    }
    // Fallback
    _gridRows = 9; _gridCols = 9;
    _grid = List.generate(9, (r) => List.generate(9,
        (c) => CrosswordCell(row: r, col: c, type: CellType.empty, correctVal: '')));
    _equations.clear();
    _fillSlots(_easyTemplates[0], rand, 5);
    _assignHints(rand, difficulty);
  }

  List<({int row, int col})>? _slotPositions(_EqSlot slot) {
    final res = <({int row, int col})>[];
    for (int i = 0; i < 5; i++) {
      final r = slot.isHorizontal ? slot.row : slot.row + i;
      final c = slot.isHorizontal ? slot.col + i : slot.col;
      if (r < 0 || r >= _gridRows || c < 0 || c >= _gridCols) return null;
      res.add((row: r, col: c));
    }
    return res;
  }

  bool _fillSlots(List<_EqSlot> slots, Random rand, int difficulty) {
    final cellVals = List.generate(_gridRows, (_) => List<String?>.filled(_gridCols, null));
    final List<String> opPool;
    if (difficulty == 5) {
      opPool = ['+', '+', '+', '-', '-'];
    } else if (difficulty == 10) {
      opPool = ['+', '+', '-', '-', '*', '/'];
    } else {
      opPool = ['+', '-', '*', '*', '/', '/'];
    }

    for (final slot in slots) {
      final positions = _slotPositions(slot);
      if (positions == null) return false;
      final existA  = cellVals[positions[0].row][positions[0].col];
      final existB  = cellVals[positions[2].row][positions[2].col];
      final existC  = cellVals[positions[4].row][positions[4].col];
      final existOp = cellVals[positions[1].row][positions[1].col];
      final existEq = cellVals[positions[3].row][positions[3].col];
      if (existOp != null && !_isOp(existOp)) return false;
      if (existEq != null && existEq != '=') return false;

      bool placed = false;
      for (int t = 0; t < 40 && !placed; t++) {
        final op = existOp ?? opPool[rand.nextInt(opPool.length)];
        int? a = existA != null ? int.tryParse(existA) : null;
        int? b = existB != null ? int.tryParse(existB) : null;
        int? c = existC != null ? int.tryParse(existC) : null;

        if (a == null && b == null && c == null) {
          final v = _rEq(op, rand); if (v == null) continue; a=v[0]; b=v[1]; c=v[2];
        } else if (a != null && b == null && c == null) {
          final v = _fA(a, op, rand); if (v == null) continue; b=v[1]; c=v[2];
        } else if (b != null && a == null && c == null) {
          final v = _fB(b, op, rand); if (v == null) continue; a=v[0]; c=v[2];
        } else if (c != null && a == null && b == null) {
          final v = _fC(c, op, rand); if (v == null) continue; a=v[0]; b=v[1];
        } else if (a != null && b != null && c == null) {
          c = _app(a, b, op);
        } else if (a != null && c != null && b == null) {
          b = _rvB(a, c, op);
        } else if (b != null && c != null && a == null) {
          a = _rvA(b, c, op);
        } else if (a != null && b != null && c != null) {
          if (_app(a, b, op) != c) continue;
        }

        if (a == null || b == null || c == null) continue;
        if (a <= 0 || b <= 0 || c <= 0 || a > 99 || b > 99 || c > 99) continue;

        void sN(int idx, int val) {
          final p = positions[idx]; final s = val.toString();
          cellVals[p.row][p.col] = s;
          _grid[p.row][p.col] = CrosswordCell(row: p.row, col: p.col, type: CellType.number, correctVal: s);
        }
        void sO(int idx, String val, CellType ct) {
          final p = positions[idx];
          cellVals[p.row][p.col] = val;
          _grid[p.row][p.col] = CrosswordCell(row: p.row, col: p.col, type: ct, correctVal: val);
        }
        sN(0, a); sO(1, op, CellType.operator); sN(2, b); sO(3, '=', CellType.equals); sN(4, c);
        _equations.add(CrosswordEquation(cells: [
          _grid[positions[0].row][positions[0].col],
          _grid[positions[1].row][positions[1].col],
          _grid[positions[2].row][positions[2].col],
          _grid[positions[3].row][positions[3].col],
          _grid[positions[4].row][positions[4].col],
        ]));
        placed = true;
      }
      if (!placed) return false;
    }
    return true;
  }

  bool _isOp(String s) => s == '+' || s == '-' || s == '*' || s == '/';

  int? _app(int a, int b, String op) {
    switch (op) {
      case '+': return a + b;
      case '-': return a - b > 0 ? a - b : null;
      case '*': return a * b;
      case '/': return (b > 0 && a % b == 0) ? a ~/ b : null;
    }
    return null;
  }

  List<int>? _rEq(String op, Random rand) {
    switch (op) {
      case '+': { final a=rand.nextInt(18)+1,b=rand.nextInt(18)+1; final c=a+b; return c<=99?[a,b,c]:null; }
      case '-': { final c=rand.nextInt(15)+1,b=rand.nextInt(15)+1; final a=b+c; return a<=99?[a,b,c]:null; }
      case '*': { final a=rand.nextInt(9)+2,b=rand.nextInt(9)+2; final c=a*b; return c<=99?[a,b,c]:null; }
      case '/': { final b=rand.nextInt(8)+2,c=rand.nextInt(9)+1; final a=b*c; return a<=99?[a,b,c]:null; }
    }
    return null;
  }

  List<int>? _fA(int a, String op, Random rand) {
    for (int i=0;i<10;i++) {
      switch(op) {
        case '+': { final b=rand.nextInt(18)+1; final c=a+b; if(c<=99) return [a,b,c]; break; }
        case '-': { if(a<2) break; final b=rand.nextInt(a-1)+1; final c=a-b; if(c>0) return [a,b,c]; break; }
        case '*': { final b=rand.nextInt(9)+2; final c=a*b; if(c<=99) return [a,b,c]; break; }
        case '/': { final ds=List.generate(9,(i)=>i+2).where((d)=>a%d==0).toList(); if(ds.isEmpty) break; final b=ds[rand.nextInt(ds.length)]; return [a,b,a~/b]; }
      }
    }
    return null;
  }

  List<int>? _fB(int b, String op, Random rand) {
    for (int i=0;i<10;i++) {
      switch(op) {
        case '+': { final a=rand.nextInt(18)+1; final c=a+b; if(c<=99) return [a,b,c]; break; }
        case '-': { final a=b+rand.nextInt(15)+1; final c=a-b; if(a<=99&&c>0) return [a,b,c]; break; }
        case '*': { final a=rand.nextInt(9)+2; final c=a*b; if(c<=99) return [a,b,c]; break; }
        case '/': { final a=b*(rand.nextInt(9)+1); if(a<=99) return [a,b,a~/b]; break; }
      }
    }
    return null;
  }

  List<int>? _fC(int c, String op, Random rand) {
    for (int i=0;i<10;i++) {
      switch(op) {
        case '+': { if(c<2) break; final b=rand.nextInt(c-1)+1; return [c-b,b,c]; }
        case '-': { final b=rand.nextInt(15)+1; final a=c+b; if(a<=99) return [a,b,c]; break; }
        case '*': { final fs=List.generate(9,(i)=>i+2).where((f)=>c%f==0&&(c~/f)>=2&&(c~/f)<=10).toList(); if(fs.isEmpty) break; final b2=fs[rand.nextInt(fs.length)]; return [c~/b2,b2,c]; }
        case '/': { final b=rand.nextInt(8)+2; final a=b*c; if(a<=99) return [a,b,c]; break; }
      }
    }
    return null;
  }

  int? _rvB(int a, int c, String op) {
    switch (op) {
      case '+': return (c-a)>0?c-a:null;
      case '-': return (a-c)>0?a-c:null;
      case '*': return (c>0&&c%a==0)?c~/a:null;
      case '/': return null;
    }
    return null;
  }

  int? _rvA(int b, int c, String op) {
    switch (op) {
      case '+': return (c-b)>0?c-b:null;
      case '-': return (c+b)<=99?c+b:null;
      case '*': return (c>0&&c%b==0)?c~/b:null;
      case '/': return (b*c)<=99?b*c:null;
    }
    return null;
  }

  void _assignHints(Random rand, int difficulty) {
    final all = <CrosswordCell>[];
    for (int r=0;r<_gridRows;r++) {
      for (int c=0;c<_gridCols;c++) {
        if (_grid[r][c].type == CellType.number) all.add(_grid[r][c]);
      }
    }
    all.shuffle(rand);
    final total = all.length;
    int hintCount;
    if (difficulty == 5) {
      hintCount = (total * 0.44).round();
    } else if (difficulty == 10) {
      hintCount = (total * (0.30 + rand.nextDouble() * 0.10)).round();
    } else {
      hintCount = (total * (0.12 + rand.nextDouble() * 0.07)).round();
    }
    hintCount = hintCount.clamp(1, total);
    for (int i=0;i<hintCount;i++) { all[i].isHint = true; }
  }

  bool _checkAllEquationsSatisfied() {
    // 1. Check if all number cells are filled
    for (int r = 0; r < _gridRows; r++) {
      for (int c = 0; c < _gridCols; c++) {
        final cell = _grid[r][c];
        if (cell.type == CellType.number && !cell.isHint) {
          if (cell.userVal.isEmpty) {
            return false;
          }
        }
      }
    }

    // 2. Check if all equations are satisfied
    for (final eq in _equations) {
      if (!eq.isSatisfied) {
        return false;
      }
    }

    return true;
  }

  void _checkWinState() {
    if (_checkAllEquationsSatisfied()) {
      _endGameAndSaveScore();
    }
  }

  void _selectCell(int r, int c) {
    if (_grid[r][c].type != CellType.number || _grid[r][c].isHint) return;
    setState(() {
      _selectedCellRow = r;
      _selectedCellCol = c;
    });
  }

  void _inputDigit(String key) {
    if (_selectedCellRow == null || _selectedCellCol == null) return;
    final cell = _grid[_selectedCellRow!][_selectedCellCol!];
    setState(() {
      if (key == 'backspace') {
        if (cell.userVal.isNotEmpty) {
          cell.userVal = cell.userVal.substring(0, cell.userVal.length - 1);
        }
      } else if (key == '-') {
        if (cell.userVal.startsWith('-')) {
          cell.userVal = cell.userVal.substring(1);
        } else {
          cell.userVal = '-${cell.userVal}';
        }
      } else {
        final digitsOnly = cell.userVal.replaceAll('-', '');
        if (digitsOnly.length < 3) {
          cell.userVal += key;
        }
      }
    });
    _checkWinState();
  }

  void _endGameAndSaveScore() async {
    _stopwatch.stop();
    _timer.cancel();

    final elapsedSeconds = _stopwatch.elapsedMilliseconds / 1000;
    
    // Scale stars based on difficulty & time limit
    int starRating = 0;
    int baseScore = 0;
    final diff = _selectedDifficulty ?? 5;

    if (diff == 5) {
      if (elapsedSeconds <= 30) {
        starRating = 3;
      } else if (elapsedSeconds <= 60) {
        starRating = 2;
      } else {
        starRating = 1;
      }
    } else if (diff == 10) {
      if (elapsedSeconds <= 60) {
        starRating = 3;
      } else if (elapsedSeconds <= 120) {
        starRating = 2;
      } else {
        starRating = 1;
      }
    } else {
      if (elapsedSeconds <= 90) {
        starRating = 3;
      } else if (elapsedSeconds <= 180) {
        starRating = 2;
      } else {
        starRating = 1;
      }
    }

    if (starRating == 3) {
      baseScore = 30;
    } else if (starRating == 2) {
      baseScore = 20;
    } else {
      baseScore = 10;
    }

    // Larger grids reward more score points
    final multiplier = (diff == 5) ? 1 : (diff == 10 ? 2 : 3);
    final finalScore = baseScore * multiplier;

    setState(() {
      _stars = starRating;
      _score = finalScore;
      _isGameOver = true;
      _isSavingScore = true;
    });

    try {
      await SupabaseService.instance.saveScore(
        gameName: 'math_crossword',
        stars: _stars,
        score: _score,
      );
    } catch (e) {
      debugPrint('Error saving score: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingScore = false;
        });
      }
    }
  }

  void _showQuitConfirmation() {
    _stopwatch.stop();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thoát Trò Chơi?'),
        content: const Text('Tiến trình chơi hiện tại của bé sẽ không được lưu lại.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopwatch.start();
            },
            child: const Text('Chơi tiếp'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // quit game screen
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlaying) {
      return _buildDifficultySelection();
    }
    if (_isGameOver) {
      return _buildSummaryView();
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final showKeypad = _selectedCellRow != null && _selectedCellCol != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Math Crossword 🔢',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _showQuitConfirmation,
        ),
        actions: [
          Container(
            width: 90, // Fixed width to prevent shifting layout
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                SizedBox(
                  width: 50, // Fixed width for text area to prevent any shaking/shifting
                  child: Text(
                    _elapsedTimeString,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCellRow = null;
            _selectedCellCol = null;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: isLandscape
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left side: Instruction + Grid
                    Expanded(
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Text(
                              'Điền các chữ số còn thiếu sao cho các phép tính hàng ngang và hàng dọc đều đúng nhé!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                          Expanded(child: _buildGridContainer()),
                        ],
                      ),
                    ),
                    // Right side: Keyboard
                    if (showKeypad) _buildInlineKeypadColumn(),
                  ],
                )
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text(
                        'Điền các chữ số còn thiếu sao cho các phép tính hàng ngang và hàng dọc đều đúng nhé!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(child: _buildGridContainer()),
                    if (showKeypad) _buildInlineKeypadColumn(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGridContainer() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        maxScale: 2.5,
        minScale: 0.8,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FittedBox(
              fit: isLandscape ? BoxFit.contain : BoxFit.fitWidth,
              child: _buildCrosswordGrid(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineKeypadColumn() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['-', '0', 'backspace'],
    ];

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    String currentValue = '';
    if (_selectedCellRow != null && _selectedCellCol != null) {
      currentValue = _grid[_selectedCellRow!][_selectedCellCol!].userVal;
    }

    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: isLandscape ? 240 : double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: isLandscape ? BorderSide.none : const BorderSide(color: AppColors.border, width: 1.5),
            left: isLandscape ? const BorderSide(color: AppColors.border, width: 1.5) : BorderSide.none,
          ),
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, isLandscape ? 12 : MediaQuery.of(context).padding.bottom + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Nhập số:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 60,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    currentValue.isEmpty ? '-' : currentValue,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          ...keys.map((row) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: row.map((key) {
                  final isSpecial = key == '-' || key == 'backspace';
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () => _inputDigit(key),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: isLandscape ? 38 : 44,
                          decoration: BoxDecoration(
                            color: isSpecial ? Colors.grey[100] : AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: key == 'backspace'
                              ? const Icon(Icons.backspace_outlined, color: AppColors.textPrimary, size: 18)
                              : Text(
                                  key,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    ),
  );
}

  Widget _buildDifficultySelection() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Math Crossword 🔢',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.grid_on_rounded,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn Số Lượng Phép Tính',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kích thước lưới ô chữ sẽ thay đổi theo số lượng phép tính bé chọn.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              _buildDifficultyButton(
                title: 'Dễ (5 Phép Tính)',
                subtitle: 'Lưới ô chữ 5x5 - Phù hợp cho bé mới bắt đầu',
                difficulty: 5,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              _buildDifficultyButton(
                title: 'Trung Bình (10 Phép Tính)',
                subtitle: 'Lưới ô chữ 9x5 - Thách thức tư duy tính toán nhanh',
                difficulty: 10,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              _buildDifficultyButton(
                title: 'Khó (20 Phép Tính)',
                subtitle: 'Lưới ô chữ 9x9 - Đỉnh cao toán học crossword',
                difficulty: 20,
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyButton({
    required String title,
    required String subtitle,
    required int difficulty,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectDifficulty(difficulty),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCrosswordGrid() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_gridRows, (r) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_gridCols, (c) {
            return _buildCellItem(_grid[r][c]);
          }),
        );
      }),
    );
  }

  Widget _buildCellItem(CrosswordCell cell) {
    if (cell.type == CellType.empty) {
      return const SizedBox(width: 44, height: 44);
    }

    // Check if this cell is part of any fully satisfied/correct equations
    bool isCellPartofCorrectEquation = false;
    for (var eq in _equations) {
      if (eq.isSatisfied) {
        if (eq.cells.contains(cell)) {
          isCellPartofCorrectEquation = true;
        }
      }
    }

    Color backColor = Colors.white;
    Color borderColor = Colors.black;
    Color textColor = AppColors.textPrimary;
    double borderWidth = 2.0;

    final isSelected = cell.row == _selectedCellRow && cell.col == _selectedCellCol;

    if (isCellPartofCorrectEquation) {
      backColor = Colors.green[50]!;
      borderColor = AppColors.success;
      textColor = AppColors.success;
      borderWidth = 2.5;
    } else if (cell.type == CellType.number) {
      if (cell.isHint) {
        backColor = Colors.white;
        textColor = AppColors.textPrimary;
      } else {
        if (isSelected) {
          backColor = AppColors.primaryLight;
          borderColor = AppColors.primary;
          textColor = AppColors.primary;
          borderWidth = 3.0;
        }
      }
    } else {
      // Operators & equals
      textColor = AppColors.textPrimary;
    }

    if (cell.type == CellType.number && !cell.isHint) {
      return GestureDetector(
        onTap: () => _selectCell(cell.row, cell.col),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 42,
          height: 42,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: backColor,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            cell.userVal,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      );
    }

    String displayText = '';
    if (cell.type == CellType.number) {
      displayText = cell.correctVal;
    } else {
      displayText = cell.correctVal;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 42,
      height: 42,
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: backColor,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      alignment: Alignment.center,
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: cell.type == CellType.number ? 16 : 18,
          fontWeight: cell.type == CellType.number ? FontWeight.bold : FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  // Removed unused keypad method

  Widget _buildSummaryView() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Trophy Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF9E6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.amber,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Giải Ô Chữ Hoàn Tất! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                'Bé đã giải thành công toàn bộ ô chữ toán học trong $_elapsedTimeString.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Stars Display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final active = index < _stars;
                  return AnimatedScale(
                    scale: active ? 1.3 : 1.0,
                    duration: Duration(milliseconds: 300 + (index * 150)),
                    curve: Curves.elasticOut,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.star_rounded,
                        size: 48,
                        color: active ? Colors.amber : AppColors.border,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),

              // Time & Score Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Thời gian',
                            style: TextStyle(fontSize: 13, color: AppColors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _elapsedTimeString,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Điểm cộng',
                            style: TextStyle(fontSize: 13, color: AppColors.success),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+$_score',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),
              
              // Action Button
              ElevatedButton(
                onPressed: _isSavingScore
                    ? null
                    : () {
                        Navigator.pop(context); // Go back to GameTab
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSavingScore
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Quay lại danh mục',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
