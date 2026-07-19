import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/eduword_model.dart';

class EduwordService {
  static const String _baseUrl = 'https://sdata.io.vn/wp-json/scrmai/v1/eduwords';
  // TODO: We could store the token securely, but for now we hardcode the provided token
  static const String _token = '01KWKATNQGB5TWXYDPJ671X3X1';

  static Future<List<EduwordModel>> fetchWords({int page = 1, int limit = 10, int? length}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_baseUrl));
      request.headers['Authorization'] = 'Bearer $_token';
      
      request.fields['page'] = page.toString();
      request.fields['limit'] = limit.toString();
      request.fields['shuffle'] = 'true';
      if (length != null) {
        request.fields['length'] = length.toString();
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final List<dynamic> dataList = decoded['data'];
          return dataList.map((item) => EduwordModel.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching eduwords: $e');
      return [];
    }
  }
}
