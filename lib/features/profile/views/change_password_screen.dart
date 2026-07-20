import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import 'package:google_fonts/google_fonts.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = SupabaseService.instance;

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isConfirmedSaved = false;
  bool _isLoading = false;

  // Password generator configuration
  double _genLength = 12.0;
  bool _genUppercase = true;
  bool _genLowercase = true;
  bool _genNumbers = true;
  bool _genSpecial = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _generateAndFillPassword() {
    // Bottom sheet options panel for generation
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
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tạo mật khẩu ngẫu nhiên',
                          style: GoogleFonts.baloo2(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    
                    // Slider for length
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Số lượng ký tự:',
                          style: GoogleFonts.baloo2(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        Text(
                          '${_genLength.toInt()} ký tự',
                          style: GoogleFonts.baloo2(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _genLength,
                      min: 8.0,
                      max: 30.0,
                      divisions: 22,
                      activeColor: AppColors.primary,
                      inactiveColor: AppColors.primaryLight,
                      onChanged: (val) {
                        setModalState(() {
                          _genLength = val;
                        });
                      },
                    ),
                    
                    // Options grid or list
                    CheckboxListTile(
                      title: Text('Ký tự hoa (A-Z)', style: GoogleFonts.baloo2(fontSize: 12)),
                      value: _genUppercase,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setModalState(() {
                          _genUppercase = val ?? true;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    CheckboxListTile(
                      title: Text('Ký tự thường (a-z)', style: GoogleFonts.baloo2(fontSize: 12)),
                      value: _genLowercase,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setModalState(() {
                          _genLowercase = val ?? true;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    CheckboxListTile(
                      title: Text('Ký tự số (0-9)', style: GoogleFonts.baloo2(fontSize: 12)),
                      value: _genNumbers,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setModalState(() {
                          _genNumbers = val ?? true;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    CheckboxListTile(
                      title: Text('Ký tự đặc biệt (!@#...)', style: GoogleFonts.baloo2(fontSize: 12)),
                      value: _genSpecial,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setModalState(() {
                          _genSpecial = val ?? true;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    SizedBox(height: 20),
                    
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final password = _doGeneratePassword();
                        _newPasswordController.text = password;
                        _confirmPasswordController.text = password;
                        
                        // Force validation update
                        setState(() {});
                        
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã tự động điền mật khẩu ngẫu nhiên! 🔑'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Text(
                        'Tạo & áp dụng mật khẩu',
                        style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
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

  String _doGeneratePassword() {
    const String upperChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String lowerChars = 'abcdefghijklmnopqrstuvwxyz';
    const String numberChars = '0123456789';
    const String specialChars = '!@#\$%^&*()_+-=[]{}|;:,./<>?';

    String allowedChars = '';
    List<String> guaranteed = [];
    final rand = Random.secure();

    if (_genUppercase) {
      allowedChars += upperChars;
      guaranteed.add(upperChars[rand.nextInt(upperChars.length)]);
    }
    if (_genLowercase) {
      allowedChars += lowerChars;
      guaranteed.add(lowerChars[rand.nextInt(lowerChars.length)]);
    }
    if (_genNumbers) {
      allowedChars += numberChars;
      guaranteed.add(numberChars[rand.nextInt(numberChars.length)]);
    }
    if (_genSpecial) {
      allowedChars += specialChars;
      guaranteed.add(specialChars[rand.nextInt(specialChars.length)]);
    }

    if (allowedChars.isEmpty) {
      allowedChars = lowerChars + numberChars;
      guaranteed.add(lowerChars[rand.nextInt(lowerChars.length)]);
      guaranteed.add(numberChars[rand.nextInt(numberChars.length)]);
    }

    final int length = _genLength.toInt();
    final int remainingLength = length - guaranteed.length;
    final List<String> result = [...guaranteed];
    
    for (int i = 0; i < remainingLength; i++) {
      result.add(allowedChars[rand.nextInt(allowedChars.length)]);
    }

    result.shuffle(rand);
    return result.join();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isConfirmedSaved) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _db.updatePassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật mật khẩu thành công! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xác thực mật khẩu cũ thất bại. Vui lòng kiểm tra lại.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating password: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = _isConfirmedSaved && !_isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Đổi mật khẩu',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield_rounded, color: AppColors.primary, size: 36),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Mật khẩu mới của bạn cần có độ bảo mật cao để bảo vệ tài khoản tốt nhất.',
                                style: GoogleFonts.baloo2(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),

                      // Old Password Input
                      TextFormField(
                        controller: _oldPasswordController,
                        obscureText: _obscureOld,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu hiện tại (Old Pass)',
                          hintText: 'Nhập mật khẩu đang sử dụng',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureOld ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureOld = !_obscureOld;
                              });
                            },
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập mật khẩu hiện tại';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 18),

                      // New Password Input
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới (New Pass)',
                          hintText: 'Nhập mật khẩu mới',
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Tạo mật khẩu ngẫu nhiên',
                                icon: Icon(
                                  Icons.auto_awesome_rounded,
                                  color: AppColors.primary,
                                ),
                                onPressed: _generateAndFillPassword,
                              ),
                              IconButton(
                                icon: Icon(
                                  _obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureNew = !_obscureNew;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập mật khẩu mới';
                          }
                          if (val.length < 6) {
                            return 'Mật khẩu phải dài ít nhất 6 ký tự';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 18),

                      // Confirm New Password Input
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Xác nhận mật khẩu mới (Confirm New Pass)',
                          hintText: 'Nhập lại mật khẩu mới',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirm = !_obscureConfirm;
                              });
                            },
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng xác nhận mật khẩu mới';
                          }
                          if (val != _newPasswordController.text) {
                            return 'Mật khẩu xác nhận không trùng khớp';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 24),

                      // Confirm checkbox
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Xác nhận tôi đã lưu / ghi nhớ mật khẩu mới này',
                          style: GoogleFonts.baloo2(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Mật khẩu sẽ thay đổi và bạn cần mật khẩu này cho lần đăng nhập sau.',
                          style: GoogleFonts.baloo2(
                            fontSize: 12, 
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        value: _isConfirmedSaved,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() {
                            _isConfirmedSaved = val ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canSubmit ? AppColors.primary : Colors.grey[300],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: canSubmit ? 2 : 0,
                          ),
                          onPressed: canSubmit ? _updatePassword : null,
                          child: Text(
                            'Cập nhật mật khẩu',
                            style: GoogleFonts.baloo2(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
