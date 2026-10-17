import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/game_code_registry.dart';
import '../../../../core/services/supabase_service.dart';
import 'mini_game_leaderboard_sheet.dart';

class MiniGameRankBanner extends StatefulWidget {
  final String gameName;
  final String gameTitle;
  final int? currentScore;
  final bool? isEnglish;

  const MiniGameRankBanner({
    super.key,
    required this.gameName,
    required this.gameTitle,
    this.currentScore,
    this.isEnglish,
  });

  @override
  State<MiniGameRankBanner> createState() => _MiniGameRankBannerState();
}

class _MiniGameRankBannerState extends State<MiniGameRankBanner> {
  late Future<Map<String, dynamic>> _rankInfoFuture;

  @override
  void initState() {
    super.initState();
    _loadRank();
  }

  @override
  void didUpdateWidget(covariant MiniGameRankBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameName != widget.gameName ||
        oldWidget.currentScore != widget.currentScore) {
      _loadRank();
    }
  }

  void _loadRank() {
    _rankInfoFuture = SupabaseService.instance.getGameRankInfo(
      gameName: widget.gameName,
      currentScore: widget.currentScore,
    );
  }

  void _openLeaderboard(List<Map<String, dynamic>>? leaderboard, bool english) {
    MiniGameLeaderboardSheet.show(
      context,
      gameName: widget.gameName,
      gameTitle: widget.gameTitle,
      initialLeaderboard: leaderboard,
      isEnglish: english,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _rankInfoFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final rank = data?['rank'] as int? ?? 1;
        final topPercent = data?['topPercent'] as int? ?? 10;
        final bestScore = data?['score'] as int? ?? (widget.currentScore ?? 0);
        final leaderboard = data?['leaderboard'] as List<Map<String, dynamic>>?;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        Widget rankIcon;
        if (rank == 1) {
          rankIcon = const Text('🥇', style: TextStyle(fontSize: 24));
        } else if (rank == 2) {
          rankIcon = const Text('🥈', style: TextStyle(fontSize: 24));
        } else if (rank == 3) {
          rankIcon = const Text('🥉', style: TextStyle(fontSize: 24));
        } else {
          rankIcon = Text(
            '#$rank',
            style: GoogleFonts.baloo2(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF92400E),
            ),
          );
        }

        final bool english = widget.isEnglish ?? GameCodeRegistry.isEnglishGame(widget.gameName);

        final rankTitle = isLoading
            ? (english ? 'Calculating rank...' : 'Đang tính thứ hạng...')
            : (english ? '${widget.gameTitle} Rank: #$rank 🏆' : 'BXH ${widget.gameTitle}: Hạng #$rank 🏆');

        final rankSubtitle = isLoading
            ? (english ? 'Syncing your score...' : 'Đang đồng bộ điểm số của bạn...')
            : (widget.currentScore != null && widget.currentScore! > 0
                ? (english ? 'This round: +${widget.currentScore} • Best: $bestScore pts' : 'Ván này: +${widget.currentScore} • Kỷ lục: $bestScore điểm')
                : (english ? 'Best score: $bestScore pts • Top $topPercent%' : 'Điểm kỷ lục: $bestScore điểm • Top $topPercent%'));

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : () => _openLeaderboard(leaderboard, english),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD97706).withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFEF08A), Color(0xFFFDE047)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFACC15).withValues(alpha: 0.4), width: 1),
                    ),
                    alignment: Alignment.center,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFF59E0B),
                            ),
                          )
                        : rankIcon,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rankTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rankSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.baloo2(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isLoading ? null : () => _openLeaderboard(leaderboard, english),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                english ? 'LEADERBOARD' : 'XEM BXH',
                                style: GoogleFonts.baloo2(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
      },
    );
  }
}
