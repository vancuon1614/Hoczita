import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../../../core/providers/game_interaction_provider.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/game_score_sync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../constants/game_content.dart';
import 'package:google_fonts/google_fonts.dart';
import 'common/mini_game_rank_banner.dart';

class MemoryCard {
  final int id;
  final int pairId;
  final String text;
  final bool isEnglish;
  final String emoji;
  bool isFlipped;
  bool isMatched;

  MemoryCard({
    required this.id,
    required this.pairId,
    required this.text,
    required this.emoji,
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
  Timer? _singleCardAutoCloseTimer;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  int _secondsElapsed = 0;
  String _elapsedTimeString = '00:00';

  int _matchedPairsCount = 0;
  int _score = 0;
  bool _isGameOver = false;
  bool _isSavingScore = false;

  static String _getVocabEmoji(String en) {
    switch (en.toLowerCase().trim()) {
      case 'dog': return '🐶';
      case 'cat': return '🐱';
      case 'lion': return '🦁';
      case 'elephant': return '🐘';
      case 'monkey': return '🐵';
      case 'rabbit': return '🐰';
      case 'bear': return '🐻';
      case 'tiger': return '🐯';
      case 'sheep': return '🐑';
      case 'pig': return '🐷';
      case 'apple': return '🍎';
      case 'banana': return '🍌';
      case 'orange': return '🍊';
      case 'watermelon': return '🍉';
      case 'strawberry': return '🍓';
      case 'grape': return '🍇';
      case 'mango': return '🥭';
      case 'pineapple': return '🍍';
      case 'peach': return '🍑';
      case 'cherry': return '🍒';
      case 'carrot': return '🥕';
      case 'tomato': return '🍅';
      case 'potato': return '🥔';
      case 'corn': return '🌽';
      case 'broccoli': return '🥦';
      case 'pumpkin': return '🎃';
      case 'onion': return '🧅';
      case 'cucumber': return '🥒';
      case 'mushroom': return '🍄';
      case 'pea': return '🫛';
      case 'car': return '🚗';
      case 'airplane': return '✈️';
      case 'train': return '🚆';
      case 'bicycle': return '🚲';
      case 'ship': return '🚢';
      case 'helicopter': return '🚁';
      case 'bus': return '🚌';
      case 'motorcycle': return '🏍️';
      case 'boat': return '🚤';
      case 'truck': return '🚚';
      case 'book': return '📖';
      case 'pen': return '🖊️';
      case 'pencil': return '✏️';
      case 'ruler': return '📏';
      case 'eraser': return '🧼';
      case 'backpack': return '🎒';
      case 'desk': return '🪑';
      case 'chair': return '🪑';
      case 'computer': return '💻';
      case 'clock': return '⏰';
      case 'bed': return '🛏️';
      case 'table': return '🪵';
      case 'sofa': return '🛋️';
      case 'lamp': return '💡';
      case 'door': return '🚪';
      case 'window': return '🪟';
      case 'cup': return '🥤';
      case 'spoon': return '🥄';
      case 'fork': return '🍴';
      case 'plate': return '🍽️';
      case 'tree': return '🌳';
      case 'flower': return '🌸';
      case 'sun': return '☀️';
      case 'moon': return '🌙';
      case 'star': return '⭐';
      case 'cloud': return '☁️';
      case 'rain': return '🌧️';
      case 'mountain': return '⛰️';
      case 'river': return '🌊';
      case 'rainbow': return '🌈';
      case 'rocket': return '🚀';
      case 'planet': return '🪐';
      case 'astronaut': return '👨‍🚀';
      case 'comet': return '☄️';
      case 'telescope': return '🔭';
      case 'satellite': return '🛰️';
      case 'fish': return '🐟';
      case 'shark': return '🦈';
      case 'whale': return '🐋';
      case 'dolphin': return '🐬';
      case 'octopus': return '🐙';
      case 'crab': return '🦀';
      case 'turtle': return '🐢';
      case 'jellyfish': return '🪼';
      case 'shell': return '🐚';
      case 'starfish': return '⭐';
      case 'ball': return '⚽';
      case 'doll': return '🪆';
      case 'robot': return '🤖';
      case 'kite': return '🪁';
      case 'balloon': return '🎈';
      case 'puzzle': return '🧩';
      case 'drum': return '🥁';
      case 'shirt': return '👕';
      case 'pants': return '👖';
      case 'dress': return '👗';
      case 'hat': return '🧢';
      case 'shoes': return '👟';
      case 'socks': return '🧦';
      case 'jacket': return '🧥';
      case 'glasses': return '👓';
      case 'scarf': return '🧣';
      case 'boots': return '👢';
      case 'bread': return '🍞';
      case 'milk': return '🥛';
      case 'ice cream': return '🍦';
      case 'lollipop': return '🍭';
      case 'cake': return '🎂';
      case 'pizza': return '🍕';
      case 'egg': return '🥚';
      case 'cheese': return '🧀';
      case 'burger': return '🍔';
      case 'juice': return '🧃';
      default: return '✨';
    }
  }

  static String _getVietnameseEmoji(String en, String defaultEmoji) {
    switch (en.toLowerCase().trim()) {
      case 'cat': return '🐾';
      case 'apple': return '🍏';
      case 'dog': return '🦴';
      case 'lion': return '🐾';
      case 'rabbit': return '🥕';
      default: return defaultEmoji;
    }
  }

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
    _singleCardAutoCloseTimer?.cancel();
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _setupGame() {
    _singleCardAutoCloseTimer?.cancel();
    _singleCardAutoCloseTimer = null;
    _matchedPairsCount = 0;
    _score = 0;
    _firstCardIndex = null;
    _secondCardIndex = null;
    _isGameOver = false;
    _isSavingScore = false;
    
    // Pick 8 random pairs from the global 120 vocabulary pool
    final vocabPool = List<VocabItem>.from(GameContent.allVocab)..shuffle();
    final selectedPairs = vocabPool.take(8).toList();

    final List<MemoryCard> cardList = [];
    for (int i = 0; i < selectedPairs.length; i++) {
      final pair = selectedPairs[i];
      final emoji = _getVocabEmoji(pair.en);
      final viEmoji = _getVietnameseEmoji(pair.en, emoji);

      // English card
      cardList.add(MemoryCard(
        id: i * 2,
        pairId: i,
        text: pair.en,
        emoji: emoji,
        isEnglish: true,
      ));
      // Vietnamese card
      cardList.add(MemoryCard(
        id: (i * 2) + 1,
        pairId: i,
        text: pair.vi,
        emoji: viEmoji,
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
      // Khởi động hẹn giờ 2 giây: nếu sau 2s người dùng không bấm thẻ thứ 2 thì thẻ sẽ tự úp lại
      _singleCardAutoCloseTimer?.cancel();
      _singleCardAutoCloseTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (_firstCardIndex != null && _secondCardIndex == null) {
          setState(() {
            _cards[_firstCardIndex!].isFlipped = false;
            _firstCardIndex = null;
          });
        }
      });
    } else {
      // Đã bấm thẻ thứ 2: hủy ngay hẹn giờ tự đóng thẻ đơn lẻ
      _singleCardAutoCloseTimer?.cancel();
      _singleCardAutoCloseTimer = null;
      _secondCardIndex = index;
      _checkMatch();
    }
  }

  void _checkMatch() {
    _singleCardAutoCloseTimer?.cancel();
    _singleCardAutoCloseTimer = null;
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
    int finalScore = 15;
    if (elapsedSeconds < 25) {
      finalScore = 30;
    } else if (elapsedSeconds < 45) {
      finalScore = 20;
    }

    setState(() {
      _score = finalScore;
      _isGameOver = true;
      _isSavingScore = true;
    });

    final authState = ref.read(authProvider);
    final memberName = authState.username ?? 'Học sinh';

    try {
      await GameScoreSyncService.instance.saveScoreParallel(
        gameCodeOrName: 'E02',
        level: '1',
        score: finalScore,
        stars: 0,
        durationSeconds: _secondsElapsed,
        memberName: memberName,
      );
    } catch (e) {
      debugPrint('Error saving memory_match score: $e');
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
        actions: const [
          GameSoundToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Tính toán kích thước để thẻ to rõ, tỷ lệ đẹp, vừa vặn không bị quá dài và không để thừa khoảng trống đáy
            const horizontalPadding = 14.0;
            const crossAxisSpacing = 8.0;
            const mainAxisSpacing = 8.0;

            final availableHeight = constraints.maxHeight;
            // Trừ phần Header (~38px) + Banner (~36px) + spacings (~20px) + đệm đáy an toàn (~16px)
            final availableGridHeight = (availableHeight - 110.0).clamp(320.0, 720.0);
            final availableGridWidth = constraints.maxWidth - (horizontalPadding * 2);

            final itemWidth = (availableGridWidth - (crossAxisSpacing * 3)) / 4;
            final itemHeight = (availableGridHeight - (mainAxisSpacing * 3)) / 4;
            final dynamicAspectRatio = (itemWidth / itemHeight).clamp(0.59, 0.65);
            final remaining = 8 - _matchedPairsCount;
            final isNearEnd = remaining <= 3 && remaining > 0;

            return Padding(
              padding: const EdgeInsets.fromLTRB(horizontalPadding, 6, horizontalPadding, 12),
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
                                    'Matched: $_matchedPairsCount / 8 • Final Sprint',
                                    style: GoogleFonts.baloo2(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'Matched: $_matchedPairsCount / 8',
                                style: GoogleFonts.baloo2(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                      ),
                      GameCountUpTimer(
                        elapsedSeconds: _secondsElapsed,
                        margin: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 2. Thẻ Bé Ong Hội Thoại (khi còn 3 cặp cuối) hoặc Instruction Banner
                  if (isNearEnd)
                    _buildMascotCard(remaining)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Tap cards to match English and Vietnamese words!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),

                  // 4x4 Grid of Cards (Lấp đầy không gian vừa vặn, không bị dư trống đáy)
                  Expanded(
                    child: Center(
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: mainAxisSpacing,
                          crossAxisSpacing: crossAxisSpacing,
                          childAspectRatio: dynamicAspectRatio,
                        ),
                        itemCount: 16,
                        itemBuilder: (context, index) {
                          return _buildCardItem(index);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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

  /// Mặt úp: Phong cách thẻ 3D xanh biển với đế dày và bong bóng dấu hỏi như mẫu
  Widget _buildGelCandyCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0275B1), // Màu đế thẻ 3D đậm hơn
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.25),
            offset: const Offset(0, 3.5),
            blurRadius: 7,
          ),
        ],
      ),
      padding: const EdgeInsets.only(bottom: 4.0), // Độ dày đế 3D
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF38BDF8), // Xanh trời sáng
              Color(0xFF0284C7), // Xanh biển đậm
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mặt lật mở: Phong cách thẻ đồ họa (hình minh họa + từ + nhãn EN/VI + tích xanh khi khớp)
  Widget _buildFacedUpCard(MemoryCard card) {
    final isMatched = card.isMatched;
    final isEnglish = card.isEnglish;

    final Color bgColor = isMatched ? const Color(0xFFF0FDF4) : Colors.white;
    final Color borderColor = isMatched ? const Color(0xFF16A34A) : const Color(0xFFBAE6FD);
    final Color base3DColor = isMatched ? const Color(0xFF15803D) : const Color(0xFFE2E8F0);
    final Color textColor = isMatched ? const Color(0xFF14532D) : const Color(0xFF00375A);
    final Color subtitleColor = isMatched ? const Color(0xFF16A34A) : const Color(0xFF38BDF8);

    final String subtitle = isMatched
        ? (isEnglish ? 'EN' : 'VN')
        : (isEnglish ? 'ENGLISH' : 'TIẾNG VIỆT');

    return Container(
      decoration: BoxDecoration(
        color: base3DColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isMatched
                ? const Color(0xFF16A34A).withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.only(bottom: 3.5), // Đế thẻ 3D
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isMatched ? 2.2 : 1.5,
          ),
        ),
        child: Stack(
          children: [
            // Badge tích xanh khi đã ghép trúng ở góc trên bên phải
            if (isMatched)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),

            // Nội dung chính của thẻ (Icon/Emoji + Tên từ vựng + Phụ đề EN/VN)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hình minh họa emoji
                    Text(
                      card.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                    const SizedBox(height: 4),

                    // Tên từ vựng (tự động co giãn theo độ dài)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        card.text,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Nhãn ngôn ngữ (ENGLISH / TIẾNG VIỆT hoặc EN / VN)
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: isMatched ? 10.0 : 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: subtitleColor,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuitConfirmation() {
    _stopwatch.stop();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit Game?'),
        content: const Text('Your current game progress will not be saved.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _stopwatch.start(); // Resume timer
            },
            child: const Text('Keep Playing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Quit game
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryView() {
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
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.amber,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                'Awesome! 🎉',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                'You matched all 8 pairs in $_elapsedTimeString!',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

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
                            'Time',
                            style: GoogleFonts.baloo2(fontSize: 11, color: AppColors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _elapsedTimeString,
                            style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
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
                          Text(
                            'Score Earned',
                            style: GoogleFonts.baloo2(fontSize: 11, color: AppColors.success),
                          ),
                          const SizedBox(height: 4),
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
                isEnglish: true,
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
                            'Back to Menu',
                            style: GoogleFonts.baloo2(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              height: 1.2,
                            ),
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

  String _getMascotDialogue(int remaining) {
    if (remaining == 1) {
      return 'Only 1 pair left! Let\'s bring sweet honey home, little bee! 🐝';
    } else if (remaining == 2) {
      return 'Only 2 pairs left! Let\'s bring sweet honey home, little bee! 🐝';
    } else if (remaining == 3) {
      return 'Only 3 pairs left! Let\'s bring sweet honey home, little bee! 🐝';
    }
    return 'Find matching pairs to complete the challenge! 🐝';
  }

  Widget _buildMascotCard(int remaining) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              // Avatar Bé Ong với huy hiệu ngôi sao xanh
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
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
                    child: const Text('🐝', style: TextStyle(fontSize: 20)),
                  ),
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.star_rounded, size: 8, color: Colors.white),
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
                          'Smart Bee',
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        Text(
                          '$_matchedPairsCount / 8 Pairs',
                          style: GoogleFonts.baloo2(
                            fontSize: 11.5,
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
                        fontSize: 11,
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
          const SizedBox(height: 7),

          // Thanh tiến trình phân đoạn 8 vạch
          Row(
            children: List.generate(8, (i) {
              final isDone = i < _matchedPairsCount;
              final isCurrent = i == _matchedPairsCount;
              Color segColor = const Color(0xFFE2E8F0);
              if (isDone) {
                segColor = const Color(0xFF16A34A);
              } else if (isCurrent) {
                segColor = const Color(0xFFF59E0B);
              }
              return Expanded(
                child: Container(
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: segColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
