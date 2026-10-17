import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/game_code_registry.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/game_score_sync_service.dart';
import '../../../../core/utils/avatar_utils.dart';

class MiniGameLeaderboardSheet extends StatelessWidget {
  final String gameName;
  final String gameTitle;
  final List<Map<String, dynamic>>? initialLeaderboard;
  final bool? isEnglish;

  const MiniGameLeaderboardSheet({
    super.key,
    required this.gameName,
    required this.gameTitle,
    this.initialLeaderboard,
    this.isEnglish,
  });

  static Future<void> show(
    BuildContext context, {
    required String gameName,
    required String gameTitle,
    List<Map<String, dynamic>>? initialLeaderboard,
    bool? isEnglish,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MiniGameLeaderboardSheet(
        gameName: gameName,
        gameTitle: gameTitle,
        initialLeaderboard: initialLeaderboard,
        isEnglish: isEnglish,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool english = isEnglish ?? GameCodeRegistry.isEnglishGame(gameName);

    return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('🏆', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            english ? '$gameTitle Leaderboard' : 'BXH $gameTitle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.baloo2(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            english ? 'All-time best scores' : 'Điểm kỷ lục theo trò chơi riêng lẻ',
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
                  ],
                ),
              ),
              const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),

              // Leaderboard Body
              Expanded(
                child: initialLeaderboard != null && initialLeaderboard!.isNotEmpty
                    ? _buildList(context, initialLeaderboard!, english)
                    : FutureBuilder<List<Map<String, dynamic>>>(
                        future: GameScoreSyncService.instance.fetchLeaderboardWithFallback(
                          gameCodeOrName: gameName,
                          internalGameName: gameName,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('🎮', style: TextStyle(fontSize: 40)),
                                    const SizedBox(height: 8),
                                    Text(
                                      english ? 'No leaderboard data yet' : 'Chưa có dữ liệu bảng xếp hạng',
                                      style: GoogleFonts.baloo2(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return _buildList(context, snapshot.data!, english);
                        },
                      ),
              ),

              // Bottom Close Button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF334155),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        english ? 'Close' : 'Đóng',
                        style: GoogleFonts.baloo2(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
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

  String _getInitials(String name) {
    final clean = name
        .replaceAll('(Bạn)', '')
        .replaceAll('(ban)', '')
        .replaceAll('(YOU)', '')
        .replaceAll('(you)', '')
        .trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final f = parts.first.isNotEmpty ? parts.first[0] : '';
      final l = parts.last.isNotEmpty ? parts.last[0] : '';
      return (f + l).toUpperCase();
    }
    return clean.substring(0, min(2, clean.length)).toUpperCase();
  }

  Widget _buildList(BuildContext context, List<Map<String, dynamic>> list, bool english) {
    final currentUsername = SupabaseService.instance.currentUsername ?? 'Bạn';

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final rank = index + 1;
        final entry = list[index];
        final rawUsername = entry['username'] as String? ?? 'Ẩn danh';
        final score = entry['total_score'] as int? ?? 0;
        final isMe = rawUsername == currentUsername ||
            rawUsername.startsWith('$currentUsername ') ||
            rawUsername.contains('(Bạn)') ||
            rawUsername.contains('(YOU)') ||
            rawUsername.toLowerCase().contains(currentUsername.toLowerCase());

        final cleanUsername = rawUsername
            .replaceAll('(Bạn)', '')
            .replaceAll('(ban)', '')
            .replaceAll('(YOU)', '')
            .replaceAll('(you)', '')
            .trim();

        final String? avatarUrl = entry['avatar_url'] as String? ?? entry['avatar'] as String?;
        final ImageProvider? avatarImage = resolveAvatarImage(avatarUrl);

        Widget rankBadge;
        if (rank == 1) {
          rankBadge = const Text('🥇', style: TextStyle(fontSize: 22));
        } else if (rank == 2) {
          rankBadge = const Text('🥈', style: TextStyle(fontSize: 22));
        } else if (rank == 3) {
          rankBadge = const Text('🥉', style: TextStyle(fontSize: 22));
        } else {
          rankBadge = Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isMe ? AppColors.primary : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: GoogleFonts.baloo2(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isMe ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFEFF6FF) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMe ? AppColors.primary.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
              width: isMe ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Center(child: rankBadge),
              ),
              const SizedBox(width: 8),
              // Avatar người chơi
              ClipOval(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: avatarImage != null
                      ? Image(
                          image: avatarImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFF1F5F9),
                            alignment: Alignment.center,
                            child: Text(
                              _getInitials(cleanUsername),
                              style: GoogleFonts.baloo2(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFF1F5F9),
                          alignment: Alignment.center,
                          child: Text(
                            _getInitials(cleanUsername),
                            style: GoogleFonts.baloo2(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        cleanUsername,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontSize: 14,
                          fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                          color: isMe ? AppColors.primary : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          english ? 'YOU' : 'BẠN',
                          style: GoogleFonts.baloo2(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                english ? '$score pts' : '$score điểm',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isMe ? const Color(0xFF059669) : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
