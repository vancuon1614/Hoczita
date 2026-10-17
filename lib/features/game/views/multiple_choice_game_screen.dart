import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../../core/widgets/pastel_toy_card.dart';
import '../../../core/providers/game_interaction_provider.dart';
import '../../../core/constants/game_code_registry.dart';
import '../../../core/services/game_score_sync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/game_question.dart';
import 'package:google_fonts/google_fonts.dart';
import 'common/mini_game_rank_banner.dart';

class MultipleChoiceGameScreen extends ConsumerStatefulWidget {
  final String gameName;
  final String gameTitle;
  final List<GameQuestion> questions;
  final int timeLimitInSeconds;
  final String level;

  const MultipleChoiceGameScreen({
    super.key,
    required this.gameName,
    required this.gameTitle,
    required this.questions,
    this.timeLimitInSeconds = 6,
    this.level = '1',
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
  late List<bool?> _questionResults;

  bool get _isEnglishGame {
    final cleanCode = GameCodeRegistry.getCodeFromInternalName(widget.gameName);
    return GameCodeRegistry.isEnglishGame(cleanCode) ||
        GameCodeRegistry.isEnglishGame(widget.gameName) ||
        cleanCode.startsWith('E');
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize user answers and question results lists
    _userAnswers = List.filled(widget.questions.length, null);
    _questionResults = List.filled(widget.questions.length, null);
    
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
        if (!_hasAnswered && !_isGameOver && mounted) {
          _handleAnswer(-1, '');
        }
      }
    });

    _gameStopwatch.start();
    _startQuestion();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(isGameActiveProvider.notifier).state = true;
      _precacheImages();
    });
  }

  void _precacheImages() {
    for (final q in widget.questions) {
      final asset = q.visualAsset;
      if (asset != null && mounted) {
        if (asset.startsWith('http://') || asset.startsWith('https://')) {
          precacheImage(CachedNetworkImageProvider(asset), context);
        } else if (asset.startsWith('assets/') || asset.startsWith('ImageFolder/')) {
          precacheImage(AssetImage(asset), context);
        }
      }
    }
  }

  @override
  void dispose() {
    ref.read(isGameActiveProvider.notifier).state = false;
    _timerController.dispose();
    TtsService.instance.stopAll();
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
      
      _questionResults[_currentQuestionIndex] = isCorrect;

      if (isCorrect) {
        _correctAnswersCount++;
      }
    });

    // Giảm thời gian chờ chuyển câu: 450ms cho comparison, 380ms cho các game khác
    final delayMs = widget.gameName == 'comparison' ? 450 : 380;
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

    final cleanGameCode = GameCodeRegistry.getCodeFromInternalName(widget.gameName);
    final cleanLevel = GameCodeRegistry.resolveLevel(widget.level);

    final authState = ref.read(authProvider);
    final memberName = authState.username ?? 'Học sinh';

    try {
      await GameScoreSyncService.instance.saveScoreParallel(
        gameCodeOrName: cleanGameCode,
        level: cleanLevel,
        score: _score,
        stars: _stars,
        durationSeconds: totalElapsedSeconds.round(),
        memberName: memberName,
      );
    } catch (e) {
      debugPrint('Error saving score in MultipleChoiceGameScreen: $e');
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
    final remaining = widget.questions.length - _currentQuestionIndex;
    final isNearEnd = remaining <= 3;
    
    final remainingSeconds = (widget.timeLimitInSeconds - (_timerController.value * widget.timeLimitInSeconds)).ceil().clamp(0, widget.timeLimitInSeconds);
    // 7s: 4s đầu màu xanh (7, 6, 5, 4s), mấy giây sau màu đỏ (3, 2, 1, 0s)
    final bool isWarning = remainingSeconds <= (widget.timeLimitInSeconds <= 6 ? 2 : 3);
    final timerColor = isWarning ? const Color(0xFFDC2626) : const Color(0xFF0284C7);
    final timerBg = isWarning ? const Color(0xFFFEF2F2) : Colors.white;
    final timerBorder = isWarning ? const Color(0xFFFECACA) : const Color(0xFFBAE6FD);

    // Cách 1: Chạm trực tiếp vào hộp cho game So Sánh Trái Phải
    if (widget.gameName == 'comparison') {
      return _buildComparisonGameLayout(
        currentQuestion,
        progress,
        timerColor,
        isNearEnd: isNearEnd,
        remaining: remaining,
        remainingSeconds: remainingSeconds,
        timerBg: timerBg,
        timerBorder: timerBorder,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.gameTitle,
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00375A),
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => _showQuitConfirmation(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GameSoundToggleButton(
              padding: EdgeInsets.zero,
              onToggled: (enabled) {
                if (enabled) {
                  TtsService.instance.speakVietnamese(currentQuestion.prompt, forced: true);
                }
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Progress & Timer Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isNearEnd ? const Color(0xFFFFFBEB) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isNearEnd ? const Color(0xFFFDE68A) : const Color(0xFFBAE6FD),
                      ),
                    ),
                    child: isNearEnd
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 15),
                              const SizedBox(width: 5),
                              Text(
                                _isEnglishGame
                                    ? 'Question ${_currentQuestionIndex + 1}/${widget.questions.length} • Final Sprint'
                                    : 'Câu ${_currentQuestionIndex + 1}/${widget.questions.length} • Về đích',
                                style: GoogleFonts.baloo2(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _isEnglishGame
                                ? 'Question ${_currentQuestionIndex + 1}/${widget.questions.length}'
                                : 'Câu ${_currentQuestionIndex + 1}/${widget.questions.length}',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                  ),

                  // Animated Countdown Timer Pill (Format 00:00, cố định khung không thụt ra/vào)
                  GameCountUpTimer(
                    elapsedSeconds: remainingSeconds,
                    margin: EdgeInsets.zero,
                    bgColor: timerBg,
                    borderColor: timerBorder,
                    textColor: timerColor,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Thẻ Bé Ong Hội Thoại & Thanh Tiến Trình (LUÔN HIỆN XUYÊN SUỐT GAME)
              _buildMascotCard(remaining),
              const SizedBox(height: 10),

              // 3. Question/Prompt Arena (Card-in-Card Style as in screentinhnhanh)
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFCCE3F5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00629D).withValues(alpha: 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Tag Thử thách về đích (kèm icon 📢 duy nhất ở 3 câu cuối)
                      if (isNearEnd) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('📢', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 6),
                              Text(
                                _isEnglishGame
                                    ? 'Final Sprint Challenge with Bee'
                                    : 'Thử thách về đích cùng Bé Ong',
                                style: GoogleFonts.baloo2(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Khung câu hỏi phụ bên trong (Card-in-Card nền xanh nhạt Color(0xFFF0F5FA))
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F5FA),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Center(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    currentQuestion.prompt,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.baloo2(
                                      fontSize: currentQuestion.prompt.length > 60
                                          ? 17.5
                                          : (currentQuestion.prompt.length > 30 ? 20.5 : 24.0),
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF00588A),
                                      height: 1.35,
                                    ),
                                  ),
                                  if (currentQuestion.comparisonLeft != null ||
                                      (currentQuestion.visualAsset != null &&
                                          currentQuestion.visualAsset!.isNotEmpty)) ...[
                                    const SizedBox(height: 10),
                                    _buildQuestionPrompt(currentQuestion),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 4. Answer options Grid (Pastel Toy Card Style)
              Expanded(
                flex: 3,
                child: _buildChoicesGrid(currentQuestion),
              ),

              // Lược bỏ hoàn toàn thanh tiến trình đáy cũ
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualAsset(
    String asset, {
    double? size,
    double? height,
    double? width,
    double fontSize = 54.0,
    double borderRadius = 20.0,
  }) {
    final double targetWidth = size ?? width ?? height ?? 136.0;
    final double targetHeight = size ?? height ?? width ?? 136.0;

    if (asset.startsWith('http://') || asset.startsWith('https://')) {
      return Container(
        width: targetWidth,
        height: targetHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: asset,
          width: targetWidth,
          height: targetHeight,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 150),
          fadeOutDuration: const Duration(milliseconds: 150),
          memCacheWidth: 400,
          memCacheHeight: 400,
          imageBuilder: (context, imageProvider) => Container(
            width: targetWidth,
            height: targetHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
          placeholder: (context, url) => Container(
            width: targetWidth,
            height: targetHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: targetWidth,
            height: targetHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: const Center(
              child: Icon(
                Icons.broken_image_rounded,
                color: AppColors.error,
                size: 40,
              ),
            ),
          ),
        ),
      );
    } else if (asset.startsWith('assets/') || asset.startsWith('ImageFolder/')) {
      return Container(
        width: targetWidth,
        height: targetHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          asset,
          width: targetWidth,
          height: targetHeight,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: targetWidth,
            height: targetHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: const Center(
              child: Icon(
                Icons.broken_image_rounded,
                color: AppColors.error,
                size: 40,
              ),
            ),
          ),
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
                  child: _buildVisualAsset(question.comparisonLeft!, size: 100.0, fontSize: 46),
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
                  child: _buildVisualAsset(question.comparisonRight!, size: 100.0, fontSize: 46),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Default question type (image/emoji/math formula)
    if (question.visualAsset == null) return const SizedBox.shrink();

    final asset = question.visualAsset!;
    final bool isImage = asset.startsWith('http://') ||
        asset.startsWith('https://') ||
        asset.startsWith('assets/') ||
        asset.startsWith('ImageFolder/');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isImage)
          // Thống nhất hình vuông góc bo tròn (140x140, borderRadius 20), không dùng khung
          _buildVisualAsset(
            asset,
            size: 140.0,
            borderRadius: 20.0,
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: _buildVisualAsset(asset, size: 120.0, fontSize: 50),
          ),
      ],
    );
  }

  double _calculateUniformChoiceFontSize(List<String> choices) {
    if (choices.isEmpty) return 22.0;
    final maxLen = choices.fold<int>(0, (max, c) => c.length > max ? c.length : max);
    if (maxLen > 18) {
      return 16.5;
    } else if (maxLen > 14) {
      return 18.0;
    } else if (maxLen > 10) {
      return 19.5;
    } else if (maxLen > 5) {
      return 22.0;
    } else if (maxLen > 2) {
      return 24.0;
    } else {
      return 28.0;
    }
  }

  Widget _buildChoicesGrid(GameQuestion question) {
    final List<String> allChoices;
    if (widget.gameName == 'comparison') {
      allChoices = const ['Bên trái', 'Bên phải', 'Bằng nhau'];
    } else {
      allChoices = question.choices;
    }
    final uniformFontSize = _calculateUniformChoiceFontSize(allChoices);

    if (widget.gameName == 'comparison') {
      final choices = allChoices;
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildChoiceButton(0, question, customValue: choices[0], fontSize: uniformFontSize)),
                const SizedBox(width: 16),
                Expanded(child: _buildChoiceButton(1, question, customValue: choices[1], fontSize: uniformFontSize)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Spacer(),
                      Expanded(flex: 2, child: _buildChoiceButton(2, question, customValue: choices[2], fontSize: uniformFontSize)),
                      const Spacer(),
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
                Expanded(child: _buildChoiceButton(0, question, fontSize: uniformFontSize)),
                const SizedBox(width: 16),
                Expanded(child: _buildChoiceButton(1, question, fontSize: uniformFontSize)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildChoiceButton(2, question, fontSize: uniformFontSize)),
                const SizedBox(width: 16),
                Expanded(child: _buildChoiceButton(3, question, fontSize: uniformFontSize)),
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
                Expanded(child: _buildChoiceButton(0, question, fontSize: uniformFontSize)),
                const SizedBox(width: 16),
                Expanded(child: _buildChoiceButton(1, question, fontSize: uniformFontSize)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Spacer(),
                      Expanded(flex: 2, child: _buildChoiceButton(2, question, fontSize: uniformFontSize)),
                      const Spacer(),
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
          Expanded(child: _buildChoiceButton(0, question, fontSize: uniformFontSize)),
          const SizedBox(width: 16),
          Expanded(child: _buildChoiceButton(1, question, fontSize: uniformFontSize)),
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
                  Expanded(child: _buildChoiceButton(index, question, fontSize: uniformFontSize)),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildChoiceButton(
    int index,
    GameQuestion question, {
    String? customValue,
    double? fontSize,
  }) {
    final choiceValue = customValue ?? question.choices[index];
    final isSelected = (_selectedChoiceIndex == index);

    final labels = ['(A)', '(B)', '(C)', '(D)'];
    final colors = PastelToyCardColor.standardFour;

    return PastelToyCard(
      label: labels[index % 4],
      title: choiceValue,
      fontSize: fontSize,
      colorConfig: colors[index % 4],
      isSelected: isSelected,
      isCorrect: null, // Tắt tự động chọn/tiết lộ đáp án khi chơi, xem ở report cuối cùng
      height: double.infinity,
      onTap: _hasAnswered ? null : () => _handleAnswer(index, choiceValue),
    );
  }

  String _getMascotDialogue(int remaining) {
    if (_isEnglishGame) {
      if (remaining == 1) {
        return 'Keep going! Only 1 question left! 🐝';
      } else if (remaining == 2) {
        return 'Keep going! Only 2 questions left! 🐝';
      } else if (remaining == 3) {
        return 'Keep going! Only 3 questions left! 🐝';
      }
      return 'Let\'s solve fast with Bee and bring sweet honey home!';
    }

    if (remaining == 1) {
      return 'Cố lên! Chỉ còn 1 câu nữa thôi bé ơi! 🐝';
    } else if (remaining == 2) {
      return 'Cố lên! Còn 2 câu nữa thôi bé ơi! 🐝';
    } else if (remaining == 3) {
      return 'Cố lên! Còn 3 câu nữa thôi bé ơi! 🐝';
    }
    return 'Cùng Bé Ong tính thật nhanh để mang mật ngọt về tổ nào!';
  }

  Widget _buildMascotCard(int remaining) {
    final total = widget.questions.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar Bé Ong (huy hiệu ngôi sao xanh chỉ xuất hiện khi còn 3 câu cuối)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withValues(alpha: 0.15),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('🐝', style: TextStyle(fontSize: 22)),
                  ),
                  if (remaining <= 3)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.star_rounded, size: 9, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),

              // Tên Mascot + Số câu + Câu thoại
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isEnglishGame ? 'Smart Bee' : 'Bé Ong Học Đi',
                          style: GoogleFonts.baloo2(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        Text(
                          _isEnglishGame
                              ? 'Question ${_currentQuestionIndex + 1} / $total'
                              : 'Câu ${_currentQuestionIndex + 1} / $total',
                          style: GoogleFonts.baloo2(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _getMascotDialogue(remaining),
                      style: GoogleFonts.baloo2(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),

          // Thanh tiến trình phân đoạn
          Row(
            children: List.generate(total, (i) {
              final isDone = i < _currentQuestionIndex;
              final isCurrent = i == _currentQuestionIndex;
              Color segColor = const Color(0xFFFDE68A);
              if (isDone) {
                segColor = const Color(0xFF047857); // xanh lá đậm như hình screentinhnhanh
              } else if (isCurrent) {
                segColor = const Color(0xFFF59E0B); // vàng amber câu hiện tại
              }
              return Expanded(
                child: Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: segColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showQuitConfirmation() {
    _timerController.stop();
    final isEng = _isEnglishGame;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEng ? 'Quit Game?' : 'Thoát Trò Chơi?'),
        content: Text(isEng
            ? 'Your current game progress and score will not be saved.'
            : 'Tiến trình chơi và điểm số của lượt này sẽ không được lưu lại.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              _timerController.forward(); // Tiếp tục đếm ngược
            },
            child: Text(isEng ? 'Keep Playing' : 'Chơi tiếp'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              Navigator.pop(context); // Thoát game
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(isEng ? 'Quit' : 'Thoát'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryView() {
    final stars = _stars;
    final isEng = _isEnglishGame;

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
              const SizedBox(height: 12),
              
              Text(
                stars > 0
                    ? (isEng ? 'Awesome! 🎉' : 'Tuyệt Vời! 🎉')
                    : (isEng ? 'Keep Trying! 💪' : 'Lần Sau Cố Gắng Hơn Nhé!'),
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              
              Text(
                isEng
                    ? 'You answered $_correctAnswersCount/${widget.questions.length} questions correctly in $_elapsedTimeString.'
                    : 'Bạn đã trả lời đúng $_correctAnswersCount/${widget.questions.length} câu đố trong $_elapsedTimeString.',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 12,
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
                          Text(
                            isEng ? 'Time' : 'Thời gian',
                            style: GoogleFonts.baloo2(fontSize: 10, color: AppColors.primary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _elapsedTimeString,
                            style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
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
                          Text(
                            isEng ? 'Score Earned' : 'Điểm cộng',
                            style: GoogleFonts.baloo2(fontSize: 10, color: AppColors.success),
                          ),
                          const SizedBox(height: 2),
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
                gameTitle: isEng ? GameCodeRegistry.getEnglishDisplayName(widget.gameName) : widget.gameTitle,
                currentScore: _score,
                isEnglish: isEng,
              ),

              // Detailed results table
              const SizedBox(height: 24),
              Text(
                isEng ? 'Result Details 📊' : 'Chi Tiết Kết Quả 📊',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
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
                      padding: EdgeInsets.zero,
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
                        : Text(
                            isEng ? 'Back to Menu' : 'Quay lại danh mục',
                            style: GoogleFonts.baloo2(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              height: 1.2,
                            ),
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

    final isEng = _isEnglishGame;

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
                      isEng ? 'Question ${index + 1}' : 'Câu hỏi ${index + 1}',
                      style: GoogleFonts.baloo2(
                        fontSize: 16,
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
                        _buildVisualAsset(question.visualAsset!, height: 80.0, fontSize: 34),
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
                                child: _buildVisualAsset(question.comparisonLeft!, height: 60.0, fontSize: 30),
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
                                child: _buildVisualAsset(question.comparisonRight!, height: 60.0, fontSize: 30),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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
                const SizedBox(height: 16),
                Text(
                  isEng ? 'Options:' : 'Các đáp án:',
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
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
                  const SizedBox(height: 12),
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
                        const Icon(Icons.timer_outlined, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          isEng ? 'Time ran out! ⏳' : 'Đã hết thời gian chọn đáp án! ⏳',
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
    Color timerColor, {
    required bool isNearEnd,
    required int remaining,
    required int remainingSeconds,
    required Color timerBg,
    required Color timerBorder,
  }) {
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => _showQuitConfirmation(),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: GameSoundToggleButton(padding: EdgeInsets.zero),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isNearEnd ? const Color(0xFFFFFBEB) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isNearEnd ? const Color(0xFFFDE68A) : const Color(0xFFBAE6FD),
                      ),
                    ),
                    child: isNearEnd
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 15),
                              const SizedBox(width: 5),
                              Text(
                                _isEnglishGame
                                    ? 'Question ${_currentQuestionIndex + 1}/${widget.questions.length} • Final Sprint'
                                    : 'Câu ${_currentQuestionIndex + 1}/${widget.questions.length} • Về đích',
                                style: GoogleFonts.baloo2(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _isEnglishGame
                                ? 'Question ${_currentQuestionIndex + 1}/${widget.questions.length}'
                                : 'Câu ${_currentQuestionIndex + 1}/${widget.questions.length}',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                  ),
                  GameCountUpTimer(
                    elapsedSeconds: remainingSeconds,
                    margin: EdgeInsets.zero,
                    bgColor: timerBg,
                    borderColor: timerBorder,
                    textColor: timerColor,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Thẻ Bé Ong Hội Thoại & Thanh Tiến Trình (LUÔN HIỆN XUYÊN SUỐT GAME)
              _buildMascotCard(remaining),
              const SizedBox(height: 10),
              const SizedBox(height: 14),

              // 3. Main Centered Interactive Area (Prompt + Comparison Boxes + Bottom Hint)
              // Đưa toàn bộ vào khối căn giữa để khoảng cách trên (từ progress bar) và khoảng cách dưới (đáy màn hình) cân đối tuyệt đối
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tag Thử thách về đích chỉ xuất hiện khi còn 3 câu cuối
                          if (isNearEnd) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('📢', style: TextStyle(fontSize: 12)),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isEnglishGame
                                        ? 'Final Sprint Challenge with Bee'
                                        : 'Thử thách về đích cùng Bé Ong',
                                    style: GoogleFonts.baloo2(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Khung câu hỏi dạng Card-in-Card nền Color(0xFFF0F5FA), chữ in đậm #00588A
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F5FA),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFCCE3F5), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00629D).withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              question.prompt,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.baloo2(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF00588A),
                                height: 1.3,
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Hai hộp so sánh chạm trực tiếp + Nút "=" ở giữa
                          // Dùng IntrinsicHeight để khung của cái lớn nhất áp dụng luôn cho cả cái nhỏ nhất
                          IntrinsicHeight(
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

                          const SizedBox(height: 16),

                          // Gợi ý thao tác dưới chân
                          Text(
                            '👉 Chạm trực tiếp vào hộp bạn chọn',
                            style: GoogleFonts.baloo2(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
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
    // Tắt tự động hiển thị đáp án đúng/sai trong lúc chơi, chỉ hiển thị ở report cuối cùng
    return _GlowingTouchBox(
      isSelected: isSelected,
      isCorrectChoice: false,
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
            // Top tag: label
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
    Color btnColor = isSelected ? const Color(0xFFEFF6FF) : Colors.white;
    Color borderColor = isSelected ? AppColors.primary : const Color(0xFFE2E8F0);
    Color iconColor = isSelected ? AppColors.primary : const Color(0xFF475569);

    return Center(
      child: _GlowingTouchBox(
        isSelected: isSelected,
        isCorrectChoice: false,
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

    if (widget.hasAnswered && widget.isSelected) {
      activeGlowColor = widget.themeColor;
      staticBorderColor = widget.themeColor;
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
                          width: widget.hasAnswered && widget.isSelected ? 2.5 : 2.0,
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

/// CustomPainter vẽ viền ánh sáng quét xoay quanh khung chữ nhật
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
