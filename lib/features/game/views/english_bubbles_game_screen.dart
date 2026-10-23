import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/game_interaction_provider.dart';
import '../../../core/services/game_score_sync_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../constants/game_content.dart';
import 'common/mini_game_rank_banner.dart';

// ==========================================
// PALETTE & CONSTANTS (Đồng bộ Màu Chủ Đạo Cobalt Blue & Nền Trời Sáng)
// ==========================================
class EnglishBubblesColors {
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

  // Màu bong bóng xà phòng tiếng Anh: Thống nhất một màu Cobalt Blue chủ đạo chuẩn thương hiệu
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
// DATA MODEL: BONG BÓNG TIẾNG ANH (40 GIÂY)
// ==========================================
class EnglishBubbleProblem {
  final String id;
  final String vietnameseMeaning; // Nội dung tiếng Việt hiển thị trong bóng
  final String englishWord;       // Đáp án tiếng Anh người dùng cần gõ
  final int level;
  final double xRatio;            // Tọa độ ngang cơ sở (0.12 .. 0.88)
  final double yRatio;            // Tọa độ dọc cơ sở (0.12 .. 0.78)
  final double durationSeconds;   // Chuẩn 40 giây theo yêu cầu
  double remainingSeconds;
  double opacity = 1.0;
  bool isPopping = false;
  bool isDissolving = false;
  bool hasTriggeredNextSpawn = false; // Đã kích hoạt bóng tiếp theo khi trôi qua 45% thời gian chưa

  // Thuộc tính phục vụ chuyển động trôi lơ lửng liên tục rộng khắp
  double floatElapsed = 0.0;
  late final double floatPhase;
  late final double floatSpeedY;
  late final double floatSpeedX;
  late final double wanderPhase;
  late final double wanderSpeed;

  EnglishBubbleProblem({
    required this.id,
    required this.vietnameseMeaning,
    required this.englishWord,
    required this.level,
    required this.xRatio,
    required this.yRatio,
    this.durationSeconds = 40.0, // 40 giây theo yêu cầu
    this.hasTriggeredNextSpawn = false,
  }) : remainingSeconds = durationSeconds {
    final rng = Random();
    floatPhase = rng.nextDouble() * 2 * pi;
    wanderPhase = rng.nextDouble() * 2 * pi;
    floatSpeedY = 1.0 + rng.nextDouble() * 0.6;
    floatSpeedX = 0.7 + rng.nextDouble() * 0.5;
    wanderSpeed = 0.35 + rng.nextDouble() * 0.3;
  }

  Color get baseColor => EnglishBubblesColors.bubbleBase;

  // Cảnh báo nguy cấp khi bóng chỉ còn dưới 18% thời gian tồn tại (sắp tan)
  bool get isCritical => remainingSeconds <= durationSeconds * 0.18;
}

// Particle hiệu ứng nổ bong bóng
class EnglishBubbleParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double opacity;
  bool isStar;

  EnglishBubbleParticle({
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

// Hiệu ứng vòng sóng xung kích khi nổ bóng
class EnglishShockwaveRing {
  final double x;
  final double y;
  double radius;
  final double maxRadius;
  double opacity;
  final Color color;

  EnglishShockwaveRing({
    required this.x,
    required this.y,
    required this.radius,
    required this.maxRadius,
    required this.opacity,
    required this.color,
  });
}

// ==========================================
// MAIN SCREEN: BONG BÓNG TIẾNG ANH
// ==========================================
class EnglishBubblesGameScreen extends ConsumerStatefulWidget {
  const EnglishBubblesGameScreen({super.key});

  @override
  ConsumerState<EnglishBubblesGameScreen> createState() => _EnglishBubblesGameScreenState();
}

class _EnglishBubblesGameScreenState extends ConsumerState<EnglishBubblesGameScreen>
    with TickerProviderStateMixin {
  int _screenState = 0; // 0: Intro, 1: Playing, 2: Game Over

  int _score = 0;
  int _level = 1;
  int _hearts = 3;
  int _poppedCount = 0;
  int _highScore = 0;
  int _comboStreak = 0;
  int _maxCombo = 0;
  int _lastSpeedMilestone = 0;

  String _currentInput = '';
  late final FocusNode _focusNode;
  String? _feedbackStatus; // 'correct', 'wrong', null
  String? _feedbackText;
  Timer? _feedbackResetTimer;

  String? _bannerNotice;
  String? _missedBubbleNotice;
  Timer? _bannerTimer;
  Timer? _missedNoticeTimer;

  final List<EnglishBubbleProblem> _activeBubbles = [];
  Timer? _gameLoopTimer;
  Timer? _spawnTimer;
  final Random _rng = Random();

  final List<EnglishBubbleParticle> _particles = [];
  final List<EnglishShockwaveRing> _shockwaves = [];
  final List<Map<String, dynamic>> _flashCenters = [];
  final List<Map<String, dynamic>> _floatingTexts = [];

  late final List<Offset> _sparklePositions;
  late final List<double> _sparkleSizes;

  late final AnimationController _skyFloatController;
  late final AnimationController _scorePulseController;

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

    _sparklePositions = List.generate(40, (i) => Offset(_rng.nextDouble(), _rng.nextDouble()));
    _sparkleSizes = List.generate(40, (i) => 2.0 + _rng.nextDouble() * 3.5);

    _skyFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
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
        _highScore = prefs.getInt('hoczita_best_score_english_bubbles') ?? 24;
      });
    } catch (_) {}
  }

  Future<void> _saveHighScore() async {
    try {
      if (_score > _highScore) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('hoczita_best_score_english_bubbles', _score);
        setState(() {
          _highScore = _score;
        });
      }

      await GameScoreSyncService.instance.saveScoreParallel(
        gameCodeOrName: 'english_bubbles',
        level: _level.toString(),
        score: _score,
        stars: _score >= 25 ? 3 : (_score >= 12 ? 2 : 1),
      );
    } catch (e) {
      debugPrint('[EnglishBubbles] Lưu điểm lỗi: $e');
    }
  }

  // ==========================================
  // GAMEPLAY LOGIC (40 GIÂY)
  // ==========================================
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && _screenState == 1) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.backspace) {
        _onKeyPress('BACK');
      } else if (key == LogicalKeyboardKey.escape) {
        _onKeyPress('CLEAR');
      } else {
        final char = event.character;
        if (char != null && RegExp(r'^[a-zA-Z]$').hasMatch(char)) {
          _onKeyPress(char.toUpperCase());
        }
      }
    }
  }

  void _startGame() {
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

    // Vòng lặp cập nhật độ mờ dần và vị trí trôi lơ lửng liên tục (50ms = 20 FPS)
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

    final jitterX = (_rng.nextDouble() - 0.5) * 0.08;
    final jitterY = (_rng.nextDouble() - 0.5) * 0.08;
    final finalX = (bestZone.dx + jitterX).clamp(0.12, 0.88).toDouble();
    final finalY = (bestZone.dy + jitterY).clamp(0.12, 0.78).toDouble();
    return Offset(finalX, finalY);
  }

  /// Gói 1: Cân bằng & Vừa sức (Tiếng Anh: Cấp 1 = 35s, Cấp 2 = 28s, Cấp 3 = 22s)
  /// Nếu vượt qua cấp 3, cứ mỗi 50 điểm tích luỹ giảm thêm 0.5s thời gian sống (tối thiểu 14s)
  double _getLifespanForLevel(int lvl) {
    double base;
    if (lvl == 1) {
      base = 35.0;
    } else if (lvl == 2) {
      base = 28.0;
    } else {
      base = 22.0;
    }

    if (_level >= 3 && _score >= 50) {
      final bonusStage = _score ~/ 50;
      base = max(14.0, base - bonusStage * 0.5);
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
    // Vừa bắt đầu: CHỈ XUẤT HIỆN 1 BÓNG DUY NHẤT
    final loc = _pickBestSpawnLocation();
    final v = _pickRandomVocab();
    final duration = _getLifespanForLevel(_level);
    final firstBubble = EnglishBubbleProblem(
      id: UniqueKey().toString(),
      vietnameseMeaning: v.vi,
      englishWord: v.en.trim().toUpperCase(),
      level: _level,
      xRatio: loc.dx,
      yRatio: loc.dy,
      durationSeconds: duration,
      hasTriggeredNextSpawn: false, // Sẽ kích hoạt bóng thứ 2 khi trôi qua 30% thời gian
    );
    firstBubble.remainingSeconds = duration;
    firstBubble.opacity = 1.0;
    _activeBubbles.add(firstBubble);
  }

  void _spawnNewBubble() {
    final loc = _pickBestSpawnLocation();
    final excludeList = _activeBubbles.map((b) => b.englishWord).toSet();
    final vocab = _pickRandomVocab(excludeSet: excludeList);
    final duration = _getLifespanForLevel(_level);

    final newBubble = EnglishBubbleProblem(
      id: UniqueKey().toString(),
      vietnameseMeaning: vocab.vi,
      englishWord: vocab.en.trim().toUpperCase(),
      level: _level,
      xRatio: loc.dx,
      yRatio: loc.dy,
      durationSeconds: duration,
      hasTriggeredNextSpawn: false,
    );

    setState(() {
      _activeBubbles.add(newBubble);
    });
  }

  VocabItem _pickRandomVocab({String? excludeEn, Set<String>? excludeSet}) {
    final pool = GameContent.allVocab;
    final candidates = pool.where((item) {
      final en = item.en.trim().toUpperCase();
      if (excludeEn != null && en == excludeEn.trim().toUpperCase()) return false;
      if (excludeSet != null && excludeSet.contains(en)) return false;
      // Ưu tiên từ độ dài vừa phải để bé gõ trong 40s
      return en.length <= 8;
    }).toList();

    if (candidates.isNotEmpty) {
      return candidates[_rng.nextInt(candidates.length)];
    }
    return pool[_rng.nextInt(pool.length)];
  }

  void _updateGameLoop(double dt) {
    bool stateChanged = false;
    final List<EnglishBubbleProblem> expired = [];
    bool needSpawnSuccessor = false;

    for (final bubble in _activeBubbles) {
      if (bubble.isPopping || bubble.isDissolving) continue;

      bubble.floatElapsed += dt * _speedFactor;
      bubble.remainingSeconds -= dt;

      // Độ mờ dần theo thời gian: opacity = remaining / durationSeconds
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

    for (final b in expired) {
      b.isDissolving = true;
      _onBubbleMissed(b);
      stateChanged = true;
    }

    // Cập nhật hạt nổ
    if (_particles.isNotEmpty) {
      for (final p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.0002;
        p.vx *= 0.96;
        p.opacity = (p.opacity - 0.04).clamp(0.0, 1.0).toDouble();
      }
      _particles.removeWhere((p) => p.opacity <= 0.0);
      stateChanged = true;
    }

    // Cập nhật sóng xung kích
    if (_shockwaves.isNotEmpty) {
      for (final sw in _shockwaves) {
        sw.radius += (sw.maxRadius - sw.radius) * 0.16 + 2.5;
        sw.opacity = (sw.opacity - 0.065).clamp(0.0, 1.0).toDouble();
      }
      _shockwaves.removeWhere((sw) => sw.opacity <= 0.0 || sw.radius >= sw.maxRadius);
      stateChanged = true;
    }

    // Cập nhật đốm flash
    if (_flashCenters.isNotEmpty) {
      for (final f in _flashCenters) {
        f['opacity'] = ((f['opacity'] as double) - 0.08).clamp(0.0, 1.0).toDouble();
        f['size'] = (f['size'] as double) + 4.0;
      }
      _flashCenters.removeWhere((f) => (f['opacity'] as double) <= 0.0);
      stateChanged = true;
    }

    // Cập nhật chữ nổi +3 ⭐...
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

  void _onBubbleMissed(EnglishBubbleProblem b) {
    HapticFeedback.mediumImpact();
    setState(() {
      _comboStreak = 0; // Đứt chuỗi combo
      _hearts = max(0, _hearts - 1);
      _missedBubbleNotice = 'Bóng đã tan! Đáp án là ${b.englishWord}';
    });

    _missedNoticeTimer?.cancel();
    _missedNoticeTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) {
        setState(() {
          _missedBubbleNotice = null;
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 300), () {
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

  // ==========================================
  // XỬ LÝ NHẬP CHỮ CÁI TIẾNG ANH & NỔ BÓNG
  // ==========================================
  void _onKeyPress(String key) {
    if (_screenState != 1 || _feedbackStatus == 'correct') return;

    HapticFeedback.lightImpact();

    if (key == 'BACK') {
      if (_currentInput.isNotEmpty) {
        final newVal = _currentInput.substring(0, _currentInput.length - 1);
        setState(() {
          _currentInput = newVal;
          _feedbackStatus = null;
          _feedbackText = null;
        });
      }
    } else if (key == 'CLEAR') {
      setState(() {
        _currentInput = '';
        _feedbackStatus = null;
        _feedbackText = null;
      });
    } else {
      if (_currentInput.length < 12) {
        final nextVal = (_currentInput + key).toUpperCase();
        setState(() {
          _currentInput = nextVal;
        });
        _checkAnswer(nextVal);
      }
    }
  }

  void _checkAnswer(String upper) {
    // Kiểm tra xem chuỗi vừa gõ có khớp chính xác với bất kỳ bong bóng nào không
    EnglishBubbleProblem? matched;
    for (final b in _activeBubbles) {
      if (!b.isPopping && !b.isDissolving && b.englishWord == upper) {
        matched = b;
        break;
      }
    }

    if (matched != null) {
      _onCorrectAnswer(matched);
    } else {
      final maxLen = _activeBubbles.fold<int>(
        1,
        (maxVal, b) => max(maxVal, b.englishWord.length),
      );

      // Nếu độ dài đã bằng hoặc lớn hơn từ dài nhất trên màn hình mà không khớp
      if (upper.length >= maxLen && upper.isNotEmpty) {
        _onWrongAnswer();
      }
    }
  }

  void _onCorrectAnswer(EnglishBubbleProblem bubble) {
    HapticFeedback.heavyImpact();
    _scorePulseController.forward(from: 1.0).then((_) => _scorePulseController.reverse());

    // Phát âm từ vựng tiếng Anh qua loa
    TtsService.instance.speakEnglish(bubble.englishWord);

    _comboStreak++;
    if (_comboStreak > _maxCombo) _maxCombo = _comboStreak;

    final basePoints = _level == 1 ? 3 : (_level == 2 ? 4 : 5);
    final comboBonus = _comboStreak >= 5 ? 2 : (_comboStreak >= 3 ? 1 : 0);
    final pointsGained = basePoints + comboBonus;

    setState(() {
      _feedbackStatus = 'correct';
      _feedbackText = '✓';
      _score += pointsGained;
      _poppedCount++;
      bubble.isPopping = true;

      // Chữ nổi bay lên kèm hiệu ứng Combo
      final comboTag = _comboStreak >= 3 ? ' (x$_comboStreak 🔥)' : '';
      _floatingTexts.add({
        'text': '+$pointsGained$comboTag ⭐',
        'x': bubble.xRatio,
        'y': bubble.yRatio - 0.08,
        'opacity': 1.0,
      });

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

    if (_score >= 25 && _level < 3) {
      _triggerLevelUp(3);
    } else if (_score >= 12 && _level < 2) {
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

  void _onWrongAnswer() {
    HapticFeedback.vibrate();
    setState(() {
      _comboStreak = 0; // Nhập sai -> đứt chuỗi combo
      _feedbackStatus = 'wrong';
      _feedbackText = '!';
    });

    _feedbackResetTimer?.cancel();
    _feedbackResetTimer = Timer(const Duration(milliseconds: 550), () {
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

  void _spawnExplosionEffect(double rx, double ry, {bool isCombo = false}) {
    _shockwaves.add(
      EnglishShockwaveRing(
        x: rx,
        y: ry,
        radius: 12.0,
        maxRadius: isCombo ? 160.0 : 130.0,
        opacity: 0.95,
        color: isCombo ? const Color(0xFFF59E0B) : const Color(0xFF60A5FA),
      ),
    );
    _shockwaves.add(
      EnglishShockwaveRing(
        x: rx,
        y: ry,
        radius: 6.0,
        maxRadius: isCombo ? 110.0 : 90.0,
        opacity: 0.85,
        color: EnglishBubblesColors.scoreStar,
      ),
    );

    _flashCenters.add({
      'x': rx,
      'y': ry,
      'size': isCombo ? 42.0 : 28.0,
      'opacity': 1.0,
    });

    final count = isCombo ? 48 : 36;
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.003 + _rng.nextDouble() * 0.012;
      final isStar = i % 3 == 0;
      final color = isStar
          ? EnglishBubblesColors.scoreStar
          : (i % 2 == 0 ? const Color(0xFF60A5FA) : Colors.white);

      _particles.add(
        EnglishBubbleParticle(
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
    _gameLoopTimer?.cancel();
    _spawnTimer?.cancel();
    _saveHighScore();
    _focusNode.unfocus();
    setState(() {
      _screenState = 2; // Game Over
    });
  }

  void _showPauseDialog() {
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
            color: EnglishBubblesColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bé đang tạm nghỉ một chút nhé!',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(color: EnglishBubblesColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            _build3DButton(
              label: 'Tiếp Tục Chơi',
              color: EnglishBubblesColors.primaryButton,
              onTap: () {
                Navigator.pop(ctx);
                _focusNode.requestFocus();
              },
            ),
            const SizedBox(height: 12),
            _build3DButton(
              label: 'Chơi Lại',
              color: EnglishBubblesColors.secondaryBlue,
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
                style: GoogleFonts.baloo2(color: EnglishBubblesColors.textSecondary, fontSize: 14),
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
              'Bóng mờ dần trong 40 giây',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: EnglishBubblesColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Quy tắc mờ dần: Nhìn nghĩa tiếng Việt trong bóng và gõ từ tiếng Anh tương ứng. Bóng có 40 giây trước khi tan biến!',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 13,
                color: EnglishBubblesColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFadingStageCard(timeLabel: '0 giây', opacity: 1.0, vietnameseText: 'Con mèo', caption: '100% rõ nét'),
                  _buildFadingStageCard(timeLabel: '10 giây', opacity: 0.8, vietnameseText: 'Con mèo', caption: 'Mờ nhẹ ~80%'),
                  _buildFadingStageCard(timeLabel: '20 giây', opacity: 0.5, vietnameseText: 'Con mèo', caption: '~50% opacity', tag: 'Bóng mới'),
                  _buildFadingStageCard(timeLabel: '30 giây', opacity: 0.25, vietnameseText: 'Con mèo', caption: 'Sắp tan ~25%'),
                  _buildFadingStageCard(timeLabel: '40 giây', opacity: 0.08, vietnameseText: 'Con mèo', caption: 'Tan biến', tag: 'Mất 1 tim', tagColor: EnglishBubblesColors.heartRed),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _build3DButton(
              label: 'Đã Hiểu',
              color: EnglishBubblesColors.primaryButton,
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
    required String vietnameseText,
    required String caption,
    String? tag,
    Color? tagColor,
  }) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: EnglishBubblesColors.lightBlueBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EnglishBubblesColors.borderCobalt),
      ),
      child: Column(
        children: [
          Text(
            timeLabel,
            style: GoogleFonts.baloo2(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: EnglishBubblesColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 58,
            height: 58,
            child: EnglishGlossyBubbleWidget(
              vietnameseText: vietnameseText,
              letterCount: 3,
              opacity: opacity,
              baseColor: EnglishBubblesColors.bubbleBase,
              diameter: 58,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(fontSize: 10, color: EnglishBubblesColors.textSecondary),
          ),
          if (tag != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: (tagColor ?? EnglishBubblesColors.noticeAmber).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tag,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  color: tagColor ?? EnglishBubblesColors.noticeAmber,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnglishBubblesColors.skyBottom,
      body: Stack(
        children: [
          // Nền trời ban ngày tươi sáng đồng bộ với App
          Positioned.fill(
            child: CustomPaint(
              painter: DaylightEnglishBubbleSkyPainter(
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
          // - 3 quả bóng từ vựng lơ lửng chiếm trọn vùng trời ở giữa (Expanded)
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
              border: Border.all(color: EnglishBubblesColors.borderLight),
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
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: EnglishBubblesColors.textPrimary, size: 18),
            ),
          ),

          // Tiêu đề + Icon (i) ngay cạnh
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bong Bóng Tiếng Anh',
                style: GoogleFonts.baloo2(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: EnglishBubblesColors.primaryCobalt,
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
                    border: Border.all(color: EnglishBubblesColors.borderCobalt),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.info_outline_rounded, color: EnglishBubblesColors.primaryCobalt, size: 15),
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
        // Bóng 1 (Con chó): Phía trên - bên trái
        final top1 = (height * 0.14 + dy1).clamp(6.0, max(6.0, height - d1 - 6)).toDouble();
        final left1 = (width * 0.10 + dx1).clamp(6.0, max(6.0, width - d1 - 6)).toDouble();

        // Bóng 2 (Quả táo): Phía trên - bên phải
        final top2 = (height * 0.18 + dy2).clamp(6.0, max(6.0, height - d2 - 6)).toDouble();
        final right2 = (width * 0.10 + dx2).clamp(6.0, max(6.0, width - d2 - 6)).toDouble();

        // Bóng 3 (Mặt trời): Ở giữa phía dưới
        final top3 = (height * 0.54 + dy3).clamp(6.0, max(6.0, height - d3 - 6)).toDouble();
        final left3 = ((width - d3) / 2 + dx3).clamp(6.0, max(6.0, width - d3 - 6)).toDouble();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Bóng 1: trên bên trái (Con chó) - mờ nhẹ (0.65)
            Positioned(
              top: top1,
              left: left1,
              child: EnglishGlossyBubbleWidget(
                vietnameseText: 'Con chó',
                letterCount: 3,
                opacity: 0.65,
                baseColor: EnglishBubblesColors.bubbleBase,
                diameter: d1,
                fontSize: d1 * 0.19,
              ),
            ),

            // Bóng 2: trên bên phải (Quả táo) - rõ dần (0.85)
            Positioned(
              top: top2,
              right: right2,
              child: EnglishGlossyBubbleWidget(
                vietnameseText: 'Quả táo',
                letterCount: 5,
                opacity: 0.85,
                baseColor: EnglishBubblesColors.bubbleBase,
                diameter: d2,
                fontSize: d2 * 0.18,
              ),
            ),

            // Bóng 3: ở giữa phía dưới (Mặt trời) - đậm nhất (1.0, chuẩn màu chủ đạo, không tối hơn)
            Positioned(
              top: top3,
              left: left3,
              child: EnglishGlossyBubbleWidget(
                vietnameseText: 'Mặt trời',
                letterCount: 3,
                opacity: 1.0,
                baseColor: EnglishBubblesColors.bubbleBase,
                diameter: d3,
                fontSize: d3 * 0.17,
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
        border: Border.all(color: EnglishBubblesColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: EnglishBubblesColors.primaryCobalt.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStepItem(
            icon: '🇻🇳',
            text: 'Đọc nghĩa\nTiếng Việt',
            bgColor: const Color(0xFFEFF6FF),
          ),
          const Icon(Icons.arrow_forward_rounded, color: Color(0xFF94A3B8), size: 18),
          _buildStepItem(
            icon: '🔤',
            text: 'Gõ từ vựng\nTiếng Anh',
            bgColor: const Color(0xFFEFF6FF),
          ),
          const Icon(Icons.arrow_forward_rounded, color: Color(0xFF94A3B8), size: 18),
          _buildStepItem(
            icon: '🫧',
            text: 'Nổ bóng trong\n35 giây!',
            bgColor: const Color(0xFFF5F3FF),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroStartButton() {
    return _build3DButton(
      label: 'BẮT ĐẦU',
      color: EnglishBubblesColors.primaryButton,
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
            color: EnglishBubblesColors.textSecondary,
          ),
        ),
        Text(
          '$_highScore điểm',
          style: GoogleFonts.baloo2(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: EnglishBubblesColors.primaryCobalt,
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
            color: EnglishBubblesColors.textPrimary,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SCREEN 2: GAMEPLAY CHÍNH (TIẾNG ANH - 40 GIÂY)
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
              // Nút Quay lại
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: EnglishBubblesColors.borderLight),
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
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: EnglishBubblesColors.textPrimary, size: 18),
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
                          const Icon(Icons.star_rounded, color: EnglishBubblesColors.scoreStar, size: 18),
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
                      color: EnglishBubblesColors.lightBlueBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: EnglishBubblesColors.borderCobalt),
                    ),
                    child: Text(
                      'Cấp $_level',
                      style: GoogleFonts.baloo2(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: EnglishBubblesColors.primaryCobalt,
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

              // Trái tim + Nút Pause
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
                            ? EnglishBubblesColors.heartRed
                            : EnglishBubblesColors.heartGrey,
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
                      border: Border.all(color: EnglishBubblesColors.borderLight),
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
                      icon: const Icon(Icons.pause_rounded, color: EnglishBubblesColors.textSecondary, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. PLAYFIELD (BẦU TRỜI BONG BÓNG TIẾNG ANH)
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
                              color: EnglishBubblesColors.primaryButton,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: EnglishBubblesColors.primaryButton.withValues(alpha: 0.35),
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
                              color: EnglishBubblesColors.noticeAmber,
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

                    // BONG BÓNG TIẾNG VIỆT TRÔI BỒNG BỀNH RỘNG KHẮP LIÊN TỤC
                    ..._activeBubbles.map((bubble) {
                      final bubbleDiameter = 148.0;
                      
                      // Chuyển động bồng bềnh lơ lửng đa hướng liên tục
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
                          child: EnglishGlossyBubbleWidget(
                            vietnameseText: bubble.vietnameseMeaning,
                            letterCount: bubble.englishWord.length,
                            opacity: bubble.opacity,
                            baseColor: bubble.baseColor,
                            diameter: bubbleDiameter,
                            isDissolving: bubble.isDissolving,
                            isCritical: bubble.isCritical,
                          ),
                        ),
                      );
                    }),

                    // VÒNG SÓNG NỔ XUNG KÍCH
                    ..._shockwaves.map((sw) {
                      return Positioned(
                        left: sw.x * playfieldWidth - sw.radius,
                        top: sw.y * playfieldHeight - sw.radius,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: sw.opacity,
                            child: Container(
                              width: sw.radius * 2,
                              height: sw.radius * 2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: sw.color,
                                  width: 3.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: sw.color.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // ĐỐM FLASH TẠI TÂM NỔ
                    ..._flashCenters.map((fc) {
                      final size = fc['size'] as double;
                      final opacity = fc['opacity'] as double;
                      return Positioned(
                        left: (fc['x'] as double) * playfieldWidth - size / 2,
                        top: (fc['y'] as double) * playfieldHeight - size / 2,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              width: size,
                              height: size,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white,
                                    Color(0xFF60A5FA),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // HẠT NỔ RỰC RỠ (36 HẠT)
                    ..._particles.map((p) {
                      return Positioned(
                        left: p.x * playfieldWidth,
                        top: p.y * playfieldHeight,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: p.opacity,
                            child: p.isStar
                                ? Icon(
                                    Icons.star_rounded,
                                    color: p.color,
                                    size: p.size * 1.5,
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

                    // CHỮ ĐIỂM NỔI (+3 ⭐)
                    ..._floatingTexts.map((ft) {
                      final tx = (ft['x'] as double) * playfieldWidth;
                      final ty = (ft['y'] as double) * playfieldHeight;
                      return Positioned(
                        left: tx - 40,
                        top: ty - 20,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: (ft['opacity'] as double).clamp(0.0, 1.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: EnglishBubblesColors.scoreStar, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: EnglishBubblesColors.scoreStar.withValues(alpha: 0.3),
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
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _feedbackStatus == 'correct'
                    ? EnglishBubblesColors.correctGreen
                    : (_feedbackStatus == 'wrong'
                        ? EnglishBubblesColors.noticeAmber
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
                    'Chạm chữ cái bên dưới để gõ đáp án',
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
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: _feedbackStatus == 'correct'
                          ? EnglishBubblesColors.correctGreen
                          : (_feedbackStatus == 'wrong'
                              ? EnglishBubblesColors.noticeAmber
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
                        ? EnglishBubblesColors.correctGreen
                        : EnglishBubblesColors.noticeAmber,
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
        ),

        // 4. ON-SCREEN QWERTY KEYPAD (BÀN PHÍM PHỔ THÔNG, KHÔNG MÀU MÈ)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
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
              _buildQwertyRow(['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P']),
              const SizedBox(height: 6),
              _buildQwertyRow(['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'], horizontalPadding: 14),
              const SizedBox(height: 6),
              _buildQwertyRowWithActions(),
            ],
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildQwertyRow(List<String> keys, {double horizontalPadding = 0}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: keys.map((key) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: _buildKeyButton(key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQwertyRowWithActions() {
    const letters = ['Z', 'X', 'C', 'V', 'B', 'N', 'M'];
    return Row(
      children: [
        // Nút CLEAR
        Expanded(
          flex: 14,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: _buildKeyButton('CLEAR'),
          ),
        ),
        // Chữ cái dòng cuối
        ...letters.map((key) {
          return Expanded(
            flex: 10,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: _buildKeyButton(key),
            ),
          );
        }),
        // Nút BACKSPACE
        Expanded(
          flex: 14,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: _buildKeyButton('BACK'),
          ),
        ),
      ],
    );
  }

  Widget _buildKeyButton(String key) {
    final isBack = key == 'BACK';
    final isClear = key == 'CLEAR';
    final isAction = isBack || isClear;

    // Phong cách phổ thông: phím chữ trắng sạch, phím chức năng xám nhẹ trung tính
    final Color bgColor = isAction ? const Color(0xFFE2E8F0) : Colors.white;
    final Color textColor = isAction ? const Color(0xFF475569) : const Color(0xFF1E293B);

    Widget content;
    if (isBack) {
      content = const Icon(Icons.backspace_outlined, color: Color(0xFF475569), size: 19);
    } else if (isClear) {
      content = Text(
        'XÓA',
        style: GoogleFonts.baloo2(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
        ),
      );
    } else {
      content = Text(
        key,
        style: GoogleFonts.baloo2(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
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
            boxShadow: [
              BoxShadow(
                color: EnglishBubblesColors.primaryCobalt.withValues(alpha: 0.1),
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
                child: const Text('🌟', style: TextStyle(fontSize: 38)),
              ),
              const SizedBox(height: 16),

              Text(
                'Xuất sắc!',
                style: GoogleFonts.baloo2(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: EnglishBubblesColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Con đã nổ $_poppedCount từ vựng tiếng Anh',
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: EnglishBubblesColors.textSecondary,
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
                  color: EnglishBubblesColors.lightBlueBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: EnglishBubblesColors.borderCobalt),
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
                gameName: 'english_bubbles',
                gameTitle: 'Bong Bóng Tiếng Anh',
                currentScore: _score,
              ),
              const SizedBox(height: 20),

              _build3DButton(
                label: 'Chơi Lại',
                color: EnglishBubblesColors.primaryButton,
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
                    color: EnglishBubblesColors.textSecondary,
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
          style: GoogleFonts.baloo2(fontSize: 12, color: EnglishBubblesColors.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.baloo2(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: EnglishBubblesColors.textPrimary,
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
                color: color == EnglishBubblesColors.primaryButton
                    ? EnglishBubblesColors.primaryButtonShadow
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
// GLOSSY BUBBLE WIDGET CHO TIẾNG ANH (3D COBALT BLUE)
// ==========================================
class EnglishGlossyBubbleWidget extends StatelessWidget {
  final String vietnameseText;
  final int letterCount;
  final double opacity;
  final Color baseColor;
  final double diameter;
  final double? fontSize;
  final bool isDissolving;
  final bool isCritical;

  const EnglishGlossyBubbleWidget({
    super.key,
    required this.vietnameseText,
    required this.letterCount,
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
            painter: EnglishGlossyBubblePainter(
              baseColor: baseColor,
              isDissolving: isDissolving,
              isCritical: isCritical,
            ),
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        vietnameseText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: fontSize ?? (diameter >= 135 ? 24 : 20),
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: max(0.4, opacity)),
                          height: 1.2,
                          shadows: [
                            BoxShadow(
                              color: const Color(0xFF001B44).withValues(alpha: 0.6),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$letterCount chữ cái',
                          style: GoogleFonts.baloo2(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
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
// PAINTER: BONG BÓNG XÀ PHÒNG COBALT 3D ÓNG ÁNH TIẾNG ANH
// ==========================================
class EnglishGlossyBubblePainter extends CustomPainter {
  final Color baseColor;
  final bool isDissolving;
  final bool isCritical;

  EnglishGlossyBubblePainter({
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

    // Nếu sắp tan (Critical): Vẽ vòng cảnh báo màu đỏ rực rỡ bên ngoài
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
  bool shouldRepaint(covariant EnglishGlossyBubblePainter oldDelegate) {
    return oldDelegate.baseColor != baseColor || oldDelegate.isDissolving != isDissolving;
  }
}

// ==========================================
// PAINTER: NỀN TRỜI BAN NGÀY TƯƠI SÁNG VỚI HẠT BÓNG LƠ LỬNG
// ==========================================
class DaylightEnglishBubbleSkyPainter extends CustomPainter {
  final List<Offset> sparklePositions;
  final List<double> sparkleSizes;
  final double floatProgress;

  DaylightEnglishBubbleSkyPainter({
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
          EnglishBubblesColors.skyTop,
          EnglishBubblesColors.skyBottom,
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
        ..color = EnglishBubblesColors.primaryCobalt.withValues(alpha: 0.07 * alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, baseSize * 1.5, bubblePaint);

      // Viền bong bóng
      final rimPaint = Paint()
        ..color = EnglishBubblesColors.primaryCobalt.withValues(alpha: 0.15 * alpha)
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
  bool shouldRepaint(covariant DaylightEnglishBubbleSkyPainter oldDelegate) {
    return oldDelegate.floatProgress != floatProgress;
  }
}
