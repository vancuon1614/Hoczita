import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_theme.dart';
import '../../game/constants/game_content.dart';

class RandomFlashcardScreen extends StatefulWidget {
  const RandomFlashcardScreen({super.key});

  @override
  State<RandomFlashcardScreen> createState() => _RandomFlashcardScreenState();
}

class _RandomFlashcardScreenState extends State<RandomFlashcardScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final FlutterTts _flutterTts = FlutterTts();
  final Random _random = Random();
  
  final List<VocabItem> _cards = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _initTts();
    _generateMoreCards(10);
  }

  void _generateMoreCards(int count) {
    for (int i = 0; i < count; i++) {
      _cards.add(GameContent.allVocab[_random.nextInt(GameContent.allVocab.length)]);
    }
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
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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
          'Từ Vựng Không Giới Hạn',
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
            // Progress indicator (infinite feel)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Đã học: ${_currentIndex + 1} thẻ',
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
            const SizedBox(height: 32),

            // Flashcard Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    // Generate more cards when getting close to the end
                    if (_currentIndex >= _cards.length - 3) {
                      _generateMoreCards(10);
                    }
                  });
                },
                itemCount: _cards.length,
                itemBuilder: (context, index) {
                  final word = _cards[index];
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
                        front: _buildCardFront(word),
                        back: _buildCardBack(word),
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
                  IconButton(
                    onPressed: _nextCard,
                    icon: const Icon(Icons.arrow_circle_right_rounded),
                    iconSize: 48,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFront(VocabItem item) {
    final imageUrl = GameContent.getSupabaseImageUrl(item);
    
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.error,
                    size: 64,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardBack(VocabItem item) {
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
                      item.en,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.volume_up_rounded),
                      color: Colors.white,
                      iconSize: 32,
                      onPressed: () => _speak(item.en),
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
                item.vi,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 32,
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
