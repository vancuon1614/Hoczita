import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../constants/word_scramble_data.dart';

enum ScrambleDifficulty { easy, medium, hard }

class ScrambleWord {
  final String en;
  final String hint;
  ScrambleWord(this.en, this.hint);
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
  // Vocabulary Database – built from wordScrambleData
  // common  → easy   | rare → medium | legendary + exclusive → hard
  static List<ScrambleWord> _buildPool(List<String> difficulties) {
    return wordScrambleData
        .where((item) => difficulties.contains(item.difficulty))
        .map((item) => ScrambleWord(item.word.toUpperCase(), item.hint))
        .toList();
  }

  // Game Settings & State
  ScrambleDifficulty? _difficulty;
  List<ScrambleWord> _selectedWords = [];
  int _currentWordIndex = 0;
  int _correctCount = 0;
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;
  int _stars = 0;
  bool _isSavingScore = false;
  final List<ScrambleResult> _results = [];

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

  @override
  void dispose() {
    _timerController.dispose();
    _tickTimer?.cancel();
    super.dispose();
  }

  void _selectDifficulty(ScrambleDifficulty diff) {
    final List<String> difficulties;
    switch (diff) {
      case ScrambleDifficulty.easy:
        difficulties = ['easy'];
        break;
      case ScrambleDifficulty.medium:
        difficulties = ['medium'];
        break;
      case ScrambleDifficulty.hard:
        difficulties = ['hard'];
        break;
    }

    final pool = _buildPool(difficulties)..shuffle();
    setState(() {
      _difficulty = diff;
      _selectedWords = pool.take(10).toList();
      _currentWordIndex = 0;
      _correctCount = 0;
      _results.clear();
      _isPlaying = true;
      _isGameOver = false;
    });

    _loadWord(_currentWordIndex);
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
      await SupabaseService.instance.saveScore(
        gameName: 'word_scramble',
        stars: stars,
        score: score,
      );
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light bluish-white background like the image
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Word Scramble',
              style: GoogleFonts.baloo2(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: const Color(0xFF2C3E50),
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.sort_by_alpha_rounded, size: 20, color: Colors.blueGrey),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: Image.asset(
                  'ImageFolder/wordscramble.webp', 
                  height: 120,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.sort_by_alpha_rounded,
                    size: 80,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Chọn Cấp Độ Từ',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 22, 
                  fontWeight: FontWeight.w600, 
                  color: const Color(0xFF2C3E50),
                ),
              ),
              SizedBox(height: 32),
              _buildDifficultyCard(
                title: 'Khởi động',
                subtitle: 'Làm quen nhẹ nhàng với từ 3-5 ký tự.',
                difficulty: ScrambleDifficulty.easy,
                backgroundColor: const Color(0xFFE4F3E4),
                iconColor: const Color(0xFF4CAF50),
                stars: 1,
              ),
              const SizedBox(height: 16),
              _buildDifficultyCard(
                title: 'Tập trung',
                subtitle: 'Tăng cường thử thách với từ 6-10 ký tự.',
                difficulty: ScrambleDifficulty.medium,
                backgroundColor: const Color(0xFFFDEBCE),
                iconColor: const Color(0xFFF59E0B),
                stars: 2,
              ),
              const SizedBox(height: 16),
              _buildDifficultyCard(
                title: 'Thử thách',
                subtitle: 'Dành cho người chơi nâng cao với dạng ghép câu.',
                difficulty: ScrambleDifficulty.hard,
                backgroundColor: const Color(0xFFFFE5E5),
                iconColor: const Color(0xFFEF4444),
                stars: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyCard({
    required String title,
    required String subtitle,
    required ScrambleDifficulty difficulty,
    required Color backgroundColor,
    required Color iconColor,
    required int stars,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectDifficulty(difficulty),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.baloo2(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B), // Dark text
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.baloo2(
                          fontSize: 10,
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(
                        Icons.star_rounded,
                        color: index < stars ? iconColor.withValues(alpha: 0.6) : Colors.transparent,
                        size: 20,
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
          // Countdown Timer Action Pill
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                width: 76,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: timerColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: timerColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 4),
                    Icon(Icons.timer_outlined, size: 14, color: timerColor),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_secondsRemaining}s',
                        textAlign: TextAlign.left,
                        style: GoogleFonts.baloo2(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: timerColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
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
                            'GỢI Ý',
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
                    Center(
                      child: SizedBox(
                        width: 220,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => _submitCurrentWord(isTimeout: false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Xác nhận', style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
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
                'Gợi ý tiếng Việt:',
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
                            ? 'Xuất sắc quá! Mình đã ghép đúng cả 10 câu rồi! Bạn thật tuyệt vời! 🏆'
                            : (_stars == 2
                                ? 'Tuyệt vời! Đã đúng $_correctCount câu rồi. Cố lên một chút nữa là được 3 sao rồi nhé! 🌟'
                                : (_stars == 1
                                    ? 'Khá tốt! Đã đúng $_correctCount câu rồi. Hãy tiếp tục cố gắng ở lượt chơi sau nhé! 👍'
                                    : (_correctCount == 0
                                        ? 'Mình đã làm không đúng rồi nhé !!! 💔'
                                        : 'Đã đúng $_correctCount câu rồi. Hơi tiếc nhỉ, cố lên. Hãy cố gắng để đạt thêm điểm và 3 sao nhé! 💔'))),
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
                SizedBox(height: 40),

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
