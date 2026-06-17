import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/api_service.dart';

enum AuthStatus {
  unauthenticated,
  authenticating,
  authenticated,
}

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? username;
  final String? errorMessage;

  AuthState({
    required this.status,
    this.email,
    this.username,
    this.errorMessage,
  });

  factory AuthState.initial() {
    final apiService = ApiService.instance;
    if (apiService.hasToken) {
      final userInfo = apiService.cachedUserInfo;
      final email = userInfo?['email'] ?? '';
      final username = userInfo?['name'] ?? userInfo?['username'] ?? email.split('@')[0];
      return AuthState(
        status: AuthStatus.authenticated,
        email: email.isNotEmpty ? email : 'guest@hoczita.edu.vn',
        username: username.isNotEmpty ? username : 'Học sinh',
      );
    }
    
    final service = SupabaseService.instance;
    if (service.hasSession) {
      return AuthState(
        status: AuthStatus.authenticated,
        email: service.currentUserEmail,
        username: service.currentUsername,
      );
    }
    return AuthState(status: AuthStatus.unauthenticated);
  }

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? username,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      username: username ?? this.username,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  final SupabaseService _service = SupabaseService.instance;

  @override
  AuthState build() {
    return AuthState.initial();
  }

  void checkCurrentSession() {
    final apiService = ApiService.instance;
    if (apiService.hasToken) {
      final userInfo = apiService.cachedUserInfo;
      final email = userInfo?['email'] ?? '';
      final username = userInfo?['name'] ?? userInfo?['username'] ?? email.split('@')[0];
      state = AuthState(
        status: AuthStatus.authenticated,
        email: email.isNotEmpty ? email : 'guest@hoczita.edu.vn',
        username: username.isNotEmpty ? username : 'Học sinh',
      );
      return;
    }

    if (_service.hasSession) {
      state = AuthState(
        status: AuthStatus.authenticated,
        email: _service.currentUserEmail,
        username: _service.currentUsername,
      );
    } else {
      state = AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> syncUserDataToCache({
    required String name,
    required String avatar,
    required int point,
    required String email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_name_$email', name);
      await prefs.setString('cached_user_avatar_$email', avatar);
      await prefs.setInt('cached_user_point_$email', point);
      debugPrint('Synced user data to cache for: $email');
    } catch (e) {
      debugPrint('Error syncing user data to cache: $e');
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      // 1. Thử đăng nhập qua NKS API trước
      try {
        final response = await ApiService.instance.login(username: email, password: password);
        final bool isSuccess = response['success'] ?? (response['error'] == null);
        if (isSuccess && ApiService.instance.hasToken) {
          final userInfo = ApiService.instance.cachedUserInfo;
          final userEmail = userInfo?['email'] ?? email;
          final username = userInfo?['name'] ?? userInfo?['username'] ?? userEmail.split('@')[0];
          
          state = AuthState(
            status: AuthStatus.authenticated,
            email: userEmail,
            username: username,
          );
          
          // Đồng bộ cache cục bộ của user
          await syncUserDataToCache(
            name: username,
            avatar: userInfo?['avatar'] ?? '',
            point: userInfo?['point'] ?? 0,
            email: userEmail,
          );
          
          return true;
        }
      } catch (apiError) {
        debugPrint('NKS API Sign In failed, falling back to Supabase: $apiError');
      }

      // 2. Fallback sang Supabase
      final success = await _service.signIn(email: email, password: password);
      if (success) {
        state = AuthState(
          status: AuthStatus.authenticated,
          email: _service.currentUserEmail,
          username: _service.currentUsername,
        );
        return true;
      } else {
        state = AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Tài khoản không tồn tại trong hệ thống, vui lòng tạo mới.',
        );
        return false;
      }
    } catch (e) {
      String errMsg = e.toString().replaceFirst('Exception: ', '');
      final lowerMsg = errMsg.toLowerCase();
      if (lowerMsg.contains('invalid login credentials') || 
          lowerMsg.contains('invalid_credentials') ||
          lowerMsg.contains('user not found')) {
        errMsg = 'Tài khoản không tồn tại trong hệ thống, vui lòng tạo mới.';
      } else if (lowerMsg.contains('email_not_confirmed') || 
                 lowerMsg.contains('email not confirmed')) {
        errMsg = 'Tài khoản đã được tạo nhưng chưa xác nhận Email. Bạn hãy check hòm thư để xác nhận, hoặc tắt tính năng bắt buộc xác nhận Email trên Supabase Dashboard nhé!';
      }
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: errMsg,
      );
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String username) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      final success = await _service.signUp(email: email, password: password, username: username);
      if (success) {
        state = AuthState(
          status: AuthStatus.authenticated,
          email: _service.currentUserEmail,
          username: _service.currentUsername,
        );
        return true;
      } else {
        state = AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Đăng ký không thành công.',
        );
        return false;
      }
    } catch (e) {
      String errMsg = e.toString().replaceFirst('Exception: ', '');
      if (errMsg.toLowerCase().contains('already exists') || 
          errMsg.toLowerCase().contains('already registered')) {
        errMsg = 'Email này đã được đăng ký bởi một tài khoản khác.';
      }
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: errMsg,
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await ApiService.instance.clearSession();
    await _service.signOut();
    state = AuthState(status: AuthStatus.unauthenticated);
  }

  void enterDemoMode() {
    _service.enableOfflineDemoMode();
    state = AuthState(
      status: AuthStatus.authenticated,
      email: _service.currentUserEmail,
      username: _service.currentUsername,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
