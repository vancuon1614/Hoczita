import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  String _selectedTimeFilter = 'month'; // default matches the monthly leaderboard

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
        final bool isSuccess = response['success'] ?? (response['error'] == null);
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
    final username = authState.username ?? 'Học sinh';
    final email = authState.email ?? 'guest@hoczita.edu.vn';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hồ sơ của bạn',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                                  'Đặt lịch hẹn trực tiếp để nhận lộ trình học tập tối ưu riêng biệt cho bé.',
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
                          hint: Text('Tất cả trò chơi', style: GoogleFonts.baloo2(fontSize: 12)),
                          isExpanded: true,
                          style: GoogleFonts.baloo2(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
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
                          style: GoogleFonts.baloo2(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
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

              // Leaderboard header
              Row(
                children: [
                  Icon(Icons.emoji_events_rounded, color: AppColors.accent, size: 24),
                  SizedBox(width: 8),
                  Text(
                    _selectedTimeFilter == 'month'
                        ? 'Bảng Xếp Hạng Tháng 🏆'
                        : (_selectedTimeFilter == 'year' ? 'Bảng Xếp Hạng Năm 🏆' : 'Bảng Xếp Hạng Tổng Hợp 🏆'),
                    style: GoogleFonts.baloo2(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Leaderboard List
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _leaderboardFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'Chưa có dữ liệu bảng xếp hạng.',
                          style: GoogleFonts.baloo2(color: AppColors.textSecondary),
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
                                  style: GoogleFonts.baloo2(
                                    fontWeight: FontWeight.bold,
                                    color: medalColor == Colors.transparent
                                        ? AppColors.primary
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),

                              // Name
                              Expanded(
                                child: Text(
                                  user,
                                  style: GoogleFonts.baloo2(
                                    fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                  ),
                                ),
                              ),

                              // Score
                              Text(
                                '$score điểm',
                                style: GoogleFonts.baloo2(
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

  ImageProvider? _getAvatarImageProvider(String path) {
    if (path.isEmpty) return null;
    if (path.startsWith('data:image/') || 
        path.startsWith('blob:') || 
        path.startsWith('http://') || 
        path.startsWith('https://') || 
        kIsWeb) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }

  Widget _buildUserCard(String username, String email) {
    final String displayName = _cachedName ?? username;
    final String activeAvatar = _cachedAvatar ?? _avatarPath ?? '';
    final ImageProvider? avatarImage = _getAvatarImageProvider(activeAvatar);

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
                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
                image: avatarImage != null
                    ? DecorationImage(
                        image: avatarImage,
                        fit: BoxFit.cover,
                      )
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
                      final points = snapshot.hasData ? snapshot.data! : (_cachedPoint ?? 0);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stars_rounded, color: AppColors.accent, size: 16),
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
