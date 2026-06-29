import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MathOpsLessonQuestion {
  final int num1;
  final int num2;
  final String operator;
  final int correctResult;
  final List<int> choices;
  int? selectedAnswer;

  MathOpsLessonQuestion({
    required this.num1,
    required this.num2,
    required this.operator,
    required this.correctResult,
    required this.choices,
    this.selectedAnswer,
  });
}

class MathOpsLessonScreen extends StatefulWidget {
  const MathOpsLessonScreen({super.key});

  @override
  State<MathOpsLessonScreen> createState() => _MathOpsLessonScreenState();
}

class _MathOpsLessonScreenState extends State<MathOpsLessonScreen> {
  final Random _random = Random();
  
  int _currentQuestion = 1;
  final int _totalQuestions = 10;
  
  final List<MathOpsLessonQuestion> _questions = [];
  int? _selectedChoiceIndex;
  bool _hasAnswered = false;
  final List<bool> _results = [];

  @override
  void initState() {
    super.initState();
    _generateAllQuestions();
  }

  void _generateAllQuestions() {
    _questions.clear();
    for (int i = 0; i < _totalQuestions; i++) {
      final bool isAddition = _random.nextBool();
      int num1;
      int num2;
      String operator;
      int correctResult;

      if (isAddition) {
        operator = '+';
        num1 = _random.nextInt(10) + 1; // 1 to 10
        num2 = _random.nextInt(9) + 1;  // 1 to 9
        correctResult = num1 + num2;
      } else {
        operator = '-';
        num1 = _random.nextInt(10) + 9; // 9 to 18
        num2 = _random.nextInt(num1 - 2) + 1; // 1 to num1-2, avoiding 0 or negative results
        correctResult = num1 - num2;
      }
      
      // Generate wrong choices
      final Set<int> uniqueChoices = {correctResult};
      while (uniqueChoices.length < 4) {
        int wrong = correctResult + _random.nextInt(5) - 2; // -2 to +2
        if (wrong >= 0 && wrong != correctResult) {
          uniqueChoices.add(wrong);
        } else {
          uniqueChoices.add(_random.nextInt(20) + 1);
        }
      }
      
      final choices = uniqueChoices.toList()..shuffle();
      _questions.add(MathOpsLessonQuestion(
        num1: num1,
        num2: num2,
        operator: operator,
        correctResult: correctResult,
        choices: choices,
      ));
    }
  }

  void _handleChoiceTap(int index, int choiceValue) async {
    if (_hasAnswered) return;

    final currentQuestion = _questions[_currentQuestion - 1];

    setState(() {
      _selectedChoiceIndex = index;
      _hasAnswered = true;
      currentQuestion.selectedAnswer = choiceValue;
      _results.add(choiceValue == currentQuestion.correctResult);
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _handleNextQuestion();
    }
  }

  void _handleNextQuestion() {
    if (_currentQuestion < _totalQuestions) {
      setState(() {
        _currentQuestion++;
        _selectedChoiceIndex = null;
        _hasAnswered = false;
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _showQuestionDetailDialog(int index) {
    final question = _questions[index];
    final isCorrect = question.selectedAnswer == question.correctResult;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isCorrect ? AppColors.success : AppColors.error,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Câu số ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  '${question.num1} ${question.operator} ${question.num2} = ?',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Các phương án lựa chọn:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...question.choices.map((choice) {
              final isCorrectAnswer = choice == question.correctResult;
              final isUserSelection = choice == question.selectedAnswer;

              Color itemBgColor = AppColors.background;
              Color itemBorderColor = AppColors.border.withValues(alpha: 0.5);
              Color itemTextColor = AppColors.textPrimary;
              Widget? suffixIcon;

              if (isCorrectAnswer) {
                itemBgColor = AppColors.success.withValues(alpha: 0.12);
                itemBorderColor = AppColors.success;
                itemTextColor = AppColors.success;
                suffixIcon = const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20);
              } else if (isUserSelection) {
                itemBgColor = AppColors.error.withValues(alpha: 0.12);
                itemBorderColor = AppColors.error;
                itemTextColor = AppColors.error;
                suffixIcon = const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20);
              }

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: itemBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: itemBorderColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        choice.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: (isCorrectAnswer || isUserSelection)
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: itemTextColor,
                        ),
                      ),
                    ),
                    suffixIcon ?? const SizedBox.shrink(),
                  ],
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    final int correctCount = _results.where((r) => r).length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F8F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.success,
                  size: 64,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Hoàn Thành Bài Học! 🎉',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bé đã trả lời đúng $correctCount/$_totalQuestions câu hỏi tính toán!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              
              const Text(
                'Kết quả chi tiết (Ấn để xem lại):',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 220,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final isCorrect = _results[index];
                    final Color color = isCorrect ? AppColors.success : AppColors.error;
                    return InkWell(
                      onTap: () => _showQuestionDetailDialog(index),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color, width: 2.0),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Đóng dialog
                  Navigator.pop(context); // Quay về LearnTab
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Quay lại danh mục'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentQuestion = _questions[_currentQuestion - 1];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thêm bớt vui nhộn',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress indicator
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _currentQuestion / _totalQuestions,
                        backgroundColor: AppColors.border,
                        color: AppColors.primary,
                        minHeight: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$_currentQuestion / $_totalQuestions',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Question Prompt Card
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Bé hãy giải phép tính sau nhé:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '${currentQuestion.num1} ${currentQuestion.operator} ${currentQuestion.num2} =',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '?',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Answer choices Grid (2x2)
              Column(
                children: [
                  SizedBox(
                    height: 68,
                    child: Row(
                      children: [
                        _buildChoiceButton(0, currentQuestion),
                        const SizedBox(width: 16),
                        _buildChoiceButton(1, currentQuestion),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 68,
                    child: Row(
                      children: [
                        _buildChoiceButton(2, currentQuestion),
                        const SizedBox(width: 16),
                        _buildChoiceButton(3, currentQuestion),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceButton(int index, MathOpsLessonQuestion question) {
    final int choiceValue = question.choices[index];

    Color buttonColor = Colors.white;
    Color borderColor = AppColors.border;
    Color textColor = AppColors.textPrimary;

    if (_selectedChoiceIndex == index) {
      buttonColor = AppColors.primaryLight;
      borderColor = AppColors.primary;
      textColor = AppColors.primary;
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => _handleChoiceTap(index, choiceValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: _selectedChoiceIndex == index
                ? [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            choiceValue.toString(),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
