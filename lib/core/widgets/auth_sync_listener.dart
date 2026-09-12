import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/learn/providers/checkin_provider.dart';

/// Bọc quanh MaterialApp (ở main.dart) để tự động reset các provider
/// phụ thuộc user (checkin, v.v...) mỗi khi tài khoản đăng nhập thay đổi.
class AuthSyncListener extends ConsumerWidget {
  final Widget child;
  const AuthSyncListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.email != next.email) {
        ref.invalidate(checkinProvider);
      }
    });
    return child;
  }
}
