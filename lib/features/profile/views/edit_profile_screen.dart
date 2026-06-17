import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _genderController = TextEditingController();
  final _dobController = TextEditingController();
  final _pobController = TextEditingController();
  final _idCardController = TextEditingController();
  final _idCardDateController = TextEditingController();
  final _idCardPlaceController = TextEditingController();
  final _addressController = TextEditingController();
  final _streetController = TextEditingController();
  final _wardController = TextEditingController();
  final _districtController = TextEditingController();
  final _provinceController = TextEditingController();

  bool _isLoading = true;

  // Geography API variables
  List<Map<String, dynamic>> _provinceList = [];
  List<Map<String, dynamic>> _districtList = [];
  List<Map<String, dynamic>> _wardList = [];
  String? _selectedProvinceId;
  String? _selectedDistrictId;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadProvinces();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _genderController.dispose();
    _dobController.dispose();
    _pobController.dispose();
    _idCardController.dispose();
    _idCardDateController.dispose();
    _idCardPlaceController.dispose();
    _addressController.dispose();
    _streetController.dispose();
    _wardController.dispose();
    _districtController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = ref.read(authProvider).email?.trim().toLowerCase() ?? '';
      final defaultUsername = ref.read(authProvider).username ?? '';

      setState(() {
        _fullNameController.text = prefs.getString('profile_fullName_$email') 
            ?? prefs.getString('profile_fullName') 
            ?? defaultUsername;
            
        _emailController.text = email.isNotEmpty ? email : (prefs.getString('profile_email') ?? '');
        
        _phoneController.text = prefs.getString('profile_phone_$email') 
            ?? prefs.getString('profile_phone') 
            ?? '';
            
        _genderController.text = prefs.getString('profile_gender_$email') 
            ?? prefs.getString('profile_gender') 
            ?? '';
            
        _dobController.text = prefs.getString('profile_dob_$email') 
            ?? prefs.getString('profile_dob') 
            ?? '';
            
        _pobController.text = prefs.getString('profile_pob_$email') 
            ?? prefs.getString('profile_pob') 
            ?? '';
            
        _idCardController.text = prefs.getString('profile_idCard_$email') 
            ?? prefs.getString('profile_idCard') 
            ?? '';
            
        _idCardDateController.text = prefs.getString('profile_idCardDate_$email') 
            ?? prefs.getString('profile_idCardDate') 
            ?? '';
            
        _idCardPlaceController.text = prefs.getString('profile_idCardPlace_$email') 
            ?? prefs.getString('profile_idCardPlace') 
            ?? '';
            
        _addressController.text = prefs.getString('profile_address_$email') 
            ?? prefs.getString('profile_address') 
            ?? '';
            
        _streetController.text = prefs.getString('profile_street_$email') 
            ?? prefs.getString('profile_street') 
            ?? '';
            
        _wardController.text = prefs.getString('profile_ward_$email') 
            ?? prefs.getString('profile_ward') 
            ?? '';
            
        _districtController.text = prefs.getString('profile_district_$email') 
            ?? prefs.getString('profile_district') 
            ?? '';
            
        _provinceController.text = prefs.getString('profile_province_$email') 
            ?? prefs.getString('profile_province') 
            ?? '';
        
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProvinces() async {
    try {
      final list = await ApiService.instance.getProvinces();
      setState(() {
        _provinceList = list;
      });
      
      // Khôi phục lại ID của tỉnh hiện tại để lấy tiếp quận/huyện
      final currentProvince = _provinceController.text.trim();
      if (currentProvince.isNotEmpty) {
        final match = _provinceList.firstWhere(
          (p) => p['title'].toString().toLowerCase() == currentProvince.toLowerCase(),
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          _selectedProvinceId = match['id'].toString();
          await _loadDistricts(match['id'].toString());
        }
      }
    } catch (e) {
      debugPrint('Error loading provinces: $e');
    }
  }

  Future<void> _loadDistricts(String provinceId) async {
    try {
      final list = await ApiService.instance.getAdministratives(provinceId: provinceId);
      setState(() {
        _districtList = list;
      });
      
      // Khôi phục lại ID của quận/huyện hiện tại để lấy tiếp phường/xã
      final currentDistrict = _districtController.text.trim();
      if (currentDistrict.isNotEmpty) {
        final match = _districtList.firstWhere(
          (d) => d['title'].toString().toLowerCase() == currentDistrict.toLowerCase(),
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          _selectedDistrictId = match['id'].toString();
          await _loadWards(match['id'].toString());
        }
      }
    } catch (e) {
      debugPrint('Error loading districts: $e');
    }
  }

  Future<void> _loadWards(String districtId) async {
    try {
      final list = await ApiService.instance.getAdministratives(districtId: districtId);
      setState(() {
        _wardList = list;
      });
    } catch (e) {
      debugPrint('Error loading wards: $e');
    }
  }

  void _showSelectionBottomSheet({
    required String title,
    required List<Map<String, dynamic>> items,
    required Function(Map<String, dynamic>) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        List<Map<String, dynamic>> filteredItems = List.from(items);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm...',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        onChanged: (query) {
                          setModalState(() {
                            filteredItems = items.where((item) {
                              final titleText = item['title'].toString().toLowerCase();
                              return titleText.contains(query.toLowerCase());
                            }).toList();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filteredItems.isEmpty
                            ? const Center(
                                child: Text('Không tìm thấy kết quả nào'),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filteredItems.length,
                                itemBuilder: (context, index) {
                                  final item = filteredItems[index];
                                  return ListTile(
                                    title: Text(
                                      item['title'].toString(),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    onTap: () {
                                      onSelected(item);
                                      Navigator.pop(context);
                                    },
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _saveProfileData() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final prefs = await SharedPreferences.getInstance();
        final email = ref.read(authProvider).email?.trim().toLowerCase() ?? '';
        
        // 1. Prepare fields for API call
        final fullName = _fullNameController.text.trim();
        final nameParts = fullName.split(' ');
        String firstname = '';
        String lastname = '';
        if (nameParts.isNotEmpty) {
          firstname = nameParts.last;
          if (nameParts.length > 1) {
            lastname = nameParts.sublist(0, nameParts.length - 1).join(' ');
          }
        }
        
        final phone = _phoneController.text.trim();
        final genderStr = _genderController.text.trim().toLowerCase();
        final genderVal = (genderStr == 'nữ' || genderStr == 'female' || genderStr == 'nu') ? 1 : 0;
        
        // Parse dates to yyyy-mm-dd
        String dobVal = '';
        final dobText = _dobController.text.trim();
        if (dobText.isNotEmpty) {
          final parts = dobText.split('/');
          if (parts.length == 3) {
            final day = parts[0].padLeft(2, '0');
            final month = parts[1].padLeft(2, '0');
            final year = parts[2];
            dobVal = '$year-$month-$day';
          } else {
            dobVal = dobText;
          }
        }
        
        final pob = _pobController.text.trim();
        final idNumber = _idCardController.text.trim();
        
        String idDateVal = '';
        final idDateText = _idCardDateController.text.trim();
        if (idDateText.isNotEmpty) {
          final parts = idDateText.split('/');
          if (parts.length == 3) {
            final day = parts[0].padLeft(2, '0');
            final month = parts[1].padLeft(2, '0');
            final year = parts[2];
            idDateVal = '$year-$month-$day';
          } else {
            idDateVal = idDateText;
          }
        }
        
        final idPlace = _idCardPlaceController.text.trim();
        
        // Use ID if available, otherwise fallback to name
        final provinceVal = _selectedProvinceId ?? _provinceController.text.trim();
        
        // 2. Call API Service
        final apiService = ApiService.instance;
        if (apiService.hasToken) {
          final response = await apiService.updateUserInfo(
            firstname: firstname,
            lastname: lastname,
            phone: phone,
            gender: genderVal,
            dob: dobVal,
            pob: pob,
            idNumber: idNumber,
            idDate: idDateVal,
            idPlace: idPlace,
            province: provinceVal,
          );
          
          final bool isSuccess = response['success'] ?? (response['error'] == null);
          if (!isSuccess) {
            final errorMsg = response['error']?.toString() ?? 'Lỗi không xác định từ máy chủ.';
            throw Exception(errorMsg);
          }
        }
        
        // 3. Save to local cache (SharedPreferences)
        // User-scoped keys
        await prefs.setString('profile_fullName_$email', _fullNameController.text.trim());
        await prefs.setString('profile_phone_$email', _phoneController.text.trim());
        await prefs.setString('profile_gender_$email', _genderController.text.trim());
        await prefs.setString('profile_dob_$email', _dobController.text.trim());
        await prefs.setString('profile_pob_$email', _pobController.text.trim());
        await prefs.setString('profile_idCard_$email', _idCardController.text.trim());
        await prefs.setString('profile_idCardDate_$email', _idCardDateController.text.trim());
        await prefs.setString('profile_idCardPlace_$email', _idCardPlaceController.text.trim());
        await prefs.setString('profile_address_$email', _addressController.text.trim());
        await prefs.setString('profile_street_$email', _streetController.text.trim());
        await prefs.setString('profile_ward_$email', _wardController.text.trim());
        await prefs.setString('profile_district_$email', _districtController.text.trim());
        await prefs.setString('profile_province_$email', _provinceController.text.trim());
        
        // Cache name for ProfileTab to update instantly
        await prefs.setString('cached_user_name_$email', _fullNameController.text.trim());
        
        // Global keys as fallback
        await prefs.setString('profile_fullName', _fullNameController.text.trim());
        await prefs.setString('profile_email', _emailController.text.trim());
        await prefs.setString('profile_phone', _phoneController.text.trim());
        await prefs.setString('profile_gender', _genderController.text.trim());
        await prefs.setString('profile_dob', _dobController.text.trim());
        await prefs.setString('profile_pob', _pobController.text.trim());
        await prefs.setString('profile_idCard', _idCardController.text.trim());
        await prefs.setString('profile_idCardDate', _idCardDateController.text.trim());
        await prefs.setString('profile_idCardPlace', _idCardPlaceController.text.trim());
        await prefs.setString('profile_address', _addressController.text.trim());
        await prefs.setString('profile_street', _streetController.text.trim());
        await prefs.setString('profile_ward', _wardController.text.trim());
        await prefs.setString('profile_district', _districtController.text.trim());
        await prefs.setString('profile_province', _provinceController.text.trim());
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật hồ sơ thành công! 🎉')),
          );
          Navigator.pop(context, true); // Return true to trigger refresh
        }
      } catch (e) {
        debugPrint('Error saving profile data: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Có lỗi xảy ra khi lưu thông tin: $e')),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cập nhật thông tin',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(_fullNameController, 'Họ tên', 'Nhập họ và tên'),
                      const SizedBox(height: 16),
                      _buildTextField(_emailController, 'Email', 'Nhập email address', keyboardType: TextInputType.emailAddress, readOnly: true),
                      const SizedBox(height: 16),
                      _buildTextField(_phoneController, 'Phone', 'Nhập số điện thoại', keyboardType: TextInputType.phone),
                      const SizedBox(height: 16),
                      _buildTextField(_genderController, 'Gender (Giới tính)', 'NAM / NỮ'),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _dobController,
                        'Date Of Birth (Ngày sinh)',
                        'Chọn ngày sinh',
                        onTap: () => _selectDate(context, _dobController),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                          onPressed: () => _selectDate(context, _dobController),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(_pobController, 'Place Of Birth (Nơi sinh)', 'Ví dụ: TP. HCM'),
                      const SizedBox(height: 16),
                      
                      const Divider(height: 32),
                      const Text(
                        'Chứng minh nhân dân (CMND)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(_idCardController, 'Số CMND', 'Nhập số CMND'),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _idCardDateController,
                        'Ngày cấp CMND',
                        'Chọn ngày cấp CMND',
                        onTap: () => _selectDate(context, _idCardDateController),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                          onPressed: () => _selectDate(context, _idCardDateController),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(_idCardPlaceController, 'Nơi cấp CMND', 'Ví dụ: CA. TP. HCM'),
                      
                      const Divider(height: 32),
                      const Text(
                        'Địa chỉ cư trú',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(_addressController, 'Số nhà', 'Nhập số nhà, số căn hộ'),
                      const SizedBox(height: 16),
                      _buildTextField(_streetController, 'Tên đường (Street)', 'Nhập tên đường'),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _wardController, 
                        'Phường / Xã (Ward)', 
                        _selectedProvinceId == null 
                            ? 'Vui lòng chọn Tỉnh / Thành trước' 
                            : (_selectedDistrictId == null 
                                ? 'Vui lòng chọn Quận / Huyện trước' 
                                : 'Chọn Phường / Xã'),
                        readOnly: true,
                        onTap: _selectedDistrictId == null
                            ? null
                            : () {
                                _showSelectionBottomSheet(
                                  title: 'Chọn Phường / Xã',
                                  items: _wardList,
                                  onSelected: (item) {
                                    setState(() {
                                      _wardController.text = item['title'].toString();
                                    });
                                  },
                                );
                              },
                        suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _districtController, 
                        'Quận / Huyện (District)', 
                        _selectedProvinceId == null ? 'Vui lòng chọn Tỉnh / Thành trước' : 'Chọn Quận / Huyện',
                        readOnly: true,
                        onTap: _selectedProvinceId == null
                            ? null
                            : () {
                                _showSelectionBottomSheet(
                                  title: 'Chọn Quận / Huyện',
                                  items: _districtList,
                                  onSelected: (item) async {
                                    setState(() {
                                      _districtController.text = item['title'].toString();
                                      _selectedDistrictId = item['id'].toString();
                                      _wardController.clear();
                                      _wardList = [];
                                    });
                                    await _loadWards(item['id'].toString());
                                  },
                                );
                              },
                        suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _provinceController, 
                        'Tỉnh / Thành phố (Province)', 
                        'Chọn Tỉnh / Thành phố',
                        readOnly: true,
                        onTap: () {
                          _showSelectionBottomSheet(
                            title: 'Chọn Tỉnh / Thành phố',
                            items: _provinceList,
                            onSelected: (item) async {
                              setState(() {
                                _provinceController.text = item['title'].toString();
                                _selectedProvinceId = item['id'].toString();
                                _districtController.clear();
                                _selectedDistrictId = null;
                                _districtList = [];
                                _wardController.clear();
                                _wardList = [];
                              });
                              await _loadDistricts(item['id'].toString());
                            },
                          );
                        },
                        suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                      ),
                      
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _saveProfileData,
                          child: const Text(
                            'Lưu thay đổi',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
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

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime initialDate = DateTime.now();
    final text = controller.text.trim();
    if (text.isNotEmpty) {
      try {
        if (text.contains('/')) {
          final parts = text.split('/');
          if (parts.length == 3) {
            initialDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        } else if (text.contains('-')) {
          final parts = text.split('-');
          if (parts.length == 3) {
            initialDate = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          }
        }
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    bool isRequired = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    final bool isFieldReadOnly = readOnly || onTap != null;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: isFieldReadOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: isFieldReadOnly,
        fillColor: isFieldReadOnly ? Colors.grey.shade100 : null,
        suffixIcon: suffixIcon,
      ),
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) {
          return 'Trường này không được để trống';
        }
        return null;
      },
    );
  }
}
