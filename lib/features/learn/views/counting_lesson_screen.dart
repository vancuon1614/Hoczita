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
    '🍎',
    '🍓',
    '🐶',
    '🐱',
    '🚗',
    '🎈',
    '⭐',
    '🦖',
    '🐝',
    '🍟',
  ];

  int _currentQuestion = 1;
  final int _totalQuestions = 10;

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
                'Bé học đếm rất giỏi! Hãy tiếp tục rèn luyện để thông minh hơn nhé.',
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
    final bool isCorrect =
        _hasAnsweredCorrectly && choiceValue == _correctCount;

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
