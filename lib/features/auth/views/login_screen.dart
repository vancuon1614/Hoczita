import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Saved account state variables
  String? _savedEmail;
  bool _showSavedMode = false;
  List<String> _savedEmails = [];
  Map<String, String> _emailToUsername = {};
  Map<String, String> _emailToAvatarPath = {};

  @override
  void initState() {
    super.initState();
    _loadSavedEmails();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload avatar mỗi khi quay lại màn hình login (ví dụ: sau khi đổi ảnh ở profile)
    _loadSavedEmails();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastEmail = prefs.getString('saved_user_email');
      final emails = prefs.getStringList('saved_user_emails_list') ?? [];
      
      final Map<String, String> mappings = {};
      final Map<String, String> avatars = {};
      for (final email in emails) {
        final username = prefs.getString('username_$email') ?? email.split('@')[0];
        mappings[email] = username;
        final avatar = prefs.getString('profile_avatar_path_$email');
        if (avatar != null && avatar.isNotEmpty) {
          avatars[email] = avatar;
        }
      }
      
      setState(() {
        _savedEmails = emails;
        _emailToUsername = mappings;
        _emailToAvatarPath = avatars;
        if (lastEmail != null && emails.contains(lastEmail)) {
          _savedEmail = lastEmail;
          _showSavedMode = true;
        } else if (emails.isNotEmpty) {
          _savedEmail = emails.last;
          _showSavedMode = true;
        } else {
          _showSavedMode = false;
        }
      });
    } catch (e) {
      debugPrint('Error loading saved emails: $e');
    }
  }

  Future<void> _saveEmail(String email, String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = prefs.getStringList('saved_user_emails_list') ?? [];
      if (!currentList.contains(email)) {
        currentList.add(email);
        await prefs.setStringList('saved_user_emails_list', currentList);
      }
      await prefs.setString('saved_user_email', email);
      await prefs.setString('username_$email', username);
    } catch (e) {
      debugPrint('Error saving account: $e');
    }
  }

  Future<void> _deleteSavedEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedEmails.remove(email);
      await prefs.setStringList('saved_user_emails_list', _savedEmails);
      await prefs.remove('username_$email');
      
      if (prefs.getString('saved_user_email') == email) {
        if (_savedEmails.isNotEmpty) {
          await prefs.setString('saved_user_email', _savedEmails.last);
          _savedEmail = _savedEmails.last;
        } else {
          await prefs.remove('saved_user_email');
          _savedEmail = null;
          _showSavedMode = false;
        }
      } else {
        if (_savedEmails.isEmpty) {
          _savedEmail = null;
          _showSavedMode = false;
        }
      }
    } catch (e) {
      debugPrint('Error deleting saved email: $e');
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      return 'Chào buổi sáng';
    } else if (hour >= 11 && hour < 18) {
      return 'Chào buổi chiều';
    } else {
      return 'Chào buổi tối';
    }
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final email = _showSavedMode && _savedEmail != null 
          ? _savedEmail! 
          : _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();

      final success = await ref.read(authProvider.notifier).signIn(
            email,
            password,
          );

      if (mounted) {
        if (success) {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          
          final authState = ref.read(authProvider);
          final username = authState.username ?? email.split('@')[0];

          await _saveEmail(email, username);

          messenger.showSnackBar(
            const SnackBar(content: Text('Đăng nhập thành công! 🎉')),
          );
          navigator.pop(); // Trở về MainScreen
        } else {
          final errorMessage = ref.read(authProvider).errorMessage ?? 'Đăng nhập thất bại.';
          _showErrorDialog(errorMessage);
        }
      }
    }
  }

  // void _handleOfflineDemo() {
  //   ref.read(authProvider.notifier).enterDemoMode();
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text('Đã kích hoạt Chế độ Demo Offline! 🚀')),
  //   );
  //   Navigator.pop(context);
  // }

  void _showErrorDialog(String message) {
    final lowerMsg = message.toLowerCase();
    final isNetworkOrServerError = lowerMsg.contains('503') ||
        lowerMsg.contains('connection') ||
        lowerMsg.contains('timeout') ||
        lowerMsg.contains('kết nối') ||
        lowerMsg.contains('máy chủ') ||
        lowerMsg.contains('mạng') ||
        lowerMsg.contains('failed host lookup');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNetworkOrServerError ? 'Lỗi Kết Nối Máy Chủ' : 'Lỗi Đăng Nhập'),
        content: Text(isNetworkOrServerError
            ? '$message\n\nHiện tại máy chủ đang gặp sự cố hoặc đang bảo trì. Bạn có muốn tiếp tục sử dụng ứng dụng ở chế độ Demo ngoại tuyến (Offline) không?'
            : message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isNetworkOrServerError ? 'Hủy' : 'Đồng ý'),
          ),
          if (isNetworkOrServerError)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                ref.read(authProvider.notifier).enterDemoMode();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã kích hoạt Chế độ Demo Offline! 🚀')),
                );
                Navigator.pop(context); // Return to MainScreen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Chế độ Offline'),
            ),
        ],
      ),
    );
  }

  /// Trả về [ImageProvider] phù hợp với định dạng lưu trữ avatar.
  /// - Data URL (base64): dùng MemoryImage
  /// - File path (mobile): dùng FileImage
  ImageProvider? _resolveAvatarImageProvider(String avatarPath) {
    if (avatarPath.isEmpty) return null;
    if (avatarPath.startsWith('data:image/')) {
      // Lấy phần base64 sau dấu phẩy
      final commaIndex = avatarPath.indexOf(',');
      if (commaIndex == -1) return null;
      try {
        final base64Str = avatarPath.substring(commaIndex + 1);
        final bytes = base64Decode(base64Str);
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint('Error decoding avatar base64: $e');
        return null;
      }
    }
    if (kIsWeb) {
      // blob: URL hoặc http URL trên web
      return NetworkImage(avatarPath);
    }
    // Đường dẫn file trên mobile/desktop
    return FileImage(File(avatarPath));
  }

  Widget _buildAvatarWidget(String email, double radius, double iconSize) {
    final avatarPath = _emailToAvatarPath[email];
    final hasAvatar = avatarPath != null && avatarPath.isNotEmpty;
    final imageProvider = hasAvatar ? _resolveAvatarImageProvider(avatarPath) : null;
    final showAvatar = imageProvider != null;

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryLight,
      backgroundImage: showAvatar ? imageProvider : null,
      child: showAvatar
          ? null
          : Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: iconSize,
            ),
    );
  }

  void _showAccountSelectorBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Chọn tài khoản',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_savedEmails.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Không có tài khoản nào được lưu',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _savedEmails.length,
                          itemBuilder: (context, index) {
                            final email = _savedEmails[index];
                            final username = _emailToUsername[email] ?? email.split('@')[0];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primary, width: 1.5),
                                ),
                                child: _buildAvatarWidget(email, 18, 20),
                              ),
                              title: Text(
                                username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                email,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.error,
                                ),
                                onPressed: () async {
                                  await _deleteSavedEmail(email);
                                  setModalState(() {});
                                  setState(() {});
                                },
                              ),
                              onTap: () {
                                setState(() {
                                  _savedEmail = email;
                                  _showSavedMode = true;
                                });
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                    const Divider(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: AppColors.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          _showSavedMode = false;
                        });
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Sử dụng tài khoản khác'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSavedAccountCard() {
    final email = _savedEmail ?? '';
    final username = _emailToUsername[email] ?? email.split('@')[0];

    return Container(
      width: 300,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: _buildAvatarWidget(email, 20, 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.swap_horiz_rounded,
              color: Colors.black87,
              size: 24,
            ),
            onPressed: _showAccountSelectorBottomSheet,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.authenticating;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Center(
            child: SizedBox(
              width: 300,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    // Brand Title Logo "HocZiTa"
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              size: 48,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'HocZiTa',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Heading logo or Saved Account Greeting
                    if (_showSavedMode && _savedEmail != null) ...[
                      Center(
                        child: Text(
                          _getGreeting(),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          _emailToUsername[_savedEmail] ?? _savedEmail!.split('@')[0],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(child: _buildSavedAccountCard()),
                      const SizedBox(height: 20),
                    ] else ...[
                      const Text(
                        'Chào mừng quay lại!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Đăng nhập để tiếp tục học và tích lũy điểm số.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Email Input (only if NOT in saved mode)
                    if (!_showSavedMode) ...[
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                        decoration: const InputDecoration(
                          labelText: 'Địa chỉ Email',
                          hintText: 'email@domain.com',
                          prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập địa chỉ email';
                          }
                          final trimmed = value.trim();
                          if (trimmed.isEmpty) {
                            return 'Email không được chỉ chứa khoảng trắng';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[a-zA-Z]{2,}$').hasMatch(trimmed)) {
                            return 'Email không hợp lệ (ví dụ: hocsinh@domain.com)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Password Input
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outlined, color: AppColors.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập mật khẩu';
                        }
                        if (value.startsWith(' ') || value.endsWith(' ')) {
                          return 'Mật khẩu không được bắt đầu hoặc kết thúc bằng khoảng trắng';
                        }
                        if (value.length < 6) {
                          return 'Mật khẩu phải dài ít nhất 6 ký tự';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),

                    // Login Button (240px wide, centered)
                    Center(
                      child: SizedBox(
                        width: 240,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Đăng nhập'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Offline Demo Shortcut (Commented out per user choice)
                    /*
                    OutlinedButton(
                      onPressed: isLoading ? null : _handleOfflineDemo,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(color: AppColors.accent, width: 1.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt_rounded, color: AppColors.accent),
                          SizedBox(width: 8),
                          Text(
                            'Chế độ Demo Offline (Không cần mạng)',
                            style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    */

                    // Register redirect
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Chưa có tài khoản? ', style: TextStyle(color: AppColors.textSecondary)),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const RegisterScreen()),
                            );
                          },
                          child: const Text(
                            'Đăng ký ngay',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
