import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

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

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
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
