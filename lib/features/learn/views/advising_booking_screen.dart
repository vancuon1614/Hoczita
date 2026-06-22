import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class AdvisingBookingScreen extends StatefulWidget {
  const AdvisingBookingScreen({super.key});

  @override
  State<AdvisingBookingScreen> createState() => _AdvisingBookingScreenState();
}

class _AdvisingBookingScreenState extends State<AdvisingBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  final List<String> _courses = [
    'Tiếng anh 1:1',
    'Tiếng Anh giao tiếp',
    'Tiếng Anh dành cho người đi làm',
  ];

  String? _selectedCourse;
  DateTime? _selectedDateTime;
  
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _prefillUserInfo();
  }

  void _prefillUserInfo() async {
    final supabase = SupabaseService.instance;
    if (supabase.hasSession) {
      _emailController.text = supabase.currentUserEmail ?? '';
      _fullNameController.text = supabase.currentUsername ?? '';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 9, minute: 0),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn khóa học cần tư vấn!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn thời gian hẹn gặp tư vấn!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final success = await SupabaseService.instance.saveBooking(
        course: _selectedCourse!,
        dateTime: _selectedDateTime!,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        notes: _notesController.text.trim(),
      );

      if (success && mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi đặt lịch: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
            SizedBox(width: 10),
            Text('Thành Công! 🎉'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lịch đặt tư vấn 1:1 của bạn đã được ghi nhận thành công.',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              '📧 Email thông báo đã được gửi cho Admin (vanncuong1614@gmail.com) và Khách hàng (${_emailController.text}).',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              Navigator.pop(context); // Quay về màn hình trước
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = _selectedDateTime == null
        ? 'Chọn thời gian tư vấn'
        : '${_selectedDateTime!.day}/${_selectedDateTime!.month}/${_selectedDateTime!.year} vào lúc ${_selectedDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Đặt Lịch Tư Vấn 1:1 📅',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Bé/Phụ huynh vui lòng để lại thông tin đặt lịch để được giáo viên liên hệ tư vấn trực tiếp 1:1 nhé!',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),

                // Dropdown khóa học
                const Text(
                  'Chọn Khóa Học Tư Vấn',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCourse,
                      hint: const Text('Chọn khóa học...'),
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      items: _courses.map((course) {
                        return DropdownMenuItem(
                          value: course,
                          child: Text(course),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCourse = val;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Thời gian hẹn tư vấn
                const Text(
                  'Chọn Thời Gian Hẹn Gặp',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectDateTime,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedDateTime == null ? AppColors.textSecondary : AppColors.textPrimary,
                              fontWeight: _selectedDateTime == null ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Họ tên
                _buildFieldTitle('Họ và Tên'),
                TextFormField(
                  controller: _fullNameController,
                  decoration: _buildInputDecoration('Nhập họ tên của bé / phụ huynh'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Vui lòng nhập họ tên!';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // SĐT
                _buildFieldTitle('Số Điện Thoại'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _buildInputDecoration('Nhập số điện thoại liên hệ'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Vui lòng nhập số điện thoại!';
                    if (val.trim().length < 9) return 'Số điện thoại không hợp lệ!';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Email
                _buildFieldTitle('Email'),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _buildInputDecoration('Nhập email để nhận thông báo'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Vui lòng nhập email!';
                    if (!val.contains('@')) return 'Email không hợp lệ!';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Ghi chú
                _buildFieldTitle('Ghi Chú'),
                TextFormField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: _buildInputDecoration('Bổ sung ghi chú cần thiết (nếu có)...'),
                ),
                const SizedBox(height: 32),

                // Button submit
                ElevatedButton(
                  onPressed: _isSaving ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Đăng Ký Đặt Lịch',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }
}
