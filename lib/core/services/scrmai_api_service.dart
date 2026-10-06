import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ScrmaiScoreItem {
  final int id;
  final String title;
  final String member;
  final String game;
  final String level;
  final String score;
  final String createdAt;

  ScrmaiScoreItem({
    required this.id,
    required this.title,
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
      member: (json['member'] ?? '').toString(),
      game: (json['game'] ?? '').toString(),
      level: (json['level'] ?? '').toString(),
      score: (json['score'] ?? '0').toString(),
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

  /// Gửi điểm số mini-game lên NKS SCRMAI API (Ưu tiên 1)
  Future<bool> submitScore({
    required String member,
    required String game,
    required String level,
    required int score,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/hoczita/score/add');
      final body = jsonEncode({
        'member': member.trim().isNotEmpty ? member.trim() : 'Học sinh',
        'game': game,
        'level': level,
        'score': score.toString(),
      });

      debugPrint('ScrmaiApiService: Submitting score to NKS SCRMAI -> $body');

      final response = await http
          .post(url, headers: _headers, body: body)
          .timeout(const Duration(seconds: 7));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('ScrmaiApiService: Score submitted successfully (${response.statusCode})');
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
