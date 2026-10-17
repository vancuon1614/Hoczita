import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/game_code_registry.dart';

class ScrmaiScoreItem {
  final int id;
  final String title;
  final String slug;
  final String member;
  final String game;
  final String level;
  final String score;
  final String createdAt;

  ScrmaiScoreItem({
    required this.id,
    required this.title,
    this.slug = '',
    required this.member,
    required this.game,
    required this.level,
    required this.score,
    required this.createdAt,
  });

  factory ScrmaiScoreItem.fromJson(Map<String, dynamic> json) {
    return ScrmaiScoreItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      title: (json['title'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      member: (json['member'] ?? json['Member'] ?? '').toString(),
      game: (json['game'] ?? json['Game'] ?? '').toString(),
      level: (json['level'] ?? json['Level'] ?? '').toString(),
      score: (json['score'] ?? json['Score'] ?? '0').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class ScrmaiApiService {
  static final ScrmaiApiService instance = ScrmaiApiService._internal();
  ScrmaiApiService._internal();

  static const String _baseUrl = 'https://sdata.io.vn/wp-json/scrmai/v1';
  static const String _bearerToken = 'Bearer 01KWKATNQGB5TWXYDPJ671X3X1';

  Map<String, String> get _headers => {
        'Authorization': _bearerToken,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Chuyển đổi chuỗi tiếng Việt thành slug URL-friendly
  String _toSlug(String text) {
    String str = text.toLowerCase().trim();
    const vietnamese = {
      'a': 'áàảãạăắằẳẵặâấầẩẫậ',
      'e': 'éèẻẽẹêếềểễệ',
      'i': 'íìỉĩị',
      'o': 'óòỏõọôốồổỗộơớờởỡợ',
      'u': 'úùủũụưứừửữự',
      'y': 'ýỳỷỹỵ',
      'd': 'đ',
    };
    for (final entry in vietnamese.entries) {
      for (final char in entry.value.split('')) {
        str = str.replaceAll(char, entry.key);
      }
    }
    str = str.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return str.replaceAll(RegExp(r'^-+|-+$'), '').replaceAll(RegExp(r'-+'), '-');
  }

  /// Gửi điểm số mini-game lên NKS SCRMAI API (Ưu tiên 1)
  /// Sử dụng multipart/form-data theo đúng chuẩn Postman API mẫu của backend
  Future<bool> submitScore({
    required String member,
    required String game,
    required String level,
    required int score,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/hoczita/score/add');
      final memberStr = member.trim().isNotEmpty ? member.trim() : 'Học sinh';
      final scoreStr = score.toString();

      final request = http.MultipartRequest('POST', url);
      request.headers.addAll({
        'Authorization': _bearerToken,
        'Accept': 'application/json',
      });

      final cleanGame = GameCodeRegistry.getCodeFromInternalName(game);
      final cleanLevel = GameCodeRegistry.resolveLevel(level);

      // Backend PHP server ghép: $title = $member . ' - ' . $game . ' - ' . $score;
      // và sinh slug: $slug = sanitize_title($title);
      // Vì backend bỏ qua trường title & slug gửi từ client, để title và slug trên hệ thống
      // có chứa thông tin level (ví dụ: "Lê Đức Hải - E01 - 1 - 15" và "le-duc-hai-e01-1-15"),
      // trường 'game' gửi lên form-data bắt buộc phải là "$cleanGame - $cleanLevel".
      final gameWithLevel = '$cleanGame - $cleanLevel';

      final titleWithLv = '$memberStr - $cleanGame - $cleanLevel - $scoreStr';
      final memberSlug = _toSlug(memberStr);
      final slugWithLv = '$memberSlug-${cleanGame.toLowerCase()}-$cleanLevel-$scoreStr';

      // Gửi theo đúng form-data (Postman Image 1).
      // Đính kèm cả key chữ thường, chữ hoa đầu và các biến title/slug/lv để PHP backend nhận diện
      request.fields['member'] = memberStr;
      request.fields['game'] = gameWithLevel;
      request.fields['Game'] = gameWithLevel;
      request.fields['level'] = cleanLevel;
      request.fields['Level'] = cleanLevel;
      request.fields['lv'] = cleanLevel;
      request.fields['Lv'] = cleanLevel;
      request.fields['LV'] = cleanLevel;
      request.fields['score'] = scoreStr;
      request.fields['Score'] = scoreStr;

      // Đính kèm title và slug có chứa level
      request.fields['title'] = titleWithLv;
      request.fields['Title'] = titleWithLv;
      request.fields['post_title'] = titleWithLv;
      request.fields['slug'] = slugWithLv;
      request.fields['Slug'] = slugWithLv;
      request.fields['post_name'] = slugWithLv;

      debugPrint('ScrmaiApiService: Submitting score via form-data -> title: "$titleWithLv", slug: "$slugWithLv", member: $memberStr, game: $gameWithLevel, level: $cleanLevel, score: $scoreStr');

      final streamedResponse = await request.send().timeout(const Duration(seconds: 7));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('ScrmaiApiService: Score submitted successfully (${response.statusCode}): ${response.body}');
        return true;
      } else {
        debugPrint('ScrmaiApiService: Failed to submit score: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('ScrmaiApiService: submitScore error (Fallback to secondary): $e');
    }
    return false;
  }

  /// Lấy danh sách bảng điểm HocZiTa từ NKS SCRMAI API
  Future<List<ScrmaiScoreItem>> fetchScores({int page = 1, int limit = 20}) async {
    try {
      final url = Uri.parse('$_baseUrl/hoczita/score');
      final body = jsonEncode({
        'page': page,
        'limit': limit,
      });

      final response = await http
          .post(url, headers: _headers, body: body)
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final data = decoded['data'];
        if (data is List) {
          return data.map((e) => ScrmaiScoreItem.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('ScrmaiApiService: fetchScores error: $e');
    }
    return [];
  }
}
