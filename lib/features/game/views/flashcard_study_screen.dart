import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/theme/app_theme.dart';
import '../models/game_question.dart';
import 'multiple_choice_game_screen.dart';

class FlashcardStudyScreen extends StatefulWidget {
  final String gameName;
  final String gameTitle;
  final List<GameQuestion> questions;

  const FlashcardStudyScreen({
    super.key,
    required this.gameName,
    required this.gameTitle,
    required this.questions,
  });

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _nextCard() {
    if (_currentIndex < widget.questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _startChallenge() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MultipleChoiceGameScreen(
          gameName: widget.gameName,
          gameTitle: widget.gameTitle,
          questions: widget.questions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Học Từ Vựng',
          style: GoogleFonts.baloo2(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Thẻ ${_currentIndex + 1}/${widget.questions.length}',
                    style: GoogleFonts.baloo2(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        'Chạm để lật thẻ',
                        style: GoogleFonts.baloo2(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Linear Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / widget.questions.length,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Flashcard Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemCount: widget.questions.length,
                itemBuilder: (context, index) {
                  final word = widget.questions[index];
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 1.0;
                      if (_pageController.position.haveDimensions) {
                        value = _pageController.page! - index;
                        value = (1 - (value.abs() * 0.2)).clamp(0.8, 1.0);
                      }
                      return Center(
                        child: Transform.scale(
                          scale: value,
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                      child: FlipCard(
                        direction: FlipDirection.HORIZONTAL,
                        front: _buildCardFront(_extractEnglishWord(word.prompt)),
                        back: _buildCardBack(_extractEnglishWord(word.prompt), word.correctAnswer),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Navigation Controls
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _currentIndex > 0 ? _previousCard : null,
                    icon: const Icon(Icons.arrow_circle_left_rounded),
                    iconSize: 48,
                    color: _currentIndex > 0 ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
                  ),
                  
                  if (_currentIndex == widget.questions.length - 1)
                    ElevatedButton.icon(
                      onPressed: _startChallenge,
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                      label: Text(
                        'Bắt Đầu Thi',
                        style: GoogleFonts.baloo2(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 4,
                      ),
                    )
                  else
                    const SizedBox(width: 150), // placeholder to keep alignment
                    
                  IconButton(
                    onPressed: _currentIndex < widget.questions.length - 1 ? _nextCard : null,
                    icon: const Icon(Icons.arrow_circle_right_rounded),
                    iconSize: 48,
                    color: _currentIndex < widget.questions.length - 1 ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFront(String word) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            word,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  String _extractEnglishWord(String prompt) {
    final match = RegExp(r'Từ "(.*?)"').firstMatch(prompt);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    return prompt;
  }

  Widget _buildCardBack(String word, String meaning) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      word,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.volume_up_rounded),
                      color: Colors.white,
                      onPressed: () => _speak(word),
                      tooltip: 'Nghe phát âm',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                height: 2,
                width: 80,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 24),
              Text(
                meaning,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
