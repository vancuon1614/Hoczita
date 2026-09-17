import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_constants.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  bool get isConfigured => 
      SupabaseConstants.url != 'YOUR_SUPABASE_PROJECT_URL' && 
      SupabaseConstants.anonKey != 'YOUR_SUPABASE_ANON_KEY';

  SupabaseClient get client => Supabase.instance.client;

  // Trạng thái Demo Offline
  bool _isOfflineDemoMode = false;
  bool get isOfflineDemoMode => _isOfflineDemoMode || !isConfigured;

  // Mock Data cho Offline Mode
  String? _mockUserEmail;
  String? _mockUsername;
  int _mockTotalScore = 0;
  final List<Map<String, dynamic>> _mockScores = [];

  // Bản đồ lưu trữ tài khoản và username tương ứng trong chế độ Demo
  final Map<String, String> _demoUsernames = {
    'guest@hoczita.edu.vn': 'Bạn Carlos',
    'vanncuong1614@gmail.com': 'Văn Cường',
  };

  void enableOfflineDemoMode() {
    _isOfflineDemoMode = true;
    _mockUserEmail = 'guest@hoczita.edu.vn';
    _mockUsername = _demoUsernames[_mockUserEmail];
    _mockTotalScore = 120; // Điểm demo ban đầu
    _mockScores.addAll([
      {'game_name': 'flashcard_speed', 'stars': 3, 'score': 50, 'completed_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
      {'game_name': 'counting', 'stars': 2, 'score': 40, 'completed_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String()},
      {'game_name': 'math_ops', 'stars': 2, 'score': 30, 'completed_at': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String()},
    ]);
  }

  // Auth Operations
  Future<bool> signIn({required String email, required String password}) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    
    if (isOfflineDemoMode) {
      await Future.delayed(const Duration(milliseconds: 800)); // Giả lập mạng
      _mockUserEmail = cleanEmail;
      _mockUsername = _demoUsernames[cleanEmail] ?? cleanEmail.split('@')[0];
      return true;
    }
    try {
      final response = await client.auth.signInWithPassword(
        email: cleanEmail, 
        password: cleanPassword,
      ).timeout(const Duration(seconds: 15));
      return response.user != null;
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow;
    }
  }

  Future<bool> signUp({required String email, required String password, required String username}) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    final cleanUsername = username.trim();

    if (isOfflineDemoMode) {
      await Future.delayed(const Duration(milliseconds: 800));
      // Giả lập check trùng email trong chế độ offline
      if (_demoUsernames.containsKey(cleanEmail)) {
        throw Exception('User already exists');
      }
      _demoUsernames[cleanEmail] = cleanUsername;
      _mockUserEmail = cleanEmail;
      _mockUsername = cleanUsername;
      _mockTotalScore = 0;
      return true;
    }
    try {
      final response = await client.auth.signUp(
        email: cleanEmail, 
        password: cleanPassword,
        data: {'username': cleanUsername},
      );
      return response.user != null;
    } catch (e) {
      debugPrint('Sign up error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (isOfflineDemoMode) {
      _mockUserEmail = null;
      _mockUsername = null;
      _mockScores.clear();
      _mockTotalScore = 0;
      return;
    }
    await client.auth.signOut();
  }

  bool get hasSession {
    if (isOfflineDemoMode) {
      return _mockUserEmail != null;
    }
    return client.auth.currentSession != null;
  }

  String? get currentUserEmail {
    if (isOfflineDemoMode) {
      return _mockUserEmail;
    }
    return client.auth.currentUser?.email;
  }

  String? get currentUsername {
    if (isOfflineDemoMode) {
      return _mockUsername;
    }
    // Trong Supabase, username được lưu trong raw_user_meta_data hoặc bảng profiles
    return client.auth.currentUser?.userMetadata?['username'] ?? currentUserEmail?.split('@')[0];
  }

  // Database Operations - Scores
  Future<List<Map<String, dynamic>>> getScores() async {
    if (isOfflineDemoMode) {
      return _mockScores;
    }
    try {
      final response = await client
          .from(SupabaseConstants.tableGameScores)
          .select()
          .order('completed_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Get scores error: $e');
      return [];
    }
  }

  Future<int> getHighestStarsForGame(String gameName) async {
    if (isOfflineDemoMode) {
      final scores = _mockScores.where((s) => s['game_name'] == gameName);
      if (scores.isEmpty) return 0;
      return scores.map((s) => s['stars'] as int).reduce((a, b) => a > b ? a : b);
    }
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await client
          .from(SupabaseConstants.tableGameScores)
          .select('stars')
          .eq('profile_id', userId)
          .eq('game_name', gameName)
          .order('stars', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return response['stars'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('Get highest stars error: $e');
      return 0;
    }
  }

  Future<int> getTotalScore() async {
    if (isOfflineDemoMode) {
      return _mockTotalScore;
    }
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return 0;
      final response = await client
          .from(SupabaseConstants.tableProfiles)
          .select('total_score')
          .eq('id', userId)
          .single();
      return response['total_score'] as int? ?? 0;
    } catch (e) {
      debugPrint('Get total score error: $e');
      return 0;
    }
  }

  Future<void> saveScore({
    required String gameName,
    required int stars,
    required int score,
    int durationSeconds = 0,                        // MỚI - optional, mặc định 0
    List<Map<String, dynamic>>? completionLog,       // MỚI - optional
  }) async {
    if (isOfflineDemoMode) {
      _mockScores.insert(0, {
        'game_name': gameName,
        'stars': stars,
        'score': score,
        'duration_seconds': durationSeconds,
        'completion_log': completionLog,
        'completed_at': DateTime.now().toIso8601String(),
      });
      _mockTotalScore += score;
      return;
    }
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      await client.from(SupabaseConstants.tableGameScores).insert({
        'profile_id': userId,
        'game_name': gameName,
        'stars': stars,
        'score': score,
        'duration_seconds': durationSeconds,
        'completion_log': completionLog,
      });
      // Sync and increment total_score in profiles table
      final currentScore = await getTotalScore();
      await client.from(SupabaseConstants.tableProfiles).update({
        'total_score': currentScore + score,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('Save score error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> saveAndGetGameRank({required String gameName, required int stars, required int score}) async {
    if (isOfflineDemoMode) {
      _mockScores.insert(0, {
        'game_name': gameName,
        'stars': stars,
        'score': score,
        'completed_at': DateTime.now().toIso8601String(),
      });
      _mockTotalScore += score;
      await Future.delayed(const Duration(milliseconds: 800)); // Simulate loading
      return {
        'rank': 1,
        'totalPlayers': 1,
        'yourScore': score,
        'averageScore': score.toDouble(),
      };
    }
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception("Not logged in");

      // 1. Save score
      await client.from(SupabaseConstants.tableGameScores).insert({
        'profile_id': userId,
        'game_name': gameName,
        'stars': stars,
        'score': score,
      });

      // Sync and increment total_score in profiles table
      final currentScore = await getTotalScore();
      await client.from(SupabaseConstants.tableProfiles).update({
        'total_score': currentScore + score,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      
      // 2. Calculate Rank for this game (based on best score per player? Or all scores? Let's do best score per player for ranking)
      // Since it's hard to do complex grouping in client, we'll fetch all scores for this game and group them manually.
      final response = await client
          .from(SupabaseConstants.tableGameScores)
          .select('profile_id, score, completed_at')
          .eq('game_name', gameName);

      List<Map<String, dynamic>> allScores = List<Map<String, dynamic>>.from(response);
      
      // Group by profile_id to find max score per player
      Map<String, int> bestScores = {};
      Map<String, String> bestTimes = {};
      for (var row in allScores) {
        String pid = row['profile_id'].toString();
        int sc = row['score'] as int? ?? 0;
        String time = row['completed_at']?.toString() ?? '';
        
        if (!bestScores.containsKey(pid) || sc > bestScores[pid]!) {
          bestScores[pid] = sc;
          bestTimes[pid] = time;
        } else if (sc == bestScores[pid]! && time.compareTo(bestTimes[pid]!) < 0) {
          // tie breaker: earlier time
          bestTimes[pid] = time;
        }
      }
      
      // Create a list of best players
      List<Map<String, dynamic>> players = bestScores.keys.map((pid) {
        return {
          'profile_id': pid,
          'score': bestScores[pid]!,
          'completed_at': bestTimes[pid]!,
        };
      }).toList();
      
      // Sort by score DESC, then time ASC
      players.sort((a, b) {
        int scA = a['score'] as int;
        int scB = b['score'] as int;
        if (scA != scB) return scB.compareTo(scA);
        
        String timeA = a['completed_at'] as String;
        String timeB = b['completed_at'] as String;
        return timeA.compareTo(timeB);
      });
      
      int rank = 1;
      int totalScore = 0;
      for (int i = 0; i < players.length; i++) {
        if (players[i]['profile_id'] == userId) {
          rank = i + 1;
        }
        totalScore += players[i]['score'] as int;
      }
      
      int totalPlayers = players.length;
      double avgScore = totalPlayers > 0 ? totalScore / totalPlayers : score.toDouble();
      
      return {
        'rank': rank,
        'totalPlayers': totalPlayers,
        'yourScore': score,
        'averageScore': avgScore,
      };
    } catch (e) {
      debugPrint('Save and get game rank error: $e');
      throw Exception('Failed to get rank: $e');
    }
  }

  // Leaderboard
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    if (isOfflineDemoMode) {
      // Trả về BXH giả lập
      return [
        {'username': '${currentUsername ?? 'Bạn'} (Bạn)', 'total_score': _mockTotalScore},
        {'username': 'Minh Anh', 'total_score': 180},
        {'username': 'Bảo Nam', 'total_score': 150},
        {'username': 'Lan Chi', 'total_score': 90},
        {'username': 'Gia Bách', 'total_score': 80},
      ]..sort((a, b) => (b['total_score'] as int).compareTo(a['total_score'] as int));
    }
    try {
      final response = await client
          .from(SupabaseConstants.tableProfiles)
          .select('username, total_score')
          .order('total_score', ascending: false)
          .limit(10);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Get leaderboard error: $e');
      return [];
    }
  }

  Future<bool> updatePassword({required String oldPassword, required String newPassword}) async {
    final email = currentUserEmail;
    if (isOfflineDemoMode) {
      await Future.delayed(const Duration(milliseconds: 800));
      return true;
    }
    try {
      if (email != null) {
        // Thử đăng nhập lại bằng mật khẩu cũ để xác thực mật khẩu cũ có đúng không
        await client.auth.signInWithPassword(
          email: email,
          password: oldPassword.trim(),
        );
      }
      
      // Nếu đăng nhập thành công (không ném lỗi), thực hiện đổi mật khẩu mới
      await client.auth.updateUser(
        UserAttributes(password: newPassword.trim()),
      );
      return true;
    } catch (e) {
      debugPrint('Update password error: $e');
      rethrow;
    }
  }

  Future<String?> uploadAvatar(String imagePathOrBase64) async {
    if (isOfflineDemoMode) return null;
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;
      
      Uint8List bytes;
      if (imagePathOrBase64.startsWith('blob:')) {
        // Blob URL (Web) - Fetch bytes via HTTP
        final response = await http.get(Uri.parse(imagePathOrBase64));
        bytes = response.bodyBytes;
      } else if (imagePathOrBase64.startsWith('data:image/') || 
                 imagePathOrBase64.length > 500) {
        // Base64 or Data URL (Web)
        final commaIndex = imagePathOrBase64.indexOf(',');
        final base64Data = commaIndex != -1 ? imagePathOrBase64.substring(commaIndex + 1) : imagePathOrBase64;
        bytes = base64Decode(base64Data);
      } else {
        // Local file path (Mobile)
        final file = File(imagePathOrBase64);
        bytes = await file.readAsBytes();
      }
      
      final fileName = 'avatar_$userId.png';
      
      // Upload to bucket 'avatars'
      await client.storage.from('avatars').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/png',
          upsert: true,
        ),
      );
      
      // Get public URL
      final publicUrl = client.storage.from('avatars').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading avatar to Supabase Storage: $e');
      return null;
    }
  }

  /// Lấy thông tin hồ sơ người dùng từ bảng profiles trên Supabase.
  Future<Map<String, dynamic>?> getProfile() async {
    if (isOfflineDemoMode) return null;
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;
      final response = await client
          .from(SupabaseConstants.tableProfiles)
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching profile from Supabase: $e');
      return null;
    }
  }

  /// Cập nhật thông tin hồ sơ người dùng lên bảng profiles trên Supabase.
  Future<bool> updateProfile({
    required String fullName,
    String? phone,
    String? gender,
    String? dob,
    String? pob,
    String? idNumber,
    String? idCardDate,
    String? idCardPlace,
    String? address,
    String? district,
    String? province,
  }) async {
    if (isOfflineDemoMode) return true;
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;

      final Map<String, dynamic> updates = {
        'username': fullName,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (phone != null) updates['phone'] = phone;
      if (gender != null) updates['gender'] = gender;
      if (dob != null) updates['dob'] = dob;
      if (pob != null) updates['pob'] = pob;
      if (idNumber != null) updates['id_number'] = idNumber;
      if (idCardDate != null) updates['id_card_date'] = idCardDate;
      if (idCardPlace != null) updates['id_card_place'] = idCardPlace;
      if (address != null) updates['address'] = address;
      if (district != null) updates['district'] = district;
      if (province != null) updates['province'] = province;

      await client
          .from(SupabaseConstants.tableProfiles)
          .update(updates)
          .eq('id', userId);

      return true;
    } catch (e) {
      debugPrint('Error updating profile on Supabase: $e');
      rethrow;
    }
  }

  /// Lấy danh sách bảng xếp hạng có lọc theo game và thời gian
  Future<List<Map<String, dynamic>>> getFilteredLeaderboard({
    String? gameName,
    String timePeriod = 'all', // 'all', 'month', 'year'
  }) async {
    if (isOfflineDemoMode) {
      final myUser = _mockUsername ?? 'Bạn';
      final myScore = gameName == null 
          ? _mockTotalScore 
          : _mockScores
              .where((s) => s['game_name'] == gameName)
              .fold<int>(0, (sum, item) => sum + (item['score'] as int? ?? 0));

      final List<Map<String, dynamic>> baseList = [
        {'username': '$myUser (Bạn)', 'total_score': myScore},
        {'username': 'Minh Anh', 'total_score': gameName == null ? 180 : 40},
        {'username': 'Bảo Nam', 'total_score': gameName == null ? 150 : 30},
        {'username': 'Lan Chi', 'total_score': gameName == null ? 90 : 20},
        {'username': 'Gia Bách', 'total_score': gameName == null ? 80 : 10},
      ];
      
      baseList.sort((a, b) => (b['total_score'] as int).compareTo(a['total_score'] as int));
      return baseList;
    }

    try {
      if (gameName == null && timePeriod == 'all') {
        final response = await client
            .from(SupabaseConstants.tableProfiles)
            .select('username, total_score')
            .order('total_score', ascending: false)
            .limit(10);
        return List<Map<String, dynamic>>.from(response);
      }

      var query = client
          .from('game_scores')
          .select('score, game_name, completed_at, profiles(username)');

      if (gameName != null) {
        query = query.eq('game_name', gameName);
      }

      final DateTime now = DateTime.now();
      DateTime? startDate;
      if (timePeriod == 'month') {
        startDate = DateTime(now.year, now.month, 1);
      } else if (timePeriod == 'year') {
        startDate = DateTime(now.year, 1, 1);
      }

      if (startDate != null) {
        query = query.gte('completed_at', startDate.toIso8601String());
      }

      final response = await query;
      final List<dynamic> rows = response as List<dynamic>;

      final Map<String, int> userScores = {};
      for (final row in rows) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final String username = profile?['username']?.toString() ?? 'Ẩn danh';
        final int score = row['score'] as int? ?? 0;
        userScores[username] = (userScores[username] ?? 0) + score;
      }

      final List<Map<String, dynamic>> leaderboard = userScores.entries.map((entry) {
        return {
          'username': entry.key,
          'total_score': entry.value,
        };
      }).toList();

      leaderboard.sort((a, b) => (b['total_score'] as int).compareTo(a['total_score'] as int));
      return leaderboard.take(10).toList();
    } catch (e) {
      debugPrint('Get filtered leaderboard error: $e');
      return [];
    }
  }

  /// Đặt lịch tư vấn 1:1
  Future<bool> saveBooking({
    required String course,
    required DateTime dateTime,
    required String fullName,
    required String phone,
    required String email,
    required String notes,
  }) async {
    if (isOfflineDemoMode) {
      await Future.delayed(const Duration(milliseconds: 1000));
      return true;
    }
    try {
      final userId = client.auth.currentUser?.id;
      await client.from('bookings').insert({
        'profile_id': userId, // Có thể null nếu đặt lịch vãng lai
        'course': course,
        'booking_time': dateTime.toIso8601String(),
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'notes': notes,
      });
      return true;
    } catch (e) {
      debugPrint('Error saving booking: $e');
      rethrow;
    }
  }
  // --- Daily Check-in ---
  final Set<DateTime> _mockCheckedDates = {};

  Future<Set<DateTime>> getCheckinDates() async {
    if (isOfflineDemoMode) {
      // Return mocked check-in dates
      final today = DateTime.now();
      final mocked = {..._mockCheckedDates};
      if (today.weekday > 1 && !mocked.any((d) => d.year == today.year && d.month == today.month && d.day == today.day - 1)) {
        mocked.add(today.subtract(const Duration(days: 1)));
      }
      return mocked;
    }
    
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return {};

      final response = await client
          .from(SupabaseConstants.tableDailyCheckins)
          .select('checkin_date')
          .eq('profile_id', userId);

      Set<DateTime> dates = {};
      for (var row in response) {
        if (row['checkin_date'] != null) {
          dates.add(DateTime.parse(row['checkin_date'].toString()));
        }
      }
      return dates;
    } catch (e) {
      debugPrint('Get checkin dates error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> saveAndGetTodayRank(int foundPaths) async {
    if (isOfflineDemoMode) {
      _mockCheckedDates.add(DateTime.now());
      await Future.delayed(const Duration(seconds: 1)); // simulate loading
      return {
        'rank': 1,
        'totalPlayersToday': 1,
        'yourScore': foundPaths,
        'averageScore': foundPaths.toDouble(),
      };
    }
    
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception("Not logged in");
      
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      
      // 1. Upsert today's checkin
      await client.from(SupabaseConstants.tableDailyCheckins).upsert({
        'profile_id': userId,
        'checkin_date': todayStr,
        'found_paths': foundPaths,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'profile_id, checkin_date');

      // 2. Fetch all checkins for today to calculate rank
      final response = await client
          .from(SupabaseConstants.tableDailyCheckins)
          .select('profile_id, found_paths, updated_at')
          .eq('checkin_date', todayStr);

      List<Map<String, dynamic>> players = List<Map<String, dynamic>>.from(response);
      
      // Sort by found_paths DESC, then updated_at ASC (tie-breaker)
      players.sort((a, b) {
        int pathsA = a['found_paths'] as int? ?? 0;
        int pathsB = b['found_paths'] as int? ?? 0;
        if (pathsA != pathsB) return pathsB.compareTo(pathsA);
        
        String timeA = a['updated_at']?.toString() ?? '';
        String timeB = b['updated_at']?.toString() ?? '';
        return timeA.compareTo(timeB);
      });

      int rank = 1;
      int totalScore = 0;
      for (int i = 0; i < players.length; i++) {
        if (players[i]['profile_id'] == userId) {
          rank = i + 1;
        }
        totalScore += (players[i]['found_paths'] as int? ?? 0);
      }

      int totalPlayers = players.length;
      double avgScore = totalPlayers > 0 ? totalScore / totalPlayers : foundPaths.toDouble();

      return {
        'rank': rank,
        'totalPlayersToday': totalPlayers,
        'yourScore': foundPaths,
        'averageScore': avgScore,
      };
    } catch (e) {
      debugPrint('Save and get rank error: $e');
      throw Exception('Failed to get rank: $e');
    }
  }
}
