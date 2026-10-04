import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../../../core/providers/game_interaction_provider.dart';
import '../models/game_question.dart';
import 'package:google_fonts/google_fonts.dart';
import 'common/mini_game_rank_banner.dart';

class MultipleChoiceGameScreen extends ConsumerStatefulWidget {
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
  ConsumerState<MultipleChoiceGameScreen> createState() => _MultipleChoiceGameScreenState();
}

class _MultipleChoiceGameScreenState extends ConsumerState<MultipleChoiceGameScreen> with SingleTickerProviderStateMixin {
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(isGameActiveProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    ref.read(isGameActiveProvider.notifier).state = false;
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

    // Pause for 700ms in comparison game to show touch feedback, 300ms for others
    final delayMs = widget.gameName == 'comparison' ? 700 : 300;
    Future.delayed(Duration(milliseconds: delayMs), () {
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
    return GameCountUpTimer.formatSeconds(seconds.round());
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
    
    // Deep bold red timer for prominent visibility
    final timerColor = Color.lerp(
      const Color(0xFFDC2626), 
      const Color(0xFF991B1B), 
      _timerController.value
    ) ?? const Color(0xFFDC2626);

    // Cách 1: Chạm trực tiếp vào hộp cho game So Sánh Trái Phải
    if (widget.gameName == 'comparison') {
      return _buildComparisonGameLayout(currentQuestion, progress, timerColor);
    }

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
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: GameSoundToggleButton(),
          ),
        ],
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
                  // Animated Circular Countdown Timer chuẩn hóa
                  GameCountdownTimer(
                    progress: 1.0 - _timerController.value,
                    remainingSeconds: (widget.timeLimitInSeconds - (_timerController.value * widget.timeLimitInSeconds).floor()),
                    totalSeconds: widget.timeLimitInSeconds,
                    customColor: timerColor,
                    size: 42,
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

              const SizedBox(height: 16),

              MiniGameRankBanner(
                gameName: widget.gameName,
                gameTitle: widget.gameTitle,
                currentScore: _score,
              ),

              // Detailed results table
              const SizedBox(height: 24),
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

  // ==========================================
  // CÁCH 1: GIAO DIỆN CHẠM TRỰC TIẾP VÀO HỘP
  // ==========================================

  Widget _buildComparisonGameLayout(
    GameQuestion question,
    double progress,
    Color timerColor,
  ) {
    final leftItems = question.comparisonLeft != null
        ? question.comparisonLeft!.characters.toList()
        : <String>[];
    final rightItems = question.comparisonRight != null
        ? question.comparisonRight!.characters.toList()
        : <String>[];

    final isSelectedLeft = _selectedChoiceIndex == 0;
    final isSelectedRight = _selectedChoiceIndex == 1;
    final isSelectedEqual = _selectedChoiceIndex == 2;

    final isCorrectLeft = question.correctAnswer == 'Bên trái';
    final isCorrectRight = question.correctAnswer == 'Bên phải';
    final isCorrectEqual = question.correctAnswer == 'Bằng nhau';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.gameTitle,
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => _showQuitConfirmation(),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: GameSoundToggleButton(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header progress & Timer Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Câu hỏi ${_currentQuestionIndex + 1}/${widget.questions.length}',
                    style: GoogleFonts.baloo2(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  GameCountdownTimer(
                    progress: 1.0 - _timerController.value,
                    remainingSeconds: (widget.timeLimitInSeconds -
                            (_timerController.value * widget.timeLimitInSeconds).floor())
                        .clamp(0, widget.timeLimitInSeconds),
                    totalSeconds: widget.timeLimitInSeconds,
                    customColor: timerColor,
                    size: 42,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Linear progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.border,
                  color: AppColors.primary,
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 16),

              // 3. Question Prompt Title
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.touch_app_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        question.prompt,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Main Comparison Interactive Stage (Hai hộp so sánh chạm trực tiếp + Nút "=" ở giữa)
              // Dùng IntrinsicHeight để khung của cái lớn nhất áp dụng luôn cho cả cái nhỏ nhất, 2 khung luôn ngang bằng nhau
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // --- HỘP BÊN TRÁI ---
                            Expanded(
                              child: _buildComparisonTouchBox(
                                index: 0,
                                label: 'Bên trái',
                                items: leftItems,
                                isSelected: isSelectedLeft,
                                isCorrectChoice: isCorrectLeft,
                                defaultBgColor: const Color(0xFFF0F7FF),
                                defaultBorderColor: const Color(0xFFBAE6FD),
                                themeColor: const Color(0xFF0284C7),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // --- NÚT BẰNG NHAU Ở GIỮA ---
                            _buildEqualButton(
                              isSelected: isSelectedEqual,
                              isCorrectChoice: isCorrectEqual,
                            ),

                            const SizedBox(width: 8),

                            // --- HỘP BÊN PHẢI ---
                            Expanded(
                              child: _buildComparisonTouchBox(
                                index: 1,
                                label: 'Bên phải',
                                items: rightItems,
                                isSelected: isSelectedRight,
                                isCorrectChoice: isCorrectRight,
                                defaultBgColor: const Color(0xFFFFF7ED),
                                defaultBorderColor: const Color(0xFFFED7AA),
                                themeColor: const Color(0xFFEA580C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 5. Gợi ý thao tác dưới chân
              Center(
                child: Text(
                  '👉 Chạm trực tiếp vào hộp bạn chọn',
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonTouchBox({
    required int index,
    required String label,
    required List<String> items,
    required bool isSelected,
    required bool isCorrectChoice,
    required Color defaultBgColor,
    required Color defaultBorderColor,
    required Color themeColor,
  }) {
    Widget? statusBadge;

    if (_hasAnswered) {
      if (isSelected) {
        if (isCorrectChoice) {
          statusBadge = const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24);
        } else {
          statusBadge = const Icon(Icons.cancel_rounded, color: AppColors.error, size: 24);
        }
      } else if (isCorrectChoice) {
        // Gợi ý đáp án đúng nếu bé chọn sai
        statusBadge = const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 22);
      }
    }

    return _GlowingTouchBox(
      isSelected: isSelected,
      isCorrectChoice: isCorrectChoice,
      hasAnswered: _hasAnswered,
      defaultBgColor: defaultBgColor,
      defaultBorderColor: defaultBorderColor,
      themeColor: themeColor,
      borderRadius: BorderRadius.circular(16),
      onTap: _hasAnswered ? null : () => _handleAnswer(index, label),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Tự động co giãn theo nội dung
          children: [
            // Top tag: label + status icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: defaultBorderColor.withValues(alpha: 0.8)),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.baloo2(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                ),
                if (statusBadge != null)
                  statusBadge
                else
                  const SizedBox(width: 22, height: 22),
              ],
            ),
            const SizedBox(height: 12),

            // Item grid: hiển thị trong Wrap gọn gàng
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 110),
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: items.map((char) {
                    return Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        char,
                        style: const TextStyle(fontSize: 26),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Hiển thị số lượng đếm khi đã trả lời
            AnimatedOpacity(
              opacity: _hasAnswered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: defaultBorderColor),
                ),
                child: Text(
                  '${items.length} vật phẩm',
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEqualButton({
    required bool isSelected,
    required bool isCorrectChoice,
  }) {
    Color btnColor = Colors.white;
    Color borderColor = const Color(0xFFE2E8F0);
    Color iconColor = const Color(0xFF475569);

    if (_hasAnswered) {
      if (isSelected) {
        if (isCorrectChoice) {
          btnColor = const Color(0xFFECFDF5);
          borderColor = AppColors.success;
          iconColor = AppColors.success;
        } else {
          btnColor = const Color(0xFFFFF1F2);
          borderColor = AppColors.error;
          iconColor = AppColors.error;
        }
      } else if (isCorrectChoice) {
        borderColor = AppColors.success;
        iconColor = AppColors.success;
      }
    }

    return Center(
      child: _GlowingTouchBox(
        isSelected: isSelected,
        isCorrectChoice: isCorrectChoice,
        hasAnswered: _hasAnswered,
        defaultBgColor: btnColor,
        defaultBorderColor: borderColor,
        themeColor: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        onTap: _hasAnswered ? null : () => _handleAnswer(2, 'Bằng nhau'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '=',
                style: GoogleFonts.baloo2(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: iconColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Bằng\nnhau',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget hộp tương tác có hiệu ứng viền sáng chạy quanh khung (Glow Sweep Border)
class _GlowingTouchBox extends StatefulWidget {
  final Widget child;
  final bool isSelected;
  final bool isCorrectChoice;
  final bool hasAnswered;
  final Color defaultBgColor;
  final Color defaultBorderColor;
  final Color themeColor;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const _GlowingTouchBox({
    required this.child,
    required this.isSelected,
    required this.isCorrectChoice,
    required this.hasAnswered,
    required this.defaultBgColor,
    required this.defaultBorderColor,
    required this.themeColor,
    required this.borderRadius,
    this.onTap,
  });

  @override
  State<_GlowingTouchBox> createState() => _GlowingTouchBoxState();
}

class _GlowingTouchBoxState extends State<_GlowingTouchBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.isSelected) {
      _glowController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _GlowingTouchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate = widget.isSelected || _isHovered;
    if (shouldAnimate && !_glowController.isAnimating) {
      _glowController.repeat();
    } else if (!shouldAnimate && _glowController.isAnimating) {
      _glowController.stop();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = widget.defaultBgColor;
    Color activeGlowColor = widget.themeColor;
    Color staticBorderColor = widget.defaultBorderColor;

    if (widget.hasAnswered) {
      if (widget.isSelected) {
        if (widget.isCorrectChoice) {
          bgColor = const Color(0xFFECFDF5);
          activeGlowColor = AppColors.success;
          staticBorderColor = AppColors.success;
        } else {
          bgColor = const Color(0xFFFFF1F2);
          activeGlowColor = AppColors.error;
          staticBorderColor = AppColors.error;
        }
      } else if (widget.isCorrectChoice) {
        staticBorderColor = AppColors.success;
        activeGlowColor = AppColors.success;
      }
    }

    final isGlowActive = _isHovered || widget.isSelected;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        if (!_glowController.isAnimating) _glowController.repeat();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        if (!widget.isSelected && _glowController.isAnimating) {
          _glowController.stop();
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, _) {
            return CustomPaint(
              painter: isGlowActive
                  ? _GlowSweepBorderPainter(
                      progress: _glowController.value,
                      glowColor: activeGlowColor,
                      borderRadius: widget.borderRadius,
                      borderWidth: 3.5,
                    )
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: widget.borderRadius,
                  border: isGlowActive
                      ? null // Vẽ bằng CustomPaint viền sáng chạy
                      : Border.all(
                          color: staticBorderColor,
                          width: widget.hasAnswered && widget.isCorrectChoice ? 3.0 : 2.0,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: isGlowActive
                          ? activeGlowColor.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.03),
                      blurRadius: isGlowActive ? 12 : 6,
                      spreadRadius: isGlowActive ? 2 : 0,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// CustomPainter vẽ viền ánh sáng chạy quanh khung chữ nhật
class _GlowSweepBorderPainter extends CustomPainter {
  final double progress;
  final Color glowColor;
  final BorderRadius borderRadius;
  final double borderWidth;

  _GlowSweepBorderPainter({
    required this.progress,
    required this.glowColor,
    required this.borderRadius,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    // 1. Viền mờ nền (Base border)
    final basePaint = Paint()
      ..color = glowColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(rrect, basePaint);

    // 2. Viền ánh sáng quét xoay quanh khung (Rotating Sweep Gradient)
    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth + 1.0
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: 2 * pi,
        transform: GradientRotation(progress * 2 * pi),
        colors: [
          Colors.transparent,
          glowColor.withValues(alpha: 0.2),
          glowColor,
          Colors.white,
          glowColor,
          glowColor.withValues(alpha: 0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.2, 0.45, 0.5, 0.55, 0.8, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _GlowSweepBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.borderRadius != borderRadius;
  }
}
