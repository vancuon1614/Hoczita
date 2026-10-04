import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/widgets/game_sound_toggle_button.dart';
import 'mini_game_how_to_play_sheet.dart';

class GameDifficultyOption {
  final String id;
  final String tabLabel;
  final String modeTitle;
  final String modeSubtitle;
  final String timerTag;
  final String wordLimitInfo;
  final String timeInfo;
  final String hintInfo;
  final String rewardInfo;
  final String tipFromHocDi;
  final Widget interactivePreview;
  final Color themeColor;

  const GameDifficultyOption({
    required this.id,
    required this.tabLabel,
    required this.modeTitle,
    required this.modeSubtitle,
    required this.timerTag,
    required this.wordLimitInfo,
    required this.timeInfo,
    required this.hintInfo,
    required this.rewardInfo,
    required this.tipFromHocDi,
    required this.interactivePreview,
    this.themeColor = const Color(0xFF006D38),
  });
}

class MiniGameLobbyScreen extends StatefulWidget {
  final String gameTitle;
  final String categoryBadge;
  final String welcomeTitle;
  final String welcomeSubtitle;
  final List<GameDifficultyOption> difficulties;
  final int initialDifficultyIndex;
  final List<GameTutorialStep> tutorialSteps;
  final void Function(GameDifficultyOption difficulty) onPlay;
  final int starsCount;

  const MiniGameLobbyScreen({
    super.key,
    required this.gameTitle,
    this.categoryBadge = 'Mini-Game Trí Tuệ',
    required this.welcomeTitle,
    this.welcomeSubtitle = 'Chọn mức độ thử thách hôm nay của bạn',
    required this.difficulties,
    this.initialDifficultyIndex = 0,
    required this.tutorialSteps,
    required this.onPlay,
    this.starsCount = 0,
  });

  @override
  State<MiniGameLobbyScreen> createState() => _MiniGameLobbyScreenState();
}

class _MiniGameLobbyScreenState extends State<MiniGameLobbyScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialDifficultyIndex;
  }

  @override
  void dispose() {
    TtsService.instance.stopAll();
    super.dispose();
  }

  void _openHowToPlay() {
    final currentDiff = widget.difficulties[_selectedIndex];
    MiniGameHowToPlaySheet.show(
      context,
      gameTitle: widget.gameTitle,
      steps: widget.tutorialSteps,
      tipText: currentDiff.tipFromHocDi,
      onStart: () => widget.onPlay(currentDiff),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDiff = widget.difficulties[_selectedIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF191C1E), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          widget.gameTitle,
          style: GoogleFonts.baloo2(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF191C1E),
          ),
        ),
        centerTitle: true,
        actions: [
          const GameSoundToggleButton(),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFDCBB).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFF885200), size: 18),
                const SizedBox(width: 4),
                Text(
                  '${widget.starsCount} ⭐',
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF885200),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Mascot Banner
              _buildMascotBanner(),
              const SizedBox(height: 14),

              // 2. Segmented Difficulty Tabs
              _buildSegmentedTabs(),
              const SizedBox(height: 16),

              // 3. Central Hero Showcase Card
              _buildHeroCard(currentDiff),
              const SizedBox(height: 18),

              // 4. Action CTA Buttons
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => widget.onPlay(currentDiff),
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 24, color: Colors.white),
                  label: Text(
                    'Đã Hiểu & Bắt Đầu Chơi Ngay',
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 3,
                    shadowColor: AppColors.primary.withValues(alpha: 0.35),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Secondary Button: Hướng dẫn nhanh 1 phút
              SizedBox(
                height: 48,
                child: TextButton.icon(
                  onPressed: _openHowToPlay,
                  icon: const Icon(Icons.menu_book_rounded, size: 20, color: Color(0xFF475569)),
                  label: Text(
                    'Xem Hướng Dẫn Nhanh 1 Phút',
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFECEEF1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
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

  Widget _buildMascotBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // HocDi Avatar
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE8F0FE),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
            ),
            child: ClipOval(
              child: Image.asset(
                'ImageFolder/Designer.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.smart_toy_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.gameTitle.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF885200),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFDCBB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.categoryBadge,
                        style: GoogleFonts.baloo2(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF885200),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.welcomeTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF191C1E),
                  ),
                ),
                Text(
                  widget.welcomeSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Audio / Tip Action
          ValueListenableBuilder<bool>(
            valueListenable: TtsService.instance.isSpeakingNotifier,
            builder: (context, isSpeaking, _) {
              return IconButton(
                icon: Icon(
                  Icons.volume_up_rounded,
                  color: isSpeaking ? AppColors.primary : AppColors.textSecondary,
                ),
                tooltip: 'Nghe lời chào',
                onPressed: () {
                  TtsService.instance.speakVietnamese(widget.welcomeTitle, forced: true);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E8EB),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: List.generate(widget.difficulties.length, (index) {
          final isSelected = index == _selectedIndex;
          final diff = widget.difficulties[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    diff.tabLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : const Color(0xFF3F4852),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeroCard(GameDifficultyOption diff) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode Title & Tag Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: diff.themeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      diff.modeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: diff.themeColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF885200)),
                  const SizedBox(width: 4),
                  Text(
                    diff.timerTag,
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF885200),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            diff.modeSubtitle,
            style: GoogleFonts.baloo2(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          // Interactive Simulation Preview Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: diff.interactivePreview,
          ),
          const SizedBox(height: 16),

          // 4 Detail Info Tiles
          _buildInfoTile(
            icon: Icons.title_rounded,
            title: 'Quy cách & Giới hạn',
            value: diff.wordLimitInfo,
          ),
          _buildInfoTile(
            icon: Icons.hourglass_top_rounded,
            title: 'Thời gian làm bài',
            value: diff.timeInfo,
          ),
          _buildInfoTile(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Gợi ý trợ giúp',
            value: diff.hintInfo,
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF6CFE9F).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00B460).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.military_tech_rounded, color: Color(0xFF006D38), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: 'Phần thưởng hoàn thành: ',
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF006D38),
                      ),
                      children: [
                        TextSpan(
                          text: diff.rewardInfo,
                          style: GoogleFonts.baloo2(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF006D38),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tip box from HocDi
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFDCBB).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFB869).withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFDCBB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, size: 16, color: Color(0xFF885200)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mẹo nhỏ từ HocDi:',
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF885200),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        diff.tipFromHocDi,
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          color: const Color(0xFF3F4852),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFECEEF1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF3F4852)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.baloo2(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF191C1E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
