import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../../../core/providers/game_interaction_provider.dart';

class MultiplicationQuestion {
  final int factorA;
  final int factorB;
  final int correctResult;
  final List<int> options;

  MultiplicationQuestion({
    required this.factorA,
    required this.factorB,
    required this.correctResult,
    required this.options,
  });
}

class MultiplicationTableGameScreen extends ConsumerStatefulWidget {
  final int? initialTable; // 2..9 or null for selection lobby

  const MultiplicationTableGameScreen({
    super.key,
    this.initialTable,
  });

  @override
  ConsumerState<MultiplicationTableGameScreen> createState() =>
      _MultiplicationTableGameScreenState();
}

class _MultiplicationTableGameScreenState
    extends ConsumerState<MultiplicationTableGameScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _db = SupabaseService.instance;
  final Random _random = Random();

  bool _isPlaying = false;
  int _selectedTable = 2; // 0: tổng hợp, 2..9: bảng tương ứng
  int _currentQuestionIndex = 0;
  List<MultiplicationQuestion> _questions = [];

  int _lives = 3;
  int _score = 0;
  int _combo = 1;
  int _maxCombo = 1;
  int _correctAnswers = 0;
  final List<bool?> _questionResults = List.filled(10, null);

  int? _selectedBubbleIndex;
  bool _isAnswering = false;

  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isGameOver = false;
  bool _isSavingScore = false;

  String _mascotMessage = 'Chào bạn! Hãy chạm vào quả bóng có kết quả đúng nhé! 🎈';

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    if (widget.initialTable != null) {
      _selectedTable = widget.initialTable!;
      _startRound(_selectedTable);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    TtsService.instance.stopAll();
    super.dispose();
  }

  void _startRound(int tableNumber) {
    _timer?.cancel();
    _animController.reset();

    setState(() {
      _selectedTable = tableNumber;
      _isPlaying = true;
      _isGameOver = false;
      _isSavingScore = false;
      _currentQuestionIndex = 0;
      _lives = 3;
      _score = 0;
      _combo = 1;
      _maxCombo = 1;
      _correctAnswers = 0;
      _secondsElapsed = 0;
      _selectedBubbleIndex = null;
      _isAnswering = false;
      for (int i = 0; i < 10; i++) {
        _questionResults[i] = null;
      }
      _questions = _generateQuestions(tableNumber);
      _mascotMessage = 'Bạn đã chọn bảng ${_selectedTable == 0 ? "Tổng hợp" : "$_selectedTable"}. Chúc bạn làm thật tốt nhé! 🚀';
    });

    ref.read(isGameActiveProvider.notifier).state = true;
    _startTimer();
    _speakCurrentQuestion();
  }

  List<MultiplicationQuestion> _generateQuestions(int tableNumber) {
    final List<MultiplicationQuestion> list = [];
    final List<int> multipliers = List.generate(10, (i) => i + 1)..shuffle(_random);

    for (int i = 0; i < 10; i++) {
      int a;
      int b;

      if (tableNumber == 0) {
        // Tổng hợp từ 2 đến 9
        a = _random.nextInt(8) + 2; // 2..9
        b = _random.nextInt(10) + 1; // 1..10
      } else {
        a = tableNumber;
        b = multipliers[i];
      }

      final correct = a * b;
      final Set<int> optionSet = {correct};

      // Sinh 3 đáp án sai gần sát và hợp lý
      final List<int> deltas = [-a, a, -1, 1, -2, 2, -10, 10, -5, 5];
      deltas.shuffle(_random);

      for (final delta in deltas) {
        final wrong = correct + delta;
        if (wrong > 0 && wrong != correct && !optionSet.contains(wrong)) {
          optionSet.add(wrong);
          if (optionSet.length == 4) break;
        }
      }

      while (optionSet.length < 4) {
        final fallback = (a * (_random.nextInt(10) + 1)) + (_random.nextBool() ? 1 : -1);
        if (fallback > 0 && fallback != correct && !optionSet.contains(fallback)) {
          optionSet.add(fallback);
        }
      }

      final options = optionSet.toList()..shuffle(_random);

      list.add(MultiplicationQuestion(
        factorA: a,
        factorB: b,
        correctResult: correct,
        options: options,
      ));
    }

    return list;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (!_isGameOver) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  void _speakCurrentQuestion({bool forced = false}) {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;
    final q = _questions[_currentQuestionIndex];
    TtsService.instance.speakVietnamese('${q.factorA} nhân ${q.factorB} bằng bao nhiêu?', forced: forced);
  }

  void _handleBubbleTap(int bubbleIndex) {
    if (_isAnswering || _isGameOver || _questions.isEmpty) return;

    final q = _questions[_currentQuestionIndex];
    final chosenValue = q.options[bubbleIndex];
    final isCorrect = (chosenValue == q.correctResult);

    setState(() {
      _isAnswering = true;
      _selectedBubbleIndex = bubbleIndex;
    });

    _animController.forward(from: 0.0);

    if (isCorrect) {
      final roundPoints = 30 + ((_combo - 1) * 15);
      final newCombo = _combo + 1;

      setState(() {
        _score += roundPoints;
        _correctAnswers++;
        _combo = newCombo;
        if (_combo > _maxCombo) _maxCombo = _combo;
        _questionResults[_currentQuestionIndex] = true;

        if (_combo >= 4) {
          _mascotMessage = 'Đúng liên tiếp ${_combo - 1} câu rồi! Bạn đỉnh quá! 🌟';
        } else if (_combo >= 2) {
          _mascotMessage = 'Chính xác! Chuỗi nhân đôi điểm x$_combo! 👏';
        } else {
          _mascotMessage = 'Đúng rồi, bạn giỏi lắm! Tiếp tục nào! 🎉';
        }
      });

      Timer(const Duration(milliseconds: 700), _nextQuestion);
    } else {
      final newLives = _lives - 1;
      setState(() {
        _lives = newLives;
        _combo = 1;
        _questionResults[_currentQuestionIndex] = false;
        _mascotMessage = 'Chưa đúng rồi! ${q.factorA} × ${q.factorB} = ${q.correctResult} bạn nhé! 💪';
      });

      if (newLives <= 0) {
        Timer(const Duration(milliseconds: 1000), _endGame);
      } else {
        Timer(const Duration(milliseconds: 1300), _nextQuestion);
      }
    }
  }

  void _nextQuestion() {
    if (!mounted || _isGameOver) return;

    if (_currentQuestionIndex + 1 < _questions.length) {
      setState(() {
        _currentQuestionIndex++;
        _selectedBubbleIndex = null;
        _isAnswering = false;
      });
      _animController.reset();
      _speakCurrentQuestion();
    } else {
      _endGame();
    }
  }

  void _endGame() async {
    _timer?.cancel();
    setState(() {
      _isGameOver = true;
      _isAnswering = false;
    });

    int stars = 0;
    if (_correctAnswers >= 9) {
      stars = 3;
    } else if (_correctAnswers >= 7) {
      stars = 2;
    } else if (_correctAnswers >= 4) {
      stars = 1;
    }

    final tableKey = _selectedTable == 0 ? 'mixed' : 'table_$_selectedTable';
    final gameName = 'multiplication_table_$tableKey';

    setState(() {
      _isSavingScore = true;
    });

    try {
      await _db.saveScore(
        gameName: gameName,
        stars: stars,
        score: _score,
      );
    } catch (e) {
      debugPrint('Error saving multiplication score: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingScore = false;
        });
      }
    }
  }

  void _showQuitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Dừng Vòng Chơi?',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Tiến trình câu hỏi hiện tại sẽ không được lưu nếu bạn thoát ra lúc này.',
          style: GoogleFonts.baloo2(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Chơi tiếp',
              style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              setState(() {
                _isPlaying = false;
              });
              _timer?.cancel();
              TtsService.instance.stopAll();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(
              'Thoát ra',
              style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlaying) {
      return _buildTableSelectionLobby();
    }

    if (_isGameOver) {
      return _buildSummaryScreen();
    }

    return _buildGameplayScreen();
  }

  Widget _buildTableSelectionLobby() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Bảng Cửu Chương',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 20,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: GameSoundToggleButton(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00629D), Color(0xFF00A3FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00629D).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'TOÁN TIỂU HỌC',
                              style: GoogleFonts.baloo2(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFCFE5FF),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Thử Thách Phép Nhân',
                            style: GoogleFonts.baloo2(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chạm bóng bay tìm kết quả đúng, tích luỹ điểm số và rèn luyện phản xạ nhanh nhẹn!',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              color: const Color(0xFFCFE5FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'ImageFolder/Multiplication.webp',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Text(
                              '✖️',
                              style: TextStyle(fontSize: 34),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'CHỌN BẢNG CỬU CHƯƠNG',
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),

              // Special "Tổng hợp" Card
              _buildTableCard(
                title: 'Thử Thách Tổng Hợp',
                subtitle: 'Gồm ngẫu nhiên tất cả các bảng từ 2 đến 9',
                tableNumber: 0,
                isSpecial: true,
                badgeText: 'HOT ⭐',
              ),

              const SizedBox(height: 12),

              // 2 to 9 Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                ),
                itemCount: 8,
                itemBuilder: (context, index) {
                  final tableNum = index + 2; // 2..9
                  return _buildTableGridItem(tableNum);
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableCard({
    required String title,
    required String subtitle,
    required int tableNumber,
    bool isSpecial = false,
    String? badgeText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSpecial ? const Color(0xFFFE9D00) : AppColors.border,
          width: isSpecial ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSpecial
                ? const Color(0xFFFE9D00).withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _startRound(tableNumber),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isSpecial
                        ? const Color(0xFFFFDCBB)
                        : const Color(0xFFCFE5FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      isSpecial ? '🌟' : '✖️',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.baloo2(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFE9D00),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badgeText,
                                style: GoogleFonts.baloo2(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Color(0xFF00629D),
                  size: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableGridItem(int tableNum) {
    final colors = [
      const Color(0xFFE0F2FE), // Blue
      const Color(0xFFFEF3C7), // Amber
      const Color(0xFFD1FAE5), // Green
      const Color(0xFFFCE7F3), // Pink
      const Color(0xFFEDE9FE), // Purple
      const Color(0xFFFFEDD5), // Orange
      const Color(0xFFCCFBF1), // Teal
      const Color(0xFFE2E8F0), // Slate
    ];
    final color = colors[(tableNum - 2) % colors.length];

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
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _startRound(tableNum),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$tableNum × ?',
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bảng $tableNum',
                      style: GoogleFonts.baloo2(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      '$tableNum × 1 ... $tableNum × 10',
                      style: GoogleFonts.baloo2(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameplayScreen() {
    final q = _questions[_currentQuestionIndex];
    final tableTitle = _selectedTable == 0
        ? 'TỔNG HỢP'
        : 'BẢNG CỬU CHƯƠNG $_selectedTable';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: _showQuitConfirmation,
        ),
        centerTitle: true,
        title: Text(
          'Thử Thách Tính Nhanh',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00629D),
            fontSize: 18,
          ),
        ),
        actions: [
          const GameSoundToggleButton(),
          GameCountUpTimer(elapsedSeconds: _secondsElapsed),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 4),

              // 1. TOP HUD CARD
              _buildTopHudCard(),

              const SizedBox(height: 12),

              // 2. PROBLEM ARENA: CLOUD FLOATING BANNER
              _buildProblemArena(q, tableTitle),

              const SizedBox(height: 14),

              // 3. 4 BUBBLE CHOICES (2x2 GRID)
              Expanded(
                child: _buildBubbleGrid(q),
              ),

              const SizedBox(height: 12),

              // (LƯỢC BỎ HOÀN TOÀN KHỐI TRỢ THỦ HỌC TẬP THEO YÊU CẦU CỦA NGƯỜI DÙNG)

              // 4. BOTTOM MASCOT REACTION CARD
              _buildBottomMascotCard(),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHudCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row 1: Lives & Score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Lives Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDAD6).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      Icon(
                        i < _lives
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: const Color(0xFFBA1A1A),
                        size: 18,
                      ),
                      if (i < 2) const SizedBox(width: 3),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      '$_lives Mạng',
                      style: GoogleFonts.baloo2(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFBA1A1A),
                      ),
                    ),
                  ],
                ),
              ),

              // Score Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDCBB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Color(0xFF885200),
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_score Điểm',
                      style: GoogleFonts.baloo2(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF663C00),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 2: Timer & Combo Gauge
          Row(
            children: [
              // Timer Display in HUD
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECEEF1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 15,
                      color: Color(0xFF00629D),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      GameCountUpTimer.formatSeconds(_secondsElapsed),
                      style: GoogleFonts.baloo2(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00629D),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Combo Gauge
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 18,
                      color: Color(0xFFFE9D00),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Combo x$_combo',
                      style: GoogleFonts.baloo2(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF663C00),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 8,
                          color: const Color(0xFFECEEF1),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: ((_combo - 1) / 3).clamp(0.1, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _combo > 1
                                    ? const Color(0xFFFE9D00)
                                    : const Color(0xFFBEC7D4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProblemArena(MultiplicationQuestion q, String tableTitle) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF00629D),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00629D).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative background bubbles
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF00A3FF).withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 40,
            top: -20,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFCFE5FF).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Main Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tableTitle,
                          style: GoogleFonts.baloo2(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFCFE5FF),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCFE5FF).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Câu ${_currentQuestionIndex + 1}/10',
                            style: GoogleFonts.baloo2(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFCFE5FF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${q.factorA} × ${q.factorB} = ?',
                      style: GoogleFonts.baloo2(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),

                // Audio Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.volume_up_rounded,
                      color: Color(0xFF00629D),
                      size: 26,
                    ),
                    onPressed: () => _speakCurrentQuestion(forced: true),
                    tooltip: 'Nghe đọc phép tính',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleGrid(MultiplicationQuestion q) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            return _buildBubbleItem(index, q);
          },
        );
      },
    );
  }

  Widget _buildBubbleItem(int index, MultiplicationQuestion q) {
    final value = q.options[index];
    final isSelected = (_selectedBubbleIndex == index);
    final isCorrectOption = (value == q.correctResult);

    // Color definitions matching design
    final bubbleConfigs = [
      {
        'label': 'BÓNG A',
        'bg': const Color(0xFFCFE5FF),
        'text': const Color(0xFF00375A),
      },
      {
        'label': 'BÓNG B',
        'bg': const Color(0xFFFFDCBB),
        'text': const Color(0xFF663C00),
      },
      {
        'label': 'BÓNG C',
        'bg': const Color(0xFFE6E8EB),
        'text': const Color(0xFF191C1E),
      },
      {
        'label': 'BÓNG D',
        'bg': const Color(0xFFD1FAE5),
        'text': const Color(0xFF003D1D),
      },
    ];

    final config = bubbleConfigs[index % bubbleConfigs.length];
    Color cardBg = config['bg'] as Color;
    Color textColor = config['text'] as Color;
    Border? border;

    if (_isAnswering) {
      if (isSelected) {
        if (isCorrectOption) {
          cardBg = const Color(0xFF6CFE9F);
          border = Border.all(color: const Color(0xFF00B460), width: 3);
        } else {
          cardBg = const Color(0xFFFFDAD6);
          border = Border.all(color: const Color(0xFFBA1A1A), width: 3);
        }
      } else if (isCorrectOption) {
        // Highlight correct option if user got it wrong
        border = Border.all(color: const Color(0xFF00B460), width: 2.5);
      }
    }

    Widget bubbleWidget = Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glossy pill reflection
          Positioned(
            top: 8,
            left: 14,
            child: Transform.rotate(
              angle: -0.26,
              child: Container(
                width: 20,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          // Correct / Wrong Badge on top right
          if (_isAnswering && (isSelected || isCorrectOption))
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCorrectOption
                      ? const Color(0xFF00B460)
                      : const Color(0xFFBA1A1A),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCorrectOption ? Icons.check_rounded : Icons.close_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  config['label'] as String,
                  style: GoogleFonts.baloo2(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$value',
                  style: GoogleFonts.baloo2(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isSelected) {
      bubbleWidget = ScaleTransition(
        scale: _scaleAnimation,
        child: bubbleWidget,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleBubbleTap(index),
        borderRadius: BorderRadius.circular(22),
        child: bubbleWidget,
      ),
    );
  }

  Widget _buildBottomMascotCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Mascot Avatar
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD1FAE5),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '🐝',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00B460),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 12),

              // Speech Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bạn Ong Học Đi',
                          style: GoogleFonts.baloo2(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF006D38),
                          ),
                        ),
                        Text(
                          'Câu ${_currentQuestionIndex + 1} / 10',
                          style: GoogleFonts.baloo2(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _mascotMessage,
                      style: GoogleFonts.baloo2(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 10 Segmented Dots
          Row(
            children: List.generate(10, (idx) {
              Color segColor;
              if (idx < _currentQuestionIndex) {
                segColor = (_questionResults[idx] == true)
                    ? const Color(0xFF00B460)
                    : const Color(0xFFBA1A1A);
              } else if (idx == _currentQuestionIndex) {
                segColor = const Color(0xFFFE9D00);
              } else {
                segColor = const Color(0xFFE0E3E6);
              }

              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(
                    left: idx == 0 ? 0 : 3,
                    right: idx == 9 ? 0 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: segColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryScreen() {
    int stars = 0;
    if (_correctAnswers >= 9) {
      stars = 3;
    } else if (_correctAnswers >= 7) {
      stars = 2;
    } else if (_correctAnswers >= 4) {
      stars = 1;
    }

    String cheerTitle = 'HOÀN THÀNH!';
    if (stars == 3) cheerTitle = 'XUẤT SẮC! 🌟';
    if (stars == 2) cheerTitle = 'TỐT LẮM! 👏';
    if (stars == 1) cheerTitle = 'CỐ GẮNG LÊN! 💪';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => setState(() => _isPlaying = false),
        ),
        title: Text(
          'Kết Quả Vòng Chơi',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mascot Celebration Avatar
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    color: Color(0xFFCFE5FF),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      stars >= 2 ? '🎉' : '🐝',
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  cheerTitle,
                  style: GoogleFonts.baloo2(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF00629D),
                  ),
                ),
                const SizedBox(height: 4),

                Text(
                  'Bạn đã hoàn thành vòng bảng ${_selectedTable == 0 ? "Tổng hợp" : "$_selectedTable"} trong ${GameCountUpTimer.formatSeconds(_secondsElapsed)}!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Star Rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final isEarned = i < stars;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        isEarned
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: isEarned
                            ? const Color(0xFFFE9D00)
                            : const Color(0xFFBEC7D4),
                        size: 46,
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 24),

                // Stats Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryStatCard(
                        title: 'Đúng',
                        value: '$_correctAnswers / 10',
                        color: const Color(0xFF00B460),
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryStatCard(
                        title: 'Tổng điểm',
                        value: '$_score',
                        color: const Color(0xFFFE9D00),
                        icon: Icons.stars_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryStatCard(
                        title: 'Thời gian',
                        value: GameCountUpTimer.formatSeconds(_secondsElapsed),
                        color: const Color(0xFF00629D),
                        icon: Icons.timer_outlined,
                      ),
                    ),
                  ],
                ),

                if (_isSavingScore) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 6),
                  Text(
                    'Đang lưu kết quả...',
                    style: GoogleFonts.baloo2(fontSize: 12),
                  ),
                ],

                const SizedBox(height: 32),

                // Action Buttons
                ElevatedButton.icon(
                  onPressed: () => _startRound(_selectedTable),
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(
                    'Chơi Lại Bảng Này',
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00629D),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: () => setState(() => _isPlaying = false),
                  icon: const Icon(Icons.grid_view_rounded),
                  label: Text(
                    'Chọn Bảng Khác',
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00629D),
                    side: const BorderSide(color: Color(0xFF00629D), width: 1.5),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.baloo2(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.baloo2(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
