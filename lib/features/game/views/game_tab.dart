import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'magic_words_game_screen.dart';
import 'magic_number_path_game_screen.dart';
import 'sudoku_lobby_screen.dart';
import 'multiplication_table_game_screen.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../../../core/providers/game_interaction_provider.dart';
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
    'magic_words': 0,
    'magic_number_path': 0,
    'sudoku_medium': 0,
    'multiplication_table': 0,
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
      final Map<String, int> tempStarsMap = {};

      for (final scoreEntry in scores) {
        final String? gameName = scoreEntry['game_name'];
        final int? stars = scoreEntry['stars'];
        if (gameName != null && stars != null) {
          final currentMax = tempStarsMap[gameName] ?? 0;
          if (stars > currentMax) {
            tempStarsMap[gameName] = stars;
          }
        }
      }

      // Đồng bộ thêm từ Local Cache nếu offline hoặc chưa đăng nhập
      try {
        final prefs = await SharedPreferences.getInstance();
        const codes = ['M01', 'M02', 'M03', 'M04', 'M05', 'M06', 'E01', 'E02', 'E03', 'E04', 'E05', 'E06'];
        for (final code in codes) {
          final localStars = prefs.getInt('hoczita_best_stars_$code') ?? 0;
          if (localStars > (tempStarsMap[code] ?? 0)) {
            tempStarsMap[code] = localStars;
          }
        }
      } catch (_) {}

      int getModeStars(String baseName) {
        int starsCount = 0;
        if ((tempStarsMap['${baseName}_easy'] ?? 0) == 3) starsCount++;
        if ((tempStarsMap['${baseName}_medium'] ?? 0) == 3) starsCount++;
        if ((tempStarsMap['${baseName}_hard'] ?? 0) == 3) starsCount++;
        return starsCount;
      }

      final Map<String, int> starsMap = {
        'flashcard_speed': max(tempStarsMap['flashcard_speed'] ?? 0, tempStarsMap['E01'] ?? 0),
        'memory_match': max(tempStarsMap['memory_match'] ?? 0, tempStarsMap['E02'] ?? 0),
        'picture_guess': max(tempStarsMap['picture_guess'] ?? 0, tempStarsMap['E03'] ?? 0),
        'counting': max(tempStarsMap['counting'] ?? 0, tempStarsMap['M01'] ?? 0),
        'math_ops': max(tempStarsMap['math_ops'] ?? 0, tempStarsMap['M02'] ?? 0),
        'comparison': max(tempStarsMap['comparison'] ?? 0, tempStarsMap['M03'] ?? 0),
        'math_crossword': max(getModeStars('math_crossword'), tempStarsMap['M04'] ?? 0),
        'english_crossword': max(getModeStars('english_crossword'), tempStarsMap['E04'] ?? 0),
        'word_scramble': max(getModeStars('word_scramble'), tempStarsMap['E05'] ?? 0),
        'magic_words': max(
          getModeStars('magic_words') > 0 ? getModeStars('magic_words') : (tempStarsMap['magic_words'] ?? 0),
          tempStarsMap['E06'] ?? 0,
        ),
        'magic_number_path': max(tempStarsMap['magic_number_path'] ?? 0, tempStarsMap['M06'] ?? 0),
        'sudoku_medium': tempStarsMap['sudoku_medium'] ?? (tempStarsMap['sudoku_easy'] ?? (tempStarsMap['M05'] ?? 0)),
        'multiplication_table': () {
          int maxS = tempStarsMap['M02'] ?? 0;
          for (final k in tempStarsMap.keys) {
            if (k.startsWith('multiplication_table')) {
              final s = tempStarsMap[k] ?? 0;
              if (s > maxS) maxS = s;
            }
          }
          return maxS;
        }(),
      };

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
    ref.read(isGameActiveProvider.notifier).state = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => gameScreen),
      );
    } finally {
      if (mounted) {
        ref.read(isGameActiveProvider.notifier).state = false;
        _loadGameScores();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hệ thống Mini-Game',
                style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 8),
              Image.asset(
                'ImageFolder/store_mini_games.gif',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Text('🎮'),
              ),
            ],
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: GameSoundToggleButton(isPlayScreen: false),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E60D0), Color(0xFF0047AB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x330047AB),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: GoogleFonts.baloo2(fontWeight: FontWeight.bold, fontSize: 14),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'English 🇬🇧'),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
          _buildGameCard(
            context: context,
            title: 'Flashcard Speed Run',
            subtitle: 'Choose the correct meaning of the English word within 6 exciting seconds.',
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
                timeLimitInSeconds: 6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildGameCard(
            context: context,
            title: 'Memory Match',
            subtitle: 'Flip 16 cards to match English words with their corresponding pictures and meanings.',
            icon: Icons.grid_view_rounded,
            color: Colors.purple,
            stars: _highestStars['memory_match'] ?? 0,
            animationType: GameAnimationType.swing,
            imagePath: 'ImageFolder/memorymatch.gif',
            onTap: () => _playGame(
              const MemoryMatchGameScreen(),
            ),
          ),
          const SizedBox(height: 16),
          _buildGameCard(
            context: context,
            title: 'Picture Guess',
            subtitle: 'Look at the picture and quickly choose the matching English word in 10 seconds.',
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
                timeLimitInSeconds: 10,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildGameCard(
            context: context,
            title: 'English Crossword',
            subtitle: 'Solve crosswords with English vocabulary and fun interactive clues.',
            icon: Icons.grid_on_rounded,
            color: Colors.pink,
            stars: _highestStars['english_crossword'] ?? 0,
            animationType: GameAnimationType.swing,
            imagePath: 'ImageFolder/crossword.gif',
            onTap: () => _playGame(
              const EnglishCrosswordGameScreen(),
            ),
          ),
          const SizedBox(height: 16),
          _buildGameCard(
            context: context,
            title: 'Word Scramble',
            subtitle: 'Rearrange scrambled letters to form the correct English word in 10 seconds.',
            icon: Icons.shuffle_rounded,
            color: Colors.deepOrange,
            stars: _highestStars['word_scramble'] ?? 0,
            animationType: GameAnimationType.pulse,
            imagePath: 'ImageFolder/wordscramble.webp',
            onTap: () => _playGame(
              const WordScrambleGameScreen(),
            ),
          ),
          const SizedBox(height: 16),
          _buildGameCard(
            context: context,
            title: 'Magic Words',
            subtitle: 'Find hidden words across the letter grid with 3 levels: Easy, Medium, and Hard.',
            icon: Icons.font_download_rounded,
            color: Colors.indigo,
            stars: _highestStars['magic_words'] ?? 0,
            animationType: GameAnimationType.pulse,
            imagePath: 'ImageFolder/magic_word.gif',
            onTap: () => _playGame(
              const MagicWordsGameScreen(),
            ),
          ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMathGames(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadGameScores,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
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
                timeLimitInSeconds: 6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildGameCard(
            context: context,
            title: 'Tính Nhanh',
            subtitle: 'Điền kết quả đúng cho phép tính cộng trừ trong phạm vi 100 trong vòng 7 giây.',
            icon: Icons.train_rounded,
            color: Colors.blue,
            stars: _highestStars['math_ops'] ?? 0,
            animationType: GameAnimationType.bounce,
            imagePath: 'ImageFolder/thembotvuinhon.gif',
            onTap: () => _playGame(
              MultipleChoiceGameScreen(
                gameName: 'math_ops',
                gameTitle: 'Tính Nhanh',
                questions: GameContent.getMathOpsQuestions(),
                timeLimitInSeconds: 7,
              ),
            ),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          _buildGameCard(
            context: context,
            title: 'Đường Số Diệu Kỳ',
            subtitle: 'Kết nối các số theo thứ tự để điền kín tất cả các ô trên bảng.',
            icon: Icons.timeline_rounded,
            color: Colors.green,
            stars: _highestStars['magic_number_path'] ?? 0,
            animationType: GameAnimationType.pulse,
            imagePath: 'ImageFolder/number.webp',
            onTap: () => _playGame(
              const MagicNumberPathGameScreen(),
            ),
          ),
          const SizedBox(height: 16),
          _buildGameCard(
            context: context,
            title: 'Sudoku Trí Tuệ',
            subtitle: 'Giải ma trận số 9x9 với 6 cấp độ và chế độ đấu trường trực tuyến.',
            icon: Icons.grid_4x4_rounded,
            color: const Color(0xFF1D4ED8),
            stars: _highestStars['sudoku_medium'] ?? 0,
            animationType: GameAnimationType.swing,
            imagePath: 'ImageFolder/sudoku.webp',
            onTap: () => _playGame(
              const SudokuLobbyScreen(),
            ),
          ),
          const SizedBox(height: 16),
          _buildGameCard(
            context: context,
            title: 'Bảng Cửu Chương',
            subtitle: 'Thử thách chạm bóng tính nhanh bảng nhân từ 2 đến 9 kèm giọng đọc sinh động.',
            icon: Icons.calculate_rounded,
            color: const Color(0xFF00629D),
            stars: _highestStars['multiplication_table'] ?? 0,
            animationType: GameAnimationType.pulse,
            imagePath: 'ImageFolder/Multiplication.webp',
            onTap: () => _playGame(
              const MultiplicationTableGameScreen(),
            ),
          ),
                ],
              ),
            ),
          );
        },
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
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F6EA0).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: const Color(0xFF4F6EA0).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Visual Squircle Icon/Image (des.zip style)
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.18),
                        color.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: color.withValues(alpha: 0.22), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.12),
                        offset: const Offset(0, 3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 46,
                          height: 46,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) => AnimatedGameIcon(
                            icon: icon,
                            color: color,
                            size: 26,
                            animationType: animationType,
                          ),
                        )
                      : imagePath != null
                          ? Padding(
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(
                                imagePath,
                                width: 44,
                                height: 44,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => AnimatedGameIcon(
                                  icon: icon,
                                  color: color,
                                  size: 26,
                                  animationType: animationType,
                                ),
                              ),
                            )
                          : AnimatedGameIcon(
                              icon: icon,
                              color: color,
                              size: 26,
                              animationType: animationType,
                            ),
                ),
                const SizedBox(width: 14),
                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                          height: 1.35,
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
