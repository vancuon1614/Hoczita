import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/scrmai_api_service.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../../../core/widgets/pastel_toy_card.dart';
import '../../../core/providers/game_interaction_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../learn/views/widgets/gel_candy_icon.dart';
import '../utils/multiplication_question_generator.dart';

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

  bool _isPlaying = false;
  int _selectedTable = 2; // 0: tổng hợp, 2..9: bảng tương ứng
  MultiplicationLevel _selectedLevel = MultiplicationLevel.easy;
  int _currentQuestionIndex = 0;
  List<MultiplicationQuestionModel> _questions = [];

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
      _startRound(MultiplicationLevel.easy);
    }
  }

  @override
  void dispose() {
    ref.read(isGameActiveProvider.notifier).state = false;
    _timer?.cancel();
    _animController.dispose();
    TtsService.instance.stopAll();
    super.dispose();
  }

  void _startRound(MultiplicationLevel level) {
    _timer?.cancel();
    _animController.reset();

    final levelName = level == MultiplicationLevel.easy
        ? 'Dễ'
        : level == MultiplicationLevel.medium
            ? 'Vừa'
            : 'Toán đố Thực tế';

    setState(() {
      _selectedLevel = level;
      _selectedTable = 0; // Luôn dùng toàn bộ bảng cửu chương 2 đến 9
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
      _questions = MultiplicationQuestionGenerator.generateQuestions(
        tableNumber: 0,
        level: level,
      );
      _mascotMessage = 'Cấp độ $levelName. Chúc bạn làm thật tốt nhé! 🚀';
    });

    ref.read(isGameActiveProvider.notifier).state = true;
    _startTimer();
    _speakCurrentQuestion();
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
    TtsService.instance.speakVietnamese(q.ttsPrompt, forced: forced);
  }

  void _handleBubbleTap(int bubbleIndex) {
    if (_isAnswering || _isGameOver || _questions.isEmpty) return;

    final q = _questions[_currentQuestionIndex];
    final chosenOpt = q.options[bubbleIndex];
    final isCorrect = (chosenOpt.value == q.correctResult);

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
        _mascotMessage = 'Chưa đúng rồi! Đáp án là ${q.correctDisplay} bạn nhé! 💪';
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

    // Ưu tiên 1: NKS SCRMAI API
    final authState = ref.read(authProvider);
    final memberName = authState.username ?? 'Học sinh';
    final levelStr = _selectedLevel == MultiplicationLevel.easy
        ? '1'
        : _selectedLevel == MultiplicationLevel.medium
            ? '2'
            : '3';

    try {
      await ScrmaiApiService.instance.submitScore(
        member: memberName,
        game: 'M01',
        level: levelStr,
        score: _score,
      );
    } catch (e) {
      debugPrint('Error syncing score to NKS SCRMAI: $e');
    }

    // Ưu tiên 2: Supabase
    try {
      await _db.saveScore(
        gameName: gameName,
        stars: stars,
        score: _score,
      );
    } catch (e) {
      debugPrint('Error saving multiplication score to Supabase: $e');
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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

              const SizedBox(height: 28),

              // Chọn Chế Độ Thử Thách
              Text(
                'CHỌN CHẾ ĐỘ THỬ THÁCH',
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),

              // Mode 1: Cấp Độ Dễ
              _buildModeCard(
                level: MultiplicationLevel.easy,
                title: 'Cấp Độ Dễ',
                subtitle: 'Phép nhân cơ bản rèn phản xạ nhanh',
                exampleFormula: '2 × 9 = ?',
                candyBadge: GelCandyBadge.green(emoji: '🟢', size: 52),
                colorConfig: PastelToyCardColor.green,
                tagText: 'Bảng Nhân 2 - 9',
              ),

              const SizedBox(height: 16),

              // Mode 2: Cấp Độ Vừa
              _buildModeCard(
                level: MultiplicationLevel.medium,
                title: 'Cấp Độ Vừa',
                subtitle: 'Điền khuyết ẩn số rèn tư duy toán học',
                exampleFormula: '? × 9 = 18',
                candyBadge: GelCandyBadge.orange(emoji: '🟡', size: 52),
                colorConfig: PastelToyCardColor.orange,
                tagText: 'Tư Duy & Điền Khuyết',
              ),

              const SizedBox(height: 16),

              // Mode 3: Toán Đố Thực Tế
              _buildModeCard(
                level: MultiplicationLevel.hard,
                title: 'Toán Đố Thực Tế',
                subtitle: 'Tình huống đời sống (Mua kẹo, chia quà...)',
                exampleFormula: 'Đời Sống 💡',
                candyBadge: GelCandyBadge.blue(emoji: '💡', size: 52),
                colorConfig: PastelToyCardColor.blue,
                tagText: 'Ứng Dụng Thực Tế ⭐',
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required MultiplicationLevel level,
    required String title,
    required String subtitle,
    required Widget candyBadge,
    required PastelToyCardColor colorConfig,
    required String tagText,
    required String exampleFormula,
  }) {
    return PastelModeCard(
      title: title,
      subtitle: subtitle,
      tagText: tagText,
      chipText: exampleFormula,
      icon: candyBadge,
      colorConfig: colorConfig,
      onTap: () => _startRound(level),
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
        centerTitle: true,
        title: Text(
          'Tính Nhanh',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00375A),
            fontSize: 20,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary, size: 20),
              onPressed: _showQuitConfirmation,
            ),
          ),
        ),
        actions: [
          // Thay Hình 4 bằng Hình 5 (nút 3D Gel Candy duy nhất trên màn hình)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _speakCurrentQuestion(forced: true),
              child: GelCandyBadge.blue(
                icon: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 22),
                size: 38,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hàng Sub-Header: Tiến độ câu hỏi & Timer (như Hình 2)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎯', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          _selectedTable == 0
                              ? 'Câu hỏi ${_currentQuestionIndex + 1}/10'
                              : 'Bảng $_selectedTable • Câu ${_currentQuestionIndex + 1}/10',
                          style: GoogleFonts.baloo2(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Mạng và Timer Pill (như Hình 2)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < 3; i++) ...[
                            Icon(
                              i < _lives
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: const Color(0xFFDC2626),
                              size: 17,
                            ),
                            if (i < 2) const SizedBox(width: 2),
                          ],
                        ],
                      ),
                      const SizedBox(width: 8),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 15, color: Color(0xFFDC2626)),
                            const SizedBox(width: 4),
                            Text(
                              GameCountUpTimer.formatSeconds(_secondsElapsed),
                              style: GoogleFonts.baloo2(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // (LƯỢC BỎ HOÀN TOÀN HÌNH 3 - THANH TIẾN TRÌNH THEO ĐÚNG YÊU CẦU)
              const SizedBox(height: 14),

              // 2. KHUNG CÂU HỎI: Pastel Toy Card Style (như Hình 2)
              Expanded(
                flex: 4,
                child: _buildProblemArena(q, tableTitle),
              ),

              const SizedBox(height: 16),

              // 3. 4 THẺ ĐÁP ÁN LỰA CHỌN (2x2 Grid)
              Expanded(
                flex: 3,
                child: _buildBubbleGrid(q),
              ),

              const SizedBox(height: 12),

              // 4. BOTTOM MASCOT PROGRESS DOTS (như Hình 2)
              _buildBottomProgressDots(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProblemArena(MultiplicationQuestionModel q, String tableTitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFCCE3F5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00629D).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glossy pill reflection
          Positioned(
            top: 0,
            left: 0,
            child: Transform.rotate(
              angle: -0.26,
              child: Container(
                width: 24,
                height: 7,
                decoration: BoxDecoration(
                  color: const Color(0xFF00629D).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          // Question content (Chỉ sử dụng 1 icon loa duy nhất trên AppBar theo yêu cầu)
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      q.level == MultiplicationLevel.hard
                          ? 'Hãy đọc đề bài và tính kết quả:'
                          : 'Hãy tính nhanh kết quả của phép tính:',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF00375A),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        q.questionText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: q.level == MultiplicationLevel.hard ? 18 : 34,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF00375A),
                          letterSpacing: q.level == MultiplicationLevel.hard ? 0.3 : 1.5,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleGrid(MultiplicationQuestionModel q) {
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

  Widget _buildBubbleItem(int index, MultiplicationQuestionModel q) {
    final opt = q.options[index];
    final isSelected = (_selectedBubbleIndex == index);
    final isCorrectOption = (opt.value == q.correctResult);

    bool? isCorrectResult;
    if (_isAnswering) {
      if (isSelected) {
        isCorrectResult = isCorrectOption;
      } else if (isCorrectOption) {
        isCorrectResult = true; // highlight correct answer if wrong
      }
    }

    final labels = ['LỰA CHỌN A', 'LỰA CHỌN B', 'LỰA CHỌN C', 'LỰA CHỌN D'];
    final colors = PastelToyCardColor.standardFour;

    Widget card = PastelToyCard(
      label: labels[index % 4],
      title: opt.display,
      colorConfig: colors[index % 4],
      isSelected: isSelected,
      isCorrect: isCorrectResult,
      onTap: () => _handleBubbleTap(index),
    );

    if (isSelected) {
      card = ScaleTransition(
        scale: _scaleAnimation,
        child: card,
      );
    }

    return card;
  }

  Widget _buildBottomProgressDots() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Tooltip(
            message: _mascotMessage,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFEF3C7),
              ),
              child: const Center(
                child: Text('🐝', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: List.generate(10, (i) {
                final res = (i < _questionResults.length) ? _questionResults[i] : null;
                Color barColor = const Color(0xFFE2E8F0);
                if (res != null) {
                  barColor = res ? const Color(0xFF00B460) : const Color(0xFFBA1A1A);
                } else if (i == _currentQuestionIndex) {
                  barColor = const Color(0xFFFE9D00);
                }
                return Expanded(
                  child: Container(
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
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
                  onPressed: () => _startRound(_selectedLevel),
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(
                    'Chơi Lại Chế Độ Này',
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
                    'Chọn Chế Độ Khác',
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
