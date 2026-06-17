import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'edit_profile_screen.dart';
import 'crop_avatar_screen.dart';
import 'change_password_screen.dart';

class ProfileDetailScreen extends ConsumerStatefulWidget {
  const ProfileDetailScreen({super.key});

  @override
  ConsumerState<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends ConsumerState<ProfileDetailScreen> {
  final SupabaseService _db = SupabaseService.instance;
  
  final String _code = '100123456789';
  String _fullName = 'Chưa cập nhật';
  String _email = 'Chưa cập nhật';
  String _gender = 'Chưa cập nhật';
  String _dob = 'Chưa cập nhật';
  String _pob = 'Chưa cập nhật';
  String _idCard = 'Chưa cập nhật';
  String _idCardDate = '';
  String _idCardPlace = '';
  String _address = 'Chưa cập nhật';
  String _tempAddress = 'Chưa cập nhật';
  
  String? _avatarPath;
  int _totalScore = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileDetails();
  }

  Future<void> _loadProfileDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final score = await _db.getTotalScore();
      final email = ref.read(authProvider).email?.trim().toLowerCase() ?? '';
      final defaultUsername = ref.read(authProvider).username ?? '';
      
      // Load user-scoped values first, fallback to legacy/global values, fallback to empty/defaults
      final String fullName = prefs.getString('profile_fullName_$email') 
          ?? prefs.getString('profile_fullName') 
          ?? defaultUsername;
          
      final String gender = prefs.getString('profile_gender_$email') 
          ?? prefs.getString('profile_gender') 
          ?? '';
          
      final String dob = prefs.getString('profile_dob_$email') 
          ?? prefs.getString('profile_dob') 
          ?? '';
          
      final String pob = prefs.getString('profile_pob_$email') 
          ?? prefs.getString('profile_pob') 
          ?? '';
          
      final String idCard = prefs.getString('profile_idCard_$email') 
          ?? prefs.getString('profile_idCard') 
          ?? '';
          
      final String idCardDate = prefs.getString('profile_idCardDate_$email') 
          ?? prefs.getString('profile_idCardDate') 
          ?? '';
          
      final String idCardPlace = prefs.getString('profile_idCardPlace_$email') 
          ?? prefs.getString('profile_idCardPlace') 
          ?? '';
          
      String? avatarPath;
      if (email.isNotEmpty) {
        avatarPath = prefs.getString('profile_avatar_path_$email');
      }
      avatarPath ??= prefs.getString('profile_avatar_path');
      
      final String street = prefs.getString('profile_street_$email') ?? prefs.getString('profile_street') ?? '';
      final String ward = prefs.getString('profile_ward_$email') ?? prefs.getString('profile_ward') ?? '';
      final String district = prefs.getString('profile_district_$email') ?? prefs.getString('profile_district') ?? '';
      final String province = prefs.getString('profile_province_$email') ?? prefs.getString('profile_province') ?? '';
      final String numHouse = prefs.getString('profile_address_$email') ?? prefs.getString('profile_address') ?? '';
      
      List<String> addressParts = [];
      if (numHouse.isNotEmpty) addressParts.add(numHouse);
      if (street.isNotEmpty && !numHouse.contains(street)) addressParts.add(street);
      if (ward.isNotEmpty) addressParts.add(ward);
      if (district.isNotEmpty) addressParts.add(district);
      if (province.isNotEmpty) addressParts.add(province);
      
      String formattedAddr = addressParts.isNotEmpty ? addressParts.join(', ') : '';

      setState(() {
        _email = email.isNotEmpty ? email : 'guest@hoczita.edu.vn';
        _fullName = fullName.isNotEmpty ? fullName : 'Chưa cập nhật';
        _gender = gender.isNotEmpty ? gender : 'Chưa cập nhật';
        _dob = dob.isNotEmpty ? dob : 'Chưa cập nhật';
        _pob = pob.isNotEmpty ? pob : 'Chưa cập nhật';
        _idCard = idCard.isNotEmpty ? idCard : 'Chưa cập nhật';
        _idCardDate = idCardDate;
        _idCardPlace = idCardPlace;
        _address = formattedAddr.isNotEmpty ? formattedAddr : 'Chưa cập nhật';
        _tempAddress = formattedAddr.isNotEmpty ? formattedAddr : 'Chưa cập nhật';
        _totalScore = score;
        _avatarPath = avatarPath;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
    if (result == true) {
      setState(() {
        _isLoading = true;
      });
      _loadProfileDetails();
    }
  }

  void _navigateToChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
    );
  }

  Future<void> _selectAndCropAvatar() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: const Text('Chụp ảnh mới', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: const Text('Chọn từ thư viện', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null) return;

      if (mounted) {
        final String? croppedPath = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CropAvatarScreen(imagePath: pickedFile.path),
          ),
        );

        if (croppedPath != null) {
          setState(() {
            _isLoading = true;
          });

          // Convert to Base64 for the server API
          String base64Image;
          if (kIsWeb) {
            base64Image = croppedPath;
          } else {
            final bytes = await File(croppedPath).readAsBytes();
            final base64Str = base64Encode(bytes);
            base64Image = 'data:image/png;base64,$base64Str';
          }

          // Call API
          final apiService = ApiService.instance;
          final response = await apiService.updateAvatar(base64Image: base64Image);
          final bool isSuccess = response['success'] ?? (response['error'] == null);

          if (isSuccess) {
            // Get updated URL if returned, otherwise fallback to local/base64 path
            String finalPath = croppedPath;
            if (response['data'] != null && response['data']['avatar'] != null) {
              finalPath = response['data']['avatar'].toString();
            }

            final prefs = await SharedPreferences.getInstance();
            final email = ref.read(authProvider).email?.trim().toLowerCase();
            await prefs.setString('profile_avatar_path', finalPath);
            if (email != null && email.isNotEmpty) {
              await prefs.setString('profile_avatar_path_$email', finalPath);
              // Also sync with the cached_user_avatar key to update ProfileTab instantly
              await prefs.setString('cached_user_avatar_$email', finalPath);
            }

            setState(() {
              _avatarPath = finalPath;
              _isLoading = false;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cập nhật ảnh đại diện thành công! 🎉')),
              );
            }
          } else {
            final errorMsg = response['error']?.toString() ?? 'Lỗi không xác định từ máy chủ.';
            throw Exception(errorMsg);
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating avatar: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể cập nhật ảnh đại diện: $e')),
        );
      }
    }
  }

  ImageProvider? _getAvatarImageProvider(String path) {
    if (path.isEmpty) return null;
    if (path.startsWith('data:image/') || 
        path.startsWith('blob:') || 
        path.startsWith('http://') || 
        path.startsWith('https://') || 
        kIsWeb) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: AppColors.textPrimary),
            onPressed: _navigateToEditProfile,
            tooltip: 'Chỉnh sửa hồ sơ',
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    
                    // Avatar stack section
                    Center(
                      child: GestureDetector(
                        onTap: _selectAndCropAvatar,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary, width: 2.5),
                              ),
                              child: CircleAvatar(
                                radius: 54,
                                backgroundColor: AppColors.primaryLight,
                                backgroundImage: _avatarPath != null && _avatarPath!.isNotEmpty
                                    ? _getAvatarImageProvider(_avatarPath!)
                                    : null,
                                child: _avatarPath != null && _avatarPath!.isNotEmpty
                                    ? null
                                    : const Icon(
                                        Icons.person_rounded,
                                        size: 72,
                                        color: AppColors.primary,
                                      ),
                              ),
                            ),
                            // Small black star on bottom right overlap
                            Positioned(
                              bottom: 2,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.star_rounded,
                                  color: Colors.black,
                                  size: 28,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Score
                    Text(
                      '$_totalScore điểm',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Stacked profile boxes
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            children: [
                              _buildDetailItem('Code', _code),
                              _buildDetailItem('Họ và tên', _fullName),
                              _buildDetailItem('Email', _email),
                              _buildDetailItem('Giới tính', _gender),
                              _buildDetailItem('Ngày sinh', _dob),
                              _buildDetailItem('Nơi sinh', _pob),
                              _buildDetailItemWithEdit(
                                'CMND',
                                _idCard,
                                subtext: (_idCardDate.isEmpty && _idCardPlace.isEmpty)
                                    ? 'Chưa cập nhật'
                                    : 'Cấp ngày $_idCardDate tại $_idCardPlace',
                                onEdit: _navigateToEditProfile,
                              ),
                              _buildDetailItem('Địa chỉ', _address),
                              _buildDetailItem('Địa chỉ tạm trú', _tempAddress, isLast: true),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Security section
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'BẢO MẬT & TÀI KHOẢN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _navigateToChangePassword,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 28),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Đổi mật khẩu',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Cập nhật mật khẩu bảo mật tài khoản',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isLast = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItemWithEdit(
    String label,
    String value, {
    required String subtext,
    required VoidCallback onEdit,
    bool isLast = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtext.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtext,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_square, color: AppColors.textSecondary, size: 20),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}
