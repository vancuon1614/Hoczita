import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../../../core/providers/game_interaction_provider.dart';
import '../constants/game_content.dart';
import 'package:google_fonts/google_fonts.dart';
import 'common/mini_game_rank_banner.dart';

class MemoryCard {
  final int id;
  final int pairId;
  final String text;
  bool isFlipped;
  bool isMatched;

  MemoryCard({
    required this.id,
    required this.pairId,
    required this.text,
    this.isFlipped = false,
    this.isMatched = false,
  });
}

class MemoryMatchGameScreen extends ConsumerStatefulWidget {
  const MemoryMatchGameScreen({super.key});

  @override
  ConsumerState<MemoryMatchGameScreen> createState() => _MemoryMatchGameScreenState();
}

class _MemoryMatchGameScreenState extends ConsumerState<MemoryMatchGameScreen> {
  late List<MemoryCard> _cards;
  int? _firstCardIndex;
  int? _secondCardIndex;
  bool _isBusy = false;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  int _secondsElapsed = 0;
  String _elapsedTimeString = '00:00';

  int _matchedPairsCount = 0;
  int _score = 0;
  bool _isGameOver = false;
  bool _isSavingScore = false;

  @override
  void initState() {
    super.initState();
    _setupGame();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(isGameActiveProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    ref.read(isGameActiveProvider.notifier).state = false;
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _setupGame() {
    _matchedPairsCount = 0;
    _score = 0;
    _firstCardIndex = null;
    _secondCardIndex = null;
    _isGameOver = false;
    _isSavingScore = false;
    
    // Pick 8 random pairs from the global 120 vocabulary pool
    final vocabPool = GameContent.allVocab.map((item) => {'en': item.en, 'vi': item.vi}).toList();
    vocabPool.shuffle();
    final selectedPairs = vocabPool.take(8).toList();

    final List<MemoryCard> cardList = [];
    for (int i = 0; i < selectedPairs.length; i++) {
      final pair = selectedPairs[i];
      // English card
      cardList.add(MemoryCard(
        id: i * 2,
        pairId: i,
        text: pair['en']!,
      ));
      // Vietnamese card
      cardList.add(MemoryCard(
        id: (i * 2) + 1,
        pairId: i,
        text: pair['vi']!,
      ));
    }

    cardList.shuffle();
    _cards = cardList;

    _secondsElapsed = 0;
    _elapsedTimeString = '00:00';
    _stopwatch.reset();
    _stopwatch.start();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_stopwatch.isRunning) {
        setState(() {
          _secondsElapsed = _stopwatch.elapsed.inSeconds;
          _elapsedTimeString = GameCountUpTimer.formatSeconds(_secondsElapsed);
        });
      }
    });
  }

  void _handleCardTap(int index) {
    if (_isBusy || _cards[index].isFlipped || _cards[index].isMatched) return;

    setState(() {
      _cards[index].isFlipped = true;
    });

    if (_firstCardIndex == null) {
      _firstCardIndex = index;
    } else {
      _secondCardIndex = index;
      _checkMatch();
    }
  }

  void _checkMatch() {
    _isBusy = true;
    final firstCard = _cards[_firstCardIndex!];
    final secondCard = _cards[_secondCardIndex!];

    if (firstCard.pairId == secondCard.pairId) {
      // It's a match!
      setState(() {
        firstCard.isMatched = true;
        secondCard.isMatched = true;
        _matchedPairsCount++;
        _score += 10;
        
        _firstCardIndex = null;
        _secondCardIndex = null;
        _isBusy = false;
      });

      if (_matchedPairsCount == 8) {
        _endGameAndSaveScore();
      }
    } else {
      // Not a match, flip back after 1 second
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(() {
          firstCard.isFlipped = false;
          secondCard.isFlipped = false;
          _firstCardIndex = null;
          _secondCardIndex = null;
          _isBusy = false;
        });
      });
    }
  }

  void _endGameAndSaveScore() async {
    _stopwatch.stop();
    _timer?.cancel();
    _secondsElapsed = _stopwatch.elapsed.inSeconds;
    _elapsedTimeString = GameCountUpTimer.formatSeconds(_secondsElapsed);

    final elapsedSeconds = _secondsElapsed;
    int stars = 0;
    if (elapsedSeconds < 25) {
      stars = 3;
    } else if (elapsedSeconds < 45) {
      stars = 2;
    } else {
      stars = 1;
    }

    int finalScore = 0;
    if (stars == 3) {
      finalScore = 30;
    } else if (stars == 2) {
      finalScore = 20;
    } else if (stars == 1) {
      finalScore = 10;
    }

    setState(() {
      _score = finalScore;
      _isGameOver = true;
      _isSavingScore = true;
    });

    try {
      await SupabaseService.instance.saveScore(
        gameName: 'memory_match',
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Memory Match 🇬🇧',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded),
          onPressed: () => _showQuitConfirmation(),
        ),
        actions: [
          const GameSoundToggleButton(),
          GameCountUpTimer(elapsedSeconds: _secondsElapsed),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Lật ghép các cặp từ tiếng Anh tương ứng với nghĩa tiếng Việt:',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 32),
                // 4x4 Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8, // Rectangular card feel
                  ),
                  itemCount: 16,
                  itemBuilder: (context, index) {
                    return _buildCardItem(index);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardItem(int index) {
    final card = _cards[index];
    final showContent = card.isFlipped || card.isMatched;

    return GestureDetector(
      onTap: () => _handleCardTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: showContent 
              ? (card.isMatched ? AppColors.success.withValues(alpha: 0.12) : Colors.white)
              : AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: showContent 
                ? (card.isMatched ? AppColors.success : AppColors.primary)
                : Colors.white.withValues(alpha: 0.2), 
            width: 2.5
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: showContent
            ? Text(
                card.text,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: card.text.length > 8 ? 12 : 14,
                  fontWeight: FontWeight.bold,
                  color: card.isMatched ? AppColors.success : AppColors.primary,
                ),
              )
            : Icon(
                Icons.help_outline_rounded,
                color: Colors.white,
                size: 28,
              ),
      ),
    );
  }

  void _showQuitConfirmation() {
    _stopwatch.stop();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Thoát Trò Chơi?'),
        content: Text('Tiến trình chơi hiện tại của bạn sẽ không được lưu lại.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              _stopwatch.start(); // Tiếp tục bấm giờ
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
    final elapsedSeconds = _stopwatch.elapsedMilliseconds / 1000;
    int stars = 0;
    if (elapsedSeconds < 25) {
      stars = 3;
    } else if (elapsedSeconds < 45) {
      stars = 2;
    } else {
      stars = 1;
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Trophy Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF9E6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.amber,
                    size: 80,
                  ),
                ),
              ),
              SizedBox(height: 24),
              
              Text(
                'Xuất Sắc! 🎉',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              
              Text(
                'Bạn đã hoàn thành ghép 8 cặp từ trong $_elapsedTimeString.',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 24),

              // Stars Display
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
              SizedBox(height: 24),

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
                          Text(
                            'Thời gian',
                            style: GoogleFonts.baloo2(fontSize: 11, color: AppColors.primary),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _elapsedTimeString,
                            style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Điểm cộng',
                            style: GoogleFonts.baloo2(fontSize: 11, color: AppColors.success),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '+$_score',
                            style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              MiniGameRankBanner(
                gameName: 'memory_match',
                gameTitle: 'Memory Match',
                currentScore: _score,
              ),

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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
