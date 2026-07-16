import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class MathOpsLessonScreen extends StatefulWidget {
  const MathOpsLessonScreen({super.key});

  @override
  State<MathOpsLessonScreen> createState() => _MathOpsLessonScreenState();
}

class _MathOpsLessonScreenState extends State<MathOpsLessonScreen> {
  final Random _random = Random();
  
  int _currentQuestion = 1;
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
      _num1 = _random.nextInt(71) + 10; // 10 to 80
      _num2 = _random.nextInt(100 - _num1) + 1; // 1 to 100-num1
      _correctResult = _num1 + _num2;
    } else {
      _operator = '-';
      _num1 = _random.nextInt(81) + 20; // 20 to 100
      _num2 = _random.nextInt(_num1 - 1) + 1; // 1 to num1-1
      _correctResult = _num1 - _num2;
    }
    
    // Generate wrong choices
    final Set<int> uniqueChoices = {_correctResult};
    while (uniqueChoices.length < 4) {
      int wrong = _correctResult + _random.nextInt(9) - 4; // -4 to +4
      if (wrong >= 1 && wrong <= 100 && wrong != _correctResult) {
        uniqueChoices.add(wrong);
      } else {
        uniqueChoices.add(_random.nextInt(100) + 1);
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
    setState(() {
      _currentQuestion++;
      _generateNewQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Thêm bớt vui nhộn',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress indicator showing current question number
              Row(
                children: [
                  Icon(Icons.psychology_rounded, color: AppColors.primary, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Câu số $_currentQuestion',
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

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
                      Text(
                        'Bé hãy giải phép tính sau nhé:',
                        style: GoogleFonts.baloo2(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '$_num1 $_operator $_num2 =',
                            style: GoogleFonts.baloo2(
                              fontSize: 46,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(width: 16),
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
                            child: Text(
                              '?',
                              style: GoogleFonts.baloo2(
                                fontSize: 34,
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
              SizedBox(height: 24),

              // Answer choices Grid (2x2)
              Column(
                children: [
                  SizedBox(
                    height: 68,
                    child: Row(
                      children: [
                        _buildChoiceButton(0),
                        SizedBox(width: 16),
                        _buildChoiceButton(1),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    height: 68,
                    child: Row(
                      children: [
                        _buildChoiceButton(2),
                        SizedBox(width: 16),
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
            style: GoogleFonts.baloo2(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
