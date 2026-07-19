import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../models/game_question.dart';
import 'package:google_fonts/google_fonts.dart';

class MultipleChoiceGameScreen extends StatefulWidget {
  final String gameName;
  final String gameTitle;
  final List<GameQuestion> questions;
  final int timeLimitInSeconds;

  const MultipleChoiceGameScreen({
    super.key,
    required this.gameName,
    required this.gameTitle,
    required this.questions,
    this.timeLimitInSeconds = 6,
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
  int _stars = 0;
  
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
    
    // Initialize timer controller
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.timeLimitInSeconds),
    );

    _timerController.addListener(() {
      setState(() {});
    });

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Timeout (user did not answer in timeLimitInSeconds)
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

    // Pause for 300ms to show selected state, then advance
    Future.delayed(const Duration(milliseconds: 300), () {
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

  String _formatTime(double seconds) {
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(1)}s';
    }
    final int totalSeconds = seconds.round();
    if (totalSeconds < 3600) {
      final int minutes = totalSeconds ~/ 60;
      final int remainingSeconds = totalSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      final int hours = totalSeconds ~/ 3600;
      final int minutes = (totalSeconds % 3600) ~/ 60;
      final int remainingSeconds = totalSeconds % 60;
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  void _endGameAndSaveScore() async {
    _gameStopwatch.stop();
    final totalElapsedSeconds = _gameStopwatch.elapsedMilliseconds / 1000;

    setState(() {
      _elapsedTimeString = _formatTime(totalElapsedSeconds);
      _isGameOver = true;
      _isSavingScore = true;
    });


    if (_correctAnswersCount >= 10) {
      _stars = 3;
    } else if (_correctAnswersCount >= 7) {
      _stars = 2;
    } else if (_correctAnswersCount >= 4) {
      _stars = 1;
    } else {
      _stars = 0;
    }

    // Mỗi câu trả lời đúng được cộng 3 điểm để khích lệ bé học tập
    _score = _correctAnswersCount * 3;

    try {
      await SupabaseService.instance.saveScore(
        gameName: widget.gameName,
        stars: _stars,
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
        centerTitle: true,
        title: Text(
          widget.gameTitle,
          style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded),
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
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
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
                        (widget.timeLimitInSeconds - (_timerController.value * widget.timeLimitInSeconds).floor()).toString(),
                        style: GoogleFonts.baloo2(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: timerColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12),
              
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
              SizedBox(height: 24),

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
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  currentQuestion.prompt,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    height: 1.3,
                                  ),
                                ),
                                SizedBox(height: 24),
                                _buildQuestionPrompt(currentQuestion),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

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
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
        errorWidget: (context, url, error) => Icon(
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
        errorBuilder: (context, error, stackTrace) => Icon(
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
        style: GoogleFonts.baloo2(fontSize: adjustedFontSize),
      );
    }
  }

  Widget _buildQuestionPrompt(GameQuestion question) {
    // If it's a Left-Right Comparison question
    if (question.comparisonLeft != null && question.comparisonRight != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                  child: _buildVisualAsset(question.comparisonLeft!, height: 100.0, fontSize: 46),
                ),
              ),
              SizedBox(width: 16),
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
                  child: _buildVisualAsset(question.comparisonRight!, height: 100.0, fontSize: 46),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Default question type (image/emoji)
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (question.visualAsset != null) ...[
          _buildVisualAsset(question.visualAsset!, height: 140.0, fontSize: 52),
        ],
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
                Expanded(child: _buildChoiceButton(0, question, choices[0])),
                SizedBox(width: 16),
                Expanded(child: _buildChoiceButton(1, question, choices[1])),
              ],
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Spacer(),
                      Expanded(flex: 2, child: _buildChoiceButton(2, question, choices[2])),
                      Spacer(),
                    ],
                  ),
                ),
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
                Expanded(child: _buildChoiceButton(0, question)),
                SizedBox(width: 16),
                Expanded(child: _buildChoiceButton(1, question)),
              ],
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildChoiceButton(2, question)),
                SizedBox(width: 16),
                Expanded(child: _buildChoiceButton(3, question)),
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
                Expanded(child: _buildChoiceButton(0, question)),
                SizedBox(width: 16),
                Expanded(child: _buildChoiceButton(1, question)),
              ],
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Spacer(),
                      Expanded(flex: 2, child: _buildChoiceButton(2, question)),
                      Spacer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (choicesCount == 2) {
      return Row(
        children: [
          Expanded(child: _buildChoiceButton(0, question)),
          SizedBox(width: 16),
          Expanded(child: _buildChoiceButton(1, question)),
        ],
      );
    } else {
      return Column(
        children: List.generate(
          choicesCount,
          (index) => Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Expanded(child: _buildChoiceButton(index, question)),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildChoiceButton(int index, GameQuestion question, [String? customValue]) {
    final choiceValue = customValue ?? question.choices[index];
    
    Color buttonColor = Colors.white;
    Color borderColor = AppColors.border;
    Color textColor = AppColors.textPrimary;

    if (_selectedChoiceIndex == index) {
      buttonColor = AppColors.primaryLight;
      borderColor = AppColors.primary;
      textColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: _hasAnswered ? null : () => _handleAnswer(index, choiceValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 2.5),
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
          choiceValue,
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
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
        title: Text('Thoát Trò Chơi?'),
        content: Text('Tiến trình chơi và điểm số của lượt này sẽ không được lưu lại.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              _timerController.forward(); // Tiếp tục đếm ngược
            },
            child: Text('Chơi tiếp'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              Navigator.pop(context); // Thoát game
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('Thoát'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryView() {
    final stars = _stars;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Trophy Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: stars > 0 ? const Color(0xFFFFF9E6) : AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    stars > 0 ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                    color: stars > 0 ? Colors.amber : AppColors.primary,
                    size: 56,
                  ),
                ),
              ),
              SizedBox(height: 12),
              
              Text(
                stars > 0 ? 'Tuyệt Vời! 🎉' : 'Lần Sau Cố Gắng Hơn Nhé!',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              
              Text(
                'Bạn đã trả lời đúng $_correctAnswersCount/${widget.questions.length} câu đố trong $_elapsedTimeString.',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 12),

              // Animated Star Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final active = index < stars;
                  return AnimatedScale(
                    scale: active ? 1.2 : 1.0,
                    duration: Duration(milliseconds: 300 + (index * 150)),
                    curve: Curves.elasticOut,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.star_rounded,
                        size: 36,
                        color: active ? Colors.amber : AppColors.border,
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 16),

              // Time & Score Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Thời gian',
                            style: GoogleFonts.baloo2(fontSize: 10, color: AppColors.primary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            _elapsedTimeString,
                            style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8F5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Điểm cộng',
                            style: GoogleFonts.baloo2(fontSize: 10, color: AppColors.success),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '+$_score',
                            style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Detailed results table
              SizedBox(height: 40),
              Text(
                'Chi Tiết Kết Quả 📊',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 12),
              _buildResultsTable(),
              SizedBox(height: 28),
              
              // End game action button
              Center(
                child: SizedBox(
                  width: 220,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSavingScore
                        ? null
                        : () {
                            Navigator.pop(context); // Quay về GameTab
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isSavingScore
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Quay lại danh mục',
                            style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
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

  Widget _buildResultsTable() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.0,
          ),
          itemCount: widget.questions.length,
          itemBuilder: (context, index) {
            final question = widget.questions[index];
            final userAnswer = _userAnswers[index];
            final isCorrect = userAnswer == question.correctAnswer;

            final Color color = isCorrect ? AppColors.success : AppColors.error;

            return InkWell(
              onTap: () => _showQuestionDetailDialog(index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 2.0),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.baloo2(
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
    );
  }

  void _showQuestionDetailDialog(int index) {
    final question = widget.questions[index];
    final userAnswer = _userAnswers[index];
    final List<String> choices = widget.gameName == 'comparison'
        ? ['Bên trái', 'Bên phải', 'Bằng nhau']
        : question.choices;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Câu hỏi ${index + 1}',
                      style: GoogleFonts.baloo2(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      if (question.visualAsset != null) ...[
                        _buildVisualAsset(question.visualAsset!, height: 80.0, fontSize: 34),
                        SizedBox(height: 12),
                      ],
                      if (question.comparisonLeft != null && question.comparisonRight != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                alignment: Alignment.center,
                                child: _buildVisualAsset(question.comparisonLeft!, height: 60.0, fontSize: 30),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                alignment: Alignment.center,
                                child: _buildVisualAsset(question.comparisonRight!, height: 60.0, fontSize: 30),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                      ],
                      Text(
                        question.prompt,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Các đáp án:',
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 8),
                Column(
                  children: choices.map((choice) {
                    final isCorrectAnswer = choice == question.correctAnswer;
                    final isUserSelection = choice == userAnswer;
                    
                    Color itemBgColor = AppColors.background;
                    Color itemBorderColor = AppColors.border.withValues(alpha: 0.5);
                    Color itemTextColor = AppColors.textPrimary;
                    Widget? suffixIcon;

                    if (isCorrectAnswer) {
                      itemBgColor = AppColors.success.withValues(alpha: 0.12);
                      itemBorderColor = AppColors.success;
                      itemTextColor = AppColors.success;
                      suffixIcon = Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20);
                    } else if (isUserSelection) {
                      itemBgColor = AppColors.error.withValues(alpha: 0.12);
                      itemBorderColor = AppColors.error;
                      itemTextColor = AppColors.error;
                      suffixIcon = Icon(Icons.cancel_rounded, color: AppColors.error, size: 20);
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: itemBgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: itemBorderColor, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              choice,
                              style: GoogleFonts.baloo2(
                                fontSize: 12,
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
                  }).toList(),
                ),
                if (userAnswer == null) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer_outlined, color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Đã hết thời gian chọn đáp án! ⏳',
                          style: GoogleFonts.baloo2(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
