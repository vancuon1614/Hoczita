import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim().toLowerCase();
      final username = _usernameController.text.trim();
      final success = await ref.read(authProvider.notifier).signUp(
            email,
            _passwordController.text.trim(),
            username,
          );
      if (mounted) {
        if (success) {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          
          // Ghi nhớ tài khoản vừa đăng ký thành công
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
            debugPrint('Error saving registered account info: $e');
          }
          
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Đăng ký thành công! Hệ thống đã gửi email xác nhận. Vui lòng kiểm tra hộp thư của bạn.'),
              duration: Duration(seconds: 4),
            ),
          );
          navigator.pop(); // Quay lại LoginScreen
        } else {
          final errorMessage = ref.read(authProvider).errorMessage ?? 'Đăng ký thất bại.';
          _showErrorDialog(errorMessage);
        }
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lỗi Đăng Ký'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đồng ý'),
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
                    SizedBox(height: 40),
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
                            child: Icon(
                              Icons.school_rounded,
                              size: 48,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'HocZiTa',
                            style: GoogleFonts.baloo2(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Tạo tài khoản mới',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Đăng ký tài khoản để học tập và tích lũy điểm số.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    SizedBox(height: 24),

                    // Username Input
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Tên người dùng (Username)',
                        prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tên người dùng';
                        }
                        if (value.trim().length < 3) {
                          return 'Tên người dùng phải dài ít nhất 3 ký tự';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    // Email Input
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                      decoration: InputDecoration(
                        labelText: 'Địa chỉ Email',
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
                    SizedBox(height: 20),

                    // Password Input
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: Icon(Icons.lock_outlined, color: AppColors.textSecondary),
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
                    SizedBox(height: 20),

                    // Confirm Password Input
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Xác nhận mật khẩu',
                        prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng xác nhận mật khẩu';
                        }
                        if (value.startsWith(' ') || value.endsWith(' ')) {
                          return 'Mật khẩu không được bắt đầu hoặc kết thúc bằng khoảng trắng';
                        }
                        if (value != _passwordController.text) {
                          return 'Mật khẩu xác nhận không khớp';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 32),

                    // Register Button (240px wide, centered inside the 280px form)
                    Center(
                      child: SizedBox(
                        width: 240,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text('Đăng ký tài khoản'),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Login redirect
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Đã có tài khoản? ', style: GoogleFonts.baloo2(color: AppColors.textSecondary)),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            );
                          },
                          child: Text(
                            'Đăng nhập ngay',
                            style: GoogleFonts.baloo2(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 40),
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
