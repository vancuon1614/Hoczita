import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/game_interaction_provider.dart';
import '../../../core/services/game_score_sync_service.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import 'common/mini_game_rank_banner.dart';

// ==========================================
// PALETTE & CONSTANTS (Đồng bộ Màu Chủ Đạo Cobalt Blue của App HocZiTa)
// ==========================================
class MathBubblesColors {
  // Nền trời ban ngày tươi sáng, đồng bộ với AppColors.background (0xFFF4F9FC)
  static const Color skyTop = Color(0xFFE0EDFB);
  static const Color skyBottom = Color(0xFFF4F9FC);

  // Màu chủ đạo Cobalt Blue thương hiệu HocZiTa
  static const Color primaryCobalt = Color(0xFF0047AB);      // Màu chủ đạo chính (Cobalt Blue)
  static const Color secondaryBlue = Color(0xFF1E60D0);      // Màu phụ
  static const Color lightBlueBg = Color(0xFFE8F0FE);        // Nền xanh pastel nhạt
  static const Color cardSurface = Colors.white;             // Nền thẻ trắng
  static const Color borderLight = Color(0xFFE2E8F0);        // Viền thẻ
  static const Color borderCobalt = Color(0xFFBFDBFE);       // Viền nhấn xanh nhạt

  // Chữ & Biểu tượng
  static const Color textPrimary = Color(0xFF1E293B);        // Chữ chính đậm
  static const Color textSecondary = Color(0xFF64748B);      // Chữ phụ xám xanh
  static const Color textMuted = Color(0xFF94A3B8);          // Chữ mờ

  // Màu bong bóng xà phòng: Thống nhất một màu Cobalt Blue chủ đạo chuẩn thương hiệu
  static const Color bubbleBase = Color(0xFF0047AB);         // Màu chủ đạo thống nhất
  static const Color bubbleBaseNormal = Color(0xFF0047AB);   // Đồng bộ thống nhất
  static const Color bubbleBaseMedium = Color(0xFF0047AB);
  static const Color bubbleBaseHard = Color(0xFF0047AB);

  // UI Colors
  static const Color scoreStar = Color(0xFFFF9800);          // Vàng cam cho điểm và sao
  static const Color primaryButton = Color(0xFF0047AB);      // Xanh Cobalt thương hiệu
  static const Color primaryButtonShadow = Color(0xFF002B66);// Viền 3D nút bấm
  static const Color correctGreen = Color(0xFF10B981);       // Xanh ngọc khi đúng
  static const Color noticeAmber = Color(0xFFF59E0B);        // Hổ phách cho thông báo / cảnh báo
  static const Color heartRed = Color(0xFFEF4444);           // Đỏ tươi cho tim
  static const Color heartGrey = Color(0xFFCBD5E1);          // Xám khi mất tim

  // Keypad & Panels (Nền trắng tinh với phím 3D Cobalt Blue nổi bật)
  static const Color keypadBackground = Colors.white;
  static const Color keyFill = Color(0xFF0047AB);
  static const Color keyShadow = Color(0xFF002B66);
  static const Color keyText = Colors.white;
}

// ==========================================
// DATA MODEL: CÂU HỎI VÀ BONG BÓNG
// ==========================================
class BubbleProblem {
  final String id;
  final String expression;
  final int answer;
  final int level;
  final double xRatio; // Vị trí ngang cơ sở (0.15 .. 0.85)
  final double yRatio; // Vị trí dọc cơ sở (0.2 .. 0.75)
  final double durationSeconds;
  double remainingSeconds;
  double opacity = 1.0;
  bool isPopping = false;
  bool isDissolving = false;
  bool hasTriggeredNextSpawn = false; // Đã kích hoạt bóng tiếp theo khi trôi qua 30% thời gian chưa

  // Thuộc tính phục vụ chuyển động trôi bồng bềnh liên tục rộng khắp
  double floatElapsed = 0.0;
  late final double floatPhase;
  late final double floatSpeedY;
  late final double floatSpeedX;
  late final double wanderPhase;
  late final double wanderSpeed;

  BubbleProblem({
    required this.id,
    required this.expression,
    required this.answer,
    required this.level,
    required this.xRatio,
    required this.yRatio,
    required this.durationSeconds,
    this.hasTriggeredNextSpawn = false,
  }) : remainingSeconds = durationSeconds {
    final rng = Random();
    floatPhase = rng.nextDouble() * 2 * pi;
    wanderPhase = rng.nextDouble() * 2 * pi;
    floatSpeedY = 1.0 + rng.nextDouble() * 0.6;
    floatSpeedX = 0.7 + rng.nextDouble() * 0.5;
    wanderSpeed = 0.35 + rng.nextDouble() * 0.3;
  }

  Color get baseColor => MathBubblesColors.bubbleBase;

  // Cảnh báo nguy cấp khi bóng chỉ còn dưới 18% thời gian tồn tại (sắp nổ)
  bool get isCritical => remainingSeconds <= durationSeconds * 0.18;
}

// Particle hiệu ứng nổ bong bóng
class BubbleParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double opacity;
  bool isStar;

  BubbleParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.opacity,
    this.isStar = false,
  });
}

// Vòng sóng xung kích tỏa tròn khi nổ
class ShockwaveRing {
  double x;
  double y;
  double radius;
  double maxRadius;
  double opacity;
  Color color;

  ShockwaveRing({
    required this.x,
    required this.y,
    required this.radius,
    required this.maxRadius,
    required this.opacity,
    required this.color,
  });
}

// ==========================================
// MAIN SCREEN WIDGET
// ==========================================
class MathBubblesGameScreen extends ConsumerStatefulWidget {
  const MathBubblesGameScreen({super.key});

  @override
  ConsumerState<MathBubblesGameScreen> createState() => _MathBubblesGameScreenState();
}

class _MathBubblesGameScreenState extends ConsumerState<MathBubblesGameScreen>
    with TickerProviderStateMixin {
  // Screen state: 0 = Intro/Lobby, 1 = Gameplay, 2 = Game Over
  int _screenState = 0;

  // Gameplay state
  int _score = 0;
  int _level = 1;
  int _hearts = 3;
  int _poppedCount = 0;
  int _highScore = 0;
  int _comboStreak = 0;
  int _maxCombo = 0;
  int _lastSpeedMilestone = 0;

  // Input & Feedback
  String _currentInput = '';
  late final FocusNode _focusNode;
  String? _feedbackStatus; // 'correct', 'wrong', null
  String? _feedbackText;
  String? _bannerNotice;
  String? _missedBubbleNotice;

  // Active elements
  final List<BubbleProblem> _activeBubbles = [];
  final List<BubbleParticle> _particles = [];
  final List<ShockwaveRing> _shockwaves = [];
  final List<Map<String, dynamic>> _flashCenters = []; // Đốm bừng sáng tại tâm nổ
  final List<Map<String, dynamic>> _floatingTexts = []; // Chữ nổi +1, +2 khi nổ bóng

  // Timers
  Timer? _gameLoopTimer;
  Timer? _spawnTimer;
  Timer? _feedbackResetTimer;
  Timer? _bannerTimer;
  Timer? _missedNoticeTimer;
  Timer? _submitDebounceTimer;

  // Random generator
  final Random _rng = Random();

  // Animation controller cho nền trời và bong bóng bồng bềnh
  late AnimationController _skyFloatController;
  late AnimationController _scorePulseController;

  // Vị trí hạt bong bóng nền
  final List<Offset> _sparklePositions = [];
  final List<double> _sparkleSizes = [];

  // Lưu provider notifier để cập nhật an toàn trong dispose() mà không truy cập ref
  dynamic _gameActiveNotifier;

  @override
  void initState() {
    super.initState();
    _gameActiveNotifier = ref.read(isGameActiveProvider.notifier);
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _gameActiveNotifier?.state = true;
      }
    });

    _loadHighScore();

    // Sinh các vị trí hạt bong bóng/sparkle bay lơ lửng trên nền trời sáng
    for (int i = 0; i < 35; i++) {
      _sparklePositions.add(Offset(_rng.nextDouble(), _rng.nextDouble()));
      _sparkleSizes.add(3.0 + _rng.nextDouble() * 7.0);
    }

    _skyFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _scorePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 1.0,
      upperBound: 1.3,
    );
  }

  @override
  void dispose() {
    _gameActiveNotifier?.state = false;
    _submitDebounceTimer?.cancel();
    _focusNode.dispose();
    _gameLoopTimer?.cancel();
    _spawnTimer?.cancel();
    _feedbackResetTimer?.cancel();
    _bannerTimer?.cancel();
    _missedNoticeTimer?.cancel();
    _skyFloatController.dispose();
    _scorePulseController.dispose();
    super.dispose();
  }

  Future<void> _loadHighScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _highScore = prefs.getInt('hoczita_best_score_math_bubbles') ?? 36;
      });
    } catch (_) {}
  }

  Future<void> _saveHighScore() async {
    try {
      if (_score > _highScore) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('hoczita_best_score_math_bubbles', _score);
        setState(() {
          _highScore = _score;
        });
      }

      await GameScoreSyncService.instance.saveScoreParallel(
        gameCodeOrName: 'math_bubbles',
        level: _level.toString(),
        score: _score,
        stars: _score >= 25 ? 3 : (_score >= 12 ? 2 : 1),
      );
    } catch (e) {
      debugPrint('[MathBubbles] Lưu điểm lỗi: $e');
    }
  }

  // ==========================================
  // LOGIC SINH BONG BÓNG & GAME LOOP (20 GIÂY)
  // ==========================================
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && _screenState == 1) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.backspace) {
        _onKeyPress('BACK');
      } else if (key == LogicalKeyboardKey.escape) {
        _onKeyPress('C');
      } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        _submitDebounceTimer?.cancel();
        _checkAnswer(_currentInput);
      } else {
        final char = event.character;
        if (char != null && RegExp(r'^[0-9]$').hasMatch(char)) {
          _onKeyPress(char);
        }
      }
    }
  }

  void _startGame() {
    _submitDebounceTimer?.cancel();
    setState(() {
      _screenState = 1;
      _score = 0;
      _level = 1;
      _hearts = 3;
      _poppedCount = 0;
      _comboStreak = 0;
      _maxCombo = 0;
      _lastSpeedMilestone = 0;
      _currentInput = '';
      _feedbackStatus = null;
      _feedbackText = null;
      _bannerNotice = null;
      _missedBubbleNotice = null;
      _activeBubbles.clear();
      _particles.clear();
      _shockwaves.clear();
      _flashCenters.clear();
      _floatingTexts.clear();
    });

    _spawnInitialBubbles();
    _focusNode.requestFocus();

    // Vòng lặp cập nhật độ mờ dần, vị trí trôi lơ lửng và hiệu ứng hạt (20 FPS = 50ms)
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _screenState != 1) return;
      _updateGameLoop(0.05);
    });

    _spawnTimer?.cancel();
  }

  /// Các vùng phân bố đa dạng trên màn hình để bóng lơ lửng nhiều chỗ
  static const List<Offset> _candidateZones = [
    Offset(0.18, 0.20), // Góc trên bên trái
    Offset(0.50, 0.16), // Phía trên ở giữa
    Offset(0.80, 0.22), // Góc trên bên phải
    Offset(0.18, 0.50), // Khu vực giữa bên trái
    Offset(0.50, 0.46), // Khu vực trung tâm
    Offset(0.82, 0.50), // Khu vực giữa bên phải
    Offset(0.24, 0.72), // Góc dưới bên trái
    Offset(0.50, 0.68), // Phía dưới ở giữa
    Offset(0.76, 0.70), // Góc dưới bên phải
  ];

  /// Chọn vị trí xuất hiện xa nhất so với các quả bóng đang lơ lửng
  Offset _pickBestSpawnLocation() {
    final alive = _activeBubbles.where((b) => !b.isPopping && !b.isDissolving).toList();
    if (alive.isEmpty) {
      final idx = _rng.nextInt(_candidateZones.length);
      return _candidateZones[idx];
    }

    Offset bestZone = _candidateZones[0];
    double maxMinDist = -1.0;

    final shuffled = List<Offset>.from(_candidateZones)..shuffle(_rng);
    for (final zone in shuffled) {
      double minDist = double.infinity;
      for (final b in alive) {
        final dx = zone.dx - b.xRatio;
        final dy = zone.dy - b.yRatio;
        final d = sqrt(dx * dx + dy * dy);
        if (d < minDist) minDist = d;
      }
      if (minDist > maxMinDist) {
        maxMinDist = minDist;
        bestZone = zone;
      }
    }

    // Thêm một chút dao động ngẫu nhiên để các bóng không bao giờ trùng khít vị trí
    final jitterX = (_rng.nextDouble() - 0.5) * 0.08;
    final jitterY = (_rng.nextDouble() - 0.5) * 0.08;
    final finalX = (bestZone.dx + jitterX).clamp(0.12, 0.88).toDouble();
    final finalY = (bestZone.dy + jitterY).clamp(0.12, 0.78).toDouble();
    return Offset(finalX, finalY);
  }

  /// Gói 1: Cân bằng & Vừa sức (Toán: Cấp 1 = 20s, Cấp 2 = 16s, Cấp 3 = 13s)
  /// Nếu vượt qua cấp 3, cứ mỗi 50 điểm tích luỹ giảm thêm 0.5s (tối thiểu 8s)
  double _getLifespanForLevel(int lvl) {
    double base;
    if (lvl == 1) {
      base = 20.0;
    } else if (lvl == 2) {
      base = 16.0;
    } else {
      base = 13.0;
    }

    if (_level >= 3 && _score >= 50) {
      final bonusStage = _score ~/ 50;
      base = max(8.0, base - bonusStage * 0.5);
    }
    return base;
  }

  /// Hệ số tốc độ trôi lơ lửng: Khi vượt qua Cấp 3, tăng nhanh +0.5x mỗi 50 điểm tích luỹ
  double get _speedFactor {
    if (_level >= 3 && _score >= 50) {
      return 1.0 + (_score ~/ 50) * 0.5;
    }
    return 1.0;
  }

  /// Giới hạn số bóng tối đa cùng tồn tại trên màn hình
  int get _maxActiveBubbles => _level == 1 ? 3 : 4;

  void _spawnInitialBubbles() {
    // Vừa bắt đầu: CHỈ XUẤT HIỆN 1 BÓNG DUY NHẤT (100% thời gian = 20 giây)
    final loc = _pickBestSpawnLocation();
    final b = _generateProblemForLevel(_level);
    final firstBubble = BubbleProblem(
      id: UniqueKey().toString(),
      expression: b['expr'] as String,
      answer: b['ans'] as int,
      level: _level,
      xRatio: loc.dx,
      yRatio: loc.dy,
      durationSeconds: _getLifespanForLevel(_level),
      hasTriggeredNextSpawn: false, // Sẽ kích hoạt bóng tiếp theo khi trôi qua 30% thời gian
    );
    firstBubble.remainingSeconds = firstBubble.durationSeconds;
    firstBubble.opacity = 1.0;
    _activeBubbles.add(firstBubble);
  }

  void _spawnNewBubble() {
    final loc = _pickBestSpawnLocation();
    final p = _generateProblemForLevel(_level);
    final newBubble = BubbleProblem(
      id: UniqueKey().toString(),
      expression: p['expr'] as String,
      answer: p['ans'] as int,
      level: _level,
      xRatio: loc.dx,
      yRatio: loc.dy,
      durationSeconds: _getLifespanForLevel(_level),
      hasTriggeredNextSpawn: false,
    );

    setState(() {
      _activeBubbles.add(newBubble);
    });
  }

  Map<String, dynamic> _generateProblemForLevel(int lvl) {
    final existingAnswers = _activeBubbles.map((b) => b.answer).toSet();

    for (int retry = 0; retry < 30; retry++) {
      int type;
      if (lvl == 1) {
        type = _rng.nextInt(2); // 0: +, 1: −
      } else if (lvl == 2) {
        type = _rng.nextInt(3); // 0: +, 1: −, 2: ×
      } else {
        type = _rng.nextInt(4); // 0: +, 1: −, 2: ×, 3: ÷
      }

      String expr = '';
      int ans = 0;

      if (type == 0) {
        // Phép cộng chuẩn dạng: a + b
        final a = 2 + _rng.nextInt(lvl == 1 ? 9 : (lvl == 2 ? 14 : 19));
        final b = 2 + _rng.nextInt(lvl == 1 ? 9 : (lvl == 2 ? 14 : 19));
        expr = '$a + $b';
        ans = a + b;
      } else if (type == 1) {
        // Phép trừ chuẩn dạng: a − b
        final b = 2 + _rng.nextInt(lvl == 1 ? 9 : (lvl == 2 ? 14 : 18));
        final ansVal = 2 + _rng.nextInt(lvl == 1 ? 9 : (lvl == 2 ? 14 : 18));
        final a = b + ansVal;
        expr = '$a − $b';
        ans = ansVal;
      } else if (type == 2) {
        // Phép nhân chuẩn dạng: a × b
        final a = 2 + _rng.nextInt(lvl >= 3 ? 10 : 9);
        final b = 2 + _rng.nextInt(lvl >= 3 ? 10 : 9);
        expr = '$a × $b';
        ans = a * b;
      } else {
        // Phép chia chuẩn dạng: a ÷ b
        final divisor = 2 + _rng.nextInt(8);
        final quotient = 2 + _rng.nextInt(8);
        final dividend = divisor * quotient;
        expr = '$dividend ÷ $divisor';
        ans = quotient;
      }

      if (!existingAnswers.contains(ans)) {
        return {'expr': expr, 'ans': ans};
      }
    }

    final fallbackA = 3 + _rng.nextInt(7);
    final fallbackB = 2 + _rng.nextInt(6);
    return {'expr': '$fallbackA + $fallbackB', 'ans': fallbackA + fallbackB};
  }

  void _updateGameLoop(double dt) {
    bool stateChanged = false;
    final List<BubbleProblem> expired = [];
    bool needSpawnSuccessor = false;

    for (final bubble in _activeBubbles) {
      if (bubble.isPopping || bubble.isDissolving) continue;

      // Cập nhật thời gian trôi bồng bềnh với hệ số tốc độ
      bubble.floatElapsed += dt * _speedFactor;

      bubble.remainingSeconds -= dt;
      // Quy tắc mờ dần theo thời gian: opacity = remaining / durationSeconds
      bubble.opacity = (bubble.remainingSeconds / bubble.durationSeconds).clamp(0.0, 1.0).toDouble();

      // Kích hoạt bóng tiếp theo khi bóng này đã trôi qua 30% thời gian (còn lại <= 70%)
      if (!bubble.hasTriggeredNextSpawn && bubble.remainingSeconds <= bubble.durationSeconds * 0.70) {
        bubble.hasTriggeredNextSpawn = true;
        needSpawnSuccessor = true;
      }

      if (bubble.remainingSeconds <= 0.0) {
        expired.add(bubble);
      } else {
        stateChanged = true;
      }
    }

    // Mỗi bóng xuất hiện khi bóng trước trôi qua 30%, nhưng không vượt trần số bóng tối đa
    final livingCount = _activeBubbles.where((b) => !b.isPopping && !b.isDissolving).length;
    if (needSpawnSuccessor && livingCount < _maxActiveBubbles) {
      _spawnNewBubble();
      stateChanged = true;
    }

    // Xử lý bong bóng bị nổ/tan do hết thời gian
    for (final b in expired) {
      b.isDissolving = true;
      _onBubbleMissed(b);
      stateChanged = true;
    }

    // Cập nhật hiệu ứng hạt (Particles)
    if (_particles.isNotEmpty) {
      for (final p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.0002; // Trọng lực nhẹ rơi xuống
        p.vx *= 0.96;   // Ma sát không khí
        p.opacity = (p.opacity - 0.04).clamp(0.0, 1.0).toDouble();
      }
      _particles.removeWhere((p) => p.opacity <= 0.0);
      stateChanged = true;
    }

    // Cập nhật vòng sóng xung kích (Shockwave Rings)
    if (_shockwaves.isNotEmpty) {
      for (final sw in _shockwaves) {
        sw.radius += (sw.maxRadius - sw.radius) * 0.16 + 2.5;
        sw.opacity = (sw.opacity - 0.065).clamp(0.0, 1.0).toDouble();
      }
      _shockwaves.removeWhere((sw) => sw.opacity <= 0.0 || sw.radius >= sw.maxRadius);
      stateChanged = true;
    }

    // Cập nhật đốm flash bùng sáng tại tâm
    if (_flashCenters.isNotEmpty) {
      for (final f in _flashCenters) {
        f['opacity'] = ((f['opacity'] as double) - 0.08).clamp(0.0, 1.0).toDouble();
        f['size'] = (f['size'] as double) + 4.0;
      }
      _flashCenters.removeWhere((f) => (f['opacity'] as double) <= 0.0);
      stateChanged = true;
    }

    // Cập nhật vị trí các chữ nổi +2, +3...
    if (_floatingTexts.isNotEmpty) {
      for (final ft in _floatingTexts) {
        ft['y'] -= 0.004;
        ft['opacity'] = (ft['opacity'] - 0.035).clamp(0.0, 1.0).toDouble();
      }
      _floatingTexts.removeWhere((ft) => ft['opacity'] <= 0.0);
      stateChanged = true;
    }

    if (stateChanged && mounted) {
      setState(() {});
    }
  }

  void _onBubbleMissed(BubbleProblem b) {
    HapticFeedback.mediumImpact();
    setState(() {
      _comboStreak = 0; // Đứt chuỗi combo
      _hearts = max(0, _hearts - 1);
      _missedBubbleNotice = 'Bóng đã tan! Đáp án là ${b.answer}';
    });

    _missedNoticeTimer?.cancel();
    _missedNoticeTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _missedBubbleNotice = null;
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _activeBubbles.remove(b);
        });
        if (_hearts <= 0) {
          _endGame();
        } else {
          final living = _activeBubbles.where((bubble) => !bubble.isPopping && !bubble.isDissolving).toList();
          if (living.isEmpty) {
            _spawnNewBubble();
          } else if (living.length < _maxActiveBubbles) {
            final hasPendingTrigger = living.any((b) => !b.hasTriggeredNextSpawn);
            if (!hasPendingTrigger) {
              _spawnNewBubble();
            }
          }
        }
      }
    });
  }

  void _onKeyPress(String key) {
    if (_screenState != 1 || _feedbackStatus == 'correct') return;

    HapticFeedback.lightImpact();

    if (key == 'BACK') {
      _submitDebounceTimer?.cancel();
      if (_currentInput.isNotEmpty) {
        final newVal = _currentInput.substring(0, _currentInput.length - 1);
        setState(() {
          _currentInput = newVal;
          _feedbackStatus = null;
          _feedbackText = null;
        });
        if (newVal.isNotEmpty) {
          _scheduleAnswerCheck(newVal, delayMs: 320);
        }
      }
    } else if (key == 'C') {
      _submitDebounceTimer?.cancel();
      setState(() {
        _currentInput = '';
        _feedbackStatus = null;
        _feedbackText = null;
      });
    } else {
      if (_currentInput.length < 3) {
        final nextVal = _currentInput + key;
        setState(() {
          _currentInput = nextVal;
          _feedbackStatus = null;
          _feedbackText = null;
        });

        // Nếu đã đủ 3 chữ số (tối đa), kiểm tra nhanh 120ms;
        // Nếu 1-2 chữ số, đợi 280ms để tránh việc gõ nhanh '100' bị nhận chốt nhầm '10'
        final delayMs = nextVal.length >= 3 ? 120 : 280;
        _scheduleAnswerCheck(nextVal, delayMs: delayMs);
      }
    }
  }

  void _scheduleAnswerCheck(String inputVal, {int delayMs = 280}) {
    _submitDebounceTimer?.cancel();
    _submitDebounceTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted || _screenState != 1) return;
      _checkAnswer(inputVal);
    });
  }

  void _checkAnswer(String inputVal) {
    if (inputVal.isEmpty || _screenState != 1 || _feedbackStatus == 'correct') return;

    final intVal = int.tryParse(inputVal);
    if (intVal == null) return;

    // Tìm bong bóng có đáp án trùng khớp chính xác
    BubbleProblem? matched;
    for (final b in _activeBubbles) {
      if (!b.isPopping && !b.isDissolving && b.answer == intVal) {
        matched = b;
        break;
      }
    }

    if (matched != null) {
      _onCorrectAnswer(matched);
    } else {
      // Kiểm tra xem có khả năng là tiền tố của đáp án bong bóng nào đang bay không
      bool canBePrefix = false;
      for (final b in _activeBubbles) {
        if (!b.isPopping && !b.isDissolving && b.answer.toString().startsWith(inputVal)) {
          canBePrefix = true;
          break;
        }
      }

      // Chỉ báo sai và xóa khi chuỗi đã nhập không phải tiền tố của bất kỳ bóng nào
      if (!canBePrefix) {
        _onWrongAnswer(inputVal);
      }
    }
  }

  void _onCorrectAnswer(BubbleProblem bubble) {
    _submitDebounceTimer?.cancel();
    HapticFeedback.heavyImpact();
    _scorePulseController.forward(from: 0.0);

    _comboStreak++;
    if (_comboStreak > _maxCombo) _maxCombo = _comboStreak;

    final basePoints = bubble.level >= 3 ? 3 : (bubble.level == 2 ? 2 : 1);
    final comboBonus = _comboStreak >= 5 ? 2 : (_comboStreak >= 3 ? 1 : 0);
    final pointsEarned = basePoints + comboBonus;

    setState(() {
      bubble.isPopping = true;
      _score += pointsEarned;
      _poppedCount++;
      _feedbackStatus = 'correct';
      _feedbackText = '+$pointsEarned';

      // Chữ nổi bay lên kèm hiệu ứng Combo
      final comboTag = _comboStreak >= 3 ? ' (x$_comboStreak 🔥)' : '';
      _floatingTexts.add({
        'x': bubble.xRatio,
        'y': bubble.yRatio,
        'text': '+$pointsEarned$comboTag 🌟',
        'opacity': 1.0,
      });

      // Tạo hiệu ứng nổ rực rỡ (tăng quy mô nếu đang có chuỗi Combo)
      _spawnExplosionEffect(bubble.xRatio, bubble.yRatio, isCombo: _comboStreak >= 3);
    });

    // Thông báo Combo hào hứng
    if (_comboStreak == 3) {
      _showBannerNotice('COMBO x3! 🔥 Cố lên!');
    } else if (_comboStreak == 5) {
      _showBannerNotice('SIÊU ĐỈNH x5! ⚡ Xuất sắc!');
    } else if (_comboStreak == 10) {
      _showBannerNotice('THẦN TỐC x10! 🚀 Quá tuyệt vời!');
    }

    if (_score >= 20 && _level < 3) {
      _triggerLevelUp(3);
    } else if (_score >= 10 && _level < 2) {
      _triggerLevelUp(2);
    }

    // Tăng nhanh 0.5 mỗi khi vượt qua cấp 3 và đạt mốc 50 điểm tích luỹ
    if (_level >= 3 && _score >= 50) {
      final currentMilestone = _score ~/ 50;
      if (currentMilestone > _lastSpeedMilestone) {
        _lastSpeedMilestone = currentMilestone;
        _showBannerNotice('Tốc độ tăng +0.5x! ⚡ (${currentMilestone * 50} Điểm)');
      }
    }

    _feedbackResetTimer?.cancel();
    _feedbackResetTimer = Timer(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      setState(() {
        _activeBubbles.remove(bubble);
        _currentInput = '';
        _feedbackStatus = null;
        _feedbackText = null;
      });
      final living = _activeBubbles.where((b) => !b.isPopping && !b.isDissolving).toList();
      if (living.isEmpty) {
        _spawnNewBubble();
      } else if (living.length < _maxActiveBubbles) {
        final hasPendingTrigger = living.any((b) => !b.hasTriggeredNextSpawn);
        if (!hasPendingTrigger) {
          _spawnNewBubble();
        }
      }
    });
  }

  void _onWrongAnswer(String wrongVal) {
    HapticFeedback.vibrate();
    setState(() {
      _comboStreak = 0; // Nhập sai -> đứt chuỗi combo
      _feedbackStatus = 'wrong';
      _feedbackText = '!';
    });

    _feedbackResetTimer?.cancel();
    _feedbackResetTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() {
        _currentInput = '';
        _feedbackStatus = null;
        _feedbackText = null;
      });
    });
  }

  void _triggerLevelUp(int newLevel) {
    setState(() {
      _level = newLevel;
      _bannerNotice = 'Nhanh hơn! ⚡ Cấp $newLevel';
    });

    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _bannerNotice = null;
        });
      }
    });
  }

  void _showBannerNotice(String text) {
    setState(() {
      _bannerNotice = text;
    });
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _bannerNotice = null;
        });
      }
    });
  }

  /// Khởi tạo vụ nổ rực rỡ với 36 (hoặc 48 khi Combo) hạt, vòng sóng xung kích và đốm chớp sáng
  void _spawnExplosionEffect(double rx, double ry, {bool isCombo = false}) {
    // 1. Thêm 2 vòng sóng xung kích tỏa ra
    _shockwaves.add(
      ShockwaveRing(
        x: rx,
        y: ry,
        radius: 12.0,
        maxRadius: isCombo ? 160.0 : 130.0,
        opacity: 0.95,
        color: isCombo ? const Color(0xFFF59E0B) : MathBubblesColors.primaryCobalt,
      ),
    );
    _shockwaves.add(
      ShockwaveRing(
        x: rx,
        y: ry,
        radius: 6.0,
        maxRadius: isCombo ? 110.0 : 90.0,
        opacity: 0.85,
        color: MathBubblesColors.scoreStar,
      ),
    );

    // 2. Thêm đốm flash bừng sáng tại tâm
    _flashCenters.add({
      'x': rx,
      'y': ry,
      'size': isCombo ? 42.0 : 28.0,
      'opacity': 1.0,
    });

    // 3. Sinh 36 (hoặc 48) hạt nổ đa dạng (Sao vàng, giọt ngọc, tia sáng Cobalt)
    final count = isCombo ? 48 : 36;
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.003 + _rng.nextDouble() * 0.012;
      final isStar = i % 3 == 0;
      final color = isStar
          ? MathBubblesColors.scoreStar
          : (i % 2 == 0 ? MathBubblesColors.primaryCobalt : const Color(0xFF60A5FA));

      _particles.add(
        BubbleParticle(
          x: rx,
          y: ry,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          size: isStar ? (7.0 + _rng.nextDouble() * 5.0) : (4.0 + _rng.nextDouble() * 6.0),
          color: color,
          opacity: 1.0,
          isStar: isStar,
        ),
      );
    }
  }

  void _endGame() {
    _submitDebounceTimer?.cancel();
    _gameLoopTimer?.cancel();
    _spawnTimer?.cancel();
    _saveHighScore();
    _focusNode.unfocus();
    setState(() {
      _screenState = 2; // Screen: Game Over
    });
  }

  void _showPauseDialog() {
    _submitDebounceTimer?.cancel();
    _focusNode.unfocus();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Tạm Dừng ⏸️',
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: MathBubblesColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bé đang tạm nghỉ một chút nhé!',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(color: MathBubblesColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            _build3DButton(
              label: 'Tiếp Tục Chơi',
              color: MathBubblesColors.primaryButton,
              onTap: () {
                Navigator.pop(ctx);
                _focusNode.requestFocus();
              },
            ),
            const SizedBox(height: 12),
            _build3DButton(
              label: 'Chơi Lại',
              color: MathBubblesColors.secondaryBlue,
              onTap: () {
                Navigator.pop(ctx);
                _startGame();
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _screenState = 0);
              },
              child: Text(
                'Thoát Về Trang Chủ',
                style: GoogleFonts.baloo2(color: MathBubblesColors.textSecondary, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReferenceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bóng mờ dần trong 20 giây',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: MathBubblesColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Quy tắc mờ dần: Bóng tan dần sau 20 giây, trở nên trong suốt chứ không chuyển sang xám!',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 13,
                color: MathBubblesColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFadingStageCard(timeLabel: '0 giây', opacity: 1.0, expression: '7 × 8', caption: '100% rõ nét'),
                  _buildFadingStageCard(timeLabel: '5 giây', opacity: 0.8, expression: '7 × 8', caption: 'Mờ nhẹ ~80%'),
                  _buildFadingStageCard(timeLabel: '10 giây', opacity: 0.5, expression: '7 × 8', caption: '~50% opacity', tag: 'Bóng mới'),
                  _buildFadingStageCard(timeLabel: '15 giây', opacity: 0.25, expression: '7 × 8', caption: 'Sắp tan ~25%'),
                  _buildFadingStageCard(timeLabel: '20 giây', opacity: 0.08, expression: '7 × 8', caption: 'Tan biến', tag: 'Mất 1 tim', tagColor: MathBubblesColors.heartRed),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _build3DButton(
              label: 'Đã Hiểu',
              color: MathBubblesColors.primaryButton,
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFadingStageCard({
    required String timeLabel,
    required double opacity,
    required String expression,
    required String caption,
    String? tag,
    Color? tagColor,
  }) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: MathBubblesColors.lightBlueBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MathBubblesColors.borderCobalt),
      ),
      child: Column(
        children: [
          Text(
            timeLabel,
            style: GoogleFonts.baloo2(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: MathBubblesColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 58,
            height: 58,
            child: GlossyBubbleWidget(
              expression: expression,
              opacity: opacity,
              baseColor: MathBubblesColors.bubbleBase,
              diameter: 58,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(fontSize: 10, color: MathBubblesColors.textSecondary),
          ),
          if (tag != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: (tagColor ?? MathBubblesColors.noticeAmber).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tag,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  color: tagColor ?? MathBubblesColors.noticeAmber,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // BUILD METHOD ROUTER
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MathBubblesColors.skyBottom,
      body: Stack(
        children: [
          // Nền trời ban ngày tươi sáng với các hạt bong bóng bồng bềnh
          Positioned.fill(
            child: CustomPaint(
              painter: DaylightBubbleSkyPainter(
                sparklePositions: _sparklePositions,
                sparkleSizes: _sparkleSizes,
                floatProgress: _skyFloatController.value,
              ),
            ),
          ),

          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _buildCurrentScreen(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_screenState) {
      case 0:
        return _buildIntroScreen();
      case 1:
        return _buildPlayScreen();
      case 2:
      default:
        return _buildGameOverScreen();
    }
  }

  // ==========================================
  // SCREEN 1: INTRO / LOBBY (ĐỒNG BỘ BỐ CỤC THEO THIẾT KẾ MẪU)
  // ==========================================
  Widget _buildIntroScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final isShortScreen = screenHeight < 540;

        Widget introBody;
        if (isShortScreen) {
          // Màn hình quá ngắn (landscape hoặc máy cũ cực nhỏ): cuộn an toàn
          introBody = SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: _buildFloatingBubblesSky(
                    width: constraints.maxWidth - 40,
                    height: 240,
                  ),
                ),
                const SizedBox(height: 14),
                _buildIntroTutorialCard(),
                const SizedBox(height: 16),
                _buildIntroStartButton(),
                const SizedBox(height: 10),
                _buildIntroHighScore(),
                const SizedBox(height: 16),
              ],
            ),
          );
        } else {
          // Bố cục chuẩn như thiết kế mẫu (media_1792748609068_2c2d9d27.png):
          // - 3 quả bóng bay bồng bềnh chiếm trọn vùng trời ở giữa (Expanded)
          // - Cụm nút BẮT ĐẦU + thẻ hướng dẫn được ghim sát đáy màn hình (loại bỏ khoảng trống chết)
          introBody = Column(
            children: [
              // Khu vực bong bóng lơ lửng ở giữa chiếm toàn bộ không gian còn lại
              Expanded(
                child: LayoutBuilder(
                  builder: (context, skyConstraints) {
                    return _buildFloatingBubblesSky(
                      width: skyConstraints.maxWidth,
                      height: skyConstraints.maxHeight,
                    );
                  },
                ),
              ),

              // Cụm hướng dẫn + Nút Bắt đầu + Kỷ lục ghim sát đáy
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIntroTutorialCard(),
                    const SizedBox(height: 16),
                    _buildIntroStartButton(),
                    const SizedBox(height: 10),
                    _buildIntroHighScore(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          key: const ValueKey('intro_screen'),
          children: [
            // 1. THANH TRẠNG THÁI TRÊN CÙNG
            _buildIntroTopBar(),

            // 2. PHẦN THÂN MÀN HÌNH
            Expanded(child: introBody),
          ],
        );
      },
    );
  }

  Widget _buildIntroTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Nút quay lại tròn
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: MathBubblesColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: MathBubblesColors.textPrimary, size: 18),
            ),
          ),

          // Tiêu đề + Icon (i) ngay cạnh
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bong Bóng Toán Học',
                style: GoogleFonts.baloo2(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: MathBubblesColors.primaryCobalt,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _showReferenceSheet,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: MathBubblesColors.borderCobalt),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.info_outline_rounded, color: MathBubblesColors.primaryCobalt, size: 15),
                  ),
                ),
              ),
            ],
          ),

          // Nút bật/tắt âm thanh tròn
          const GameSoundToggleButton(isPlayScreen: false),
        ],
      ),
    );
  }

  Widget _buildFloatingBubblesSky({required double width, required double height}) {
    return AnimatedBuilder(
      animation: _skyFloatController,
      builder: (context, child) {
        final t = _skyFloatController.value * 2 * pi;
        // Dao động lơ lửng bồng bềnh nhẹ nhàng
        final dy1 = sin(t) * 8.0;
        final dx1 = cos(t * 0.7) * 4.0;

        final dy2 = sin(t + 2.0) * 8.0;
        final dx2 = cos(t * 0.8 + 1.2) * 4.5;

        final dy3 = sin(t + 4.2) * 9.0;
        final dx3 = cos(t * 0.6 + 2.8) * 5.0;

        // Kích thước bong bóng tương tự hình mẫu
        final double d1 = (height * 0.26).clamp(100.0, 126.0).toDouble();
        final double d2 = (height * 0.24).clamp(94.0, 118.0).toDouble();
        final double d3 = (height * 0.23).clamp(90.0, 112.0).toDouble();

        // Vị trí hình tam giác ngược như hình mẫu media_1792748609068_2c2d9d27.png:
        // Bóng 1 (6 × 7): Phía trên - bên trái
        final top1 = (height * 0.14 + dy1).clamp(6.0, max(6.0, height - d1 - 6)).toDouble();
        final left1 = (width * 0.10 + dx1).clamp(6.0, max(6.0, width - d1 - 6)).toDouble();

        // Bóng 2 (15 − 8): Phía trên - bên phải
        final top2 = (height * 0.18 + dy2).clamp(6.0, max(6.0, height - d2 - 6)).toDouble();
        final right2 = (width * 0.10 + dx2).clamp(6.0, max(6.0, width - d2 - 6)).toDouble();

        // Bóng 3 (24 ÷ 4): Ở giữa phía dưới
        final top3 = (height * 0.54 + dy3).clamp(6.0, max(6.0, height - d3 - 6)).toDouble();
        final left3 = ((width - d3) / 2 + dx3).clamp(6.0, max(6.0, width - d3 - 6)).toDouble();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Bóng 1: trên bên trái (6 × 7) - mờ nhẹ (0.65)
            Positioned(
              top: top1,
              left: left1,
              child: GlossyBubbleWidget(
                expression: '6 × 7',
                opacity: 0.65,
                baseColor: MathBubblesColors.bubbleBase,
                diameter: d1,
                fontSize: d1 * 0.21,
              ),
            ),

            // Bóng 2: trên bên phải (15 − 8) - rõ dần (0.85)
            Positioned(
              top: top2,
              right: right2,
              child: GlossyBubbleWidget(
                expression: '15 − 8',
                opacity: 0.85,
                baseColor: MathBubblesColors.bubbleBase,
                diameter: d2,
                fontSize: d2 * 0.20,
              ),
            ),

            // Bóng 3: ở giữa phía dưới (24 ÷ 4) - đậm nhất (1.0, chuẩn màu chủ đạo, không tối hơn)
            Positioned(
              top: top3,
              left: left3,
              child: GlossyBubbleWidget(
                expression: '24 ÷ 4',
                opacity: 1.0,
                baseColor: MathBubblesColors.bubbleBase,
                diameter: d3,
                fontSize: d3 * 0.19,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIntroTutorialCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MathBubblesColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: MathBubblesColors.primaryCobalt.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStepItem(
            icon: '📖',
            text: 'Đọc phép\ntính',
            bgColor: const Color(0xFFEFF6FF),
          ),
          const Icon(Icons.arrow_forward_rounded, color: Color(0xFF94A3B8), size: 18),
          _buildStepItem(
            icon: '⌨️',
            text: 'Gõ đáp\nán',
            bgColor: const Color(0xFFEFF6FF),
          ),
          const Icon(Icons.arrow_forward_rounded, color: Color(0xFF94A3B8), size: 18),
          _buildStepItem(
            icon: '🫧',
            text: 'Nổ bóng trong\n20 giây!',
            bgColor: const Color(0xFFF5F3FF),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroStartButton() {
    return _build3DButton(
      label: 'BẮT ĐẦU',
      color: MathBubblesColors.primaryButton,
      onTap: _startGame,
    );
  }

  Widget _buildIntroHighScore() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🏆 ', style: TextStyle(fontSize: 16)),
        Text(
          'Kỷ lục: ',
          style: GoogleFonts.baloo2(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: MathBubblesColors.textSecondary,
          ),
        ),
        Text(
          '$_highScore điểm',
          style: GoogleFonts.baloo2(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: MathBubblesColors.primaryCobalt,
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem({required String icon, required String text, Color? bgColor}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor ?? const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 22)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: MathBubblesColors.textPrimary,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SCREEN 2: GAMEPLAY
  // ==========================================
  Widget _buildPlayScreen() {
    return KeyboardListener(
      key: const ValueKey('play_screen'),
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Column(
      children: [
        // 1. TOP STATUS BAR (Hài hòa tông sáng)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button (Nền trắng viền nhẹ)
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: MathBubblesColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: MathBubblesColors.textPrimary, size: 18),
                ),
              ),

              // Pill Điểm sao + Cấp độ
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _scorePulseController,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: MathBubblesColors.scoreStar, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '$_score',
                            style: GoogleFonts.baloo2(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: MathBubblesColors.lightBlueBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MathBubblesColors.borderCobalt),
                    ),
                    child: Text(
                      'Cấp $_level',
                      style: GoogleFonts.baloo2(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: MathBubblesColors.primaryCobalt,
                      ),
                    ),
                  ),

                  // Huy hiệu Combo rực lửa khi đạt chuỗi liên tiếp từ 2 trở lên
                  if (_comboStreak >= 2) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFF59E0B)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 3),
                          Text(
                            'x$_comboStreak',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              // Trái tim + Pause Button
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...List.generate(3, (i) {
                    final isAlive = i < _hearts;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 20,
                        color: isAlive
                            ? MathBubblesColors.heartRed
                            : MathBubblesColors.heartGrey,
                      ),
                    );
                  }),
                  const SizedBox(width: 6),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: MathBubblesColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: _showPauseDialog,
                      icon: const Icon(Icons.pause_rounded, color: MathBubblesColors.textSecondary, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. PLAYFIELD (BẦU TRỜI BONG BÓNG TOÁN HỌC)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _focusNode.requestFocus(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final playfieldWidth = constraints.maxWidth;
                final playfieldHeight = constraints.maxHeight;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (_bannerNotice != null)
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: MathBubblesColors.primaryButton,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: MathBubblesColors.primaryButton.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Text(
                              _bannerNotice!,
                              style: GoogleFonts.baloo2(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (_missedBubbleNotice != null)
                      Positioned(
                        top: 48,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: MathBubblesColors.noticeAmber,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.priority_high_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  _missedBubbleNotice!,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // BONG BÓNG TRÔI LƠ LỬNG RỘNG KHẮP LIÊN TỤC
                    ..._activeBubbles.map((bubble) {
                      final bubbleDiameter = 144.0;
                      
                      // Chuyển động bồng bềnh lơ lửng đa hướng liên tục (lơ lửng rộng khắp nhiều chỗ)
                      final wobbleX = sin(bubble.floatElapsed * bubble.floatSpeedX + bubble.floatPhase) * 35.0 +
                                      cos(bubble.floatElapsed * bubble.wanderSpeed + bubble.wanderPhase) * 22.0;
                      final wobbleY = cos(bubble.floatElapsed * bubble.floatSpeedY + bubble.floatPhase) * 32.0 +
                                      sin(bubble.floatElapsed * (bubble.wanderSpeed * 1.3) + bubble.wanderPhase) * 20.0;
                      final wobbleScale = 1.0 + sin(bubble.floatElapsed * 2.0 + bubble.floatPhase) * 0.035;

                      final leftPos = bubble.xRatio * (playfieldWidth - bubbleDiameter) + wobbleX;
                      final topPos = bubble.yRatio * (playfieldHeight - bubbleDiameter) + wobbleY;

                      return Positioned(
                        left: leftPos.clamp(8.0, playfieldWidth - bubbleDiameter - 8.0).toDouble(),
                        top: topPos.clamp(8.0, playfieldHeight - bubbleDiameter - 8.0).toDouble(),
                        child: Transform.scale(
                          scale: wobbleScale,
                          child: GlossyBubbleWidget(
                            expression: bubble.expression,
                            opacity: bubble.opacity,
                            baseColor: bubble.baseColor,
                            diameter: bubbleDiameter,
                            isDissolving: bubble.isDissolving,
                            isCritical: bubble.isCritical,
                          ),
                        ),
                      );
                    }),

                    // VÒNG SÓNG XUNG KÍCH KHI NỔ (SHOCKWAVE RIPPLES)
                    ..._shockwaves.map((sw) {
                      final cx = sw.x * playfieldWidth;
                      final cy = sw.y * playfieldHeight;
                      return Positioned(
                        left: cx - sw.radius,
                        top: cy - sw.radius,
                        child: IgnorePointer(
                          child: Container(
                            width: sw.radius * 2,
                            height: sw.radius * 2,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: sw.color.withValues(alpha: sw.opacity),
                                width: 3.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // ĐỐM FLASH BÙNG SÁNG TẠI TÂM NỔ
                    ..._flashCenters.map((f) {
                      final cx = (f['x'] as double) * playfieldWidth;
                      final cy = (f['y'] as double) * playfieldHeight;
                      final size = f['size'] as double;
                      final opacity = f['opacity'] as double;
                      return Positioned(
                        left: cx - size / 2,
                        top: cy - size / 2,
                        child: IgnorePointer(
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: opacity),
                              boxShadow: [
                                BoxShadow(
                                  color: MathBubblesColors.primaryCobalt.withValues(alpha: opacity * 0.8),
                                  blurRadius: 18,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    // CÁC HẠT NỔ BONG BÓNG (PARTICLES)
                    ..._particles.map((p) {
                      final px = p.x * playfieldWidth;
                      final py = p.y * playfieldHeight;
                      return Positioned(
                        left: px - p.size / 2,
                        top: py - p.size / 2,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: p.opacity,
                            child: p.isStar
                                ? Icon(
                                    Icons.star_rounded,
                                    size: p.size,
                                    color: p.color,
                                  )
                                : Container(
                                    width: p.size,
                                    height: p.size,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: p.color,
                                      boxShadow: [
                                        BoxShadow(
                                          color: p.color.withValues(alpha: 0.6),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      );
                    }),

                    // CHỮ NỔI BAY LÊN (+1, +2, +3)
                    ..._floatingTexts.map((ft) {
                      final tx = (ft['x'] as double) * playfieldWidth;
                      final ty = (ft['y'] as double) * playfieldHeight;
                      return Positioned(
                        left: tx - 40,
                        top: ty - 20,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: ft['opacity'] as double,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: MathBubblesColors.scoreStar, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: MathBubblesColors.scoreStar.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Text(
                                ft['text'] as String,
                                style: GoogleFonts.baloo2(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ),

        // 3. INPUT DISPLAY (Ô HIỂN THỊ ĐÁP ÁN ĐANG GÕ)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: GestureDetector(
            onTap: () {
              if (_currentInput.isNotEmpty) {
                _submitDebounceTimer?.cancel();
                _checkAnswer(_currentInput);
              }
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _feedbackStatus == 'correct'
                      ? MathBubblesColors.correctGreen
                      : (_feedbackStatus == 'wrong'
                          ? MathBubblesColors.noticeAmber
                          : const Color(0xFFCBD5E1)),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_currentInput.isEmpty)
                    Text(
                      'Chạm số bên dưới để gõ đáp án',
                      style: GoogleFonts.baloo2(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    )
                  else
                    Text(
                      _currentInput,
                      style: GoogleFonts.baloo2(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                        color: _feedbackStatus == 'correct'
                            ? MathBubblesColors.correctGreen
                            : (_feedbackStatus == 'wrong'
                                ? MathBubblesColors.noticeAmber
                                : const Color(0xFF1E293B)),
                      ),
                    ),

                  if (_feedbackText != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      _feedbackStatus == 'correct'
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      color: _feedbackStatus == 'correct'
                          ? MathBubblesColors.correctGreen
                          : MathBubblesColors.noticeAmber,
                      size: 22,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // 4. ON-SCREEN KEYPAD (BÀN PHÍM PHỔ THÔNG, KHÔNG MÀU MÈ)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9), // Màu xám nhạt trung tính chuẩn bàn phím
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
            border: Border(
              top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildKeypadRow(['1', '2', '3']),
              const SizedBox(height: 6),
              _buildKeypadRow(['4', '5', '6']),
              const SizedBox(height: 6),
              _buildKeypadRow(['7', '8', '9']),
              const SizedBox(height: 6),
              _buildKeypadRow(['C', '0', 'BACK']),
            ],
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: _buildKeypadButton(key),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeypadButton(String key) {
    final isBack = key == 'BACK';
    final isClear = key == 'C';
    final isAction = isBack || isClear;

    // Phong cách phổ thông: phím số trắng sạch, phím chức năng xám nhẹ trung tính
    final Color bgColor = isAction ? const Color(0xFFE2E8F0) : Colors.white;
    final Color textColor = isAction ? const Color(0xFF475569) : const Color(0xFF1E293B);

    Widget content;
    if (isBack) {
      content = const Icon(Icons.backspace_outlined, color: Color(0xFF475569), size: 21);
    } else if (isClear) {
      content = Text(
        'C',
        style: GoogleFonts.baloo2(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      );
    } else {
      content = Text(
        key,
        style: GoogleFonts.baloo2(
          fontSize: 23,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(key),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isAction ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFFCBD5E1),
                offset: Offset(0, 1.8),
                blurRadius: 0,
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }

  // ==========================================
  // SCREEN 3: MÀN KẾT THÚC (GAME OVER)
  // ==========================================
  Widget _buildGameOverScreen() {
    return Center(
      key: const ValueKey('game_over_screen'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: MathBubblesColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: MathBubblesColors.primaryCobalt.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFEF3C7),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 2),
                ),
                alignment: Alignment.center,
                child: const Text('🏆', style: TextStyle(fontSize: 38)),
              ),
              const SizedBox(height: 16),

              Text(
                'Giỏi lắm!',
                style: GoogleFonts.baloo2(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: MathBubblesColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Con đã nổ $_poppedCount quả bóng',
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MathBubblesColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.favorite_rounded, color: Color(0xFFCBD5E1), size: 24),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('Điểm', '$_score'),
                    Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                    _buildStatColumn('Combo', '$_maxCombo 🔥'),
                    Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                    _buildStatColumn('Cấp', '$_level'),
                    Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                    _buildStatColumn('Kỷ lục', '$_highScore'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              MiniGameRankBanner(
                gameName: 'math_bubbles',
                gameTitle: 'Bong Bóng Toán Học',
                currentScore: _score,
              ),
              const SizedBox(height: 20),

              _build3DButton(
                label: 'Chơi Lại',
                color: MathBubblesColors.primaryButton,
                onTap: _startGame,
              ),
              const SizedBox(height: 10),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Về Trang Chủ',
                  style: GoogleFonts.baloo2(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: MathBubblesColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.baloo2(fontSize: 12, color: MathBubblesColors.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.baloo2(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: MathBubblesColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _build3DButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(26),
        child: Container(
          width: double.infinity,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: color == MathBubblesColors.primaryButton
                    ? MathBubblesColors.primaryButtonShadow
                    : const Color(0xFF1447A0),
                offset: const Offset(0, 3.5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.baloo2(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// GLOSSY SOAP BUBBLE WIDGET (SẮC NÉT TRÊN NỀN SÁNG)
// ==========================================
class GlossyBubbleWidget extends StatelessWidget {
  final String expression;
  final double opacity;
  final Color baseColor;
  final double diameter;
  final double? fontSize;
  final bool isDissolving;
  final bool isCritical;

  const GlossyBubbleWidget({
    super.key,
    required this.expression,
    required this.opacity,
    required this.baseColor,
    required this.diameter,
    this.fontSize,
    this.isDissolving = false,
    this.isCritical = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0).toDouble(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(diameter, diameter),
            painter: GlossyBubblePainter(
              baseColor: baseColor,
              isDissolving: isDissolving,
              isCritical: isCritical,
            ),
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    expression,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.baloo2(
                      fontSize: fontSize ?? (diameter >= 130 ? 30 : 23),
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withValues(alpha: max(0.5, opacity)),
                      shadows: [
                        BoxShadow(
                          color: const Color(0xFF001B44).withValues(alpha: 0.6),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Biểu tượng cảnh báo nguy cấp khi bóng sắp tan
          if (isCritical && !isDissolving)
            Positioned(
              top: 8,
              right: 14,
              child: Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==========================================
// PAINTER: BONG BÓNG XÀ PHÒNG COBALT 3D ÓNG ÁNH
// ==========================================
class GlossyBubblePainter extends CustomPainter {
  final Color baseColor;
  final bool isDissolving;
  final bool isCritical;

  GlossyBubblePainter({
    required this.baseColor,
    this.isDissolving = false,
    this.isCritical = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    if (isDissolving) {
      final dissolvePaint = Paint()
        ..color = baseColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, radius - 2, dissolvePaint);
      return;
    }

    // 1. Thân bóng 3D trong suốt óng ánh (tâm sáng trong -> viền ngoài là màu chủ đạo, tuyệt đối không tối hơn màu chủ đạo)
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.95,
        colors: [
          baseColor.withValues(alpha: 0.45),
          baseColor.withValues(alpha: 0.75),
          baseColor, // Màu đậm nhất ở viền ngoài đúng bằng baseColor (#0047AB), không bị đen hay đậm quá màu chủ đạo
        ],
        stops: const [0.15, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius - 1, bodyPaint);

    // Nếu sắp nổ (Critical): Vẽ vòng cảnh báo màu đỏ rực rỡ bên ngoài
    if (isCritical) {
      final alertPaint = Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2;
      canvas.drawCircle(center, radius + 2.0, alertPaint);
    }

    // 2. Viền ngoài sáng bóng (Gleaming Rim)
    final rimPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: 0.85),
          const Color(0xFF60A5FA).withValues(alpha: 0.7),
          Colors.cyanAccent.withValues(alpha: 0.8),
          Colors.white.withValues(alpha: 0.85),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    canvas.drawCircle(center, radius - 1, rimPaint);

    // 3. Vệt sáng phản chiếu góc trên bên trái
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(radius * 0.2, radius * 0.15, radius * 0.7, radius * 0.35))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.14;

    final highlightPath = Path();
    highlightPath.addArc(
      Rect.fromCircle(center: center, radius: radius * 0.72),
      -pi * 0.85,
      pi * 0.45,
    );
    canvas.drawPath(highlightPath, highlightPaint);

    // 4. Đốm sáng phụ nhỏ
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx - radius * 0.52, center.dy - radius * 0.48),
      radius * 0.065,
      dotPaint,
    );

    // 5. Phản chiếu nhẹ ở đáy dưới bên phải
    final bottomReflection = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(radius, radius, radius * 0.8, radius * 0.8))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;

    final bottomPath = Path();
    bottomPath.addArc(
      Rect.fromCircle(center: center, radius: radius * 0.82),
      pi * 0.2,
      pi * 0.3,
    );
    canvas.drawPath(bottomPath, bottomReflection);
  }

  @override
  bool shouldRepaint(covariant GlossyBubblePainter oldDelegate) {
    return oldDelegate.baseColor != baseColor || oldDelegate.isDissolving != isDissolving;
  }
}

// ==========================================
// PAINTER: NỀN TRỜI BAN NGÀY TƯƠI SÁNG VỚI HẠT BÓNG LƠ LỬNG
// ==========================================
class DaylightBubbleSkyPainter extends CustomPainter {
  final List<Offset> sparklePositions;
  final List<double> sparkleSizes;
  final double floatProgress;

  DaylightBubbleSkyPainter({
    required this.sparklePositions,
    required this.sparkleSizes,
    required this.floatProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Nền chuyển sắc dịu mắt đồng bộ với màu ứng dụng HocZiTa
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          MathBubblesColors.skyTop,
          MathBubblesColors.skyBottom,
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Các hạt bong bóng/sparkle bay lơ lửng bồng bềnh
    for (int i = 0; i < sparklePositions.length; i++) {
      final phase = (i % 5) / 5.0;
      final wave = sin((floatProgress + phase) * 2 * pi);
      final pos = Offset(
        sparklePositions[i].dx * size.width,
        (sparklePositions[i].dy + wave * 0.015) * size.height,
      );
      final baseSize = sparkleSizes[i];
      final alpha = (0.25 + 0.5 * sin((floatProgress + phase) * pi)).clamp(0.1, 0.7).toDouble();

      // Vòng ngoài bong bóng mờ
      final bubblePaint = Paint()
        ..color = MathBubblesColors.primaryCobalt.withValues(alpha: 0.07 * alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, baseSize * 1.5, bubblePaint);

      // Viền bong bóng
      final rimPaint = Paint()
        ..color = MathBubblesColors.primaryCobalt.withValues(alpha: 0.15 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(pos, baseSize * 1.5, rimPaint);

      // Điểm sáng trắng
      final shinePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5 * alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(pos.dx - baseSize * 0.4, pos.dy - baseSize * 0.4), baseSize * 0.35, shinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant DaylightBubbleSkyPainter oldDelegate) {
    return oldDelegate.floatProgress != floatProgress;
  }
}
