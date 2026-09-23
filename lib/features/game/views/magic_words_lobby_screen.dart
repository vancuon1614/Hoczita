import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../utils/wend_puzzle_generator.dart';
import 'common/mini_game_how_to_play_sheet.dart';
import 'common/mini_game_lobby_screen.dart';
import 'magic_words_game_screen.dart';

class MagicWordsLobbyScreen extends StatefulWidget {
  const MagicWordsLobbyScreen({super.key});

  @override
  State<MagicWordsLobbyScreen> createState() => _MagicWordsLobbyScreenState();
}

class _MagicWordsLobbyScreenState extends State<MagicWordsLobbyScreen> {
  int _highestStars = 0;

  @override
  void initState() {
    super.initState();
    _loadStars();
  }

  @override
  void dispose() {
    TtsService.instance.stopAll();
    super.dispose();
  }

  Future<void> _loadStars() async {
    try {
      final stars = await SupabaseService.instance.getHighestStarsForGame('magic_words');
      if (mounted) {
        setState(() => _highestStars = stars);
      }
    } catch (_) {}
  }

  Widget _buildPreviewBox({
    required List<String> letters,
    required String meaning,
    required Color color,
  }) {
    final word = letters.join('');
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
                return IconButton(
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.volume_up_rounded,
                    color: isSpeaking ? AppColors.primary : AppColors.textSecondary,
                  ),
                  tooltip: 'Nghe phát âm từ mẫu',
                  onPressed: () => TtsService.instance.speakEnglish(word),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: letters.map((char) {
            return Container(
              width: 42,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 4),
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate_rounded, size: 16, color: Color(0xFF00B460)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  meaning,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<bool>(
                valueListenable: TtsService.instance.isSpeakingNotifier,
                builder: (context, isSpeaking, _) {
                  return InkWell(
                    onTap: () => TtsService.instance.speakEnglish(word),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.volume_up_rounded,
                        size: 18,
                        color: isSpeaking ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MiniGameLobbyScreen(
      gameTitle: 'Magic Words',
      categoryBadge: 'Ngoại Ngữ 🇬🇧',
      welcomeTitle: 'Chào mừng bạn đến với Magic Words!',
      welcomeSubtitle: 'Tìm từ ẩn bằng cách nối các ô chữ liên tiếp',
      starsCount: _highestStars,
      difficulties: [
        GameDifficultyOption(
          id: 'easy',
          tabLabel: 'Dễ (5x5)',
          modeTitle: 'Chế độ Dễ (Easy Mode)',
          modeSubtitle: 'Lý tưởng cho người mới bắt đầu hoặc học viên nhỏ tuổi',
          timerTag: '3 Phút',
          wordLimitInfo: 'Ma trận 5x5, tìm 3 từ ngắn (3 - 4 chữ cái)',
          timeInfo: 'Thư giãn tự do hoặc 3 phút êm đềm',
          hintInfo: 'Tặng sẵn 3 gợi ý mở chữ cái đầu & hướng đi',
          rewardInfo: '+10 Điểm ⭐️',
          tipFromHocDi: 'Hãy ưu tiên tìm các nguyên âm (A, E, I, O, U) trước nhé. Hầu hết các từ tiếng Anh đều xoay quanh nguyên âm!',
          themeColor: const Color(0xFF006D38),
          interactivePreview: _buildPreviewBox(
            letters: ['B', 'O', 'O', 'K'],
            meaning: 'Quyển sách (Phiên âm: /bʊk/)',
            color: const Color(0xFF00B460),
          ),
        ),
        GameDifficultyOption(
          id: 'medium',
          tabLabel: 'Trung Bình (6x6)',
          modeTitle: 'Chế độ Trung Bình (Medium Mode)',
          modeSubtitle: 'Cân bằng độ dài từ và tính toán đường đi khéo léo',
          timerTag: '4 Phút',
          wordLimitInfo: 'Ma trận 6x6, tìm 4 từ (3 - 5 chữ cái)',
          timeInfo: '4 phút làm bài tiêu chuẩn',
          hintInfo: 'Tặng sẵn 2 gợi ý mở chữ cái đầu',
          rewardInfo: '+20 Điểm ⭐️',
          tipFromHocDi: 'Quan sát các chữ cái ít gặp như Z, X, V trước để dễ định vị từ dài!',
          themeColor: const Color(0xFF00629D),
          interactivePreview: _buildPreviewBox(
            letters: ['P', 'L', 'A', 'N', 'T'],
            meaning: 'Cây cối (Phiên âm: /plænt/)',
            color: const Color(0xFF0047AB),
          ),
        ),
        GameDifficultyOption(
          id: 'hard',
          tabLabel: 'Cao Thủ (7x7/8x8)',
          modeTitle: 'Chế độ Cao Thủ (Hard Mode)',
          modeSubtitle: 'Đấu trường từ vựng lớn với mạng lưới chữ cái đa chiều',
          timerTag: '5 Phút',
          wordLimitInfo: 'Ma trận 7x7 hoặc 8x8, tìm 5 - 6 từ (4 - 7 chữ cái)',
          timeInfo: '5 phút thi đấu kịch tính',
          hintInfo: '1 gợi ý duy nhất khi thực sự bế tắc',
          rewardInfo: '+35 Điểm ⭐️',
          tipFromHocDi: 'Hãy lần theo các đường ziczac từ các góc của ma trận để không bỏ sót ô chữ nào!',
          themeColor: const Color(0xFF885200),
          interactivePreview: _buildPreviewBox(
            letters: ['F', 'O', 'R', 'E', 'S', 'T'],
            meaning: 'Khu rừng (Phiên âm: /ˈfɒr.ɪst/)',
            color: const Color(0xFF885200),
          ),
        ),
      ],
      tutorialSteps: [
        const GameTutorialStep(
          stepNumber: 1,
          icon: Icons.visibility_rounded,
          themeColor: Color(0xFF00629D),
          title: 'Quan sát bảng chữ & từ cần tìm',
          description: 'Đọc lướt qua danh sách từ gợi ý bên dưới để định hình các chữ cái cần tìm.',
        ),
        const GameTutorialStep(
          stepNumber: 2,
          icon: Icons.touch_app_rounded,
          themeColor: Color(0xFF885200),
          title: 'Kéo vuốt nối các ô chữ liền kề',
          description: 'Chạm vào chữ cái đầu tiên và vuốt liên tục qua các ô lân cận theo đường ziczac.',
        ),
        const GameTutorialStep(
          stepNumber: 3,
          icon: Icons.military_tech_rounded,
          themeColor: Color(0xFF006D38),
          title: 'Tô kín bảng & nhận điểm thưởng',
          description: 'Dùng mỗi ô chữ đúng một lần. Khi giải hết tất cả các từ, bạn sẽ giành chiến thắng!',
        ),
      ],
      onPlay: (diff) {
        MagicWordsDifficulty level;
        if (diff.id == 'hard') {
          level = MagicWordsDifficulty.hard;
        } else if (diff.id == 'medium') {
          level = MagicWordsDifficulty.medium;
        } else {
          level = MagicWordsDifficulty.easy;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MagicWordsGameScreen(difficulty: level),
          ),
        );
      },
    );
  }
}
