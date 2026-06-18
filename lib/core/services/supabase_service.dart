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
      );
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

  Future<void> saveScore({required String gameName, required int stars, required int score}) async {
    if (isOfflineDemoMode) {
      _mockScores.insert(0, {
        'game_name': gameName,
        'stars': stars,
        'score': score,
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
      });
    } catch (e) {
      debugPrint('Save score error: $e');
      rethrow;
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
}
