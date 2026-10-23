import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/game_score_sync_service.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../../../core/providers/game_interaction_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'common/mini_game_rank_banner.dart';

class WordScrambleGameScreen extends ConsumerStatefulWidget {
  const WordScrambleGameScreen({super.key});

  @override
  ConsumerState<WordScrambleGameScreen> createState() => _WordScrambleGameScreenState();
}

class _WordScrambleGameScreenState extends ConsumerState<WordScrambleGameScreen> with SingleTickerProviderStateMixin {
  late AnimationController _timerController;
  late Stopwatch _stopwatch;
  String get _elapsedTimeString => GameCountUpTimer.formatSeconds(_stopwatch.elapsed.inSeconds);

  final List<bool> _questionResults = [];
  final List<String> _userFormedAnswers = [];
  
  final List<Map<String, String>> _allWords = [
    {'word': 'APPLE', 'hint': 'A sweet, crunchy fruit, usually red or green.'},
    {'word': 'BANANA', 'hint': 'A long, yellow curved fruit that monkeys love.'},
    {'word': 'ORANGE', 'hint': 'A round citrus fruit rich in Vitamin C.'},
    {'word': 'SCHOOL', 'hint': 'A place where students go to learn and make friends.'},
    {'word': 'TEACHER', 'hint': 'A person who helps students learn new things.'},
    {'word': 'FRIEND', 'hint': 'A person you know well and like to play with.'},
    {'word': 'FAMILY', 'hint': 'Parents and children living together in a home.'},
    {'word': 'FLOWER', 'hint': 'The colorful blossom of a plant with sweet fragrance.'},
    {'word': 'GARDEN', 'hint': 'An area of ground where plants and flowers grow.'},
    {'word': 'SUMMER', 'hint': 'The warmest season of the year with sunny days.'},
  ];

  late String _currentWord;
  late String _currentHint;
  late List<String> _scrambledLetters;
  late List<String> _userLetters;
  
  int _score = 0;
  int _currentQuestionIndex = 0;
  int _secondsRemaining = 10;
  bool _isGameOver = false;
  bool _isSavingScore = false;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _timerController.addListener(() {
      setState(() {
        _secondsRemaining = (10 - (_timerController.value * 10)).ceil();
      });
    });

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleTimeout();
      }
    });

    _setupGame();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(isGameActiveProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    ref.read(isGameActiveProvider.notifier).state = false;
    _timerController.dispose();
    TtsService.instance.stopAll();
    super.dispose();
  }

  void _setupGame() {
    final wordData = _allWords[_currentQuestionIndex];
    _currentWord = wordData['word']!;
    _currentHint = wordData['hint']!;
    
    List<String> letters = _currentWord.split('');
    do {
      letters.shuffle();
    } while (letters.join('') == _currentWord);
    
    setState(() {
      _scrambledLetters = letters;
      _userLetters = [];
      _secondsRemaining = 10;
      _isGameOver = false;
    });

    _timerController.forward(from: 0.0);
    _speakHint();
  }

  void _speakHint() {
    TtsService.instance.speakEnglish(_currentHint);
  }

  void _onLetterTap(int index, bool fromScrambled) {
    if (_isGameOver) return;

    setState(() {
      if (fromScrambled) {
        if (_userLetters.length < _currentWord.length) {
          _userLetters.add(_scrambledLetters[index]);
          _scrambledLetters.removeAt(index);
        }
      } else {
        _scrambledLetters.add(_userLetters[index]);
        _userLetters.removeAt(index);
      }
    });
  }

  void _moveBack(int index) {
    if (_isGameOver || index >= _userLetters.length) return;
    setState(() {
      _scrambledLetters.add(_userLetters[index]);
      _userLetters.removeAt(index);
    });
  }

  void _resetUserLetters() {
    if (_isGameOver || _userLetters.isEmpty) return;
    setState(() {
      _scrambledLetters.addAll(_userLetters);
      _userLetters.clear();
    });
  }

  void _submitAnswer() {
    if (_isGameOver) return;
    _timerController.stop();

    final userWord = _userLetters.join('');
    final isCorrect = userWord == _currentWord;

    _questionResults.add(isCorrect);
    _userFormedAnswers.add(userWord);

    if (isCorrect) {
      _score += 20;
    }

    Future.delayed(const Duration(milliseconds: 250), _nextWord);
  }

  void _handleTimeout() {
    if (_isGameOver) return;
    _timerController.stop();

    final userWord = _userLetters.join('');
    final isCorrect = userWord == _currentWord;

    _questionResults.add(isCorrect);
    _userFormedAnswers.add(userWord);

    if (isCorrect) {
      _score += 20;
    }

    Future.delayed(const Duration(milliseconds: 250), _nextWord);
  }

  void _nextWord() {
    if (_currentQuestionIndex < _allWords.length - 1) {
      _currentQuestionIndex++;
      _setupGame();
    } else {
      _endGame();
    }
  }

  void _endGame() async {
    _timerController.stop();
    _stopwatch.stop();
    setState(() {
      _isGameOver = true;
      _isSavingScore = true;
    });

    final authState = ref.read(authProvider);
    final memberName = authState.username ?? 'Student';

    final correctCount = _questionResults.where((r) => r).length;
    final stars = correctCount >= 8 ? 3 : (correctCount >= 5 ? 2 : (correctCount >= 1 ? 1 : 0));

    try {
      await GameScoreSyncService.instance.saveScoreParallel(
        gameCodeOrName: 'E05',
        level: '1',
        score: _score,
        stars: stars,
        memberName: memberName,
      );
    } catch (e) {
      debugPrint('Error saving score: $e');
    } finally {
      if (mounted) setState(() => _isSavingScore = false);
    }
  }

  void _showQuitConfirmation() {
    _timerController.stop();
    _stopwatch.stop();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit Game?'),
        content: const Text('Your current game progress will not be saved.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (!_isGameOver) {
                _timerController.forward();
                _stopwatch.start();
              }
            },
            child: const Text('Keep Playing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isGameOver && !_isSavingScore) return _buildSummaryScreen();

    final remaining = _allWords.length - _currentQuestionIndex;
    final isNearEnd = remaining <= 3;
    final isWarning = _secondsRemaining <= 3;
    final timerColor = isWarning ? const Color(0xFFEF4444) : const Color(0xFF0284C7);
    final timerBg = isWarning ? const Color(0xFFFEF2F2) : const Color(0xFFF0F9FF);
    final timerBorder = isWarning ? const Color(0xFFFECACA) : const Color(0xFFBAE6FD);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Word Scramble 🇬🇧',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: _showQuitConfirmation,
        ),
        actions: const [
          GameSoundToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Progress & Countdown Timer Row
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
                                'Question ${_currentQuestionIndex + 1}/${_allWords.length} • Final Sprint',
                                style: GoogleFonts.baloo2(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Question ${_currentQuestionIndex + 1}/${_allWords.length}',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                  ),

                  // Countdown Timer Pill (Format 00:00, cố định khung không thụt ra/vào)
                  GameCountUpTimer(
                    elapsedSeconds: _secondsRemaining,
                    margin: EdgeInsets.zero,
                    bgColor: timerBg,
                    borderColor: timerBorder,
                    textColor: timerColor,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Thẻ Bé Ong Hội Thoại (CHỈ XUẤT HIỆN KHI CÒN 3 CÂU CUỐI)
              if (isNearEnd) ...[
                _buildMascotCard(remaining),
                const SizedBox(height: 10),
              ],

              // 3. Main Game Arena
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Hint Card (Fixed height 112px)
                    _buildHintCard(),

                    // User Word Slots Area (Fixed height 52px)
                    _buildUserArea(),

                    // Scrambled Letter Pool (Fixed height 90px)
                    _buildLetterPool(),

                    // Action Buttons (Fixed height 44px)
                    _buildActionButtons(),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHintCard() {
    return Container(
      width: double.infinity,
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCCE3F5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00629D).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'CLUE / HINT',
                  style: GoogleFonts.baloo2(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2563EB),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _speakHint,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDBEAFE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.volume_up_rounded, color: Color(0xFF1D4ED8), size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: Text(
                _currentHint,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserArea() {
    return SizedBox(
      height: 52,
      child: Center(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: List.generate(_currentWord.length, (index) {
            final hasLetter = index < _userLetters.length;
            final letter = hasLetter ? _userLetters[index] : '';

            return GestureDetector(
              onTap: hasLetter ? () => _moveBack(index) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: hasLetter ? const Color(0xFFE0F2FE) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasLetter ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: hasLetter
                          ? const Color(0xFF0284C7).withValues(alpha: 0.18)
                          : Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: GoogleFonts.baloo2(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0369A1),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLetterPool() {
    return SizedBox(
      height: 90,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'AVAILABLE LETTERS',
            style: GoogleFonts.baloo2(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: _scrambledLetters.asMap().entries.map((entry) {
              return _buildLetterTile(entry.key, entry.value);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLetterTile(int index, String letter) {
    const tileColors = [
      {'bg': Color(0xFFEFF6FF), 'border': Color(0xFF93C5FD), 'text': Color(0xFF1D4ED8), 'shadow': Color(0xFFBFDBFE)},
      {'bg': Color(0xFFFEF3C7), 'border': Color(0xFFFCD34D), 'text': Color(0xFFB45309), 'shadow': Color(0xFFFDE68A)},
      {'bg': Color(0xFFF0FDF4), 'border': Color(0xFF86EFAC), 'text': Color(0xFF15803D), 'shadow': Color(0xFFBBF7D0)},
      {'bg': Color(0xFFFDF2F8), 'border': Color(0xFFF9A8D4), 'text': Color(0xFFBE185D), 'shadow': Color(0xFFFBCFE8)},
    ];
    final color = tileColors[index % tileColors.length];

    return GestureDetector(
      onTap: () => _onLetterTap(index, true),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color['bg'],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color['border']!, width: 2),
          boxShadow: [
            BoxShadow(
              color: color['shadow']!.withValues(alpha: 0.6),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: GoogleFonts.baloo2(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: color['text'],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _userLetters.isEmpty ? null : _resetUserLetters,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(
            'Reset',
            style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF64748B),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _userLetters.isNotEmpty ? _submitAnswer : null,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: Text(
            'Submit',
            style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            disabledForegroundColor: const Color(0xFF94A3B8),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          ),
        ),
      ],
    );
  }

  String _getMascotDialogue(int remaining) {
    if (remaining == 1) {
      return 'Only 1 question left! Let\'s bring sweet honey home, little bee! 🐝';
    } else if (remaining == 2) {
      return 'Only 2 questions left! Let\'s bring sweet honey home, little bee! 🐝';
    } else if (remaining == 3) {
      return 'Only 3 questions left! Let\'s bring sweet honey home, little bee! 🐝';
    }
    return 'Unscramble the letters to make the right word! 🐝';
  }

  Widget _buildMascotCard(int remaining) {
    final total = _allWords.length;
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
              // Avatar Bé Ong với huy hiệu ngôi sao xanh
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('🐝', style: TextStyle(fontSize: 22)),
                  ),
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
                          'Smart Bee',
                          style: GoogleFonts.baloo2(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E40AF),
                          ),
                        ),
                        Text(
                          'Question ${_currentQuestionIndex + 1} / $total',
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
              Color segColor = const Color(0xFFDBEAFE);
              if (isDone) {
                segColor = const Color(0xFF2563EB); // xanh chủ đạo dịu
              } else if (isCurrent) {
                segColor = const Color(0xFF60A5FA); // xanh sáng nổi bật câu hiện tại
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

  Widget _buildSummaryScreen() {
    final correctCount = _questionResults.where((r) => r).length;
    final totalQuestions = _allWords.length;
    final stars = correctCount >= 8 ? 3 : (correctCount >= 5 ? 2 : (correctCount >= 1 ? 1 : 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: stars > 0 ? const Color(0xFFFFF9E6) : AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    stars > 0 ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                    color: stars > 0 ? Colors.amber : AppColors.primary,
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                stars > 0 ? 'Awesome! 🎉' : 'Keep Trying! 💪',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                'You solved $correctCount/$totalQuestions words correctly in $_elapsedTimeString!',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Animated Star Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final filled = index < stars;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 38,
                      color: filled ? Colors.amber : Colors.grey.shade300,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Time & Score Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(18),
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
                            style: GoogleFonts.baloo2(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8F5),
                        borderRadius: BorderRadius.circular(18),
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
                            style: GoogleFonts.baloo2(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              MiniGameRankBanner(
                gameName: 'word_scramble',
                gameTitle: 'Word Scramble',
                currentScore: _score,
                isEnglish: true,
              ),

              const SizedBox(height: 24),
              Text(
                'Result Details 📊',
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
                    onPressed: _isSavingScore ? null : () => Navigator.pop(context),
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
          itemCount: _allWords.length,
          itemBuilder: (context, index) {
            final isAnswered = index < _questionResults.length;
            final isCorrect = isAnswered && _questionResults[index];
            final Color color = isAnswered
                ? (isCorrect ? AppColors.success : AppColors.error)
                : Colors.grey.shade400;

            return InkWell(
              onTap: () => _showQuestionDetailDialog(index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 2.0),
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
    if (index >= _allWords.length) return;
    final item = _allWords[index];
    final isAnswered = index < _questionResults.length;
    final isCorrect = isAnswered && _questionResults[index];
    final userAnswer = index < _userFormedAnswers.length ? _userFormedAnswers[index] : null;

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
                      'Word ${index + 1}',
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item['word'] ?? '',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.baloo2(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 22),
                            onPressed: () => TtsService.instance.speakEnglish(item['word'] ?? ''),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['hint'] ?? '',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isCorrect)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Correct! 🎉',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        )
                      else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            (userAnswer != null && userAnswer.isNotEmpty)
                                ? 'Your answer: $userAnswer'
                                : 'Time ran out! ⏳',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 140,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: Center(
                        child: Text(
                          'Close',
                          style: GoogleFonts.baloo2(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
