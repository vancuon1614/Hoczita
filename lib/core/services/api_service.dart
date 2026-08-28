import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  ApiService._internal();

  static const String _accountBaseUrl = 'https://account.nks.vn/api';
  static const String _onlineBaseUrl = 'https://online.nks.vn/api';

  // Local storage keys
  static const String _tokenKey = 'nks_access_token';
  static const String _userInfoKey = 'nks_user_info';

  String? _accessToken;
  Map<String, dynamic>? _cachedUserInfo;

  // Initialize service
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
    final cachedInfoStr = prefs.getString(_userInfoKey);
    if (cachedInfoStr != null) {
      try {
        _cachedUserInfo = jsonDecode(cachedInfoStr) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Error decoding cached user info: $e');
      }
    }
  }

  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;
  String? get accessToken => _accessToken;
  Map<String, dynamic>? get cachedUserInfo => _cachedUserInfo;

  // Save authentication token
  Future<void> _saveToken(String token) async {
    _accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Clear authentication session
  Future<void> clearSession() async {
    _accessToken = null;
    _cachedUserInfo = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userInfoKey);
  }

  // 1. Đăng nhập hệ thống (nks/user/login)
  // URL: https://account.nks.vn/api/nks/user/login
  // Method: POST
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    String fbtoken = '',
    String system = 'NKS',
    String device = 'Mobile App',
    String ipAddress = '127.0.0.1',
    String location = '10.7789,106.6880',
  }) async {
    final url = Uri.parse('$_accountBaseUrl/nks/user/login');
    try {
      final response = await http.post(
        url,
        body: {
          'username': username,
          'password': password,
          'fbtoken': fbtoken,
          'system': system,
          'device': device,
          'ip_address': ipAddress,
          'location': location,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Check success based on standard API formats
        final bool isSuccess = data['success'] ?? (data['error'] == null);
        
        if (isSuccess && data['data'] != null && data['data']['access_token'] != null) {
          final String token = data['data']['access_token'];
          await _saveToken(token);
          
          _cachedUserInfo = data['data']['user'] ?? data['data'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_userInfoKey, jsonEncode(_cachedUserInfo));
        }
        return data;
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Login API error: $e');
      rethrow;
    }
  }

  // 2. Lấy thông tin tài khoản đăng nhập (nks/user)
  // URL: https://account.nks.vn/api/nks/user
  // Method: POST
  Future<Map<String, dynamic>> getUserInfo() async {
    if (!hasToken) {
      throw Exception('Unauthenticated: Access token is missing');
    }
    
    final url = Uri.parse('$_accountBaseUrl/nks/user');
    try {
      final response = await http.post(
        url,
        body: {
          'access_token': _accessToken!,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final bool isSuccess = data['success'] ?? (data['error'] == null);
        
        if (isSuccess && data['data'] != null) {
          _cachedUserInfo = data['data']['user'] ?? data['data'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_userInfoKey, jsonEncode(_cachedUserInfo));
        }
        return data;
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Get User Info API error: $e');
      rethrow;
    }
  }

  // 3. Cập nhật thông tin thành viên (nks/user/updateInfo)
  // URL: https://account.nks.vn/api/nks/user/updateInfo
  // Method: POST
  Future<Map<String, dynamic>> updateUserInfo({
    required String firstname,
    required String lastname,
    String intro = '',
    required String phone,
    required int gender, // 0 for Male, 1 for Female
    String website = '',
    String dob = '', // yyyy-mm-dd
    String pob = '',
    String idNumber = '',
    String idDate = '',
    String idPlace = '',
    String province = '',
  }) async {
    if (!hasToken) {
      throw Exception('Unauthenticated: Access token is missing');
    }

    final url = Uri.parse('$_accountBaseUrl/nks/user/updateInfo');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Accept'] = 'application/json';
      
      request.fields['access_token'] = _accessToken!;
      request.fields['firstname'] = firstname;
      request.fields['lastname'] = lastname;
      request.fields['intro'] = intro;
      request.fields['phone'] = phone;
      request.fields['gender'] = gender.toString();
      request.fields['website'] = website;
      request.fields['pob'] = pob;
      request.fields['id_number'] = idNumber;
      request.fields['id_place'] = idPlace;
      request.fields['province'] = province;
      
      // Dates can cause 500 SQL errors if passed as empty strings, so conditionally add them
      if (dob.isNotEmpty) request.fields['dob'] = dob;
      if (idDate.isNotEmpty) request.fields['id_date'] = idDate;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final bool isSuccess = data['success'] ?? (data['error'] == null);
        if (isSuccess) {
          await getUserInfo();
        } else {
          throw Exception('NKS Error: ${data['message'] ?? response.body}');
        }
        return data;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Update User Info API error: $e');
      rethrow;
    }
  }

  // 4. Cập nhật thông tin mật khẩu (nks/user/updatePass)
  // URL: https://account.nks.vn/api/nks/user/updatePass
  // Method: POST
  Future<Map<String, dynamic>> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (!hasToken) {
      throw Exception('Unauthenticated: Access token is missing');
    }

    final url = Uri.parse('$_accountBaseUrl/nks/user/updatePass');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Accept'] = 'application/json';
      request.fields['old_password'] = oldPassword;
      request.fields['password'] = newPassword;
      request.fields['access_token'] = _accessToken!;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final bool isSuccess = data['success'] ?? (data['error'] == null);
        if (!isSuccess) {
           throw Exception(data['message'] ?? response.body);
        }
        return data;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Update Password API error: $e');
      rethrow;
    }
  }

  // 5. Cập nhật ảnh đại diện (nks/user/updateAvatar)
  // URL: https://account.nks.vn/api/nks/user/updateAvatar
  // Method: POST
  Future<Map<String, dynamic>> updateAvatar({
    required String base64Image, // complete Base64 image string (with data:image/png;base64, prefix if needed)
  }) async {
    if (!hasToken) {
      throw Exception('Unauthenticated: Access token is missing');
    }

    final url = Uri.parse('$_accountBaseUrl/nks/user/updateAvatar');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Accept'] = 'application/json';
      request.fields['avatar'] = base64Image;
      request.fields['access_token'] = _accessToken!;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final bool isSuccess = data['success'] ?? (data['error'] == null);
        if (isSuccess) {
          await getUserInfo();
        } else {
          throw Exception('NKS Error: ${data['message'] ?? response.body}');
        }
        return data;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Update Avatar API error: $e');
      rethrow;
    }
  }

  // 6. Cập nhật căn cước công dân (nks/user/updateCccd)
  // URL: https://account.nks.vn/api/nks/user/updateCccd
  // Method: POST
  Future<Map<String, dynamic>> updateCccd({
    required String frontBase64,
    required String backBase64,
    required String number,
    required String date,
    required String place,
  }) async {
    if (!hasToken) {
      throw Exception('Unauthenticated: Access token is missing');
    }

    final url = Uri.parse('$_accountBaseUrl/nks/user/updateCccd');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Accept'] = 'application/json';
      request.fields['front'] = frontBase64;
      request.fields['back'] = backBase64;
      if (number.isNotEmpty) request.fields['number'] = number;
      if (date.isNotEmpty) request.fields['date'] = date;
      if (place.isNotEmpty) request.fields['place'] = place;
      request.fields['access_token'] = _accessToken!;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final bool isSuccess = data['success'] ?? (data['error'] == null);
        if (isSuccess) {
          await getUserInfo();
        }
        return data;
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Update CCCD API error: $e');
      rethrow;
    }
  }

  // 7. Lấy dữ liệu tỉnh, thành phố (provinces)
  // URL: https://online.nks.vn/api/nks/provinces
  // Method: POST
  Future<List<Map<String, dynamic>>> getProvinces({
    int countryId = 192,
    bool slcBox = true,
  }) async {
    final url = Uri.parse('$_onlineBaseUrl/nks/provinces?country_id=$countryId&slcBox=$slcBox');
    try {
      final response = await http.post(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> list = data['data'];
          return list.map((item) => <String, dynamic>{
            'id': item['id']?.toString() ?? '',
            'title': item['title']?.toString() ?? '',
          }).toList();
        }
        return [];
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Get Provinces API error: $e');
      return [];
    }
  }

  // 8. Lấy dữ liệu phường, xã (administratives)
  // URL: https://online.nks.vn/api/nks/administratives
  // Method: POST
  Future<List<Map<String, dynamic>>> getAdministratives({
    String? provinceId,
    String? districtId,
    bool slcBox = true,
  }) async {
    String query = 'slcBox=$slcBox';
    if (provinceId != null) query += '&province_id=$provinceId';
    if (districtId != null) query += '&district_id=$districtId';
    
    final url = Uri.parse('$_onlineBaseUrl/nks/administratives?$query');
    try {
      final response = await http.post(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final bool isSuccess = data['success'] ?? (data['error'] == null);
        if (isSuccess && data['data'] != null) {
          final List<dynamic> list = data['data'];
          return list.map((item) => <String, dynamic>{
            'id': item['id']?.toString() ?? '',
            'title': item['title']?.toString() ?? '',
          }).toList();
        }
        return [];
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Get Administratives API error: $e');
      return [];
    }
  }
}
