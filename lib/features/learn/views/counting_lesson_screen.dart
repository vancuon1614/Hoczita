import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CountingLessonScreen extends StatefulWidget {
  const CountingLessonScreen({super.key});

  @override
  State<CountingLessonScreen> createState() => _CountingLessonScreenState();
}

class _CountingLessonScreenState extends State<CountingLessonScreen> {
  final Random _random = Random();
  final List<String> _emojiPool = [
    '🍎', '🍓', '🐶', '🐱', '🚗', '🎈', '⭐', '🦖', '🐝', '🍟',
  ];

  int _currentQuestion = 1;
  late String _currentEmoji;
  late int _correctCount;
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
    _currentEmoji = _emojiPool[_random.nextInt(_emojiPool.length)];
    _correctCount = _random.nextInt(8) + 3; // Random from 3 to 10

    // Generate 3 unique wrong choices close to correct count
    final Set<int> uniqueChoices = {_correctCount};
    while (uniqueChoices.length < 4) {
      int wrong = _correctCount + _random.nextInt(5) - 2; // -2 to +2
      if (wrong > 0 && wrong != _correctCount) {
        uniqueChoices.add(wrong);
      } else {
        uniqueChoices.add(_random.nextInt(10) + 1);
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
      if (choiceValue == _correctCount) {
        _hasAnsweredCorrectly = true;
      } else {
        if (!_wrongChoicesSelected.contains(index)) {
          _wrongChoicesSelected.add(index);
        }
      }
    });

    if (choiceValue == _correctCount) {
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
        title: const Text(
          'Đếm số thông minh',
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
              // Progress indicator showing current question number
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Câu số $_currentQuestion',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
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
                    children: [
                      Text(
                        'Bé đếm xem có bao nhiêu $_currentEmoji?',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 35,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Emojis Display Grid
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              alignment: WrapAlignment.center,
                              children: List.generate(
                                _correctCount,
                                (index) => AnimatedContainer(
                                  duration: Duration(
                                    milliseconds: 200 + (index * 50),
                                  ),
                                  curve: Curves.easeOutBack,
                                  width: _correctCount > 6 ? 50 : 64,
                                  height: _correctCount > 6 ? 50 : 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _currentEmoji,
                                    style: TextStyle(
                                      fontSize: _correctCount > 6 ? 32 : 40,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
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
    final bool isCorrect = _hasAnsweredCorrectly && choiceValue == _correctCount;

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
                    ),
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
