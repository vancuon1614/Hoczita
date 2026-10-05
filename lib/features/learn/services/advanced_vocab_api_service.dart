import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdvancedVocabItem {
  final int id;
  final String word;
  final String viWord;
  final String transcription;
  final String example;
  final String description;
  final String viDescription;
  final String level;

  const AdvancedVocabItem({
    required this.id,
    required this.word,
    required this.viWord,
    required this.transcription,
    required this.example,
    required this.description,
    required this.viDescription,
    required this.level,
  });

  factory AdvancedVocabItem.fromJson(Map<String, dynamic> json) {
    // API có thể trả fields ở root hoặc lồng trong acf
    final acf = json['acf'] is Map<String, dynamic> ? json['acf'] as Map<String, dynamic> : null;

    final String word = (json['title'] ?? acf?['title'] ?? '').toString().trim();
    final String viWord = (json['viword'] ?? acf?['viword'] ?? '').toString().trim();
    final String transcription = (json['transcription'] ?? acf?['transcription'] ?? '').toString().trim();
    final String example = (json['example'] ?? acf?['example'] ?? '').toString().trim();
    final String description = (json['description'] ?? acf?['description'] ?? '').toString().trim();
    final String viDescription = (json['videscription'] ?? acf?['videscription'] ?? '').toString().trim();
    final String level = (json['level'] ?? acf?['level'] ?? 'A1').toString().trim().toUpperCase();

    return AdvancedVocabItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      word: word.isNotEmpty ? word : 'Word',
      viWord: viWord.isNotEmpty ? viWord : 'Nghĩa từ vựng',
      transcription: transcription,
      example: example,
      description: description,
      viDescription: viDescription,
      level: level.isNotEmpty ? level : 'A1',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': word,
        'viword': viWord,
        'transcription': transcription,
        'example': example,
        'description': description,
        'videscription': viDescription,
        'level': level,
      };
}

class AdvancedVocabApiService {
  static final AdvancedVocabApiService instance = AdvancedVocabApiService._internal();
  AdvancedVocabApiService._internal();

  static const String _apiUrl = 'https://sdata.io.vn/wp-json/scrmai/v1/eduwords';
  static const String _bearerToken = 'Bearer 01KWKATNQGB5TWXYDPJ671X3X1';
  static const String _cacheKey = 'advanced_vocab_cache_v1';

  List<AdvancedVocabItem> _cachedItems = [];
  bool _isLoading = false;

  List<AdvancedVocabItem> get cachedItems => _cachedItems;
  bool get hasData => _cachedItems.isNotEmpty;

  /// Tải danh sách từ vựng nâng cao từ API hoặc Cache
  Future<List<AdvancedVocabItem>> fetchAdvancedVocab({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Đọc từ local cache nếu chưa force refresh
    if (!forceRefresh && _cachedItems.isEmpty) {
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(cachedJson) as List<dynamic>;
          _cachedItems = decoded.map((e) => AdvancedVocabItem.fromJson(e as Map<String, dynamic>)).toList();
          if (_cachedItems.isNotEmpty) {
            // Tải ngầm phiên bản mới nhất nếu có mạng
            _fetchFromApiInBackground();
            return _cachedItems;
          }
        } catch (e) {
          debugPrint('Error reading vocab cache: $e');
        }
      }
    }

    if (_cachedItems.isNotEmpty && !forceRefresh) {
      return _cachedItems;
    }

    // 2. Gọi API POST eduwords
    try {
      _isLoading = true;
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': _bearerToken,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final data = decoded['data'];
        if (data is List) {
          _cachedItems = data
              .map((e) => AdvancedVocabItem.fromJson(e as Map<String, dynamic>))
              .where((item) => item.word.isNotEmpty)
              .toList();

          // Lưu vào local cache
          await prefs.setString(_cacheKey, jsonEncode(_cachedItems.map((e) => e.toJson()).toList()));
          return _cachedItems;
        }
      }
    } catch (e) {
      debugPrint('Error fetching advanced vocab from API: $e');
    } finally {
      _isLoading = false;
    }

    // 3. Fallback danh sách mẫu nếu chưa kết nối được mạng lần đầu
    if (_cachedItems.isEmpty) {
      _cachedItems = _getFallbackItems();
    }
    return _cachedItems;
  }

  void _fetchFromApiInBackground() async {
    if (_isLoading) return;
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': _bearerToken,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final data = decoded['data'];
        if (data is List) {
          final items = data
              .map((e) => AdvancedVocabItem.fromJson(e as Map<String, dynamic>))
              .where((item) => item.word.isNotEmpty)
              .toList();
          if (items.isNotEmpty) {
            _cachedItems = items;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_cacheKey, jsonEncode(_cachedItems.map((e) => e.toJson()).toList()));
          }
        }
      }
    } catch (_) {}
  }

  List<AdvancedVocabItem> _getFallbackItems() {
    return const [
      AdvancedVocabItem(
        id: 767,
        word: 'Young',
        viWord: 'Trẻ, trẻ tuổi',
        transcription: '/jʌŋ/',
        example: 'She is very young. Young children learn quickly.',
        description: 'having lived for only a short time; not old',
        viDescription: 'chỉ mới sống trong một thời gian ngắn; không già',
        level: 'A1',
      ),
      AdvancedVocabItem(
        id: 766,
        word: 'Year',
        viWord: 'Năm',
        transcription: '/jɪə(r)/',
        example: 'I was born in this year. Next year we will travel to Japan.',
        description: 'a period of twelve months',
        viDescription: 'một khoảng thời gian mười hai tháng',
        level: 'A1',
      ),
      AdvancedVocabItem(
        id: 775,
        word: 'Accessible',
        viWord: 'Có thể tiếp cận được',
        transcription: '/əkˈsesəbl/',
        example: 'The library is accessible to all students.',
        description: 'able to be reached, entered, or used',
        viDescription: 'có thể đến được, vào được hoặc sử dụng được',
        level: 'B1',
      ),
    ];
  }
}
