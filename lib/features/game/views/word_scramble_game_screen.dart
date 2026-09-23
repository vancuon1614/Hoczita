import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../../core/providers/game_interaction_provider.dart';
import '../../../core/services/tts_service.dart';
import 'common/mini_game_lobby_screen.dart';
import 'common/mini_game_how_to_play_sheet.dart';
import 'common/mini_game_rank_banner.dart';
import '../services/eduword_service.dart';
import '../models/eduword_model.dart';

enum ScrambleDifficulty { easy, medium, hard }

class ScrambleWord {
  final String en;
  final String hint;
  final EduwordModel? model;
  ScrambleWord(this.en, this.hint, {this.model});
}

class ScrambledTile {
  final String char;
  final int originalIndex;
  bool isUsed;

  ScrambledTile(this.char, this.originalIndex, {this.isUsed = false});
}

class ScrambleResult {
  final ScrambleWord word;
  final String userAnswer;
  final bool isCorrect;
  final bool isTimeout;

  ScrambleResult({
    required this.word,
    required this.userAnswer,
    required this.isCorrect,
    required this.isTimeout,
  });
}

class WordScrambleGameScreen extends ConsumerStatefulWidget {
  const WordScrambleGameScreen({super.key});

  @override
  ConsumerState<WordScrambleGameScreen> createState() => _WordScrambleGameScreenState();
}

class _WordScrambleGameScreenState extends ConsumerState<WordScrambleGameScreen> with TickerProviderStateMixin {
  // Game Settings & State
  ScrambleDifficulty? _difficulty;
  List<ScrambleWord> _selectedWords = [];
  int _currentWordIndex = 0;
  int _correctCount = 0;
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isLoading = false;
  int _score = 0;
  int _stars = 0;
  bool _isSavingScore = false;
  final List<ScrambleResult> _results = [];
  
  int _easyStars = 0;
  int _mediumStars = 0;
  int _hardStars = 0;

  // Word specific states
  List<ScrambledTile> _scrambledTiles = [];
  List<ScrambledTile?> _answerSlots = [];

  // Animation controller for the 10-second timer
  late AnimationController _timerController;
  int _secondsRemaining = 10;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _loadHighestStars();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _submitCurrentWord(isTimeout: true);
      }
    });
  }

  Future<void> _loadHighestStars() async {
    final easy = await SupabaseService.instance.getHighestStarsForGame('word_scramble_easy');
    final medium = await SupabaseService.instance.getHighestStarsForGame('word_scramble_medium');
    final hard = await SupabaseService.instance.getHighestStarsForGame('word_scramble_hard');
    if (mounted) {
      setState(() {
        _easyStars = easy;
        _mediumStars = medium;
        _hardStars = hard;
      });
    }
  }

  @override
  void dispose() {
    ref.read(isGameActiveProvider.notifier).state = false;
    _timerController.dispose();
    _tickTimer?.cancel();
    TtsService.instance.stopAll();
    super.dispose();
  }

  Future<void> _selectDifficulty(ScrambleDifficulty diff) async {
    setState(() {
      _isLoading = true;
    });

    List<ScrambleWord> selectedWords = [];
    int limitParam = 100;
    
    try {
      final eduwords = await EduwordService.fetchWords(limit: limitParam);
      
      if (diff == ScrambleDifficulty.hard) {
        selectedWords = eduwords.where((e) => e.acf.level == 'C1' && e.title.isNotEmpty).map((e) {
          final hint = e.acf.description.isNotEmpty ? e.acf.description : e.acf.viword;
          return ScrambleWord(
            e.title.toUpperCase(),
            hint,
            model: e,
          );
        }).take(10).toList();
      } else if (diff == ScrambleDifficulty.medium) {
        selectedWords = eduwords.where((e) => e.title.trim().length > 4 && e.title.trim().length <= 8 && e.acf.level != 'C1' && e.title.isNotEmpty).map((e) {
          final hint = e.acf.description.isNotEmpty ? e.acf.description : e.acf.viword;
          return ScrambleWord(
            e.title.toUpperCase(),
            hint,
            model: e,
          );
        }).take(10).toList();
      } else {
        selectedWords = eduwords.where((e) => e.title.trim().length <= 4 && e.acf.level != 'C1' && e.title.isNotEmpty).map((e) {
          final hint = e.acf.description.isNotEmpty ? e.acf.description : e.acf.viword;
          return ScrambleWord(
            e.title.toUpperCase(),
            hint,
            model: e,
          );
        }).take(10).toList();
      }
      
      selectedWords.shuffle();
    } catch (e) {
      debugPrint('Failed to fetch from API: $e');
    }

    if (!mounted) return;

    if (selectedWords.isNotEmpty) {
      ref.read(isGameActiveProvider.notifier).state = true;
      setState(() {
        _isLoading = false;
        _difficulty = diff;
        _selectedWords = selectedWords;
        _currentWordIndex = 0;
        _correctCount = 0;
        _results.clear();
        _isPlaying = true;
        _isGameOver = false;
      });
      _loadWord(_currentWordIndex);
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không đủ từ vựng cho độ khó này. Vui lòng thử lại!')),
      );
    }
  }

  void _loadWord(int index) {
    if (index >= _selectedWords.length) {
      _endGame();
      return;
    }

    final word = _selectedWords[index];
    final isHardMode = word.en.contains(' / ');
    final originalChars = isHardMode ? word.en.toUpperCase().split(' / ') : word.en.toUpperCase().split('');
    final List<String> shuffledChars = List<String>.from(originalChars);

    // Shuffle characters and ensure it is not exactly equal to the original word
    int shuffleTries = 0;
    while (shuffleTries < 10) {
      shuffledChars.shuffle();
      final joinChar = isHardMode ? ' / ' : '';
      if (shuffledChars.join(joinChar) != word.en.toUpperCase()) {
        break;
      }
      shuffleTries++;
    }

    // Initialize tile objects
    final tiles = <ScrambledTile>[];
    for (int i = 0; i < shuffledChars.length; i++) {
      tiles.add(ScrambledTile(shuffledChars[i], i));
    }

    final totalSeconds = _difficulty == ScrambleDifficulty.easy ? 10 : 15;
    _timerController.duration = Duration(seconds: totalSeconds);

    setState(() {
      _currentWordIndex = index;
      _scrambledTiles = tiles;
      _answerSlots = List<ScrambledTile?>.filled(originalChars.length, null, growable: true);
      _secondsRemaining = totalSeconds;
    });

    // Reset and start timer
    _timerController.reset();
    _timerController.forward();

    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          }
        });
      }
    });
  }

  void _selectTile(ScrambledTile tile) {
    if (tile.isUsed) {
      final slotIndex = _answerSlots.indexOf(tile);
      if (slotIndex != -1) {
        _removeLetter(slotIndex);
      }
      return;
    }

    // Find the first empty slot in answerSlots
    final firstEmptyIdx = _answerSlots.indexOf(null);
    if (firstEmptyIdx != -1) {
      setState(() {
        tile.isUsed = true;
        _answerSlots[firstEmptyIdx] = tile;
      });
    }
  }

  void _removeLetter(int slotIndex) {
    if (_answerSlots[slotIndex] == null) return;

    setState(() {
      final tile = _answerSlots[slotIndex]!;
      tile.isUsed = false;
      _answerSlots.removeAt(slotIndex);
      _answerSlots.add(null); // Keep the length same by appending null
    });
  }

  void _undoLastWord() {
    // Find the last non-null index in _answerSlots
    int lastNonNullIdx = -1;
    for (int i = _answerSlots.length - 1; i >= 0; i--) {
      if (_answerSlots[i] != null) {
        lastNonNullIdx = i;
        break;
      }
    }
    if (lastNonNullIdx != -1) {
      _removeLetter(lastNonNullIdx);
    }
  }

  bool _isQuestionSentence(String sentence) {
    final lower = sentence.toLowerCase().trim();
    return lower.startsWith('what') ||
        lower.startsWith('how') ||
        lower.startsWith('who') ||
        lower.startsWith('where') ||
        lower.startsWith('why') ||
        lower.startsWith('when') ||
        lower.startsWith('is ') ||
        lower.startsWith('are ') ||
        lower.startsWith('can ') ||
        lower.startsWith('do ') ||
        lower.startsWith('does ') ||
        lower.startsWith('could ') ||
        lower.startsWith('would ') ||
        lower.startsWith('should ');
  }



  void _submitCurrentWord({bool isTimeout = false}) {
    _timerController.stop();
    _tickTimer?.cancel();

    final targetWord = _selectedWords[_currentWordIndex].en.toUpperCase();
    final isHardMode = targetWord.contains(' / ');
    final joinChar = isHardMode ? ' / ' : '';
    final userAnswer = _answerSlots
        .where((t) => t != null)
        .map((t) => t!.char)
        .join(joinChar)
        .toUpperCase();

    final normalizedUser = userAnswer.replaceAll(' / ', ' ').replaceAll('  ', ' ').trim().toUpperCase();
    final normalizedTarget = targetWord.replaceAll(' / ', ' ').replaceAll('  ', ' ').trim().toUpperCase();
    final isCorrect = normalizedUser == normalizedTarget;

    setState(() {
      _results.add(ScrambleResult(
        word: _selectedWords[_currentWordIndex],
        userAnswer: userAnswer,
        isCorrect: isCorrect,
        isTimeout: isTimeout,
      ));
      if (isCorrect) {
        _correctCount++;
        TtsService.instance.speakEnglish(normalizedTarget);
      }
    });

    // Move directly to next word
    if (_currentWordIndex < _selectedWords.length - 1) {
      _loadWord(_currentWordIndex + 1);
    } else {
      _endGame();
    }
  }

  void _endGame() {
    _timerController.stop();
    _tickTimer?.cancel();

    int stars = 0;
    if (_correctCount == 10) {
      stars = 3;
    } else if (_correctCount >= 7) {
      stars = 2;
    } else if (_correctCount >= 4) {
      stars = 1;
    }

    final scorePoints = _correctCount * 10;

    setState(() {
      _stars = stars;
      _score = scorePoints;
      _isGameOver = true;
    });

    _saveGameScore(stars, scorePoints);
  }

  Future<void> _saveGameScore(int stars, int score) async {
    setState(() {
      _isSavingScore = true;
    });
    try {
      final diffName = _difficulty?.name ?? 'easy';
      await SupabaseService.instance.saveScore(
        gameName: 'word_scramble_$diffName',
        stars: stars,
        score: score,
      );
      
      // Update local highest stars so the difficulty screen reflects the new score immediately
      _loadHighestStars();
    } catch (e) {
      debugPrint('Error saving Word Scramble score: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingScore = false;
        });
      }
    }
  }



  void _exitToMenu() {
    ref.read(isGameActiveProvider.notifier).state = false;
    setState(() {
      _isPlaying = false;
      _isGameOver = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlaying) {
      return _buildDifficultySelectionScreen();
    }

    if (_isGameOver) {
      return _buildResultScreen();
    }

    return _buildGameplayScreen();
  }

  // --- UI Screens ---

  Widget _buildDifficultySelectionScreen() {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F9FC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return MiniGameLobbyScreen(
      gameTitle: 'Word Scramble',
      categoryBadge: 'Ngoại Ngữ 🇬🇧',
      welcomeTitle: 'Chào mừng bạn đến với Word Scramble!',
      welcomeSubtitle: 'Sắp xếp các chữ cái bị xáo trộn thành từ hoàn chỉnh',
      starsCount: _easyStars + _mediumStars + _hardStars,
      difficulties: [
        GameDifficultyOption(
          id: 'easy',
          tabLabel: 'Dễ (4 ký tự)',
          modeTitle: 'Chế độ Dễ (Easy Mode)',
          modeSubtitle: 'Lý tưởng cho người mới bắt đầu hoặc học viên nhí',
          timerTag: '10 Giây/từ',
          wordLimitInfo: 'Tối đa 3 - 4 chữ cái (Cat, Sun, Book, Star...)',
          timeInfo: 'Thư giãn tự do hoặc 10 giây/từ',
          hintInfo: 'Tặng sẵn gợi ý dịch nghĩa & phát âm IPA chuẩn',
          rewardInfo: '+10 Điểm ⭐️',
          tipFromHocDi: 'Hãy ưu tiên tìm và xếp các nguyên âm (A, E, I, O, U) vào trước. Hầu hết các từ tiếng Anh đều cần nguyên âm làm trục trung tâm để dễ đoán vần!',
          themeColor: const Color(0xFF006D38),
          interactivePreview: _buildScramblePreviewBox(
            letters: ['B', 'O', 'O', 'K'],
            meaning: 'Quyển sách',
            ipa: '/bʊk/',
            color: const Color(0xFF00B460),
          ),
        ),
        GameDifficultyOption(
          id: 'medium',
          tabLabel: 'Trung Bình',
          modeTitle: 'Chế độ Trung Bình (Medium Mode)',
          modeSubtitle: 'Thử thách nâng cao với các từ vựng 5 đến 8 chữ cái',
          timerTag: '10 Giây/từ',
          wordLimitInfo: 'Từ 5 - 8 chữ cái (School, Planet, Friend...)',
          timeInfo: '10 giây tốc độ cao cho mỗi từ',
          hintInfo: 'Gợi ý mở chữ cái đầu và dịch nghĩa tiếng Việt',
          rewardInfo: '+20 Điểm ⭐️',
          tipFromHocDi: 'Chú ý các tiền tố (un-, re-) hoặc hậu tố (-ing, -ed, -ly) để nhận diện nhanh các nhóm chữ cái đi cùng nhau!',
          themeColor: const Color(0xFF00629D),
          interactivePreview: _buildScramblePreviewBox(
            letters: ['S', 'C', 'H', 'O', 'O', 'L'],
            meaning: 'Trường học',
            ipa: '/skuːl/',
            color: const Color(0xFF0047AB),
          ),
        ),
        GameDifficultyOption(
          id: 'hard',
          tabLabel: 'Cao Thủ C1',
          modeTitle: 'Chế độ Cao Thủ C1 (Advanced)',
          modeSubtitle: 'Chinh phục các từ vựng học thuật C1 chuẩn quốc tế',
          timerTag: '10 Giây/từ',
          wordLimitInfo: 'Từ vựng học thuật cao cấp chuẩn CEFR C1',
          timeInfo: '10 giây căng thẳng và kịch tính',
          hintInfo: 'Giải nghĩa chuyên sâu bằng tiếng Anh',
          rewardInfo: '+35 Điểm ⭐️',
          tipFromHocDi: 'Đoán từ dựa trên gốc từ ngữ nghĩa (root words) và phân loại từ (danh từ, tính từ) để xếp chữ chính xác!',
          themeColor: const Color(0xFF885200),
          interactivePreview: _buildScramblePreviewBox(
            letters: ['A', 'C', 'A', 'D', 'E', 'M', 'I', 'C'],
            meaning: 'Thuộc học thuật',
            ipa: '/ˌæk.əˈdem.ɪk/',
            color: const Color(0xFF885200),
          ),
        ),
      ],
      tutorialSteps: [
        const GameTutorialStep(
          stepNumber: 1,
          icon: Icons.visibility_rounded,
          themeColor: Color(0xFF00629D),
          title: 'Nhìn chữ bị xáo trộn',
          description: 'Quan sát các chữ cái bị đảo lộn và đọc gợi ý nghĩa của từ bên dưới.',
        ),
        const GameTutorialStep(
          stepNumber: 2,
          icon: Icons.touch_app_rounded,
          themeColor: Color(0xFF885200),
          title: 'Chạm hoặc kéo vào ô',
          description: 'Chạm lần lượt các chữ cái theo đúng thứ tự đánh vần để đưa vào ô đáp án.',
        ),
        const GameTutorialStep(
          stepNumber: 3,
          icon: Icons.military_tech_rounded,
          themeColor: Color(0xFF006D38),
          title: 'Nghe đọc & nhận thưởng',
          description: 'Ghép đúng trong 10 giây để được nghe phát âm chuẩn và nhận thêm Điểm & Sao!',
        ),
      ],
      onPlay: (diff) {
        if (diff.id == 'hard') {
          _selectDifficulty(ScrambleDifficulty.hard);
        } else if (diff.id == 'medium') {
          _selectDifficulty(ScrambleDifficulty.medium);
        } else {
          _selectDifficulty(ScrambleDifficulty.easy);
        }
      },
    );
  }

  Widget _buildScramblePreviewBox({
    required List<String> letters,
    required String meaning,
    required String ipa,
    required Color color,
  }) {
    final sampleWord = letters.join('');
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'MINH HỌA: GHÉP TỪ ${letters.length} KÝ TỰ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<bool>(
              valueListenable: TtsService.instance.isSpeakingNotifier,
              builder: (context, isSpeaking, _) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => TtsService.instance.speakEnglish(sampleWord),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSpeaking ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                            size: 18,
                            color: isSpeaking ? const Color(0xFF00B460) : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Phát âm',
                            style: GoogleFonts.baloo2(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSpeaking ? const Color(0xFF00B460) : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: letters.map((char) {
              return Container(
                width: 38,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    char,
                    style: GoogleFonts.baloo2(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => TtsService.instance.speakEnglish(sampleWord),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.volume_up_rounded, size: 16, color: Color(0xFF00B460)),
                  const SizedBox(width: 6),
                  Text(
                    'Nghĩa hiển thị sẵn: "$meaning" (Phát âm chuẩn $ipa)',
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameplayScreen() {
    final word = _selectedWords[_currentWordIndex];
    final wordLength = word.en.length;

    // Calculate dynamic tile sizes to fit screen width (accounting for tile margins)
    final screenWidth = MediaQuery.of(context).size.width;
    final double maxTileWidth = (screenWidth - 64 - (wordLength * 8)) / wordLength;
    final double tileSize = maxTileWidth.clamp(24.0, 52.0);

    // Color code the timer bar based on remaining time
    Color timerColor = AppColors.success;
    if (_secondsRemaining <= 3) {
      timerColor = AppColors.error;
    } else if (_secondsRemaining <= 6) {
      timerColor = AppColors.accent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Từ ${_currentWordIndex + 1}/10',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded),
          onPressed: () {
            _timerController.stop();
            _tickTimer?.cancel();
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Thoát Trò Chơi?'),
                content: Text('Bạn có thực sự muốn thoát trò chơi hiện tại không? Điểm số sẽ không được ghi nhận.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _timerController.forward();
                      _loadWord(_currentWordIndex);
                    },
                    child: Text('Chơi tiếp'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      _exitToMenu();
                    },
                    child: Text('Thoát'),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          // Countdown Timer chuẩn Flashcard Speedrun
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: AnimatedBuilder(
                animation: _timerController,
                builder: (context, child) => GameCountdownTimer(
                  progress: 1.0 - _timerController.value,
                  remainingSeconds: _secondsRemaining,
                  totalSeconds: 10,
                  size: 38,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Smooth Timer progress indicator
          AnimatedBuilder(
            animation: _timerController,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: 1.0 - _timerController.value,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                minHeight: 6,
              );
            },
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [


                  // Hint Box
                  if (word.hint.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'DESCRIPTION',
                            style: GoogleFonts.baloo2(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            word.hint,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.baloo2(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 48),
                  ],

                  // Answer slots & scrambled pool & controls
                  if (word.en.contains(' / ')) ...[
                    // --- HARD MODE VIEW (Sentence Scramble) ---
                    // 1. Scrambled Words Pool (Capsules displayed above the textbox, hidden when used but maintains size/space)
                    Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 10,
                      runSpacing: 14, // Increased spacing/pacing
                      children: _scrambledTiles.map((tile) {
                        return Visibility(
                          visible: !tile.isUsed,
                          maintainSize: true,
                          maintainState: true,
                          maintainAnimation: true,
                          child: GestureDetector(
                            onTap: () => _selectTile(tile),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1B78), // Dark blue
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tile.char,
                                style: GoogleFonts.baloo2(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 28), // Increased vertical spacing/pacing

                    // 2. Question Input Row: "01 - [ Textbox ] ?"
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${(_currentWordIndex + 1).toString().padLeft(2, '0')} - ',
                          style: GoogleFonts.baloo2(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 46),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black, width: 1.5),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _answerSlots
                                  .where((t) => t != null)
                                  .map((t) => t!.char)
                                  .join(' '), // plain text sentence
                              style: GoogleFonts.baloo2(
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          _isQuestionSentence(word.en) ? ' ?' : ' .',
                          style: GoogleFonts.baloo2(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24), // Increased vertical spacing/pacing

                    // 3. Action Buttons Row: Undo and Check (Check appears only when all slots are filled)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(width: 42),
                        GestureDetector(
                          onTap: _undoLastWord,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4E6F1), // Light blue background
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF2980B9), width: 1.2), // Blue border
                            ),
                            child: Text(
                              'Undo',
                              style: GoogleFonts.baloo2(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2980B9),
                              ),
                            ),
                          ),
                        ),
                        if (!_answerSlots.contains(null)) ...[
                          SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _submitCurrentWord(isTimeout: false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4E6F1), // Light blue background
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF2980B9), width: 1.2), // Blue border
                              ),
                              child: Text(
                                'Confirm',
                                style: GoogleFonts.baloo2(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2980B9),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ] else ...[
                    // --- EASY/MEDIUM VIEW ---
                    // Reverted back to not using a surrounding text box wrapper
                    Wrap(
                      alignment: WrapAlignment.center, // Centered
                      spacing: 6,
                      runSpacing: 8,
                      children: List.generate(_answerSlots.length, (idx) {
                        final tile = _answerSlots[idx];
                        return GestureDetector(
                          onTap: () => _removeLetter(idx),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: tileSize,
                            height: tileSize,
                            decoration: BoxDecoration(
                              color: tile != null ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: tile != null ? AppColors.primary : AppColors.border,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              tile?.char ?? '',
                              style: GoogleFonts.baloo2(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 48),

                    // Scrambled letters pool
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: _scrambledTiles.map((tile) {
                        return Opacity(
                          opacity: tile.isUsed ? 0.3 : 1.0,
                          child: GestureDetector(
                            onTap: () => _selectTile(tile),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: tile.isUsed ? AppColors.border : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: tile.isUsed ? AppColors.border : AppColors.primary,
                                  width: 2,
                                ),
                                boxShadow: tile.isUsed
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                tile.char,
                                style: GoogleFonts.baloo2(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: tile.isUsed ? AppColors.textSecondary : AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 48),

                    // Control Buttons: Confirm only
                    if (!_answerSlots.contains(null))
                      Center(
                        child: GestureDetector(
                          onTap: () => _submitCurrentWord(isTimeout: false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4E6F1), // Light blue background
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF2980B9), width: 1.2), // Blue border
                            ),
                            child: Text(
                              'Confirm',
                              style: GoogleFonts.baloo2(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2980B9),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResultDetailsDialog(ScrambleResult res, int index) {
    final isHardMode = res.word.en.contains(' / ');
    final model = res.word.model;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              res.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: res.isCorrect ? AppColors.success : AppColors.error,
            ),
            SizedBox(width: 8),
            Text('Câu hỏi số ${index + 1}', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isHardMode) ...[
              // --- HARD MODE VIEW ---
              if (!res.isCorrect) ...[
                Text(
                  'Nội dung đã xếp:',
                  style: GoogleFonts.baloo2(fontSize: 10, color: AppColors.textSecondary),
                ),
                SizedBox(height: 4),
                Text(
                  res.userAnswer.replaceAll(' / ', ' ').trim(), // clean user sentence
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // Black color for user answer
                  ),
                ),
                SizedBox(height: 16),
              ],
              Text(
                'Đáp án chính xác:',
                style: GoogleFonts.baloo2(fontSize: 10, color: AppColors.textSecondary),
              ),
              SizedBox(height: 4),
              Text(
                res.word.en.replaceAll(' / ', ' ').toUpperCase().trim(), // clean target sentence
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success, // Green color for correct answer
                ),
              ),
            ] else ...[
              // --- EASY/MEDIUM MODE VIEW ---
              Text(
                'Gợi ý:',
                style: GoogleFonts.baloo2(fontSize: 10, color: AppColors.textSecondary),
              ),
              Text(
                res.word.hint,
                style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              SizedBox(height: 16),
              if (!res.isCorrect) ...[
                Text(
                  'Nội dung đã chọn:',
                  style: GoogleFonts.baloo2(fontSize: 10, color: AppColors.textSecondary),
                ),
                Text(
                  res.userAnswer,
                  style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                SizedBox(height: 16),
              ],
              Text(
                'Đáp án chính xác:',
                style: GoogleFonts.baloo2(fontSize: 10, color: AppColors.textSecondary),
              ),
              Text(
                res.word.en,
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                  letterSpacing: 1.5,
                ),
              ),
            ],
            if (res.isTimeout && !res.isCorrect) ...[
              SizedBox(height: 12),
              Text(
                '* Đã hết thời gian làm câu này.',
                style: GoogleFonts.baloo2(fontSize: 9, color: AppColors.error, fontStyle: FontStyle.italic),
              ),
            ],
            if (model != null) ...[
              SizedBox(height: 16),
              Divider(),
              SizedBox(height: 8),
              Text('Từ vựng: ${model.title}', style: GoogleFonts.baloo2(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              if (model.acf.transcription.isNotEmpty)
                Text('Phiên âm: ${model.acf.transcription}', style: GoogleFonts.baloo2(fontSize: 12, color: AppColors.textSecondary)),
              if (model.acf.viword.isNotEmpty)
                Text('Nghĩa: ${model.acf.viword}', style: GoogleFonts.baloo2(fontSize: 12, color: AppColors.textPrimary)),
              if (model.acf.description.isNotEmpty)
                Text('Định nghĩa: ${model.acf.description}', style: GoogleFonts.baloo2(fontSize: 12, color: AppColors.textPrimary)),
              if (model.acf.videscription.isNotEmpty)
                Text('Giải nghĩa VN: ${model.acf.videscription}', style: GoogleFonts.baloo2(fontSize: 12, color: AppColors.textPrimary)),
              if (model.acf.example.isNotEmpty)
                Text('Ví dụ: ${model.acf.example}', style: GoogleFonts.baloo2(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textPrimary)),
              if (model.acf.level.isNotEmpty)
                Text('Trình độ: ${model.acf.level}', style: GoogleFonts.baloo2(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 16),
                Text(
                  'KẾT QUẢ',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Sắp Xếp Từ Vựng',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 24),

                // Animated Star rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final active = index < _stars;
                    return AnimatedScale(
                      scale: active ? 1.2 : 1.0,
                      duration: Duration(milliseconds: 300 + index * 100),
                      curve: Curves.easeOutBack,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Icon(
                          Icons.star_rounded,
                          size: 56,
                          color: active ? Colors.amber : AppColors.border,
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: 24),

                // Cards with score & result details
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _stars == 3
                            ? 'Xuất sắc quá! Bạn đã ghép đúng cả 10 câu rồi! Bạn thật tuyệt vời! 🏆'
                            : (_stars == 2
                                ? 'Tuyệt vời! Bạn đã đúng $_correctCount câu rồi. Cố lên một chút nữa là được 3 sao rồi nhé! 🌟'
                                : (_stars == 1
                                    ? 'Khá tốt! Bạn đã đúng $_correctCount câu rồi. Hãy tiếp tục cố gắng ở lượt chơi sau nhé! 👍'
                                    : (_correctCount == 0
                                        ? 'Bạn chưa ghi được điểm nào lần này. Đừng nản lòng nhé! 💔'
                                        : 'Bạn đã đúng $_correctCount câu rồi. Hơi tiếc nhỉ, cố lên. Hãy cố gắng để đạt thêm điểm và 3 sao nhé! 💔'))),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Đúng',
                                style: GoogleFonts.baloo2(fontSize: 10, color: AppColors.textSecondary),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '$_correctCount/10',
                                style: GoogleFonts.baloo2(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: AppColors.border,
                          ),
                          Column(
                            children: [
                              Text(
                                'Điểm cộng',
                                style: GoogleFonts.baloo2(fontSize: 10, color: AppColors.textSecondary),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '+$_score',
                                style: GoogleFonts.baloo2(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                MiniGameRankBanner(
                  gameName: 'word_scramble_${_difficulty?.name ?? 'easy'}',
                  gameTitle: 'Word Scramble',
                  currentScore: _score,
                ),
                const SizedBox(height: 24),

                // Table showing results of all 10 questions
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

                // Action Button
                Center(
                  child: SizedBox(
                    width: 220,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSavingScore
                          ? null
                          : () {
                              Navigator.pop(context); // Go back to GameTab
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
          itemCount: _results.length,
          itemBuilder: (context, index) {
            final res = _results[index];
            final color = res.isCorrect ? AppColors.success : AppColors.error;

            return InkWell(
              onTap: () => _showResultDetailsDialog(res, index),
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
}
