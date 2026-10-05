import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/supabase_service.dart';

class LearningProgressService {
  static final LearningProgressService instance = LearningProgressService._internal();
  LearningProgressService._internal();

  static const String _keyMathCorrectToday = 'lp_math_correct_today';
  static const String _keyMathDate = 'lp_math_date';
  static const String _keyEnglishLearnedWords = 'lp_english_learned_words';
  static const String _keyAdvancedViewedCount = 'lp_advanced_viewed_count';

  static const int dailyMathTarget = 20;
  static const int totalBasicVocabCount = 120;

  /// Ghi nhận 1 câu toán làm đúng
  Future<void> recordMathCorrect({required String subject}) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = prefs.getString(_keyMathDate) ?? '';

    int currentToday = 0;
    if (lastDate == todayStr) {
      currentToday = prefs.getInt(_keyMathCorrectToday) ?? 0;
    }
    currentToday++;
    await prefs.setString(_keyMathDate, todayStr);
    await prefs.setInt(_keyMathCorrectToday, currentToday);

    // Đồng bộ lên Supabase nếu có bảng
    _syncToSupabase(
      subject: subject,
      topic: 'all',
      incrementCorrect: 1,
      incrementPracticed: 1,
    );
  }

  /// Lấy tiến độ toán hôm nay (0.0 -> 1.0) và số câu đã làm đúng
  Future<Map<String, dynamic>> getMathTodayProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = prefs.getString(_keyMathDate) ?? '';

    int count = 0;
    if (lastDate == todayStr) {
      count = prefs.getInt(_keyMathCorrectToday) ?? 0;
    }

    // Ưu tiên đọc từ Supabase nếu online
    final supaCount = await _fetchSupabaseMathToday(todayStr);
    if (supaCount != null && supaCount > count) {
      count = supaCount;
      await prefs.setInt(_keyMathCorrectToday, count);
      await prefs.setString(_keyMathDate, todayStr);
    }

    final double ratio = (count / dailyMathTarget).clamp(0.0, 1.0);
    return {
      'count': count,
      'target': dailyMathTarget,
      'ratio': ratio,
      'percent': (ratio * 100).round(),
    };
  }

  /// Ghi nhận 1 từ vựng cơ bản đã học
  Future<void> recordBasicVocabLearned(String wordEn, {String? category}) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_keyEnglishLearnedWords) ?? [];
    if (!list.contains(wordEn)) {
      list.add(wordEn);
      await prefs.setStringList(_keyEnglishLearnedWords, list);
    }

    _syncToSupabase(
      subject: 'english_basic_flashcard',
      topic: category ?? 'all',
      incrementPracticed: 1,
      learnedItem: wordEn,
    );
  }

  /// Lấy tiến độ tiếng Anh cơ bản (0.0 -> 1.0)
  Future<Map<String, dynamic>> getEnglishBasicProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_keyEnglishLearnedWords) ?? [];

    final supaList = await _fetchSupabaseLearnedItems('english_basic_flashcard');
    final Set<String> merged = {...list, ...?supaList};

    final int count = merged.length;
    final double ratio = (count / totalBasicVocabCount).clamp(0.0, 1.0);
    return {
      'count': count,
      'total': totalBasicVocabCount,
      'ratio': ratio,
      'percent': (ratio * 100).round(),
    };
  }

  /// Ghi nhận từ vựng nâng cao đã xem
  Future<void> recordAdvancedVocabViewed(String wordTitle) async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyAdvancedViewedCount) ?? 0;
    current++;
    await prefs.setInt(_keyAdvancedViewedCount, current);

    _syncToSupabase(
      subject: 'english_advanced_flashcard',
      topic: 'api_eduwords',
      incrementPracticed: 1,
      learnedItem: wordTitle,
    );
  }

  // ================= PRIVATE SUPABASE SYNC (GRACEFUL FALLBACK) =================

  Future<void> _syncToSupabase({
    required String subject,
    required String topic,
    int incrementPracticed = 1,
    int incrementCorrect = 0,
    String? learnedItem,
  }) async {
    try {
      final supa = SupabaseService.instance;
      if (supa.isOfflineDemoMode || !supa.isConfigured) return;

      final userId = supa.client.auth.currentUser?.id;
      if (userId == null) return;

      // Đọc hàng hiện tại nếu có
      final existing = await supa.client
          .from('learning_progress')
          .select()
          .eq('profile_id', userId)
          .eq('subject', subject)
          .eq('topic', topic)
          .maybeSingle();

      int totalPracticed = incrementPracticed;
      int correctCount = incrementCorrect;
      List<dynamic> items = [];

      if (existing != null) {
        totalPracticed += (existing['total_practiced'] as int? ?? 0);
        correctCount += (existing['correct_count'] as int? ?? 0);
        if (existing['learned_items'] is List) {
          items = List.from(existing['learned_items']);
        }
      }

      if (learnedItem != null && !items.contains(learnedItem)) {
        items.add(learnedItem);
      }

      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      await supa.client.from('learning_progress').upsert({
        'profile_id': userId,
        'subject': subject,
        'topic': topic,
        'total_practiced': totalPracticed,
        'correct_count': correctCount,
        'learned_items': items,
        'last_practiced_date': todayStr,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'profile_id, subject, topic');
    } catch (e) {
      // Graceful fallback: nếu bảng chưa tạo trên Supabase hoặc mất mạng -> không throw lỗi
      debugPrint('LearningProgressService sync ignored (Table may not exist yet or offline): $e');
    }
  }

  Future<int?> _fetchSupabaseMathToday(String todayStr) async {
    try {
      final supa = SupabaseService.instance;
      if (supa.isOfflineDemoMode || !supa.isConfigured) return null;
      final userId = supa.client.auth.currentUser?.id;
      if (userId == null) return null;

      final res = await supa.client
          .from('learning_progress')
          .select('correct_count, last_practiced_date')
          .eq('profile_id', userId)
          .inFilter('subject', ['math_counting', 'math_ops']);

      if (res.isNotEmpty) {
        int sum = 0;
        for (var row in res) {
          if (row['last_practiced_date'] == todayStr) {
            sum += (row['correct_count'] as int? ?? 0);
          }
        }
        return sum;
      }
    } catch (_) {}
    return null;
  }

  Future<List<String>?> _fetchSupabaseLearnedItems(String subject) async {
    try {
      final supa = SupabaseService.instance;
      if (supa.isOfflineDemoMode || !supa.isConfigured) return null;
      final userId = supa.client.auth.currentUser?.id;
      if (userId == null) return null;

      final res = await supa.client
          .from('learning_progress')
          .select('learned_items')
          .eq('profile_id', userId)
          .eq('subject', subject);

      if (res.isNotEmpty) {
        final Set<String> items = {};
        for (var row in res) {
          if (row['learned_items'] is List) {
            for (var item in row['learned_items']) {
              items.add(item.toString());
            }
          }
        }
        return items.toList();
      }
    } catch (_) {}
    return null;
  }
}
