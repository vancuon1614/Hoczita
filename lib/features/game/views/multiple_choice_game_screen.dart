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
  int _stars = 0;
  
  int? _selectedChoiceIndex;
  bool _hasAnswered = false;
  bool _isGameOver = false;
  bool _isSavingScore = false;
  late List<String?> _userAnswers;
  bool _isPrecached = false;
  bool _isCurrentImageReady = true;

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

    if (widget.gameName == 'picture_guess') {
      _isPrecached = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _precacheImages();
      });
    } else {
      _isPrecached = true;
      _gameStopwatch.start();
      _startQuestion();
    }
  }

  Future<void> _precacheImages() async {
    try {
      // Chỉ tải trước 2 ảnh đầu tiên để vào game lập tức (< 0.3 giây)
      for (int i = 0; i < 2 && i < widget.questions.length; i++) {
        final q = widget.questions[i];
        if (q.visualAsset != null && q.visualAsset!.startsWith('http')) {
          await precacheImage(
            CachedNetworkImageProvider(q.visualAsset!),
            context,
          );
        }
      }
    } catch (e) {
      debugPrint('Error precaching initial images: $e');
    }
    if (mounted) {
      setState(() {
        _isPrecached = true;
      });
      _gameStopwatch.start();
      _startQuestion();
    }
  }

  void _precacheNextQuestion() {
    // Tải trước gối đầu câu tiếp theo (cách 2 câu) trong nền
    final nextIndex = _currentQuestionIndex + 2;
    if (nextIndex < widget.questions.length) {
      final nextQuestion = widget.questions[nextIndex];
      if (nextQuestion.visualAsset != null && nextQuestion.visualAsset!.startsWith('http')) {
        precacheImage(
          CachedNetworkImageProvider(nextQuestion.visualAsset!),
          context,
        ).catchError((e) {
          debugPrint('Background prefetch failed for index $nextIndex: $e');
        });
      }
    }
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  void _startQuestion() async {
    setState(() {
      _selectedChoiceIndex = null;
      _hasAnswered = false;
      _isCurrentImageReady = false;
    });

    // Kích hoạt tải trước gối đầu trong nền
    _precacheNextQuestion();

    final currentQuestion = widget.questions[_currentQuestionIndex];
    if (currentQuestion.visualAsset != null && currentQuestion.visualAsset!.startsWith('http')) {
      // Đợi ảnh của câu hiện tại tải xong (sẽ phản hồi ngay lập tức nếu đã được tải trước gối đầu thành công)
      try {
        await precacheImage(
          CachedNetworkImageProvider(currentQuestion.visualAsset!),
          context,
        );
      } catch (e) {
        debugPrint('Failed to cache current question image: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isCurrentImageReady = true;
      });
      _timerController.forward(from: 0.0);
    }
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

    final totalQuestions = widget.questions.length;
    final accuracyPct = totalQuestions > 0 ? _correctAnswersCount / totalQuestions : 0.0;

    if (accuracyPct == 1.0) {
      _stars = 3;
    } else if (accuracyPct >= 0.7) {
      _stars = 2;
    } else if (accuracyPct >= 0.4) {
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
    if (!_isPrecached) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.gameTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 4,
              ),
              SizedBox(height: 24),
              Text(
                'Đang chuẩn bị hình ảnh câu hỏi...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Hình ảnh đang được tải trước để chơi mượt mà nhất',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
        onTap: (_hasAnswered || !_isCurrentImageReady) ? null : () => _handleAnswer(index, choiceValue),
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
    final stars = _stars;

    return Scaffold(
      body: SafeArea(
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
              const SizedBox(height: 12),
              
              Text(
                stars > 0 ? 'Tuyệt Vời! 🎉' : 'Cố Gắng Lên Bé Ơi!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              
              Text(
                'Bé đã trả lời đúng $_correctAnswersCount/${widget.questions.length} câu đố trong $_elapsedTimeString.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

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
              const SizedBox(height: 16),

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
                          const Text(
                            'Thời gian',
                            style: TextStyle(fontSize: 12, color: AppColors.primary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _elapsedTimeString,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8F5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Điểm cộng',
                            style: TextStyle(fontSize: 12, color: AppColors.success),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+$_score',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Detailed results table
              const SizedBox(height: 40),
              const Text(
                'Chi Tiết Kết Quả 📊',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildResultsTable(),
              const SizedBox(height: 28),
              
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
                ),
              ),
            ],
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
                  style: TextStyle(
                    fontSize: 16,
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                        _buildVisualAsset(question.visualAsset!, height: 80.0, fontSize: 36.0),
                        const SizedBox(height: 12),
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
                                child: _buildVisualAsset(question.comparisonLeft!, height: 60.0, fontSize: 32.0),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                alignment: Alignment.center,
                                child: _buildVisualAsset(question.comparisonRight!, height: 60.0, fontSize: 32.0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        question.prompt,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Các đáp án:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
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
                      suffixIcon = const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20);
                    } else if (isUserSelection) {
                      itemBgColor = AppColors.error.withValues(alpha: 0.12);
                      itemBorderColor = AppColors.error;
                      itemTextColor = AppColors.error;
                      suffixIcon = const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20);
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
                  }).toList(),
                ),
                if (userAnswer == null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer_outlined, color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Bé đã không chọn đáp án (Hết giờ ⏳)',
                          style: TextStyle(
                            fontSize: 12,
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
