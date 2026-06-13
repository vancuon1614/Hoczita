import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  final SupabaseService _db = SupabaseService.instance;
  late Future<List<Map<String, dynamic>>> _leaderboardFuture;
  late Future<int> _totalScoreFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _leaderboardFuture = _db.getLeaderboard();
      _totalScoreFuture = _db.getTotalScore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final username = authState.username ?? 'Học sinh';
    final email = authState.email ?? 'guest@hoczita.edu.vn';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hồ sơ của bạn',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(authProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info card
              _buildUserCard(username, email),
              const SizedBox(height: 32),

              // Leaderboard header
              const Row(
                children: [
                  Icon(Icons.emoji_events_rounded, color: AppColors.accent, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Bảng Xếp Hạng Tháng 🏆',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Leaderboard List
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _leaderboardFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'Chưa có dữ liệu bảng xếp hạng.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }

                  final list = snapshot.data!;
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        color: AppColors.border,
                        indent: 20,
                        endIndent: 20,
                      ),
                      itemBuilder: (context, index) {
                        final rank = index + 1;
                        final entry = list[index];
                        final user = entry['username'] as String? ?? 'Ẩn danh';
                        final score = entry['total_score'] as int? ?? 0;

                        // Custom styling for top 3
                        Color medalColor = Colors.transparent;
                        if (rank == 1) medalColor = const Color(0xFFFFD700); // Gold
                        if (rank == 2) medalColor = const Color(0xFFC0C0C0); // Silver
                        if (rank == 3) medalColor = const Color(0xFFCD7F32); // Bronze

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            children: [
                              // Rank number or Medal
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: medalColor == Colors.transparent
                                      ? AppColors.primaryLight
                                      : medalColor,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  rank.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: medalColor == Colors.transparent
                                        ? AppColors.primary
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Name
                              Expanded(
                                child: Text(
                                  user,
                                  style: TextStyle(
                                    fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                              ),

                              // Score
                              Text(
                                '$score điểm',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(String username, String email) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 20),

          // User details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 12),
                // Score info
                FutureBuilder<int>(
                  future: _totalScoreFuture,
                  builder: (context, snapshot) {
                    final points = snapshot.data ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, color: AppColors.accent, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '$points điểm tích lũy',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
