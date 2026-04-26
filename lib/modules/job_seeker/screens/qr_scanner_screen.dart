import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'public_profile_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  // MobileScannerController allows us to control the camera (flash, front/back)
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _isNavigating = false; // Prevents multiple pushes if scanned twice quickly

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isNavigating) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null) {

        String? scannedSeekerId;

        // 👉 Handle the URL format (if using Deep Links from the previous step)
        if (rawValue.contains('/profile/')) {
          scannedSeekerId = rawValue.split('/').last;
        }
        // 👉 Handle the raw scheme format (if you just used 'profile:UUID')
        else if (rawValue.startsWith('profile:')) {
          scannedSeekerId = rawValue.replaceFirst('profile:', '');
        }

        // If we successfully extracted an ID, stop scanning and navigate
        if (scannedSeekerId != null && scannedSeekerId.isNotEmpty) {
          setState(() => _isNavigating = true);
          _scannerController.stop(); // Stop camera to save battery

          // 👉 Completed TODO: Navigate to the read-only Public Profile Screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PublicProfileScreen(seekerId: scannedSeekerId!),
            ),
          ).then((_) {
            if (!mounted) return;
            setState(() => _isNavigating = false);
            _scannerController.start();
          });

          break; // Stop checking other barcodes
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Flashlight Toggle
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder(
              // 👉 Fix: Listen to the controller directly instead of torchState
              valueListenable: _scannerController,
              builder: (context, state, child) {
                // 👉 Fix: Check the torchState from the emitted state object
                switch (state.torchState) {
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                  case TorchState.off:
                  default: // Handles unavailable or auto states
                    return const Icon(Icons.flash_off, color: Colors.grey);
                }
              },
            ),
            iconSize: 28.0,
            onPressed: () => _scannerController.toggleTorch(),
          ),
        ],
      ),
      extendBodyBehindAppBar: true, // Makes camera go full screen behind AppBar
      body: Stack(
        children: [
          // 1. The Camera View
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // 2. The Scanner Overlay (creates the darkened edges and clear center box)
          QRScannerOverlay(overlayColour: Colors.black.withValues(alpha: 0.6)),

          // 3. Instructions at the bottom
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.white, size: 40),
                SizedBox(height: 16),
                Text(
                  'Align the QR code within the frame to view profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// CUSTOM OVERLAY PAINTER (Makes it look like a real scanner)
// =========================================================================
class QRScannerOverlay extends StatelessWidget {
  const QRScannerOverlay({super.key, required this.overlayColour});

  final Color overlayColour;

  @override
  Widget build(BuildContext context) {
    double scanArea = (MediaQuery.of(context).size.width < 400 ||
        MediaQuery.of(context).size.height < 400)
        ? 250.0
        : 330.0;

    return CustomPaint(
      painter: _ScannerOverlayPainter(
        overlayColour: overlayColour,
        scanAreaWidth: scanArea,
      ),
      child: Container(),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color overlayColour;
  final double scanAreaWidth;

  _ScannerOverlayPainter({required this.overlayColour, required this.scanAreaWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = overlayColour;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final scanArea = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanAreaWidth,
      height: scanAreaWidth,
    );

    // Draw the darkened background
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromRectAndRadius(scanArea, const Radius.circular(20)))
          ..close(),
      ),
      backgroundPaint,
    );

    // Draw corner brackets
    final double cornerLength = 30;
    final double radius = 20;

    // Top Left
    canvas.drawPath(Path()..moveTo(scanArea.left, scanArea.top + cornerLength)..arcToPoint(Offset(scanArea.left + radius, scanArea.top), radius: Radius.circular(radius))..lineTo(scanArea.left + cornerLength, scanArea.top), borderPaint);
    // Top Right
    canvas.drawPath(Path()..moveTo(scanArea.right - cornerLength, scanArea.top)..arcToPoint(Offset(scanArea.right, scanArea.top + radius), radius: Radius.circular(radius))..lineTo(scanArea.right, scanArea.top + cornerLength), borderPaint);
    // Bottom Left
    canvas.drawPath(Path()..moveTo(scanArea.left, scanArea.bottom - cornerLength)..arcToPoint(Offset(scanArea.left + radius, scanArea.bottom), radius: Radius.circular(radius), clockwise: false)..lineTo(scanArea.left + cornerLength, scanArea.bottom), borderPaint);
    // Bottom Right
    canvas.drawPath(Path()..moveTo(scanArea.right - cornerLength, scanArea.bottom)..arcToPoint(Offset(scanArea.right, scanArea.bottom - radius), radius: Radius.circular(radius), clockwise: false)..lineTo(scanArea.right, scanArea.bottom - cornerLength), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}