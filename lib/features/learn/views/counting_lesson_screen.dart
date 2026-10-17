import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pastel_toy_card.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../../../core/services/tts_service.dart';
import '../services/learning_progress_service.dart';

class CountingQuestion {
  final String emoji;
  final int correctCount;
  final List<int> choices;
  final String prompt;

  CountingQuestion({
    required this.emoji,
    required this.correctCount,
    required this.choices,
    required this.prompt,
  });
}

class CountingLessonScreen extends StatefulWidget {
  final int timeLimitInSeconds;

  const CountingLessonScreen({
    super.key,
    this.timeLimitInSeconds = 6,
  });

  @override
  State<CountingLessonScreen> createState() => _CountingLessonScreenState();
}

class _CountingLessonScreenState extends State<CountingLessonScreen>
    with TickerProviderStateMixin {
  final Random _random = Random();
  final List<String> _emojiPool = [
    '🐶', '🐱', '🍎', '🍓', '🚗', '🎈', '⭐', '🦖', '🐝', '🍟',
  ];

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  final Stopwatch _lessonStopwatch = Stopwatch();

  static const int _totalQuestions = 30;
  late List<CountingQuestion> _questions;
  int _currentQuestionIndex = 0;
  int _score = 0;
  int _correctAnswers = 0;
  int? _selectedChoiceIndex;
  bool _hasAnswered = false;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _questions = _generateRoundQuestions();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _lessonStopwatch.start();
    _startQuestion();
  }

  @override
  void dispose() {
    _animController.dispose();
    _lessonStopwatch.stop();
    TtsService.instance.stopAll();
    super.dispose();
  }

  List<CountingQuestion> _generateRoundQuestions() {
    final list = <CountingQuestion>[];
    for (int i = 0; i < _totalQuestions; i++) {
      final emoji = _emojiPool[_random.nextInt(_emojiPool.length)];
      final correctCount = _random.nextInt(8) + 3; // 3 to 10

      final Set<int> uniqueChoices = {correctCount};
      while (uniqueChoices.length < 4) {
        int wrong = correctCount + _random.nextInt(5) - 2; // -2 to +2
        if (wrong > 0 && wrong != correctCount) {
          uniqueChoices.add(wrong);
        } else {
          uniqueChoices.add(_random.nextInt(10) + 1);
        }
      }

      final choices = uniqueChoices.toList()..shuffle();
      list.add(CountingQuestion(
        emoji: emoji,
        correctCount: correctCount,
        choices: choices,
        prompt: 'Đếm nhanh xem có bao nhiêu vật thể?',
      ));
    }
    return list;
  }

  void _startQuestion() {
    setState(() {
      _selectedChoiceIndex = null;
      _hasAnswered = false;
    });
    _animController.reset();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _speakCurrentQuestion();
    });
  }

  void _speakCurrentQuestion() {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;
    final q = _questions[_currentQuestionIndex];
    TtsService.instance.stopAll();
    TtsService.instance.speakVietnamese(q.prompt, forced: false);
  }

  void _handleAnswer(int choiceIndex, int answerValue) {
    if (_hasAnswered) return;

    final q = _questions[_currentQuestionIndex];
    final isCorrect = (answerValue == q.correctCount);

    setState(() {
      _hasAnswered = true;
      _selectedChoiceIndex = choiceIndex;

      if (isCorrect) {
        _score += 10;
        _correctAnswers++;
        LearningProgressService.instance.recordMathCorrect(subject: 'math_counting');
      }
    });

    _animController.forward(from: 0.0);

    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      _animController.reset();
      if (_currentQuestionIndex < _totalQuestions - 1) {
        setState(() {
          _currentQuestionIndex++;
        });
        _startQuestion();
      } else {
        _endLesson();
      }
    });
  }

  void _endLesson() {
    _lessonStopwatch.stop();
    TtsService.instance.stopAll();
    setState(() {
      _isGameOver = true;
    });
  }

  void _restartRound() {
    _lessonStopwatch.reset();
    _lessonStopwatch.start();
    setState(() {
      _questions = _generateRoundQuestions();
      _currentQuestionIndex = 0;
      _score = 0;
      _correctAnswers = 0;
      _isGameOver = false;
      _selectedChoiceIndex = null;
      _hasAnswered = false;
    });
    _startQuestion();
  }

  void _showQuitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Tạm dừng học?',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bạn có chắc muốn thoát vòng luyện tập này không?',
          style: GoogleFonts.baloo2(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tiếp tục',
              style: GoogleFonts.baloo2(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // exit screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00629D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
    if (_isGameOver) {
      return _buildSummaryScreen();
    }

    final q = _questions[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Đếm Số Nhanh',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00375A),
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: _showQuitConfirmation,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GameSoundToggleButton(
              padding: EdgeInsets.zero,
              onToggled: (enabled) {
                if (enabled) {
                  TtsService.instance.speakVietnamese(q.prompt, forced: true);
                }
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isShortScreen = constraints.maxHeight < 560;

            final subHeader = Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. Pill tiến độ: 🎯 Câu hỏi 1/30
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(
                        'Câu hỏi ${_currentQuestionIndex + 1}/$_totalQuestions',
                        style: GoogleFonts.baloo2(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Pill số câu đúng: ⭐ Đã đúng: X/30
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(
                        'Đã đúng: $_correctAnswers/$_totalQuestions',
                        style: GoogleFonts.baloo2(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            if (isShortScreen) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    subHeader,
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 200, maxHeight: 270),
                      child: _buildQuestionArena(q),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 180, maxHeight: 240),
                      child: _buildChoicesGrid(q),
                    ),
                    const SizedBox(height: 12),
                    _buildBottomProgressDots(),
                  ],
                ),
              );
            }

            final arenaFlex = constraints.maxHeight < 680 ? 3 : 4;
            final gridFlex = constraints.maxHeight < 680 ? 2 : 3;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  subHeader,
                  const SizedBox(height: 14),
                  Expanded(
                    flex: arenaFlex,
                    child: _buildQuestionArena(q),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    flex: gridFlex,
                    child: _buildChoicesGrid(q),
                  ),
                  const SizedBox(height: 12),
                  _buildBottomProgressDots(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuestionArena(CountingQuestion q) {
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
          // Glossy reflection pill ở góc trái trên
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


          // Nội dung câu hỏi và icon đếm
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36.0),
                      child: Text(
                        q.prompt,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF00375A),
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Khung bo góc xám nhạt chứa danh sách vật thể đếm
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: List.generate(
                          q.correctCount,
                          (index) => Text(
                            q.emoji,
                            style: const TextStyle(fontSize: 32),
                          ),
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

  Widget _buildChoicesGrid(CountingQuestion q) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        const crossAxisSpacing = 14.0;
        const mainAxisSpacing = 14.0;

        double aspectRatio = 1.35;
        if (availableHeight.isFinite && availableHeight > 0) {
          final itemWidth = (availableWidth - crossAxisSpacing) / 2;
          final itemHeight = (availableHeight - mainAxisSpacing) / 2;
          if (itemHeight > 0 && itemWidth > 0) {
            aspectRatio = (itemWidth / itemHeight).clamp(1.05, 2.8);
          }
        }

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            final choiceValue = q.choices[index];
            final isSelected = (_selectedChoiceIndex == index);

            Widget card = PastelToyCard(
              label: '(${String.fromCharCode(65 + index)})',
              title: '$choiceValue',
              colorConfig: PastelToyCardColor.standardFour[index % 4],
              isSelected: isSelected,
              isCorrect: null, // Tắt tự động chọn/tiết lộ đáp án, xem ở report cuối cùng
              height: null,
              onTap: () => _handleAnswer(index, choiceValue),
            );

            if (isSelected) {
              card = ScaleTransition(
                scale: _scaleAnimation,
                child: card,
              );
            }

            return card;
          },
        );
      },
    );
  }

  Widget _buildBottomProgressDots() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mascot Bee Avatar
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF9C3),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('🐝', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          // 30 Progress Dashes
          Expanded(
            child: Row(
              children: List.generate(
                _totalQuestions,
                (i) {
                  final bool isDone = i <= _currentQuestionIndex;
                  final bool isCurrent = i == _currentQuestionIndex;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.0),
                      height: 5,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFFF59E0B)
                            : (isDone
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                                : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Kết Quả Luyện Tập',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: const Color(0xFF00375A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 54)),
                    const SizedBox(height: 12),
                    Text(
                      'Hoàn Thành Bài Học!',
                      style: GoogleFonts.baloo2(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00375A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bạn đã hoàn thành xuất sắc vòng luyện đếm số.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatBox(
                          title: 'Đúng',
                          value: '$_correctAnswers/$_totalQuestions',
                          color: const Color(0xFF16A34A),
                          icon: Icons.check_circle_rounded,
                        ),
                        _buildStatBox(
                          title: 'Điểm',
                          value: '+$_score',
                          color: AppColors.primary,
                          icon: Icons.stars_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _restartRound,
                icon: const Icon(Icons.replay_rounded),
                label: Text(
                  'Luyện tập lại vòng này',
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.grid_view_rounded),
                label: Text(
                  'Quay về danh sách học',
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.baloo2(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.baloo2(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
