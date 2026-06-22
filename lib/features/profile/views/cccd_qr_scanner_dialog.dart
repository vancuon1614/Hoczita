import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_theme.dart';

class CccdQrScannerDialog extends StatefulWidget {
  const CccdQrScannerDialog({super.key});

  @override
  State<CccdQrScannerDialog> createState() => _CccdQrScannerDialogState();
}

class _CccdQrScannerDialogState extends State<CccdQrScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: double.infinity,
          height: 480,
          child: Stack(
            children: [
              // Camera Preview
              MobileScanner(
                controller: _controller,
                onDetect: (capture) {
                  if (_isScanned) return;
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String? rawValue = barcodes.first.rawValue;
                    if (rawValue != null && rawValue.isNotEmpty) {
                      setState(() {
                        _isScanned = true;
                      });
                      _controller.stop();
                      Navigator.pop(context, rawValue);
                    }
                  }
                },
              ),

              // Scanner Overlay
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.success, width: 3),
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),

              // Dark surrounding overlay (Visual guidance)
              IgnorePointer(
                child: Stack(
                  children: [
                    // Top dark bar
                    Positioned(
                      top: 0, left: 0, right: 0, bottom: 380,
                      child: Container(color: Colors.black.withOpacity(0.5)),
                    ),
                    // Bottom dark bar
                    Positioned(
                      top: 380, left: 0, right: 0, bottom: 0,
                      child: Container(color: Colors.black.withOpacity(0.5)),
                    ),
                    // Left dark bar
                    Positioned(
                      top: 100, left: 0, right: 280 + 35, bottom: 100,
                      child: Container(color: Colors.black.withOpacity(0.5)),
                    ),
                    // Right dark bar
                    Positioned(
                      top: 100, left: 280 + 35, right: 0, bottom: 100,
                      child: Container(color: Colors.black.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),

              // Title and guide text
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    const Text(
                      'Quét QR Căn cước công dân 💳',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Di chuyển camera để mã QR nằm giữa khung hình',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              // Controls: Flash & Close
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Flash toggle button
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.black87,
                      child: IconButton(
                        icon: ValueListenableBuilder(
                          valueListenable: _controller.torchState,
                          builder: (context, state, child) {
                            switch (state) {
                              case TorchState.off:
                                return const Icon(Icons.flash_off_rounded, color: Colors.white);
                              case TorchState.on:
                                return const Icon(Icons.flash_on_rounded, color: Colors.yellow);
                            }
                          },
                        ),
                        onPressed: () => _controller.toggleTorch(),
                      ),
                    ),

                    // Close button
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.black87,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
