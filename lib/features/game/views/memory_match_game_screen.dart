import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../../../core/providers/game_interaction_provider.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/scrmai_api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../constants/game_content.dart';
import 'package:google_fonts/google_fonts.dart';
import 'common/mini_game_rank_banner.dart';

class MemoryCard {
  final int id;
  final int pairId;
  final String text;
  final bool isEnglish;
  bool isFlipped;
  bool isMatched;

  MemoryCard({
    required this.id,
    required this.pairId,
    required this.text,
    this.isEnglish = true,
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
        isEnglish: true,
      ));
      // Vietnamese card
      cardList.add(MemoryCard(
        id: (i * 2) + 1,
        pairId: i,
        text: pair['vi']!,
        isEnglish: false,
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

    final card = _cards[index];
    setState(() {
      card.isFlipped = true;
    });

    // Phát âm từ vựng tương ứng khi lật
    if (card.isEnglish) {
      TtsService.instance.speakEnglish(card.text, forced: true);
    } else {
      TtsService.instance.speakVietnamese(card.text, forced: true);
    }

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

    // Ưu tiên 1: NKS SCRMAI API
    final authState = ref.read(authProvider);
    final memberName = authState.username ?? 'Học sinh';

    try {
      await ScrmaiApiService.instance.submitScore(
        member: memberName,
        game: 'L02',
        level: '1',
        score: finalScore,
      );
    } catch (e) {
      debugPrint('Error syncing score to NKS SCRMAI: $e');
    }

    // Ưu tiên 2: Supabase
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
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Memory Match 🇬🇧',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => _showQuitConfirmation(),
        ),
        actions: [
          const GameSoundToggleButton(),
          GameCountUpTimer(elapsedSeconds: _secondsElapsed),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Status & Instruction Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '8 CẶP TỪ VỰNG',
                            style: GoogleFonts.baloo2(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0369A1),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded, color: Color(0xFF16A34A), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Đã ghép: $_matchedPairsCount / 8',
                                style: GoogleFonts.baloo2(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF003D1D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chạm lật thẻ kẹo thạch 3D để ghép các cặp từ Tiếng Anh và Tiếng Việt tương ứng!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 4x4 Grid of Cards
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.76, // Tỉ lệ thẻ chữ nhật dọc thanh thoát
                ),
                itemCount: 16,
                itemBuilder: (context, index) {
                  return _buildCardItem(index);
                },
              ),

              const SizedBox(height: 16),
            ],
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: showContent
            ? _buildFacedUpCard(card)
            : _buildGelCandyCard(),
      ),
    );
  }

  /// Mặt úp: Phong cách Gel Candy / Jelly 3D bóng bẩy căng mọng
  Widget _buildGelCandyCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF38BDF8), // Xanh trời sáng
            Color(0xFF0284C7), // Xanh dương kẹo thạch
            Color(0xFF0369A1), // Xanh biển sâu 3D
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          // 3D Bottom Depth Shadow
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.42),
            offset: const Offset(0, 5),
            blurRadius: 8,
          ),
          // Ambient Glow
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.2),
            offset: const Offset(0, 1),
            blurRadius: 3,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Vòm phản quang bóng loáng (Glossy Dome Reflection)
          Positioned(
            top: 2,
            left: 4,
            right: 4,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                  bottom: Radius.circular(8),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.65),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
          ),

          // Tâm thẻ: Viên ngọc tròn Jelly 3D chứa dấu hỏi trắng
          Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 1.5),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mặt lật mở: Phong cách Pastel Toy Card (hoặc Victory Mint khi đã ghép trúng)
  Widget _buildFacedUpCard(MemoryCard card) {
    final isMatched = card.isMatched;
    final isEnglish = card.isEnglish;

    // Màu sắc theo ngữ cảnh
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final Color shadowColor;
    final String tagLabel;

    if (isMatched) {
      // Victory Mint Pastel Green
      bgColor = const Color(0xFFD1FAE5);
      borderColor = const Color(0xFF16A34A);
      textColor = const Color(0xFF003D1D);
      shadowColor = const Color(0xFF16A34A).withValues(alpha: 0.25);
      tagLabel = isEnglish ? 'EN 🇬🇧' : 'VI 🇻🇳';
    } else if (isEnglish) {
      // Pastel Toy Blue
      bgColor = const Color(0xFFCFE5FF);
      borderColor = const Color(0xFF00629D);
      textColor = const Color(0xFF00375A);
      shadowColor = const Color(0xFF00629D).withValues(alpha: 0.15);
      tagLabel = 'EN 🇬🇧';
    } else {
      // Pastel Toy Orange
      bgColor = const Color(0xFFFFDCBB);
      borderColor = const Color(0xFFEA580C);
      textColor = const Color(0xFF663C00);
      shadowColor = const Color(0xFFEA580C).withValues(alpha: 0.15);
      tagLabel = 'VI 🇻🇳';
    }

    // Adaptive font size
    final textLength = card.text.length;
    final double fontSize = textLength > 10 ? 11.0 : (textLength > 6 ? 12.5 : 14.5);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Vệt bóng viên thuốc nghiêng (Glossy Pill Reflection)
          Positioned(
            top: 6,
            left: 8,
            child: Transform.rotate(
              angle: -0.26,
              child: Container(
                width: 18,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

          // Tag ngôn ngữ EN/VI ở góc trên phải
          Positioned(
            top: 5,
            right: 5,
            child: isMatched
                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16)
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tagLabel,
                      style: GoogleFonts.baloo2(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: textColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
          ),

          // Nội dung chữ từ vựng
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                card.text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  height: 1.15,
                ),
              ),
            ),
          ),
        ],
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
