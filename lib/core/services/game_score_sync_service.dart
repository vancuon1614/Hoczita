import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/game_code_registry.dart';
import 'scrmai_api_service.dart';
import 'supabase_service.dart';
import 'api_service.dart';

/// Service điều phối lưu và đồng bộ điểm số 2 chiều giữa NKS SCRMAI API và Supabase
/// Tuân thủ nguyên tắc "Tuy 2 là 1", tự động chịu lỗi (Fallback) và đồng bộ bù (Re-sync)
class GameScoreSyncService {
  static final GameScoreSyncService instance = GameScoreSyncService._internal();
  GameScoreSyncService._internal();

  static const String _pendingQueueKey = 'hoczita_pending_sync_scores_v1';
  bool _isSyncing = false;

  /// Lưu điểm song song lên cả Local Cache, Supabase và NKS SCRMAI API
  Future<void> saveScoreParallel({
    required String gameCodeOrName,
    String level = '1',
    required int score,
    int stars = 0,
    int durationSeconds = 0,
    String? memberName,
    List<Map<String, dynamic>>? completionLog,
  }) async {
    final cleanCode = GameCodeRegistry.getCodeFromInternalName(gameCodeOrName);
    final cleanLevel = GameCodeRegistry.resolveLevel(level);
    final String resolvedMember = _resolveMemberName(memberName);

    // 1. Tầng Local Cache (Ghi tức thì vào máy để Offline-First luôn mượt mà)
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyScore = 'hoczita_best_score_$cleanCode';
      int currentBest = prefs.getInt(keyScore) ?? 0;
      if (cleanCode == 'M02' && currentBest >= 300) {
        currentBest = 0;
        await prefs.remove(keyScore);
      }
      if (score > currentBest) {
        await prefs.setInt(keyScore, score);
      }

      final keyStars = 'hoczita_best_stars_$cleanCode';
      final currentStars = prefs.getInt(keyStars) ?? 0;
      if (stars > currentStars) {
        await prefs.setInt(keyStars, stars);
      }
    } catch (e) {
      debugPrint('[GameScoreSync] Lưu local cache error: $e');
    }

    // 2. Tầng Supabase (Lưu cơ sở dữ liệu tài khoản chính thức)
    try {
      // Lưu với mã chuẩn cleanCode (M01..M06, E01..E06)
      await SupabaseService.instance.saveScore(
        gameName: cleanCode,
        stars: stars,
        score: score,
        durationSeconds: durationSeconds,
        completionLog: completionLog,
      );
    } catch (e) {
      debugPrint('[GameScoreSync] Lưu Supabase error: $e');
    }

    // 3. Tầng NKS SCRMAI API (Gửi lên Server hệ thống chung)
    bool apiSuccess = false;
    try {
      apiSuccess = await ScrmaiApiService.instance.submitScore(
        member: resolvedMember,
        game: cleanCode,
        level: cleanLevel,
        score: score,
      );
    } catch (e) {
      debugPrint('[GameScoreSync] Gửi NKS API error: $e');
      apiSuccess = false;
    }

    // 4. Nếu API thất bại -> Đưa vào hàng đợi chờ đẩy bù (Pending Sync Queue)
    if (!apiSuccess) {
      await _enqueuePendingScore(
        member: resolvedMember,
        gameCode: cleanCode,
        level: cleanLevel,
        score: score,
      );
    } else {
      // Nếu API thành công, kiểm tra đẩy bù các ván cũ còn tồn (nếu có)
      syncPendingScoresToApi();
    }
  }

  /// Nạp Bảng xếp hạng: Ưu tiên NKS API -> Nếu API lỗi, tự động Fallback sang Supabase
  Future<List<Map<String, dynamic>>> fetchLeaderboardWithFallback({
    required String gameCodeOrName,
    String? internalGameName,
  }) async {
    final cleanCode = GameCodeRegistry.getCodeFromInternalName(gameCodeOrName);
    final String primaryMyName = _resolveMemberName(null);
    final bool isEnglish = GameCodeRegistry.isEnglishGame(cleanCode) || GameCodeRegistry.isEnglishGame(gameCodeOrName);
    final String youSuffix = isEnglish ? ' (YOU)' : ' (BẠN)';

    // Thu thập danh sách các alias (biệt danh / username / họ tên) của chính người dùng hiện tại
    final Set<String> myAliases = {};
    if (primaryMyName.isNotEmpty) {
      myAliases.add(primaryMyName.trim().toLowerCase());
    }
    final curUsername = SupabaseService.instance.currentUsername;
    if (curUsername != null && curUsername.trim().isNotEmpty) {
      myAliases.add(curUsername.trim().toLowerCase());
    }
    final nksInfo = ApiService.instance.cachedUserInfo;
    if (nksInfo != null) {
      final name = nksInfo['name']?.toString();
      if (name != null && name.trim().isNotEmpty) {
        myAliases.add(name.trim().toLowerCase());
      }
      final username = nksInfo['username']?.toString();
      if (username != null && username.trim().isNotEmpty) {
        myAliases.add(username.trim().toLowerCase());
      }
      final email = nksInfo['email']?.toString();
      if (email != null && email.contains('@')) {
        myAliases.add(email.split('@')[0].trim().toLowerCase());
      }
    }
    final supaEmail = SupabaseService.instance.currentUserEmail;
    if (supaEmail != null && supaEmail.contains('@')) {
      myAliases.add(supaEmail.split('@')[0].trim().toLowerCase());
    }

    bool isMe(String memberName) {
      final clean = memberName
          .replaceAll('(Bạn)', '')
          .replaceAll('(ban)', '')
          .replaceAll('(YOU)', '')
          .replaceAll('(you)', '')
          .trim()
          .toLowerCase();
      if (clean.isEmpty) return false;
      return myAliases.contains(clean);
    }

    // THỬ 1: Tải từ NKS SCRMAI API (Timeout tối đa 4 giây để không làm đơ giao diện)
    try {
      final apiScores = await ScrmaiApiService.instance
          .fetchScores(page: 1, limit: 50)
          .timeout(const Duration(seconds: 4));

      if (apiScores.isNotEmpty) {
        // Lọc dữ liệu thuộc game này (kiểm tra cả cleanCode lẫn internalName)
        final List<Map<String, dynamic>> filteredList = [];
        final Map<String, int> bestScoresPerMember = {};

        for (final item in apiScores) {
          final itemCode = GameCodeRegistry.getCodeFromInternalName(item.game);
          final g = item.game.trim().toUpperCase();
          final isMatch = itemCode.toUpperCase() == cleanCode.toUpperCase() ||
              g == cleanCode.toUpperCase() ||
              (internalGameName != null && g == internalGameName.toUpperCase()) ||
              g == gameCodeOrName.toUpperCase();

          if (!isMatch) continue;

          final member = item.member.trim();
          final score = int.tryParse(item.score.trim()) ?? 0;

          // Bộ lọc làm sạch dữ liệu: Bỏ qua bản ghi rác / rỗng / điểm âm hoặc điểm test cũ của Bảng cửu chương (Phương án B)
          if (member.isEmpty || member == '-' || member == '-  -' || score <= 0) {
            continue;
          }
          if (cleanCode == 'M02' && score >= 300) {
            continue;
          }

          // Chuẩn hóa tên: Gom mọi biến thể tên/tài khoản của người dùng về cùng 1 key primaryMyName
          final targetMemberKey = isMe(member) ? primaryMyName : member;

          // Lấy điểm cao nhất của mỗi người chơi
          if (!bestScoresPerMember.containsKey(targetMemberKey) || score > bestScoresPerMember[targetMemberKey]!) {
            bestScoresPerMember[targetMemberKey] = score;
          }
        }

        // So khớp với Current User: Nếu điểm hiện tại trên máy/Supabase cao hơn trên API
        int localBest = 0;
        try {
          final prefs = await SharedPreferences.getInstance();
          localBest = prefs.getInt('hoczita_best_score_$cleanCode') ?? 0;
          if (cleanCode == 'M02' && localBest >= 300) {
            localBest = 0;
            await prefs.remove('hoczita_best_score_$cleanCode');
          }
        } catch (_) {}

        if (localBest > (bestScoresPerMember[primaryMyName] ?? 0)) {
          bestScoresPerMember[primaryMyName] = localBest;
          // Kích hoạt đồng bộ bù lên API
          _enqueuePendingScore(
            member: primaryMyName,
            gameCode: cleanCode,
            level: '1',
            score: localBest,
          );
          syncPendingScoresToApi();
        }

        for (final entry in bestScoresPerMember.entries) {
          final isCurrentUser = isMe(entry.key);
          filteredList.add({
            'username': isCurrentUser ? '${entry.key}$youSuffix' : entry.key,
            'total_score': entry.value,
            'avatar_url': null,
          });
        }

        filteredList.sort((a, b) => (b['total_score'] as int).compareTo(a['total_score'] as int));

        if (filteredList.isNotEmpty) {
          debugPrint('[GameScoreSync] Đã nạp thành công ${filteredList.length} kỷ lục từ NKS API');
          // Khi API thông, tranh thủ đẩy bù các ván pending
          syncPendingScoresToApi();
          return filteredList.take(20).toList();
        }
      }
    } catch (e) {
      debugPrint('[GameScoreSync] NKS API không khả dụng hoặc timeout ($e), tự động chuyển sang Supabase');
    }

    // THỬ 2: FALLBACK sang Supabase (Đảm bảo 100% không bao giờ trắng bảng điểm)
    try {
      final supabaseLeaderboard = await SupabaseService.instance.getFilteredLeaderboard(
        gameName: internalGameName ?? gameCodeOrName,
      );
      if (supabaseLeaderboard.isNotEmpty) {
        debugPrint('[GameScoreSync] Đã nạp thành công từ Supabase Fallback');
        return supabaseLeaderboard;
      }
    } catch (e) {
      debugPrint('[GameScoreSync] Supabase fallback error: $e');
    }

    // THỬ 3: Fallback cuối cùng từ Local Cache nếu cả 2 đều không có
    try {
      final prefs = await SharedPreferences.getInstance();
      final localScore = prefs.getInt('hoczita_best_score_$cleanCode') ?? 0;
      if (localScore > 0) {
        return [
          {
            'username': '$primaryMyName$youSuffix',
            'total_score': localScore,
            'avatar_url': null,
          }
        ];
      }
    } catch (_) {}

    return [];
  }

  /// Đồng bộ bù: Đẩy các ván chơi còn tồn trong hàng đợi lên NKS API
  Future<void> syncPendingScoresToApi() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawQueue = prefs.getString(_pendingQueueKey);
      if (rawQueue == null || rawQueue.isEmpty) {
        _isSyncing = false;
        return;
      }

      final List<dynamic> list = jsonDecode(rawQueue);
      if (list.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('[GameScoreSync] Bắt đầu đẩy bù ${list.length} ván chơi lên NKS API...');
      final List<Map<String, dynamic>> remaining = [];

      for (final item in list) {
        final Map<String, dynamic> record = Map<String, dynamic>.from(item);
        final member = record['member']?.toString() ?? 'Học sinh';
        final game = record['game']?.toString() ?? '';
        final level = record['level']?.toString() ?? '1';
        final score = int.tryParse(record['score']?.toString() ?? '0') ?? 0;

        final success = await ScrmaiApiService.instance.submitScore(
          member: member,
          game: game,
          level: level,
          score: score,
        );

        if (!success) {
          // Chưa gửi được thì giữ lại cho lần kế tiếp
          remaining.add(record);
        }
      }

      await prefs.setString(_pendingQueueKey, jsonEncode(remaining));
      debugPrint('[GameScoreSync] Đẩy bù hoàn tất. Còn lại ${remaining.length} ván chưa gửi.');
    } catch (e) {
      debugPrint('[GameScoreSync] Lỗi trong tiến trình syncPendingScoresToApi: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _enqueuePendingScore({
    required String member,
    required String gameCode,
    required String level,
    required int score,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawQueue = prefs.getString(_pendingQueueKey);
      List<dynamic> list = [];
      if (rawQueue != null && rawQueue.isNotEmpty) {
        try {
          list = jsonDecode(rawQueue);
        } catch (_) {
          list = [];
        }
      }

      // Tránh trùng lặp ván chơi giống hệt nhau
      final isDuplicate = list.any((item) =>
          item['member'] == member &&
          GameCodeRegistry.getCodeFromInternalName(item['game'].toString()) == GameCodeRegistry.getCodeFromInternalName(gameCode) &&
          item['level'] == level &&
          item['score'] == score);

      if (!isDuplicate) {
        list.add({
          'member': member,
          'game': gameCode,
          'level': level,
          'score': score,
          'created_at': DateTime.now().toIso8601String(),
        });
        await prefs.setString(_pendingQueueKey, jsonEncode(list));
        debugPrint('[GameScoreSync] Đã thêm ván chơi vào hàng đợi chờ đẩy bù ($gameCode - $score điểm)');
      }
    } catch (e) {
      debugPrint('[GameScoreSync] Lỗi khi thêm vào hàng đợi: $e');
    }
  }

  String _resolveMemberName(String? memberName) {
    if (memberName != null && memberName.trim().isNotEmpty) {
      return memberName.trim();
    }
    final nksInfo = ApiService.instance.cachedUserInfo;
    if (nksInfo != null) {
      final nksName = nksInfo['name']?.toString() ?? nksInfo['username']?.toString();
      if (nksName != null && nksName.trim().isNotEmpty) {
        return nksName.trim();
      }
    }
    final supabaseUser = SupabaseService.instance.currentUsername;
    if (supabaseUser != null && supabaseUser.trim().isNotEmpty) {
      return supabaseUser.trim();
    }
    return 'Học sinh';
  }
}
