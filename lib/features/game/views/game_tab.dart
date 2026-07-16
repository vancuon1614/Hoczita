import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_icon.dart';
import '../../../core/services/supabase_service.dart';
import '../constants/game_content.dart';
import 'multiple_choice_game_screen.dart';
import 'memory_match_game_screen.dart';
import 'math_crossword_game_screen.dart';
import 'english_crossword_game_screen.dart';
import 'word_scramble_game_screen.dart';
import 'package:google_fonts/google_fonts.dart';


class GameTab extends ConsumerStatefulWidget {
  const GameTab({super.key});

  @override
  ConsumerState<GameTab> createState() => _GameTabState();
}

class _GameTabState extends ConsumerState<GameTab> {
  final SupabaseService _db = SupabaseService.instance;
  Map<String, int> _highestStars = {
    'flashcard_speed': 0,
    'memory_match': 0,
    'picture_guess': 0,
    'counting': 0,
    'math_ops': 0,
    'comparison': 0,
    'math_crossword': 0,
    'english_crossword': 0,
    'word_scramble': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGameScores();
  }

  Future<void> _loadGameScores() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final scores = await _db.getScores();
      final Map<String, int> starsMap = {
        'flashcard_speed': 0,
        'memory_match': 0,
        'picture_guess': 0,
        'counting': 0,
        'math_ops': 0,
        'comparison': 0,
        'math_crossword': 0,
        'english_crossword': 0,
        'word_scramble': 0,
      };

      for (final scoreEntry in scores) {
        final String? gameName = scoreEntry['game_name'];
        final int? stars = scoreEntry['stars'];
        if (gameName != null && stars != null) {
          final currentMax = starsMap[gameName] ?? 0;
          if (stars > currentMax) {
            starsMap[gameName] = stars;
          }
        }
      }

      if (mounted) {
        setState(() {
          _highestStars = starsMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading scores in GameTab: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _playGame(Widget gameScreen) async {
    // Navigate to game screen and wait for completion
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => gameScreen),
    );
    // Reload scores to update star rating immediately
    _loadGameScores();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Hệ thống Mini-Game 🎮',
            style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: GoogleFonts.baloo2(fontWeight: FontWeight.bold, fontSize: 14),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Ngoại ngữ 🇬🇧'),
                  Tab(text: 'Toán học 🔢'),
                ],
              ),
            ),
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildLanguageGames(context),
                  _buildMathGames(context),
                ],
              ),
      ),
    );
  }

  Widget _buildLanguageGames(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadGameScores,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _buildGameCard(
            context: context,
            title: 'Flashcard Speed Run',
            subtitle: 'Chọn đúng nghĩa của từ tiếng Anh trong vòng 6 giây cực kỳ kịch tính.',
            icon: Icons.flash_on_rounded,
            color: Colors.amber,
            stars: _highestStars['flashcard_speed'] ?? 0,
            animationType: GameAnimationType.bounce,
            imagePath: 'ImageFolder/flashcard.gif',
            onTap: () => _playGame(
              MultipleChoiceGameScreen(
                gameName: 'flashcard_speed',
                gameTitle: 'Flashcard Speed Run',
                questions: GameContent.getFlashcardQuestions(),
              ),
            ),
          ),
          SizedBox(height: 20),
          _buildGameCard(
            context: context,
            title: 'Memory Match',
            subtitle: 'Lật 16 mảnh thẻ ghép cặp từ tiếng Anh với nghĩa tiếng Việt tương ứng.',
            icon: Icons.grid_view_rounded,
            color: Colors.purple,
            stars: _highestStars['memory_match'] ?? 0,
            animationType: GameAnimationType.swing,
            imagePath: 'ImageFolder/memorymatch.gif',
            onTap: () => _playGame(
              const MemoryMatchGameScreen(),
            ),
          ),
          SizedBox(height: 20),
          _buildGameCard(
            context: context,
            title: 'Picture Guess',
            subtitle: 'Nhìn hình ảnh minh họa đoán nhanh từ vựng tương ứng trong 6 giây.',
            icon: Icons.image_search_rounded,
            color: Colors.teal,
            stars: _highestStars['picture_guess'] ?? 0,
            animationType: GameAnimationType.pulse,
            imagePath: 'ImageFolder/pictureguess.gif',
            onTap: () => _playGame(
              MultipleChoiceGameScreen(
                gameName: 'picture_guess',
                gameTitle: 'Picture Guess',
                questions: GameContent.getPictureGuessQuestions(),
              ),
            ),
          ),
          _buildGameCard(
            context: context,
            title: 'Ô Chữ Tiếng Anh',
            subtitle: 'Giải ô chữ bằng từ vựng Tiếng Anh theo các gợi ý tiếng Việt sinh động.',
            icon: Icons.grid_on_rounded,
            color: Colors.pink,
            stars: _highestStars['english_crossword'] ?? 0,
            animationType: GameAnimationType.swing,
            imagePath: 'ImageFolder/crossword.gif',
            onTap: () => _playGame(
              const EnglishCrosswordGameScreen(),
            ),
          ),
          SizedBox(height: 20),
          _buildGameCard(
            context: context,
            title: 'Sắp Xếp Từ Vựng',
            subtitle: 'Sắp xếp các chữ cái bị xáo trộn thành từ tiếng Anh hoàn chỉnh trong 10 giây.',
            icon: Icons.shuffle_rounded,
            color: Colors.deepOrange,
            stars: _highestStars['word_scramble'] ?? 0,
            animationType: GameAnimationType.pulse,
            imagePath: 'ImageFolder/wordscramble.webp',
            onTap: () => _playGame(
              const WordScrambleGameScreen(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMathGames(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadGameScores,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _buildGameCard(
            context: context,
            title: 'Đếm Số Nhanh',
            subtitle: 'Nhìn các vật thể xuất hiện và đếm nhanh số lượng trong vòng 6 giây.',
            icon: Icons.filter_9_plus_rounded,
            color: Colors.orange,
            stars: _highestStars['counting'] ?? 0,
            animationType: GameAnimationType.pulse,
            imagePath: 'ImageFolder/mathcount.gif',
            onTap: () => _playGame(
              MultipleChoiceGameScreen(
                gameName: 'counting',
                gameTitle: 'Đếm Số Nhanh',
                questions: GameContent.getCountingQuestions(),
              ),
            ),
          ),
          SizedBox(height: 20),
          _buildGameCard(
            context: context,
            title: 'Thêm Bớt Vui Nhộn',
            subtitle: 'Điền kết quả đúng cho phép tính cộng trừ trong phạm vi 100.',
            icon: Icons.train_rounded,
            color: Colors.blue,
            stars: _highestStars['math_ops'] ?? 0,
            animationType: GameAnimationType.bounce,
            imagePath: 'ImageFolder/thembotvuinhon.gif',
            onTap: () => _playGame(
              MultipleChoiceGameScreen(
                gameName: 'math_ops',
                gameTitle: 'Tàu Hỏa Thêm Bớt',
                questions: GameContent.getMathOpsQuestions(),
              ),
            ),
          ),
          SizedBox(height: 20),
          _buildGameCard(
            context: context,
            title: 'So Sánh Trái Phải',
            subtitle: 'Lựa chọn bên nhiều hơn hoặc ít hơn dựa theo câu đố trong 6 giây.',
            icon: Icons.compare_arrows_rounded,
            color: Colors.red,
            stars: _highestStars['comparison'] ?? 0,
            animationType: GameAnimationType.swing,
            imagePath: 'ImageFolder/sosanhtraiphai.gif',
            onTap: () => _playGame(
              MultipleChoiceGameScreen(
                gameName: 'comparison',
                gameTitle: 'So Sánh Trái Phải',
                questions: GameContent.getComparisonQuestions(),
              ),
            ),
          ),
          SizedBox(height: 20),
          _buildGameCard(
            context: context,
            title: 'Ô Chữ Toán Học',
            subtitle: 'Giải ô chữ bằng các con số sao cho các phép tính ngang dọc đều đúng.',
            icon: Icons.grid_on_rounded,
            color: Colors.purple,
            stars: _highestStars['math_crossword'] ?? 0,
            animationType: GameAnimationType.swing,
            imagePath: 'ImageFolder/crossword.gif',
            onTap: () => _playGame(
              const MathCrosswordGameScreen(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int stars,
    required GameAnimationType animationType,
    String? imagePath,
    String? imageUrl,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Visual Icon/Image
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) => AnimatedGameIcon(
                            icon: icon,
                            color: color,
                            size: 28,
                            animationType: animationType,
                          ),
                        )
                      : imagePath != null
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: Image.asset(
                                imagePath,
                                width: 44,
                                height: 44,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => AnimatedGameIcon(
                                  icon: icon,
                                  color: color,
                                  size: 28,
                                  animationType: animationType,
                                ),
                              ),
                            )
                          : AnimatedGameIcon(
                              icon: icon,
                              color: color,
                              size: 28,
                              animationType: animationType,
                            ),
                ),
                SizedBox(width: 16),
                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.baloo2(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          // Star Badge
                          Row(
                            children: List.generate(
                              3,
                              (index) => Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: index < stars ? AppColors.accent : AppColors.border,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
