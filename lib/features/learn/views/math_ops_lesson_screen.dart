import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MathOpsLessonScreen extends StatefulWidget {
  const MathOpsLessonScreen({super.key});

  @override
  State<MathOpsLessonScreen> createState() => _MathOpsLessonScreenState();
}

class _MathOpsLessonScreenState extends State<MathOpsLessonScreen> {
  final Random _random = Random();
  
  int _currentQuestion = 1;
  final int _totalQuestions = 10;
  
  late int _num1;
  late int _num2;
  late String _operator;
  late int _correctResult;
  late List<int> _choices;
  
  int? _selectedChoiceIndex;
  bool _hasAnsweredCorrectly = false;
  final List<int> _wrongChoicesSelected = [];

  @override
  void initState() {
    super.initState();
    _generateNewQuestion();
  }

  void _generateNewQuestion() {
    final bool isAddition = _random.nextBool();
    
    if (isAddition) {
      _operator = '+';
      _num1 = _random.nextInt(10) + 1; // 1 to 10
      _num2 = _random.nextInt(9) + 1;  // 1 to 9
      _correctResult = _num1 + _num2;
    } else {
      _operator = '-';
      _num1 = _random.nextInt(10) + 9; // 9 to 18
      _num2 = _random.nextInt(_num1 - 2) + 1; // 1 to num1-2, avoiding 0 or negative results
      _correctResult = _num1 - _num2;
    }
    
    // Generate wrong choices
    final Set<int> uniqueChoices = {_correctResult};
    while (uniqueChoices.length < 4) {
      int wrong = _correctResult + _random.nextInt(5) - 2; // -2 to +2
      if (wrong >= 0 && wrong != _correctResult) {
        uniqueChoices.add(wrong);
      } else {
        uniqueChoices.add(_random.nextInt(20) + 1);
      }
    }
    
    _choices = uniqueChoices.toList()..shuffle();
    _selectedChoiceIndex = null;
    _hasAnsweredCorrectly = false;
    _wrongChoicesSelected.clear();
  }

  void _handleChoiceTap(int index, int choiceValue) async {
    if (_hasAnsweredCorrectly) return;

    setState(() {
      _selectedChoiceIndex = index;
      if (choiceValue == _correctResult) {
        _hasAnsweredCorrectly = true;
      } else {
        if (!_wrongChoicesSelected.contains(index)) {
          _wrongChoicesSelected.add(index);
        }
      }
    });

    if (choiceValue == _correctResult) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        _handleNextQuestion();
      }
    }
  }

  void _handleNextQuestion() {
    if (_currentQuestion < _totalQuestions) {
      setState(() {
        _currentQuestion++;
        _generateNewQuestion();
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Padding(
          padding: const EdgeInsets.all(28),
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
              const SizedBox(height: 24),
              const Text(
                'Hoàn Thành Bài Học! 🎉',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bé tính toán rất giỏi! Hãy tiếp tục rèn luyện các phép tính để đạt điểm cao nhé.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
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
              // Progress bar
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

              // Chalkboard Math Card
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4C3A), // Chalkboard forest green
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFD4AF37), width: 6), // Wooden frame effect
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Bé hãy giải phép tính sau nhé:',
                        style: TextStyle(
                          color: Color(0xFFEAEAEA),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$_num1 $_operator $_num2 = ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace', // Gives a chalky board vibe
                            ),
                          ),
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '?',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Choice buttons (2x2)
              Column(
                children: [
                  SizedBox(
                    height: 68,
                    child: Row(
                      children: [
                        _buildChoiceButton(0),
                        const SizedBox(width: 16),
                        _buildChoiceButton(1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 68,
                    child: Row(
                      children: [
                        _buildChoiceButton(2),
                        const SizedBox(width: 16),
                        _buildChoiceButton(3),
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

  Widget _buildChoiceButton(int index) {
    final int choiceValue = _choices[index];
    final bool isWrong = _wrongChoicesSelected.contains(index);
    final bool isCorrect = _hasAnsweredCorrectly && choiceValue == _correctResult;
    
    Color buttonColor = Colors.white;
    Color borderColor = AppColors.border;
    Color textColor = AppColors.textPrimary;

    if (isCorrect) {
      buttonColor = AppColors.success.withValues(alpha: 0.12);
      borderColor = AppColors.success;
      textColor = AppColors.success;
    } else if (isWrong) {
      buttonColor = AppColors.error.withValues(alpha: 0.12);
      borderColor = AppColors.error;
      textColor = AppColors.error;
    } else if (_selectedChoiceIndex == index && !_hasAnsweredCorrectly) {
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
            boxShadow: isCorrect || _selectedChoiceIndex == index
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
