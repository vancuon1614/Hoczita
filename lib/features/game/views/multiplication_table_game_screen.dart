import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/widgets/mini_game_timer.dart';
import '../../../core/widgets/game_sound_toggle_button.dart';
import '../../../core/widgets/pastel_toy_card.dart';
import '../../../core/providers/game_interaction_provider.dart';
import '../../../core/services/game_score_sync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../utils/multiplication_question_generator.dart';
import 'common/mini_game_rank_banner.dart';

class MultiplicationTableGameScreen extends ConsumerStatefulWidget {
  final int? initialTable; // 2..9 or null for selection lobby

  const MultiplicationTableGameScreen({
    super.key,
    this.initialTable,
  });

  @override
  ConsumerState<MultiplicationTableGameScreen> createState() =>
      _MultiplicationTableGameScreenState();
}

class _MultiplicationTableGameScreenState
    extends ConsumerState<MultiplicationTableGameScreen>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  int _selectedTable = 2; // 0: tổng hợp, 2..9: bảng tương ứng
  MultiplicationLevel _selectedLevel = MultiplicationLevel.easy;
  int _currentQuestionIndex = 0;
  List<MultiplicationQuestionModel> _questions = [];

  int _score = 0;
  int _combo = 1;
  int _maxCombo = 1;
  int _correctAnswers = 0;
  final List<bool?> _questionResults = List.filled(10, null);
  final List<int?> _userSelectedAnswers = List.filled(10, null);

  int? _selectedBubbleIndex;
  bool _isAnswering = false;

  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isGameOver = false;
  bool _isSavingScore = false;

  String _mascotMessage = 'Cùng Bé Ong tính thật nhanh để mang mật ngọt về tổ nào!';

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    if (widget.initialTable != null) {
      _startRound(MultiplicationLevel.easy);
    }
  }

  @override
  void dispose() {
    ref.read(isGameActiveProvider.notifier).state = false;
    _timer?.cancel();
    _animController.dispose();
    TtsService.instance.stopAll();
    super.dispose();
  }

  void _startRound(MultiplicationLevel level) {
    _timer?.cancel();
    _animController.reset();

    final levelName = level == MultiplicationLevel.easy
        ? 'Dễ'
        : level == MultiplicationLevel.medium
            ? 'Trung bình'
            : 'Toán đố Thực tế';

    setState(() {
      _selectedLevel = level;
      _selectedTable = 0; // Luôn dùng toàn bộ bảng cửu chương 2 đến 9
      _isPlaying = true;
      _isGameOver = false;
      _isSavingScore = false;
      _currentQuestionIndex = 0;
      _score = 0;
      _combo = 1;
      _maxCombo = 1;
      _correctAnswers = 0;
      _secondsElapsed = 0;
      _selectedBubbleIndex = null;
      _isAnswering = false;
      for (int i = 0; i < 10; i++) {
        _questionResults[i] = null;
        _userSelectedAnswers[i] = null;
      }
      _questions = MultiplicationQuestionGenerator.generateQuestions(
        tableNumber: 0,
        level: level,
      );
      _mascotMessage = 'Cấp độ $levelName. Chúc bạn làm thật tốt nhé!';
    });

    ref.read(isGameActiveProvider.notifier).state = true;
    _startTimer();
    _speakCurrentQuestion();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (!_isGameOver) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  void _speakCurrentQuestion({bool forced = false}) {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;
    final q = _questions[_currentQuestionIndex];
    TtsService.instance.speakVietnamese(q.ttsPrompt, forced: forced);
  }

  void _handleBubbleTap(int bubbleIndex) {
    if (_isAnswering || _isGameOver || _questions.isEmpty) return;

    final q = _questions[_currentQuestionIndex];
    final chosenOpt = q.options[bubbleIndex];
    final isCorrect = (chosenOpt.value == q.correctResult);

    setState(() {
      _isAnswering = true;
      _selectedBubbleIndex = bubbleIndex;
      _userSelectedAnswers[_currentQuestionIndex] = chosenOpt.value;
    });

    _animController.forward(from: 0.0);

    if (isCorrect) {
      // Chuẩn hóa thang điểm: Mỗi câu đúng 3 điểm + thưởng Combo tối đa 2 điểm -> 3..5 điểm/câu (Tối đa 47 điểm cho 10 câu đúng)
      final int roundPoints = 3 + min<int>(_combo - 1, 2);
      final newCombo = _combo + 1;

      setState(() {
        _score += roundPoints;
        _correctAnswers++;
        _combo = newCombo;
        if (_combo > _maxCombo) _maxCombo = _combo;
        _questionResults[_currentQuestionIndex] = true;

        if (_combo >= 4) {
          _mascotMessage = 'Đúng liên tiếp ${_combo - 1} câu rồi! Bạn đỉnh quá!';
        } else if (_combo >= 2) {
          _mascotMessage = 'Chính xác! Chuỗi combo x$_combo!';
        } else {
          _mascotMessage = 'Đúng rồi, bạn giỏi lắm! Tiếp tục nào!';
        }
      });

      // Giảm thời gian chờ chuyển câu: 380ms cho câu đúng, 550ms cho câu sai
      Timer(const Duration(milliseconds: 380), _nextQuestion);
    } else {
      setState(() {
        _combo = 1;
        _questionResults[_currentQuestionIndex] = false;
        _mascotMessage = 'Chưa đúng rồi! Cố gắng ở câu tiếp theo nhé!';
      });

      Timer(const Duration(milliseconds: 550), _nextQuestion);
    }
  }

  void _nextQuestion() {
    if (!mounted || _isGameOver) return;

    if (_currentQuestionIndex + 1 < _questions.length) {
      setState(() {
        _currentQuestionIndex++;
        _selectedBubbleIndex = null;
        _isAnswering = false;
      });
      _animController.reset();
      _speakCurrentQuestion();
    } else {
      _endGame();
    }
  }

  void _endGame() async {
    _timer?.cancel();
    setState(() {
      _isGameOver = true;
      _isAnswering = false;
    });

    int stars = 0;
    if (_correctAnswers >= 9) {
      stars = 3;
    } else if (_correctAnswers >= 7) {
      stars = 2;
    } else if (_correctAnswers >= 4) {
      stars = 1;
    }

    setState(() {
      _isSavingScore = true;
    });

    // Đồng bộ điểm song song (Local Cache, Supabase, NKS SCRMAI API)
    final authState = ref.read(authProvider);
    final memberName = authState.username ?? 'Học sinh';
    final levelStr = _selectedLevel == MultiplicationLevel.easy
        ? '1'
        : _selectedLevel == MultiplicationLevel.medium
            ? '2'
            : '3';

    try {
      await GameScoreSyncService.instance.saveScoreParallel(
        gameCodeOrName: 'M02',
        level: levelStr,
        score: _score,
        stars: stars,
        memberName: memberName,
      );
    } catch (e) {
      debugPrint('Error saving multiplication score: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingScore = false;
        });
      }
    }
  }

  void _showQuitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Dừng Vòng Chơi?',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Tiến trình câu hỏi hiện tại sẽ không được lưu nếu bạn thoát ra lúc này.',
          style: GoogleFonts.baloo2(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Chơi tiếp',
              style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              setState(() {
                _isPlaying = false;
              });
              _timer?.cancel();
              TtsService.instance.stopAll();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(
              'Thoát ra',
              style: GoogleFonts.baloo2(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlaying) {
      return _buildTableSelectionLobby();
    }

    if (_isGameOver) {
      return _buildSummaryScreen();
    }

    return _buildGameplayScreen();
  }

  Widget _buildTableSelectionLobby() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Bảng Cửu Chương',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 20,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: GameSoundToggleButton(isPlayScreen: false),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00629D), Color(0xFF00A3FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00629D).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'TOÁN TIỂU HỌC',
                              style: GoogleFonts.baloo2(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFCFE5FF),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Thử Thách Phép Nhân',
                            style: GoogleFonts.baloo2(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chạm bóng bay tìm kết quả đúng, tích luỹ điểm số và rèn luyện phản xạ nhanh nhẹn!',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              color: const Color(0xFFCFE5FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'ImageFolder/Multiplication.webp',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Text(
                              '✖️',
                              style: TextStyle(fontSize: 34),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Header: BẢN ĐỒ VƯỢT ẢI + Nút Thưởng Phản Xạ Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BẢN ĐỒ VƯỢT ẢI',
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showBonusExplanationDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF1D4ED8)),
                          const SizedBox(width: 4),
                          Text(
                            'Thưởng Phản Xạ',
                            style: GoogleFonts.baloo2(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // TẦNG 3: BỨT PHÁ (Toán Đố Thực Tế - Tím Tinh Anh)
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: _buildTowerTierCard(
                  tierNumber: 3,
                  tierLabel: 'CHẶNG 3 • BỨT PHÁ',
                  tagText: 'Ứng Dụng Thực Tế',
                  title: 'Toán Đố Thực Tế',
                  subtitle: 'Tình huống đời sống (Mua kẹo, chia quà...)',
                  emoji: '🏆',
                  primaryColor: const Color(0xFF7C3AED),
                  lightBgColor: const Color(0xFFF5F3FF),
                  borderColor: const Color(0xFFDDD6FE),
                  gradientColors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                  difficultyText: 'Khó',
                  onTap: () => _startRound(MultiplicationLevel.hard),
                ),
              ),

              _buildCurvedPathConnector(curveToRight: true),

              // TẦNG 2: SUY LUẬN (Cấp Độ Vừa - Cam Ấm)
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: _buildTowerTierCard(
                  tierNumber: 2,
                  tierLabel: 'CHẶNG 2 • SUY LUẬN',
                  tagText: 'Tư Duy & Điền Khuyết',
                  title: 'Cấp Độ Vừa',
                  subtitle: 'Điền khuyết ẩn số rèn tư duy toán học (? × 9 = 18)',
                  emoji: '🧩',
                  primaryColor: const Color(0xFFD97706),
                  lightBgColor: const Color(0xFFFFF7ED),
                  borderColor: const Color(0xFFFED7AA),
                  gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                  difficultyText: 'Trung bình',
                  onTap: () => _startRound(MultiplicationLevel.medium),
                ),
              ),

              _buildCurvedPathConnector(curveToRight: false),

              // TẦNG 1: KHỞI ĐỘNG (Cấp Độ Dễ - Xanh Ngọc)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildTowerTierCard(
                  tierNumber: 1,
                  tierLabel: 'CHẶNG 1 • KHỞI ĐỘNG',
                  tagText: 'Bảng Nhân 2 - 9',
                  title: 'Cấp Độ Dễ',
                  subtitle: 'Phép nhân cơ bản rèn phản xạ nhanh (2 × 9 = ?)',
                  emoji: '🌱',
                  primaryColor: const Color(0xFF059669),
                  lightBgColor: const Color(0xFFF0FDF4),
                  borderColor: const Color(0xFFA7F3D0),
                  gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
                  difficultyText: 'Dễ',
                  onTap: () => _startRound(MultiplicationLevel.easy),
                ),
              ),

              const SizedBox(height: 28),

              // Footer Card quy chuẩn & phần thưởng
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x06000000),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('🎯', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QUY CHUẨN VÒNG CHƠI',
                            style: GoogleFonts.baloo2(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            '10 câu hỏi bóng bay tính nhanh',
                            style: GoogleFonts.baloo2(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                    const SizedBox(width: 12),
                    const Text('⚡', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HỆ SỐ PHẦN THƯỞNG',
                            style: GoogleFonts.baloo2(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            'Thưởng Phản Xạ Kép',
                            style: GoogleFonts.baloo2(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurvedPathConnector({
    required bool curveToRight,
  }) {
    return SizedBox(
      height: 38,
      child: CustomPaint(
        painter: _CurvedDashedPathPainter(curveToRight: curveToRight),
      ),
    );
  }

  Widget _buildTowerTierCard({
    required int tierNumber,
    required String tierLabel,
    required String tagText,
    required String title,
    required String subtitle,
    required String emoji,
    required Color primaryColor,
    required Color lightBgColor,
    required Color borderColor,
    required List<Color> gradientColors,
    required String difficultyText,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Sub-badge hàng trên: Số tầng + Tên chặng + Tag
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$tierNumber',
                      style: GoogleFonts.baloo2(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tierLabel,
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: lightBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor.withValues(alpha: 0.6)),
                ),
                child: Text(
                  tagText,
                  style: GoogleFonts.baloo2(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // 2. Thẻ Pastel Toy Card tương tác
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0x06000000),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                child: Row(
                  children: [
                    // Squircle Pastel Toy Icon (Màu nhạt mềm mại như hình mẫu)
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: lightBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Tiêu đề, mô tả và vạch tiến độ 3 nấc
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.baloo2(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: GoogleFonts.baloo2(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              for (int i = 1; i <= 3; i++) ...[
                                Container(
                                  width: 14,
                                  height: 4.5,
                                  decoration: BoxDecoration(
                                    color: i <= tierNumber ? primaryColor : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                if (i < 3) const SizedBox(width: 3),
                              ],
                              const SizedBox(width: 6),
                              Text(
                                difficultyText,
                                style: GoogleFonts.baloo2(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Mũi tên điều hướng
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: lightBgColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor.withValues(alpha: 0.8)),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showBonusExplanationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.bolt_rounded, size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cơ Chế Thưởng Điểm',
                          style: GoogleFonts.baloo2(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Bí kíp chinh phục Bảng Cửu Chương',
                          style: GoogleFonts.baloo2(
                            fontSize: 12.5,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildBonusInfoRow(
                icon: '🔥',
                title: 'Chuỗi Combo Liên Tiếp',
                desc: 'Mỗi câu trả lời đúng liên tiếp sẽ tăng chuỗi Combo, cộng thêm điểm thưởng cho mỗi câu tiếp theo.',
              ),
              const SizedBox(height: 12),
              _buildBonusInfoRow(
                icon: '⚡',
                title: 'Thưởng Phản Xạ Kép',
                desc: 'Phản xạ tính nhẩm càng nhanh, điểm tích lũy và số sao đạt được sau 10 câu hỏi càng cao!',
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Đã hiểu',
                      style: GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBonusInfoRow({
    required String icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.baloo2(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameplayScreen() {
    final q = _questions[_currentQuestionIndex];
    final isNearEnd = _currentQuestionIndex >= 7;
    final tableTitle = _selectedTable == 0
        ? 'TỔNG HỢP'
        : 'BẢNG CỬU CHƯƠNG $_selectedTable';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Bảng Cửu Chương',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00375A),
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: _showQuitConfirmation,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GameSoundToggleButton(
              padding: EdgeInsets.zero,
              onToggled: (enabled) {
                if (enabled) {
                  _speakCurrentQuestion(forced: true);
                }
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hàng Sub-Header: Tiến độ câu hỏi & Timer (như Hình 2 & 1)
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
                                'Câu ${_currentQuestionIndex + 1}/10 • Về đích',
                                style: GoogleFonts.baloo2(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Câu ${_currentQuestionIndex + 1}/10',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                  ),

                  // Timer Pill chuẩn Hình 1: format 00:00, cố định khung không thụt ra/vào
                  GameCountUpTimer(
                    elapsedSeconds: _secondsElapsed,
                    margin: EdgeInsets.zero,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 2. Thẻ Bé Ong Hội Thoại & Thanh Tiến Trình (LUÔN HIỆN XUYÊN SUỐT GAME)
              _buildMascotCard(),
              const SizedBox(height: 10),

              // 3. KHUNG CÂU HỎI (Tiêu đề tag theo mẫu Hình 4)
              Expanded(
                flex: 4,
                child: _buildProblemArena(q, tableTitle),
              ),

              const SizedBox(height: 12),

              // 4. 4 THẺ ĐÁP ÁN LỰA CHỌN (2x2 Grid)
              Expanded(
                flex: 3,
                child: _buildBubbleGrid(q),
              ),

              // (KHÔNG SỬ DỤNG THIẾT KẾ CỦA HÌNH 3 - LƯỢC BỎ HOÀN TOÀN THANH ĐÁY)
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  String _getMascotDialogue() {
    final remaining = 10 - _currentQuestionIndex;
    if (remaining == 1) {
      return 'Cố lên! Chỉ còn 1 câu nữa thôi bé ơi! 🐝';
    } else if (remaining == 2) {
      return 'Cố lên! Còn 2 câu nữa thôi bé ơi! 🐝';
    } else if (remaining == 3) {
      return 'Cố lên! Còn 3 câu nữa thôi bé ơi! 🐝';
    }
    return _mascotMessage;
  }

  Widget _buildMascotCard() {
    final isNearEnd = _currentQuestionIndex >= 7;
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
              // Avatar Bé Ong (huy hiệu ngôi sao xanh chỉ xuất hiện khi còn 3 câu cuối)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
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
                    child: const Text('🐝', style: TextStyle(fontSize: 22)),
                  ),
                  if (isNearEnd)
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
                          'Bé Ong Học Đi',
                          style: GoogleFonts.baloo2(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        Text(
                          'Câu ${_currentQuestionIndex + 1} / 10',
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
                      _getMascotDialogue(),
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

          // Thanh tiến trình phân đoạn 10 vạch
          Row(
            children: List.generate(10, (i) {
              final isDone = i < _currentQuestionIndex;
              final isCurrent = i == _currentQuestionIndex;
              Color segColor = const Color(0xFFFDE68A);
              if (isDone) {
                segColor = const Color(0xFF047857); // xanh lá đậm
              } else if (isCurrent) {
                segColor = const Color(0xFFF59E0B); // cam vàng câu hiện tại
              }
              return Expanded(
                child: Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: segColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemArena(MultiplicationQuestionModel q, String tableTitle) {
    final isNearEnd = _currentQuestionIndex >= 7;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCCE3F5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00629D).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tiêu đề tag (kèm icon 📢 duy nhất ở 3 câu cuối)
          if (isNearEnd) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📢', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(
                    'Thử thách về đích cùng Bé Ong',
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Khung câu hỏi phụ bên trong (Card-in-Card nền xanh nhạt Color(0xFFF0F5FA))
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5FA),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    q.questionText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.baloo2(
                      fontSize: q.level == MultiplicationLevel.hard ? 18.5 : 32,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF00588A),
                      letterSpacing: q.level == MultiplicationLevel.hard ? 0.3 : 1.2,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleGrid(MultiplicationQuestionModel q) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) {
            return _buildBubbleItem(index, q);
          },
        );
      },
    );
  }

  Widget _buildBubbleItem(int index, MultiplicationQuestionModel q) {
    final opt = q.options[index];
    final isSelected = (_selectedBubbleIndex == index);
    final labels = ['(A)', '(B)', '(C)', '(D)'];
    final colors = PastelToyCardColor.standardFour;

    Widget card = PastelToyCard(
      label: labels[index % 4],
      title: opt.display,
      colorConfig: colors[index % 4],
      isSelected: isSelected,
      isCorrect: null, // Tắt tự động chọn/tiết lộ đáp án khi chơi, xem ở report cuối cùng
      onTap: () => _handleBubbleTap(index),
    );

    if (isSelected) {
      card = ScaleTransition(
        scale: _scaleAnimation,
        child: card,
      );
    }

    return card;
  }

  Widget _buildSummaryScreen() {
    int stars = 0;
    if (_correctAnswers >= 9) {
      stars = 3;
    } else if (_correctAnswers >= 7) {
      stars = 2;
    } else if (_correctAnswers >= 4) {
      stars = 1;
    }

    final elapsedStr = GameCountUpTimer.formatSeconds(_secondsElapsed);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Trophy Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: stars > 0 ? const Color(0xFFFFF9E6) : AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      stars > 0 ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                      color: stars > 0 ? Colors.amber : AppColors.primary,
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  stars > 0 ? 'Tuyệt Vời! 🎉' : 'Lần Sau Cố Gắng Hơn Nhé!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),

                Text(
                  'Bạn đã trả lời đúng $_correctAnswers/10 câu đố trong $elapsedStr.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                // Animated Star Rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final active = index < stars;
                    return AnimatedScale(
                      scale: active ? 1.2 : 1.0,
                      duration: Duration(milliseconds: 300 + (index * 150)),
                      curve: Curves.elasticOut,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.star_rounded,
                          size: 36,
                          color: active ? Colors.amber : AppColors.border,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Time & Score Cards
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Thời gian',
                              style: GoogleFonts.baloo2(fontSize: 10, color: AppColors.primary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              elapsedStr,
                              style: GoogleFonts.baloo2(
                                fontSize: 16,
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
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F8F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Điểm cộng',
                              style: GoogleFonts.baloo2(fontSize: 10, color: AppColors.success),
                            ),
                            const SizedBox(height: 2),
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
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                MiniGameRankBanner(
                  gameName: 'multiplication_table',
                  gameTitle: 'Bảng Cửu Chương',
                  currentScore: _score,
                ),

                // Detailed results table
                const SizedBox(height: 24),
                Text(
                  'Chi Tiết Kết Quả 📊',
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
                      onPressed: _isSavingScore
                          ? null
                          : () {
                              setState(() => _isPlaying = false);
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
                              'Quay lại danh mục',
                              style: GoogleFonts.baloo2(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                height: 1.2,
                              ),
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
          itemCount: _questions.length.clamp(0, 10),
          itemBuilder: (context, index) {
            final isCorrect = _questionResults[index] == true;
            final Color color = isCorrect ? AppColors.success : AppColors.error;

            return InkWell(
              onTap: () => _showQuestionDetailDialog(index),
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

  void _showQuestionDetailDialog(int index) {
    if (index >= _questions.length) return;
    final q = _questions[index];
    final userAns = _userSelectedAnswers[index];
    final isCorrect = _questionResults[index] == true;

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
                      'Câu hỏi ${index + 1}',
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
                      Text(
                        q.questionText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Đáp án đúng: ${q.correctDisplay}',
                        style: GoogleFonts.baloo2(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      if (userAns != null && !isCorrect) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Bạn đã chọn: $userAns',
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ],
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

class _CurvedDashedPathPainter extends CustomPainter {
  final bool curveToRight;

  const _CurvedDashedPathPainter({required this.curveToRight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (curveToRight) {
      // From top-left to bottom-right (Chặng 3 xuống Chặng 2)
      path.moveTo(size.width * 0.32, 0);
      path.cubicTo(
        size.width * 0.32,
        size.height * 0.55,
        size.width * 0.68,
        size.height * 0.45,
        size.width * 0.68,
        size.height,
      );
    } else {
      // From top-right to bottom-left (Chặng 2 xuống Chặng 1)
      path.moveTo(size.width * 0.68, 0);
      path.cubicTo(
        size.width * 0.68,
        size.height * 0.55,
        size.width * 0.32,
        size.height * 0.45,
        size.width * 0.32,
        size.height,
      );
    }

    // Vẽ nét đứt mềm mại
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      const dashLength = 6.0;
      const spaceLength = 5.0;
      while (distance < metric.length) {
        final len = (distance + dashLength < metric.length)
            ? dashLength
            : metric.length - distance;
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += dashLength + spaceLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CurvedDashedPathPainter oldDelegate) =>
      oldDelegate.curveToRight != curveToRight;
}

