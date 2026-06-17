import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_theme.dart';

class CropAvatarScreen extends StatefulWidget {
  final String imagePath;

  const CropAvatarScreen({super.key, required this.imagePath});

  @override
  State<CropAvatarScreen> createState() => _CropAvatarScreenState();
}

class _CropAvatarScreenState extends State<CropAvatarScreen> {
  static const double _maxAreaSize = 320.0;
  bool _isSaving = false;

  late ImageProvider _imageProvider;
  ui.Image? _resolvedUiImage;
  double? _imageAspectRatio;
  bool _isLoadingImageSize = true;

  // Rotation quarter turns (0, 1, 2, 3)
  int _rotationSteps = 0;

  // Movable crop circle parameters
  late Offset _circleCenter;
  late double _circleRadius;

  // Helper getters to compute effective aspect ratio and display size dynamically
  double get _effectiveAspectRatio {
    if (_imageAspectRatio == null) return 1.0;
    final isOdd = _rotationSteps % 2 != 0;
    return isOdd ? 1.0 / _imageAspectRatio! : _imageAspectRatio!;
  }

  double get _displayWidth {
    final ratio = _effectiveAspectRatio;
    return ratio >= 1.0 ? _maxAreaSize : _maxAreaSize * ratio;
  }

  double get _displayHeight {
    final ratio = _effectiveAspectRatio;
    return ratio >= 1.0 ? _maxAreaSize / ratio : _maxAreaSize;
  }

  // Getters for unrotated dimensions (to calculate scale correctly)
  double get _unrotatedDisplayWidth {
    if (_imageAspectRatio == null) return _maxAreaSize;
    return _imageAspectRatio! >= 1.0 ? _maxAreaSize : _maxAreaSize * _imageAspectRatio!;
  }

  // Minimum and maximum radius values
  double get _minRadius => math.min(40.0, math.min(_displayWidth, _displayHeight) / 4);
  double get _maxRadius => math.max(_minRadius + 5.0, math.min(_displayWidth, _displayHeight) / 2);

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _imageProvider = NetworkImage(widget.imagePath);
    } else {
      _imageProvider = FileImage(File(widget.imagePath));
    }
    _resolveImageSize();
  }

  void _resolveImageSize() {
    final ImageStream stream = _imageProvider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (mounted) {
          final width = info.image.width;
          final height = info.image.height;
          final ratio = width / height;

          // Save original ratio
          _imageAspectRatio = ratio;

          // Calculate display sizes (unrotated)
          double displayWidth, displayHeight;
          if (ratio >= 1.0) {
            displayWidth = _maxAreaSize;
            displayHeight = _maxAreaSize / ratio;
          } else {
            displayWidth = _maxAreaSize * ratio;
            displayHeight = _maxAreaSize;
          }

          final minDim = math.min(displayWidth, displayHeight);
          // Initial radius is 1/3 of the min dimension, clamped within dynamic bounds
          final tempMin = math.min(40.0, minDim / 4);
          final tempMax = math.max(tempMin + 5.0, minDim / 2);
          final initialRadius = (minDim / 3).clamp(tempMin, tempMax);
          final initialCenter = Offset(displayWidth / 2, displayHeight / 2);

          setState(() {
            _resolvedUiImage = info.image;
            _circleRadius = initialRadius;
            _circleCenter = initialCenter;
            _isLoadingImageSize = false;
          });
        }
        stream.removeListener(listener);
      },
      onError: (exception, stackTrace) {
        debugPrint('Error resolving image size: $exception');
        if (mounted) {
          setState(() {
            _imageAspectRatio = 1.0;
            _circleRadius = _maxAreaSize / 3;
            _circleCenter = Offset(_maxAreaSize / 2, _maxAreaSize / 2);
            _isLoadingImageSize = false;
          });
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  }

  void _rotateImage({required bool clockwise}) {
    if (_imageAspectRatio == null) return;
    
    setState(() {
      if (clockwise) {
        _rotationSteps = (_rotationSteps + 1) % 4;
      } else {
        _rotationSteps = (_rotationSteps - 1) % 4;
      }
      
      // Calculate new display size
      final dw = _displayWidth;
      final dh = _displayHeight;
      
      // Recalculate/clamp circle radius and center for the new dimensions
      _circleRadius = _circleRadius.clamp(_minRadius, _maxRadius);
      _circleCenter = Offset(dw / 2, dh / 2);
    });
  }

  Future<void> _cropAndSaveImage() async {
    if (_isSaving || _resolvedUiImage == null) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final ui.Image originalImage = _resolvedUiImage!;

      // Create a PictureRecorder to draw the cropped image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Output size is 500x500 pixels (high-res square)
      const double outputSize = 500.0;

      // 1. Translate canvas origin to the center of the output image (250, 250)
      canvas.translate(outputSize / 2, outputSize / 2);

      // 2. Rotate canvas by the current steps * 90 degrees
      canvas.rotate(_rotationSteps * math.pi / 2);

      // 3. Scale canvas to map the selected crop circle to the output circle
      final double outputScale = (outputSize / 2) / _circleRadius;
      canvas.scale(outputScale);

      // 4. Translate back by the selected circle center to align the crop center with (0,0)
      canvas.translate(-_circleCenter.dx, -_circleCenter.dy);

      // 5. Draw the entire original image in its unrotated display dimensions
      final double unrotatedDisplayWidth = _unrotatedDisplayWidth;
      final double unrotatedDisplayHeight = unrotatedDisplayWidth / (_imageAspectRatio ?? 1.0);

      final srcRect = Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble());
      final dstRect = Rect.fromLTWH(0, 0, unrotatedDisplayWidth, unrotatedDisplayHeight);

      canvas.drawImageRect(
        originalImage, 
        srcRect, 
        dstRect, 
        Paint()
          ..isAntiAlias = true
          ..filterQuality = ui.FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final croppedUiImage = await picture.toImage(outputSize.toInt(), outputSize.toInt());
      
      final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Cannot convert image to byte data');
      final bytes = byteData.buffer.asUint8List();

      String resultPath;
      if (kIsWeb) {
        // Convert to base64 Data URL to bypass File System restrictions on web
        final base64String = base64Encode(bytes);
        resultPath = 'data:image/png;base64,$base64String';
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/cropped_avatar_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(path);
        await file.writeAsBytes(bytes);
        resultPath = path;
      }

      if (mounted) {
        Navigator.pop(context, resultPath);
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lưu ảnh đã cắt. Vui lòng thử lại.')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Căn chỉnh ảnh',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoadingImageSize
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : Center(
                      child: Container(
                        width: _displayWidth,
                        height: _displayHeight,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          border: Border.all(color: Colors.white12, width: 1),
                        ),
                        child: Stack(
                          children: [
                            // 1. The background image (with RotatedBox)
                            Positioned.fill(
                              child: RotatedBox(
                                quarterTurns: _rotationSteps,
                                child: Image(
                                  image: _imageProvider,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                            
                            // 2. Translucent screen mask overlay with transparent circle center
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _MovableCircularMaskPainter(
                                  circleCenter: _circleCenter,
                                  circleRadius: _circleRadius,
                                ),
                              ),
                            ),
                            
                            // 3. Highlighted border for user visibility (IgnorePointer so touch goes to detector)
                            Positioned(
                              left: _circleCenter.dx - _circleRadius,
                              top: _circleCenter.dy - _circleRadius,
                              child: IgnorePointer(
                                child: Container(
                                  width: _circleRadius * 2,
                                  height: _circleRadius * 2,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary, width: 2),
                                  ),
                                ),
                              ),
                            ),

                            // 4. GestureDetector for dragging the crop circle
                            Positioned.fill(
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  final newCenter = _circleCenter + details.delta;
                                  
                                  // Clamp so that the circular frame is completely within the image boundaries
                                  final clampedX = newCenter.dx.clamp(_circleRadius, _displayWidth - _circleRadius);
                                  final clampedY = newCenter.dy.clamp(_circleRadius, _displayHeight - _circleRadius);
                                  
                                  setState(() {
                                    _circleCenter = Offset(clampedX, clampedY);
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            
            // Zoom instruction text
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Kéo khung tròn để di chuyển vùng chọn, dùng thanh trượt dưới đây để thay đổi kích thước khung cắt.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            
            // Rotation Buttons Row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _isLoadingImageSize ? null : () => _rotateImage(clockwise: false),
                    icon: const Icon(Icons.rotate_left_rounded, color: Colors.white, size: 28),
                    tooltip: 'Xoay trái',
                  ),
                  const SizedBox(width: 32),
                  IconButton(
                    onPressed: _isLoadingImageSize ? null : () => _rotateImage(clockwise: true),
                    icon: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 28),
                    tooltip: 'Xoay phải',
                  ),
                ],
              ),
            ),
            
            // Zoom Slider Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.zoom_out_rounded, color: Colors.white70, size: 20),
                  Expanded(
                    child: Slider(
                      value: _circleRadius.clamp(_minRadius, _maxRadius),
                      min: _minRadius,
                      max: _maxRadius,
                      activeColor: AppColors.primary,
                      inactiveColor: Colors.white24,
                      onChanged: _isLoadingImageSize
                          ? null
                          : (value) {
                              setState(() {
                                _circleRadius = value;
                                // Re-clamp center using new radius
                                final clampedX = _circleCenter.dx.clamp(_circleRadius, _displayWidth - _circleRadius);
                                final clampedY = _circleCenter.dy.clamp(_circleRadius, _displayHeight - _circleRadius);
                                _circleCenter = Offset(clampedX, clampedY);
                              });
                            },
                    ),
                  ),
                  const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 20),
                ],
              ),
            ),
            
            // Bottom bar actions
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.black,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0x8CFFFFFF)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSaving ? null : _cropAndSaveImage,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Lưu ảnh',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter to draw a dark overlay with a transparent hole in the middle (movable)
class _MovableCircularMaskPainter extends CustomPainter {
  final Offset circleCenter;
  final double circleRadius;

  _MovableCircularMaskPainter({
    required this.circleCenter,
    required this.circleRadius,
  });

  @override
  void paint(Canvas canvas, ui.Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.saveLayer(rect, Paint());
    
    // Draw solid dark overlay
    canvas.drawRect(rect, paint);

    // Draw clear circle at circleCenter to cut out overlay
    final clearPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = ui.BlendMode.clear;
    
    canvas.drawCircle(
      circleCenter,
      circleRadius,
      clearPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MovableCircularMaskPainter oldDelegate) {
    return oldDelegate.circleCenter != circleCenter || oldDelegate.circleRadius != circleRadius;
  }
}
