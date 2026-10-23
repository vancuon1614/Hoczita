import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/game/constants/game_content.dart';

/// Dịch vụ đồng bộ danh sách từ vựng động từ Cloud (Supabase Storage JSON)
/// Hỗ trợ cơ chế 3 lớp: Remote Cloud -> Local Cache -> Bundled Asset / Fallback.
/// Hoạt động offline 100% khi mất mạng.
class VocabSyncService {
  static final VocabSyncService instance = VocabSyncService._internal();
  VocabSyncService._internal();

  /// URL trỏ trực tiếp đến file JSON trên Supabase Storage
  static const String remoteUrl =
      'https://sinqzsswmecneliyjfrg.supabase.co/storage/v1/object/public/game-assets/data/vocab_config.json';

  static const String _cacheKey = 'hoczita_vocab_config_cache_v1';
  static const String _versionKey = 'hoczita_vocab_config_version';
  static const String _assetPath = 'assets/data/vocab_config.json';

  List<VocabItem> _vocabList = [];
  List<Map<String, dynamic>> _topics = [];
  int _currentVersion = 1;
  bool _isInitialized = false;
  bool _isSyncing = false;

  /// Notifier để UI (như Flashcards, Mini-games) có thể lắng nghe khi có từ mới
  final ValueNotifier<int> vocabUpdatedNotifier = ValueNotifier<int>(0);

  List<VocabItem> get vocabList =>
      _vocabList.isNotEmpty ? _vocabList : GameContent.defaultVocab;

  List<Map<String, dynamic>> get topics => _topics;
  int get currentVersion => _currentVersion;
  int get totalCount => vocabList.length;

  /// Lọc từ vựng theo chủ đề (null = lấy tất cả)
  List<VocabItem> getVocabForCategory(String? category) {
    if (category == null || category.isEmpty || category.toLowerCase() == 'all') {
      return List.unmodifiable(vocabList);
    }
    final cleanCategory = category.trim().toLowerCase();
    final filtered = vocabList
        .where((item) => item.category.trim().toLowerCase() == cleanCategory)
        .toList();
    return filtered.isNotEmpty ? filtered : List.unmodifiable(vocabList);
  }

  /// Khởi tạo dữ liệu khi ứng dụng mở
  Future<void> init() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _currentVersion = prefs.getInt(_versionKey) ?? 1;

    // 1. Đọc từ Local Cache (SharedPreferences)
    final cachedJson = prefs.getString(_cacheKey);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded =
            jsonDecode(cachedJson) as Map<String, dynamic>;
        _parseAndApply(decoded);
      } catch (e) {
        debugPrint('[VocabSync] Lỗi đọc cache từ vựng: $e');
      }
    }

    // 2. Nếu Cache trống, nạp từ file bundled asset sẵn trong app
    if (_vocabList.isEmpty) {
      await _loadFromBundledAsset();
    }

    // 3. Nếu vẫn trống (ví dụ lỗi đọc asset), nạp fallback mặc định
    if (_vocabList.isEmpty) {
      _vocabList = List.from(GameContent.defaultVocab);
    }

    _isInitialized = true;

    // 4. Kiểm tra cập nhật từ Supabase Storage ngầm
    syncWithRemoteInBackground();
  }

  /// Nạp từ file JSON đóng gói sẵn trong App
  Future<void> _loadFromBundledAsset() async {
    try {
      final jsonString = await rootBundle.loadString(_assetPath);
      final Map<String, dynamic> decoded =
          jsonDecode(jsonString) as Map<String, dynamic>;
      _parseAndApply(decoded);
      debugPrint(
          '[VocabSync] Đã nạp ${_vocabList.length} từ từ bundled asset.');
    } catch (e) {
      debugPrint('[VocabSync] Lỗi đọc bundled asset: $e');
    }
  }

  /// Đồng bộ ngầm trong background (không chặn UI)
  void syncWithRemoteInBackground() {
    Future.microtask(() async {
      await syncWithRemote(force: false);
    });
  }

  /// Đồng bộ với Supabase Storage
  Future<bool> syncWithRemote({bool force = false}) async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      // Thêm query timestamp chống cache HTTP proxy
      final uri = Uri.parse('$remoteUrl?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final int remoteVersion = (decoded['version'] as num?)?.toInt() ?? 1;

        // Nếu bản trên server mới hơn hoặc được yêu cầu force refresh
        if (remoteVersion > _currentVersion || force || _vocabList.isEmpty) {
          final success = _parseAndApply(decoded);
          if (success) {
            _currentVersion = remoteVersion;

            // Lưu vào SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_cacheKey, utf8.decode(response.bodyBytes));
            await prefs.setInt(_versionKey, _currentVersion);

            vocabUpdatedNotifier.value++;
            debugPrint(
                '[VocabSync] Đã cập nhật thành công v$_currentVersion (${_vocabList.length} từ).');
            return true;
          }
        } else {
          debugPrint(
              '[VocabSync] Từ vựng đã ở phiên bản mới nhất (v$_currentVersion).');
        }
      } else {
        debugPrint(
            '[VocabSync] Server trả về mã HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[VocabSync] Không thể kết nối Supabase Storage (sử dụng offline cache): $e');
    } finally {
      _isSyncing = false;
    }
    return false;
  }

  /// Parse dữ liệu JSON thành danh sách VocabItem
  bool _parseAndApply(Map<String, dynamic> json) {
    try {
      final wordsData = json['words'];
      if (wordsData is List && wordsData.isNotEmpty) {
        final List<VocabItem> parsedWords = [];
        for (final item in wordsData) {
          if (item is Map<String, dynamic>) {
            final en = item['en']?.toString().trim() ?? '';
            final vi = item['vi']?.toString().trim() ?? '';
            final cat = item['category']?.toString().trim() ?? 'all';
            final transcription = item['transcription']?.toString().trim();
            final example = item['example']?.toString().trim();
            final imageUrl = item['image_url']?.toString().trim();

            if (en.isNotEmpty && vi.isNotEmpty) {
              parsedWords.add(VocabItem(
                en,
                vi,
                cat,
                transcription: transcription,
                example: example,
                customImageUrl: imageUrl,
              ));
            }
          }
        }

        if (parsedWords.isNotEmpty) {
          _vocabList = parsedWords;

          // Parse topics nếu có
          final topicsData = json['topics'];
          if (topicsData is List) {
            _topics = topicsData
                .whereType<Map<String, dynamic>>()
                .map((t) => Map<String, dynamic>.from(t))
                .toList();
          }
          return true;
        }
      }
    } catch (e) {
      debugPrint('[VocabSync] Lỗi phân tích JSON: $e');
    }
    return false;
  }
}
