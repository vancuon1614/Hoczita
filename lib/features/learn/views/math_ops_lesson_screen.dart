import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pastel_toy_card.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../../../core/services/tts_service.dart';
import '../services/learning_progress_service.dart';

class MathOpQuestion {
  final int num1;
  final int num2;
  final String operator;
  final int correctResult;
  final List<int> choices;
  final String ttsPrompt;

  MathOpQuestion({
    required this.num1,
    required this.num2,
    required this.operator,
    required this.correctResult,
    required this.choices,
    required this.ttsPrompt,
  });
}

class MathOpsLessonScreen extends StatefulWidget {
  const MathOpsLessonScreen({super.key});

  @override
  State<MathOpsLessonScreen> createState() => _MathOpsLessonScreenState();
}

class _MathOpsLessonScreenState extends State<MathOpsLessonScreen>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();

  static const int _totalQuestions = 30;
  late MathOpQuestion _currentQuestionData;
  int _currentQuestion = 1;
  int _correctAnswers = 0;
  bool get _isSoundEnabled => TtsService.instance.isEnabled;

  int? _selectedChoiceIndex;
  bool _isAnswering = false;
  bool _isGameOver = false;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _generateNewQuestion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakCurrentQuestion();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    TtsService.instance.stopAll();
    super.dispose();
  }

  void _generateNewQuestion() {
    final bool isAddition = _random.nextBool();
    int num1, num2, correctResult;
    String op;

    if (isAddition) {
      op = '+';
      num1 = _random.nextInt(71) + 10; // 10 to 80
      num2 = _random.nextInt(100 - num1) + 1; // 1 to 100-num1
      correctResult = num1 + num2;
    } else {
      op = '-';
      num1 = _random.nextInt(81) + 20; // 20 to 100
      num2 = _random.nextInt(num1 - 1) + 1; // 1 to num1-1
      correctResult = num1 - num2;
    }

    final Set<int> uniqueChoices = {correctResult};
    while (uniqueChoices.length < 4) {
      int wrong = correctResult + _random.nextInt(9) - 4; // -4 to +4
      if (wrong >= 1 && wrong <= 100 && wrong != correctResult) {
        uniqueChoices.add(wrong);
      } else {
        uniqueChoices.add(_random.nextInt(100) + 1);
      }
    }

    final choices = uniqueChoices.toList()..shuffle();
    final prompt = isAddition
        ? '$num1 cộng $num2 bằng bao nhiêu?'
        : '$num1 trừ $num2 bằng bao nhiêu?';

    setState(() {
      _currentQuestionData = MathOpQuestion(
        num1: num1,
        num2: num2,
        operator: op,
        correctResult: correctResult,
        choices: choices,
        ttsPrompt: prompt,
      );
      _selectedChoiceIndex = null;
      _isAnswering = false;
    });
  }

  void _speakCurrentQuestion({bool forced = false}) {
    if (!_isSoundEnabled && !forced) return;
    TtsService.instance.stopAll(); // Dọn dẹp hàng đợi trước khi đọc câu mới
    TtsService.instance.speakVietnamese(_currentQuestionData.ttsPrompt, forced: forced);
  }

  void _handleChoiceTap(int index) {
    if (_isAnswering) return;

    final chosenValue = _currentQuestionData.choices[index];
    final isCorrect = (chosenValue == _currentQuestionData.correctResult);

    setState(() {
      _isAnswering = true;
      _selectedChoiceIndex = index;
    });

    _animController.forward(from: 0.0);

    if (isCorrect) {
      _correctAnswers++;
      LearningProgressService.instance.recordMathCorrect(subject: 'math_ops');
    }

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _animController.reset();
      if (_currentQuestion < _totalQuestions) {
        setState(() {
          _currentQuestion++;
          _selectedChoiceIndex = null;
          _isAnswering = false;
          _generateNewQuestion();
        });
        _speakCurrentQuestion();
      } else {
        setState(() {
          _isGameOver = true;
        });
      }
    });
  }

  void _restartRound() {
    setState(() {
      _currentQuestion = 1;
      _correctAnswers = 0;
      _selectedChoiceIndex = null;
      _isAnswering = false;
      _isGameOver = false;
      _generateNewQuestion();
    });
    _speakCurrentQuestion();
  }

  void _showQuitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Kết thúc luyện tập?',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
        ),
        content: Text(
          _currentQuestion > 1
              ? 'Bạn đã trả lời đúng $_correctAnswers trên ${_currentQuestion - 1} câu hỏi. Bạn có muốn kết thúc bài học không?'
              : 'Bạn có chắc muốn thoát bài học này không?',
          style: GoogleFonts.baloo2(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Luyện tiếp', style: GoogleFonts.baloo2(color: AppColors.textSecondary)),
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
            child: Text('Thoát ra', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold)),
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

    final q = _currentQuestionData;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Thêm Bớt Vui Nhộn',
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
                  _speakCurrentQuestion(forced: true);
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
                        'Câu hỏi $_currentQuestion/$_totalQuestions',
                        style: GoogleFonts.baloo2(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),

                // Số câu trả lời đúng đã tích lũy
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF16A34A)),
                      const SizedBox(width: 5),
                      Text(
                        'Đã đúng: $_correctAnswers/$_totalQuestions',
                        style: GoogleFonts.baloo2(
                          fontSize: 13,
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
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 180, maxHeight: 260),
                      child: _buildProblemArena(q),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 180, maxHeight: 240),
                      child: _buildBubbleGrid(q),
                    ),
                    const SizedBox(height: 14),
                    _buildBottomProgressDots(),
                  ],
                ),
              );
            }

            final arenaFlex = constraints.maxHeight < 680 ? 1 : 4;
            final gridFlex = constraints.maxHeight < 680 ? 1 : 3;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  subHeader,
                  const SizedBox(height: 16),
                  Expanded(
                    flex: arenaFlex,
                    child: _buildProblemArena(q),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    flex: gridFlex,
                    child: _buildBubbleGrid(q),
                  ),
                  const SizedBox(height: 14),
                  _buildBottomProgressDots(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProblemArena(MathOpQuestion q) {
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

          // Question content
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Hãy tính nhanh kết quả của phép tính:',
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
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '${q.num1} ${q.operator} ${q.num2} = ?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF00375A),
                          letterSpacing: 1.5,
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

  Widget _buildBubbleGrid(MathOpQuestion q) {
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
            return _buildBubbleItem(index, q);
          },
        );
      },
    );
  }

  Widget _buildBubbleItem(int index, MathOpQuestion q) {
    final choiceValue = q.choices[index];
    final isSelected = (_selectedChoiceIndex == index);
    final labels = ['(A)', '(B)', '(C)', '(D)'];
    final colors = PastelToyCardColor.standardFour;

    Widget card = PastelToyCard(
      label: labels[index % 4],
      title: '$choiceValue',
      colorConfig: colors[index % 4],
      isSelected: isSelected,
      isCorrect: null, // Tắt tự động chọn/tiết lộ đáp án khi chơi, xem ở report cuối cùng
      height: null,
      onTap: () => _handleChoiceTap(index),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
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
          Expanded(
            child: Row(
              children: List.generate(
                _totalQuestions,
                (i) {
                  final bool isDone = i < _currentQuestion - 1;
                  final bool isCurrent = i == _currentQuestion - 1;
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
                      'Bạn đã hoàn thành xuất sắc vòng luyện thêm bớt vui nhộn.',
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
                          value: '+${_correctAnswers * 10}',
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
