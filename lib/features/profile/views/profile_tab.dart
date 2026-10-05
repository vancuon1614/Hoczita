import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/utils/avatar_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../learn/views/advising_booking_screen.dart';
import 'profile_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  final SupabaseService _db = SupabaseService.instance;
  late Future<List<Map<String, dynamic>>> _leaderboardFuture;
  late Future<int> _totalScoreFuture;
  String? _avatarPath;

  String? _selectedGameFilter;
  String _selectedTimeFilter =
      'month'; // default matches the monthly leaderboard
  bool _showFullLeaderboard = false;

  // Local caching variables
  String? _cachedName;
  String? _cachedAvatar;
  int? _cachedPoint;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    _loadCachedUserData();
    setState(() {
      _leaderboardFuture = _db.getFilteredLeaderboard(
        gameName: _selectedGameFilter,
        timePeriod: _selectedTimeFilter,
      );
      _totalScoreFuture = _db.getTotalScore().then((score) {
        // Sync point back to cache
        final email = ref.read(authProvider).email?.trim().toLowerCase() ?? '';
        if (email.isNotEmpty) {
          SharedPreferences.getInstance().then((prefs) {
            prefs.setInt('cached_user_point_$email', score);
          });
          setState(() {
            _cachedPoint = score;
          });
        }
        return score;
      });
    });
    _loadAvatarPath();
    _fetchLatestUserDataFromServer();
  }

  void _updateLeaderboard() {
    setState(() {
      _leaderboardFuture = _db.getFilteredLeaderboard(
        gameName: _selectedGameFilter,
        timePeriod: _selectedTimeFilter,
      );
    });
  }

  Future<void> _loadCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = ref.read(authProvider).email?.trim().toLowerCase() ?? '';
      if (email.isNotEmpty) {
        setState(() {
          _cachedName = prefs.getString('cached_user_name_$email');
          _cachedAvatar = prefs.getString('cached_user_avatar_$email');
          _cachedPoint = prefs.getInt('cached_user_point_$email');
        });
      }
    } catch (e) {
      debugPrint('Error loading cached user data: $e');
    }
  }

  Future<void> _fetchLatestUserDataFromServer() async {
    try {
      final apiService = ApiService.instance;
      if (apiService.hasToken) {
        final response = await apiService.getUserInfo();
        final bool isSuccess =
            response['success'] ?? (response['error'] == null);
        if (isSuccess && response['data'] != null) {
          final data = response['data'];
          final email = data['email'] ?? '';
          final name = data['name'] ?? data['username'] ?? email.split('@')[0];
          final avatar = data['avatar'] ?? '';
          final point = data['point'] ?? 0;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_user_name_$email', name);
          await prefs.setString('cached_user_avatar_$email', avatar);
          await prefs.setInt('cached_user_point_$email', point);

          if (mounted) {
            setState(() {
              _cachedName = name;
              _cachedAvatar = avatar;
              _cachedPoint = point;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching latest user data from server: $e');
    }
  }

  Future<void> _loadAvatarPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = ref.read(authProvider).email?.trim().toLowerCase();
      String? avatarPath;
      if (email != null && email.isNotEmpty) {
        avatarPath = prefs.getString('profile_avatar_path_$email');
      }

      // Fallback: lấy avatar_url từ Supabase profiles nếu local chưa có
      if (avatarPath == null || avatarPath.isEmpty) {
        try {
          final supabaseService = SupabaseService.instance;
          if (supabaseService.hasSession) {
            final userId = supabaseService.client.auth.currentUser?.id;
            if (userId != null) {
              final row = await supabaseService.client
                  .from('profiles')
                  .select('avatar_url')
                  .eq('id', userId)
                  .maybeSingle();
              final url = row?['avatar_url']?.toString();
              if (url != null && url.isNotEmpty) {
                avatarPath = url;
                // Cache lại cho lần sau
                if (email != null && email.isNotEmpty) {
                  await prefs.setString('profile_avatar_path_$email', url);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error fetching avatar from Supabase: $e');
        }
      }

      setState(() {
        _avatarPath = avatarPath;
      });
    } catch (e) {
      debugPrint('Error loading avatar path: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (previous?.email != next.email) {
        _refreshData();
      }
    });

    final username = authState.username ?? 'Học sinh';
    final email = authState.email ?? 'guest@hoczita.edu.vn';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hồ sơ của bạn',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(authProvider.notifier).signOut();
            },
            icon: Icon(Icons.logout_rounded, color: AppColors.error),
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
              SizedBox(height: 24),

              // 1:1 Advising Booking Banner
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdvisingBookingScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tư Vấn 1:1 Với Giáo Viên 🧑‍🏫',
                                  style: GoogleFonts.baloo2(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Đặt lịch hẹn trực tiếp để nhận lộ trình học tập tối ưu riêng biệt cho bạn.',
                                  style: GoogleFonts.baloo2(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Filter Dropdowns Row
              Row(
                children: [
                  // Game Filter
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedGameFilter,
                          hint: Text(
                            'Tất cả trò chơi',
                            style: GoogleFonts.baloo2(fontSize: 12),
                          ),
                          isExpanded: true,
                          style: GoogleFonts.baloo2(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          items: const [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Tất cả trò chơi'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'flashcard_speed',
                              child: Text('Flashcard Speed Run'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'memory_match',
                              child: Text('Memory Match'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'picture_guess',
                              child: Text('Picture Guess'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'counting',
                              child: Text('Đếm Số Nhanh'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'math_ops',
                              child: Text('Thêm Bớt Vui Nhộn'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'comparison',
                              child: Text('So Sánh Trái Phải'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'math_crossword',
                              child: Text('Ô Chữ Toán Học'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'english_crossword',
                              child: Text('Ô Chữ Tiếng Anh'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'word_scramble',
                              child: Text('Word Scramble'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'magic_words',
                              child: Text('Magic Words'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'magic_number_path',
                              child: Text('Magic Number Path'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'sudoku',
                              child: Text('Sudoku'),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedGameFilter = val;
                              _updateLeaderboard();
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  // Time Filter
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTimeFilter,
                          isExpanded: true,
                          style: GoogleFonts.baloo2(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          items: const [
                            DropdownMenuItem<String>(
                              value: 'all',
                              child: Text('Tất cả thời gian'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'month',
                              child: Text('Tháng này'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'year',
                              child: Text('Năm nay'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedTimeFilter = val;
                                _updateLeaderboard();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              const SizedBox(height: 20),

              // Bảng xếp hạng với 3D Podium theo mẫu ranking.zip (tính theo tháng, có lọc theo năm)
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _leaderboardFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }

                  final list = snapshot.data ?? <Map<String, dynamic>>[];
                  return _buildPodiumLeaderboard(list, username, email);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final clean = name.replaceAll('(Bạn)', '').replaceAll('(ban)', '').trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final f = parts.first.isNotEmpty ? parts.first[0] : '';
      final l = parts.last.isNotEmpty ? parts.last[0] : '';
      return (f + l).toUpperCase();
    }
    return clean.substring(0, min(2, clean.length)).toUpperCase();
  }

  Widget _buildPodiumLeaderboard(
    List<Map<String, dynamic>> list,
    String currentUsername,
    String currentEmail,
  ) {
    final rank1 = list.isNotEmpty ? list[0] : null;
    final rank2 = list.length > 1 ? list[1] : null;
    final rank3 = list.length > 2 ? list[2] : null;

    // Tìm thứ hạng và điểm của người dùng hiện tại dựa trên dữ liệu thật
    int? myRank;
    int? myScore;
    final myCleanName = currentUsername.trim().toLowerCase();
    final myCleanEmail = currentEmail.trim().toLowerCase();
    final emailPrefix =
        myCleanEmail.contains('@') ? myCleanEmail.split('@')[0] : '';

    for (int i = 0; i < list.length; i++) {
      final u = (list[i]['username'] as String? ?? '').trim().toLowerCase();
      if (u.isNotEmpty &&
          (u == myCleanName ||
              u == '$myCleanName (bạn)' ||
              u.contains('(bạn)') ||
              (emailPrefix.isNotEmpty && u == emailPrefix))) {
        myRank = i + 1;
        myScore = list[i]['total_score'] as int? ?? 0;
        break;
      }
    }

    final thirdScore = rank3 != null ? (rank3['total_score'] as int? ?? 0) : 0;
    final currentUserScore = myScore ?? (_cachedPoint ?? 0);
    final pointsNeededToTop3 = max(1, thirdScore - currentUserScore + 1);

    String rankStatusText;
    if (myRank == 1) {
      rankStatusText = '👑 Bạn đang dẫn đầu!';
    } else if (myRank == 2 || myRank == 3) {
      rankStatusText = '✨ Bạn đang trong Top 3!';
    } else if (rank3 != null) {
      rankStatusText = 'Cần +$pointsNeededToTop3 điểm để vào Top 3';
    } else {
      rankStatusText = 'Tham gia chơi để ghi tên vào Top 3';
    }

    final periodTitle = _selectedTimeFilter == 'month'
        ? 'Bảng Xếp Hạng Tháng'
        : (_selectedTimeFilter == 'year'
            ? 'Bảng Xếp Hạng Năm'
            : 'Bảng Xếp Hạng Tổng Hợp');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tiêu đề: 🏆 Bảng Xếp Hạng Tháng / Năm 🏆
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                periodTitle,
                style: GoogleFonts.baloo2(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 8),
              const Text('🏆', style: TextStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 18),

          // 3D Podium Visualization
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Hạng 2: Bục Bạc (Bên trái)
              _buildPodiumColumn(
                rank: 2,
                player: rank2,
                blockHeight: 66,
                gradientColors: const [
                  Color(0xFFE2E8F0),
                  Color(0xFFCBD5E1),
                  Color(0xFF94A3B8),
                ],
                borderColor: const Color(0xFFCBD5E1),
                textColor: const Color(0xFF475569),
                pillBgColor: const Color(0xFFEFF6FF),
                pillTextColor: const Color(0xFF2563EB),
                title: 'SILVER',
              ),

              const SizedBox(width: 8),

              // Hạng 1: Bục Vàng Quán Quân (Ở giữa - Cao nhất)
              _buildPodiumColumn(
                rank: 1,
                player: rank1,
                blockHeight: 98,
                gradientColors: const [
                  Color(0xFFFCD34D),
                  Color(0xFFF59E0B),
                  Color(0xFFD97706),
                ],
                borderColor: const Color(0xFFF59E0B),
                textColor: const Color(0xFF78350F),
                pillBgColor: const Color(0xFFFEF3C7),
                pillTextColor: const Color(0xFFB45309),
                title: 'WINNER',
                isWinner: true,
              ),

              const SizedBox(width: 8),

              // Hạng 3: Bục Đồng (Bên phải)
              _buildPodiumColumn(
                rank: 3,
                player: rank3,
                blockHeight: 52,
                gradientColors: const [
                  Color(0xFFFED7AA),
                  Color(0xFFFB923C),
                  Color(0xFFEA580C),
                ],
                borderColor: const Color(0xFFFDBA74),
                textColor: const Color(0xFF7C2D12),
                pillBgColor: const Color(0xFFFFF7ED),
                pillTextColor: const Color(0xFFEA580C),
                title: 'BRONZE',
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Thanh trạng thái thứ hạng của người dùng dưới bục
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Thứ hạng của bạn: ',
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: myRank != null ? '#$myRank' : '#--',
                        style: GoogleFonts.baloo2(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  rankStatusText,
                  style: GoogleFonts.baloo2(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),

          // Danh sách mở rộng cho các thứ hạng tiếp theo (Hạng 4 đến 10) nếu có
          if (list.length > 3) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showFullLeaderboard = !_showFullLeaderboard;
                  });
                },
                icon: Icon(
                  _showFullLeaderboard
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                label: Text(
                  _showFullLeaderboard
                      ? 'Thu gọn bảng xếp hạng'
                      : 'Xem thêm hạng 4 - ${list.length}',
                  style: GoogleFonts.baloo2(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            if (_showFullLeaderboard) ...[
              const Divider(height: 16, color: Color(0xFFF1F5F9)),
              ...List.generate(list.length - 3, (idx) {
                final itemIndex = idx + 3;
                final entry = list[itemIndex];
                final r = itemIndex + 1;
                final name = entry['username'] as String? ?? 'Ẩn danh';
                final s = entry['total_score'] as int? ?? 0;
                final isMe = r == myRank;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFFEFF6FF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isMe
                        ? Border.all(color: const Color(0xFFBFDBFE))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.primary
                              : const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$r',
                          style: GoogleFonts.baloo2(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color:
                                isMe ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name + (isMe ? ' (Bạn)' : ''),
                          style: GoogleFonts.baloo2(
                            fontSize: 13,
                            fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                            color: isMe
                                ? AppColors.primary
                                : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      Text(
                        '$s điểm',
                        style: GoogleFonts.baloo2(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color:
                              isMe ? AppColors.primary : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPodiumColumn({
    required int rank,
    required Map<String, dynamic>? player,
    required double blockHeight,
    required List<Color> gradientColors,
    required Color borderColor,
    required Color textColor,
    required Color pillBgColor,
    required Color pillTextColor,
    required String title,
    bool isWinner = false,
  }) {
    final hasPlayer = player != null;
    final name =
        hasPlayer ? (player['username'] as String? ?? 'Ẩn danh') : '---';
    final score = hasPlayer ? (player['total_score'] as int? ?? 0) : 0;
    final initials = hasPlayer ? _getInitials(name) : '-';

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Vương miện cho Quán quân
          if (isWinner)
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text(
                '👑',
                style: TextStyle(fontSize: 22),
              ),
            )
          else
            const SizedBox(height: 26),

          // Avatar kèm vòng viền màu tương ứng
          Container(
            width: isWinner ? 54 : 44,
            height: isWinner ? 54 : 44,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: isWinner ? 2.5 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: GoogleFonts.baloo2(
                  fontSize: isWinner ? 18 : 14,
                  fontWeight: FontWeight.w900,
                  color: isWinner ? const Color(0xFF78350F) : textColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Tên người chơi thật từ hệ thống
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: isWinner ? 12 : 11,
                fontWeight: isWinner ? FontWeight.w800 : FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 3),

          // Huy hiệu điểm số
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isWinner ? 8 : 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: pillBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              hasPlayer ? '$score điểm' : '0 điểm',
              style: GoogleFonts.baloo2(
                fontSize: isWinner ? 11 : 10,
                fontWeight: FontWeight.w800,
                color: pillTextColor,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Khối bục 3D (Podium Block)
          Container(
            height: blockHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(isWinner ? 18 : 14),
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.last.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$rank',
                  style: GoogleFonts.baloo2(
                    fontSize: isWinner ? 30 : 22,
                    fontWeight: FontWeight.w900,
                    color: isWinner ? Colors.white : textColor,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.baloo2(
                    fontSize: isWinner ? 9.5 : 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: isWinner
                        ? const Color(0xFF451A03).withValues(alpha: 0.85)
                        : textColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildUserCard(String username, String email) {
    final String displayName = _cachedName ?? username;
    final String activeAvatar = _cachedAvatar ?? _avatarPath ?? '';
    final ImageProvider? avatarImage = resolveAvatarImage(activeAvatar);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileDetailScreen()),
        );
        _refreshData();
      },
      child: Container(
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
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 3,
                ),
                image: avatarImage != null
                    ? DecorationImage(image: avatarImage, fit: BoxFit.cover)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: avatarImage != null
                  ? null
                  : Icon(
                      Icons.person_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
            ),
            SizedBox(width: 20),

            // User details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.baloo2(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Score info
                  FutureBuilder<int>(
                    future: _totalScoreFuture,
                    builder: (context, snapshot) {
                      final points = snapshot.hasData
                          ? snapshot.data!
                          : (_cachedPoint ?? 0);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.stars_rounded,
                              color: AppColors.accent,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '$points điểm tích lũy',
                              style: GoogleFonts.baloo2(
                                color: Colors.white,
                                fontSize: 11,
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
      ),
    );
  }
}
