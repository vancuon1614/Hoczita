import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_theme.dart';

class CccdOcrDialog extends StatefulWidget {
  const CccdOcrDialog({super.key});

  @override
  State<CccdOcrDialog> createState() => _CccdOcrDialogState();
}

class _CccdOcrDialogState extends State<CccdOcrDialog> {
  File? _frontImage;
  File? _backImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source, bool isFront) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      setState(() {
        if (isFront) {
          _frontImage = File(pickedFile.path);
        } else {
          _backImage = File(pickedFile.path);
        }
      });
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn ảnh: $e')),
        );
      }
    }
  }

  void _showImagePickerSource(bool isFront) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: const Text('Chụp ảnh từ Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, isFront);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: const Text('Chọn ảnh từ Thư viện'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, isFront);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processOcr() async {
    if (_frontImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn hoặc chụp ảnh mặt trước CCCD'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (kIsWeb) {
      // Simulate processing delay on Web
      await Future.delayed(const Duration(milliseconds: 1000));
      final Map<String, String> mockData = {
        'idNumber': '038096001234',
        'fullName': 'NGUYEN VAN A',
        'dob': '15/08/1996',
        'gender': 'NAM',
        'address': '123 Đường Láng, Phường Láng Thượng, Quận Đống Đa, Thành phố Hà Nội',
        'issueDate': '20/11/2021',
        'issuePlace': 'Cục Cảnh sát QLHC về TTXH',
        'frontBase64': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
        'backBase64': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      };
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trình duyệt Web không hỗ trợ thư viện nhận diện chữ. Hệ thống tự động điền dữ liệu mẫu để thử nghiệm! 🧪'),
            backgroundColor: Colors.blue,
          ),
        );
        Navigator.pop(context, mockData);
      }
      return;
    }

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      // 1. Process Front Image
      final frontInputImage = InputImage.fromFilePath(_frontImage!.path);
      final frontResult = await textRecognizer.processImage(frontInputImage);
      final frontOcr = _parseFrontCard(frontResult.text);

      // 2. Process Back Image (optional, but highly recommended)
      Map<String, String> backOcr = {};
      if (_backImage != null) {
        final backInputImage = InputImage.fromFilePath(_backImage!.path);
        final backResult = await textRecognizer.processImage(backInputImage);
        backOcr = _parseBackCard(backResult.text);
      }

      // Read images as base64 bytes
      String frontBase64 = '';
      if (_frontImage != null) {
        final bytes = await _frontImage!.readAsBytes();
        frontBase64 = base64Encode(bytes);
      }
      String backBase64 = '';
      if (_backImage != null) {
        final bytes = await _backImage!.readAsBytes();
        backBase64 = base64Encode(bytes);
      }

      final Map<String, String> finalData = {
        'idNumber': frontOcr['idNumber'] ?? '',
        'fullName': frontOcr['fullName'] ?? '',
        'dob': frontOcr['dob'] ?? '',
        'gender': frontOcr['gender'] ?? '',
        'address': frontOcr['address'] ?? '',
        'issueDate': backOcr['issueDate'] ?? '',
        'issuePlace': backOcr['issuePlace'] ?? 'Cục Cảnh sát QLHC về TTXH',
        'frontBase64': frontBase64,
        'backBase64': backBase64,
      };

      if (mounted) {
        textRecognizer.close();
        Navigator.pop(context, finalData);
      }
    } catch (e) {
      debugPrint('OCR Processing error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Có lỗi xảy ra khi đọc ảnh: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      textRecognizer.close();
    }
  }

  Map<String, String> _parseFrontCard(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
    String idNumber = '';
    String fullName = '';
    String dob = '';
    String gender = '';
    String address = '';

    // 1. Extract 12-digit ID Number
    final idRegex = RegExp(r'\b\d{12}\b');
    for (var line in lines) {
      final match = idRegex.firstMatch(line);
      if (match != null) {
        idNumber = match.group(0)!;
        break;
      }
    }

    // 2. Extract Date of Birth
    final dateRegex = RegExp(r'\b\d{1,2}/\d{1,2}/\d{4}\b');
    final vnDateRegex = RegExp(r'ngày\s+(\d{1,2})\s+tháng\s+(\d{1,2})\s+năm\s+(\d{4})', caseSensitive: false);

    for (var line in lines) {
      if (line.toLowerCase().contains('ngày sinh') || 
          line.toLowerCase().contains('birth') ||
          line.toLowerCase().contains('birth:')) {
        final vnMatch = vnDateRegex.firstMatch(line);
        if (vnMatch != null) {
          final d = vnMatch.group(1)!.padLeft(2, '0');
          final m = vnMatch.group(2)!.padLeft(2, '0');
          final y = vnMatch.group(3)!;
          dob = '$d/$m/$y';
        } else {
          final match = dateRegex.firstMatch(line);
          if (match != null) {
            dob = match.group(0)!;
          } else {
            int idx = lines.indexOf(line);
            if (idx != -1 && idx + 1 < lines.length) {
              final nextVnMatch = vnDateRegex.firstMatch(lines[idx + 1]);
              if (nextVnMatch != null) {
                final d = nextVnMatch.group(1)!.padLeft(2, '0');
                final m = nextVnMatch.group(2)!.padLeft(2, '0');
                final y = nextVnMatch.group(3)!;
                dob = '$d/$m/$y';
              } else {
                final nextMatch = dateRegex.firstMatch(lines[idx + 1]);
                if (nextMatch != null) {
                  dob = nextMatch.group(0)!;
                }
              }
            }
          }
        }
      }
    }
    // Fallback DOB
    if (dob.isEmpty) {
      for (var line in lines) {
        final vnMatch = vnDateRegex.firstMatch(line);
        if (vnMatch != null) {
          final d = vnMatch.group(1)!.padLeft(2, '0');
          final m = vnMatch.group(2)!.padLeft(2, '0');
          final y = vnMatch.group(3)!;
          dob = '$d/$m/$y';
          break;
        }
        final match = dateRegex.firstMatch(line);
        if (match != null) {
          dob = match.group(0)!;
          break;
        }
      }
    }

    // 3. Extract Gender
    for (var line in lines) {
      final l = line.toLowerCase();
      if (l.contains('giới tính') || l.contains('sex') || l.contains('sex:')) {
        if (l.contains('nam')) {
          gender = 'NAM';
        } else if (l.contains('nữ')) {
          gender = 'NỮ';
        } else {
          int idx = lines.indexOf(line);
          if (idx != -1 && idx + 1 < lines.length) {
            final nextLine = lines[idx + 1].toLowerCase();
            if (nextLine.contains('nam')) {
              gender = 'NAM';
            } else if (nextLine.contains('nữ')) {
              gender = 'NỮ';
            }
          }
        }
      }
    }

    // 4. Extract Full Name
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.toLowerCase().contains('họ và tên') || line.toLowerCase().contains('full name')) {
        if (line.contains(':')) {
          final part = line.split(':').last.trim();
          if (part.length > 3 && part == part.toUpperCase()) {
            fullName = part;
            break;
          }
        }
        for (int j = 1; j <= 2; j++) {
          if (i + j < lines.length) {
            final candidate = lines[i + j].trim();
            if (candidate.length > 3 && 
                candidate == candidate.toUpperCase() && 
                !candidate.contains('SỐ') && 
                !candidate.contains('NO') &&
                !candidate.contains('NGÀY') &&
                !candidate.contains('DATE') &&
                !candidate.contains('CỘNG HÒA')) {
              fullName = candidate;
              break;
            }
          }
        }
        if (fullName.isNotEmpty) break;
      }
    }

    // 5. Extract Residence / Nơi thường trú
    int residenceIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (line.contains('nơi thường trú') || line.contains('residence')) {
        residenceIndex = i;
        break;
      }
    }

    if (residenceIndex != -1) {
      List<String> addressParts = [];
      final currentLine = lines[residenceIndex];
      if (currentLine.contains(':')) {
        final part = currentLine.split(':').last.trim();
        if (part.isNotEmpty && !part.toLowerCase().contains('residence')) {
          addressParts.add(part);
        }
      }
      for (int j = 1; j <= 3; j++) {
        if (residenceIndex + j < lines.length) {
          final nextLine = lines[residenceIndex + j].trim();
          if (nextLine.toLowerCase().contains('ngày') || 
              nextLine.toLowerCase().contains('giá trị') || 
              nextLine.toLowerCase().contains('expiry') ||
              nextLine.startsWith('1') || 
              nextLine.startsWith('2') ||
              nextLine.startsWith('3') ||
              nextLine.startsWith('4') ||
              nextLine.length < 3) {
            break;
          }
          addressParts.add(nextLine);
        }
      }
      address = addressParts.join(', ');
    }

    return {
      'idNumber': idNumber,
      'fullName': fullName,
      'dob': dob,
      'gender': gender,
      'address': address,
    };
  }

  Map<String, String> _parseBackCard(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
    String issueDate = '';
    String issuePlace = 'Cục Cảnh sát QLHC về TTXH';

    final dateRegex = RegExp(r'\b\d{1,2}/\d{1,2}/\d{4}\b');
    final vnDateRegex = RegExp(r'ngày\s+(\d{1,2})\s+tháng\s+(\d{1,2})\s+năm\s+(\d{4})', caseSensitive: false);

    for (var line in lines) {
      final vnMatch = vnDateRegex.firstMatch(line);
      if (vnMatch != null) {
        final d = vnMatch.group(1)!.padLeft(2, '0');
        final m = vnMatch.group(2)!.padLeft(2, '0');
        final y = vnMatch.group(3)!;
        issueDate = '$d/$m/$y';
        break;
      }
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        issueDate = match.group(0)!;
        break;
      }
    }
    
    if (issueDate.isEmpty) {
      for (var line in lines) {
        final vnMatch = vnDateRegex.firstMatch(line);
        if (vnMatch != null) {
          final d = vnMatch.group(1)!.padLeft(2, '0');
          final m = vnMatch.group(2)!.padLeft(2, '0');
          final y = vnMatch.group(3)!;
          issueDate = '$d/$m/$y';
          break;
        }
        final match = dateRegex.firstMatch(line);
        if (match != null) {
          issueDate = match.group(0)!;
          break;
        }
      }
    }

    for (var line in lines) {
      if (line.toUpperCase().contains('CỤC TRƯỞNG') || 
          line.toUpperCase().contains('CỤC CẢNH SÁT') ||
          line.toLowerCase().contains('qlhc')) {
        issuePlace = 'Cục Cảnh sát QLHC về TTXH';
        break;
      }
    }

    return {
      'issueDate': issueDate,
      'issuePlace': issuePlace,
    };
  }

  Widget _buildImageSelector({
    required String title,
    required File? imageFile,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: imageFile != null ? AppColors.success : AppColors.border,
              width: imageFile != null ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: imageFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: kIsWeb
                      ? Image.network(
                          imageFile.path,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : Image.file(
                          imageFile,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tải ảnh lên',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Đọc Thông Tin CCCD 💳',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Bé vui lòng tải ảnh thẻ Căn cước công dân rõ nét để hệ thống tự động nhận dạng thông tin.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildImageSelector(
                  title: 'Mặt trước',
                  imageFile: _frontImage,
                  onTap: () => _showImagePickerSource(true),
                ),
                const SizedBox(width: 16),
                _buildImageSelector(
                  title: 'Mặt sau',
                  imageFile: _backImage,
                  onTap: () => _showImagePickerSource(false),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _processOcr,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Bắt đầu đọc thông tin',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
