import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/utils/snackbar_helper.dart';
import 'public_profile_screen.dart';

/// Scans a job seeker's profile QR code and opens their public profile.
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// The seeker ID in a profile QR code ("profile:<id>" or a link with
  /// /profile/<id>), or null for any other QR code.
  static String? seekerIdFrom(String rawValue) {
    final text = rawValue.trim();
    String? id;
    if (text.startsWith('profile:')) {
      id = text.substring('profile:'.length);
    } else {
      final segments = Uri.tryParse(text)?.pathSegments.where((s) => s.isNotEmpty).toList() ?? const [];
      final i = segments.indexOf('profile');
      if (i != -1 && i + 1 < segments.length) id = segments[i + 1];
    }
    id = id?.trim();
    return id != null && _uuid.hasMatch(id) ? id : null;
  }

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  // The camera used for scanning (also turns the flash on and off)
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _isNavigating = false; // the same code is seen many times: open it only once
  DateTime? _lastWrongCodeHint;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  /// "Not a profile QR code", at most every 3 seconds (the camera sees it many times).
  void _showWrongCodeHint() {
    final now = DateTime.now();
    final last = _lastWrongCodeHint;
    if (last != null && now.difference(last) < const Duration(seconds: 3)) return;
    _lastWrongCodeHint = now;
    SnackBarHelper.showError(context, 'This QR code is not a job seeker profile.');
  }

  /// Handles a scanned code: opens the profile, or says it isn't a profile code.
  void _onDetect(BarcodeCapture capture) {
    if (_isNavigating) return;

    var sawOtherCode = false;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null) continue;

      final scannedSeekerId = QRScannerScreen.seekerIdFrom(rawValue);
      if (scannedSeekerId == null) {
        sawOtherCode = true;
        continue;
      }

      // Found a profile: stop scanning and open it
      setState(() => _isNavigating = true);
      _scannerController.stop(); // camera off while the profile is open

      // Open the read-only public profile
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PublicProfileScreen(seekerId: scannedSeekerId),
        ),
      ).then((_) {
        if (!mounted) return;
        setState(() => _isNavigating = false);
        _scannerController.start();
      });
      return;
    }
    if (sawOtherCode) _showWrongCodeHint();
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
          // Flash on / off
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                  case TorchState.off:
                  default: // auto, or the phone has no flash
                    return const Icon(Icons.flash_off, color: Colors.grey);
                }
              },
            ),
            iconSize: 28.0,
            onPressed: () => _scannerController.toggleTorch(),
          ),
        ],
      ),
      extendBodyBehindAppBar: true, // the camera fills the screen behind the AppBar
      body: Stack(
        children: [
          // 1. Camera
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // 2. Dark overlay with a clear scan box
          QRScannerOverlay(overlayColour: Colors.black.withValues(alpha: 0.6)),

          // 3. Instructions
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

/// Darkens everything outside the scan box and draws its rounded corners.
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

/// Paints the dark overlay and the corners of the scan box.
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

    // Dark background with a hole for the scan box
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

    // Corner brackets
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