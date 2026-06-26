import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../models/game_question.dart';

class MultipleChoiceGameScreen extends StatefulWidget {
  final String gameName;
  final String gameTitle;
  final List<GameQuestion> questions;

  const MultipleChoiceGameScreen({
    super.key,
    required this.gameName,
    required this.gameTitle,
    required this.questions,
  });

  @override
  State<MultipleChoiceGameScreen> createState() => _MultipleChoiceGameScreenState();
}

class _MultipleChoiceGameScreenState extends State<MultipleChoiceGameScreen> with SingleTickerProviderStateMixin {
  late AnimationController _timerController;
  final Stopwatch _gameStopwatch = Stopwatch();
  String _elapsedTimeString = '0.0';
  
  int _currentQuestionIndex = 0;
  int _correctAnswersCount = 0;
  int _score = 0;
  
  int? _selectedChoiceIndex;
  bool _hasAnswered = false;
  bool _isGameOver = false;
  bool _isSavingScore = false;
  late List<String?> _userAnswers;

  @override
  void initState() {
    super.initState();
    
    // Initialize user answers list
    _userAnswers = List.filled(widget.questions.length, null);
    
    // Initialize 6-second timer controller
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _timerController.addListener(() {
      setState(() {});
    });

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Timeout (user did not answer in 6 seconds)
        _handleAnswer(-1, '');
      }
    });

    _gameStopwatch.start();
    _startQuestion();
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  void _startQuestion() {
    setState(() {
      _selectedChoiceIndex = null;
      _hasAnswered = false;
    });
    _timerController.forward(from: 0.0);
  }

  void _handleAnswer(int choiceIndex, String answerValue) {
    if (_hasAnswered) return;

    _timerController.stop();

    setState(() {
      _hasAnswered = true;
      _selectedChoiceIndex = choiceIndex;
      
      if (choiceIndex != -1) {
        _userAnswers[_currentQuestionIndex] = answerValue;
      }
      
      final currentQuestion = widget.questions[_currentQuestionIndex];
      final isCorrect = choiceIndex != -1 && answerValue == currentQuestion.correctAnswer;
      
      if (isCorrect) {
        _correctAnswersCount++;
      }
    });

    // Pause for 1.2s to show correct/incorrect state, then advance
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_currentQuestionIndex < widget.questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
        });
        _startQuestion();
      } else {
        _endGameAndSaveScore();
      }
    });
  }

  void _endGameAndSaveScore() async {
    _gameStopwatch.stop();
    final totalElapsedSeconds = _gameStopwatch.elapsedMilliseconds / 1000;

    setState(() {
      _elapsedTimeString = totalElapsedSeconds.toStringAsFixed(1);
      _isGameOver = true;
      _isSavingScore = true;
    });

    int stars = 0;
    if (_correctAnswersCount > 0) {
      if (totalElapsedSeconds <= 20) {
        stars = 3;
      } else if (totalElapsedSeconds <= 40) {
        stars = 2;
      } else {
        stars = 1;
      }
    }

    int basePoints = 0;
    if (stars == 3) {
      basePoints = 30;
    } else if (stars == 2) {
      basePoints = 20;
    } else if (stars == 1) {
      basePoints = 10;
    }

    _score = (basePoints * _correctAnswersCount) ~/ 10;

    try {
      await SupabaseService.instance.saveScore(
        gameName: widget.gameName,
        stars: stars,
        score: _score,
      );
    } catch (e) {
      debugPrint('Error saving score: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingScore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isGameOver) {
      return _buildSummaryView();
    }

    final currentQuestion = widget.questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / widget.questions.length;
    
    // Lerp timer color from green to red based on time spent
    final timerColor = Color.lerp(
      AppColors.success, 
      AppColors.error, 
      _timerController.value
    ) ?? AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.gameTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _showQuitConfirmation(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header progress & Timer Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Câu hỏi ${_currentQuestionIndex + 1}/${widget.questions.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  // Animated Circular Timer
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: 1.0 - _timerController.value,
                        backgroundColor: AppColors.border,
                        color: timerColor,
                        strokeWidth: 6,
                      ),
                      Text(
                        (6 - (_timerController.value * 6).floor()).toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: timerColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Top linear progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.border,
                  color: AppColors.primary,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 24),

              // Question/Prompt Card
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildQuestionPrompt(currentQuestion),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Answer options Grid (supports dynamic number of choices)
              Expanded(
                flex: 3,
                child: _buildChoicesGrid(currentQuestion),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualAsset(String asset, {double height = 120.0, double fontSize = 54.0}) {
    if (asset.startsWith('http://') || asset.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: asset,
        height: height,
        fit: BoxFit.contain,
        placeholder: (context, url) => SizedBox(
          height: height,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
        errorWidget: (context, url, error) => const Icon(
          Icons.broken_image_rounded,
          color: AppColors.error,
          size: 48,
        ),
      );
    } else if (asset.startsWith('assets/') || asset.startsWith('ImageFolder/')) {
      return Image.asset(
        asset,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.broken_image_rounded,
          color: AppColors.error,
          size: 48,
        ),
      );
    } else {
      // It's likely an emoji or a short text count (e.g. '🍎🍎🍎')
      double adjustedFontSize = fontSize;
      if (asset.length > 5) {
        adjustedFontSize = fontSize * 0.7;
      }
      if (asset.length > 10) {
        adjustedFontSize = fontSize * 0.5;
      }
      return Text(
        asset,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: adjustedFontSize),
      );
    }
  }

  Widget _buildQuestionPrompt(GameQuestion question) {
    // If it's a Left-Right Comparison question
    if (question.comparisonLeft != null && question.comparisonRight != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            question.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Left panel
              Expanded(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: _buildVisualAsset(question.comparisonLeft!, height: 100.0, fontSize: 48.0),
                ),
              ),
              const SizedBox(width: 16),
              // Right panel
              Expanded(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: _buildVisualAsset(question.comparisonRight!, height: 100.0, fontSize: 48.0),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Default question type (image/emoji + prompt text)
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (question.visualAsset != null) ...[
          _buildVisualAsset(question.visualAsset!, height: 140.0, fontSize: 54.0),
          const SizedBox(height: 20),
        ],
        Text(
          question.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildChoicesGrid(GameQuestion question) {
    if (widget.gameName == 'comparison') {
      final choices = ['Bên trái', 'Bên phải', 'Bằng nhau'];
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildChoiceButton(0, question, choices[0]),
                const SizedBox(width: 16),
                _buildChoiceButton(1, question, choices[1]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                _buildChoiceButton(2, question, choices[2]),
              ],
            ),
          ),
        ],
      );
    }

    final choicesCount = question.choices.length;
    if (choicesCount == 4) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildChoiceButton(0, question),
                const SizedBox(width: 16),
                _buildChoiceButton(1, question),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                _buildChoiceButton(2, question),
                const SizedBox(width: 16),
                _buildChoiceButton(3, question),
              ],
            ),
          ),
        ],
      );
    } else if (choicesCount == 3) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildChoiceButton(0, question),
                const SizedBox(width: 16),
                _buildChoiceButton(1, question),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                _buildChoiceButton(2, question),
              ],
            ),
          ),
        ],
      );
    } else if (choicesCount == 2) {
      return Row(
        children: [
          _buildChoiceButton(0, question),
          const SizedBox(width: 16),
          _buildChoiceButton(1, question),
        ],
      );
    } else {
      return Column(
        children: List.generate(
          choicesCount,
          (index) => Expanded(
            child: Row(
              children: [
                _buildChoiceButton(index, question),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildChoiceButton(int index, GameQuestion question, [String? customValue]) {
    final choiceValue = customValue ?? question.choices[index];
    final isCorrectAnswer = choiceValue == question.correctAnswer;
    
    Color buttonColor = Colors.white;
    Color borderColor = AppColors.border;
    Color textColor = AppColors.textPrimary;

    if (_hasAnswered && _selectedChoiceIndex != -1) {
      if (isCorrectAnswer) {
        // Correct answer always turns green
        buttonColor = AppColors.success.withValues(alpha: 0.12);
        borderColor = AppColors.success;
        textColor = AppColors.success;
      } else if (_selectedChoiceIndex == index) {
        // Selected incorrect answer turns red
        buttonColor = AppColors.error.withValues(alpha: 0.12);
        borderColor = AppColors.error;
        textColor = AppColors.error;
      }
    } else if (_selectedChoiceIndex == index) {
      buttonColor = AppColors.primaryLight;
      borderColor = AppColors.primary;
      textColor = AppColors.primary;
    }

    return Expanded(
      child: GestureDetector(
        onTap: _hasAnswered ? null : () => _handleAnswer(index, choiceValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 2.5),
            boxShadow: (_selectedChoiceIndex == index || (_hasAnswered && isCorrectAnswer && _selectedChoiceIndex != -1))
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
            choiceValue,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  void _showQuitConfirmation() {
    _timerController.stop();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thoát Trò Chơi?'),
        content: const Text('Tiến trình chơi và điểm số của lượt này sẽ không được lưu lại.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              _timerController.forward(); // Tiếp tục đếm ngược
            },
            child: const Text('Chơi tiếp'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              Navigator.pop(context); // Thoát game
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryView() {
    final totalElapsedSeconds = double.tryParse(_elapsedTimeString) ?? 0.0;
    int stars = 0;
    if (_correctAnswersCount > 0) {
      if (totalElapsedSeconds <= 20) {
        stars = 3;
      } else if (totalElapsedSeconds <= 40) {
        stars = 2;
      } else {
        stars = 1;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Trophy Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: stars > 0 ? const Color(0xFFFFF9E6) : AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    stars > 0 ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                    color: stars > 0 ? Colors.amber : AppColors.primary,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                stars > 0 ? 'Tuyệt Vời! 🎉' : 'Cố Gắng Lên Bé Ơi!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                'Bé đã trả lời đúng $_correctAnswersCount/${widget.questions.length} câu đố trong ${_elapsedTimeString}s.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Animated Star Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final active = index < stars;
                  return AnimatedScale(
                    scale: active ? 1.3 : 1.0,
                    duration: Duration(milliseconds: 300 + (index * 150)),
                    curve: Curves.elasticOut,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.star_rounded,
                        size: 48,
                        color: active ? Colors.amber : AppColors.border,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),

              // Time & Score Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Thời gian',
                            style: TextStyle(fontSize: 13, color: AppColors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_elapsedTimeString}s',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Điểm cộng',
                            style: TextStyle(fontSize: 13, color: AppColors.success),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+$_score',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Detailed results table
              const SizedBox(height: 32),
              const Text(
                'Chi Tiết Kết Quả 📊',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildResultsTable(),
              const SizedBox(height: 32),
              
              // End game action button
              ElevatedButton(
                onPressed: _isSavingScore
                    ? null
                    : () {
                        Navigator.pop(context); // Quay về GameTab
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSavingScore
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Quay lại danh mục',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(widget.questions.length, (index) {
          final question = widget.questions[index];
          final userAnswer = _userAnswers[index];
          final isCorrect = userAnswer == question.correctAnswer;
          
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: index < widget.questions.length - 1
                  ? const Border(bottom: BorderSide(color: AppColors.border))
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question index and icon
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isCorrect 
                      ? AppColors.success.withValues(alpha: 0.1) 
                      : AppColors.error.withValues(alpha: 0.1),
                  child: Icon(
                    isCorrect ? Icons.check_rounded : Icons.close_rounded,
                    color: isCorrect ? AppColors.success : AppColors.error,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Question content and answers
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Câu ${index + 1}: ${question.prompt}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text(
                            'Đáp án đúng: ',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          Text(
                            question.correctAnswer,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text(
                            'Bé chọn: ',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          Text(
                            userAnswer ?? 'Hết giờ ⏳',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCorrect 
                                  ? AppColors.success 
                                  : (userAnswer == null ? Colors.orange : AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
