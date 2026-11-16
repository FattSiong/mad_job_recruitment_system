import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../shared_widgets/hero_icon_button.dart';
import '../widgets/profile/profile_sections.dart';

/// Opens the crop screen for [source]. Returns a square 512 x 512 PNG of
/// the area inside the circle, or null if the user cancels.
Future<File?> cropProfilePhoto(BuildContext context, File source) {
  return Navigator.push<File>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ProfilePhotoCropScreen(source: source),
    ),
  );
}

/// "Adjust your photo": drag to move, pinch or use the slider to zoom.
/// The circle shows what will be kept. Same layout as the other job seeker
/// screens: gradient header card, white content card, white bottom bar.
class ProfilePhotoCropScreen extends StatefulWidget {
  final File source;

  const ProfilePhotoCropScreen({super.key, required this.source});

  @override
  State<ProfilePhotoCropScreen> createState() => _ProfilePhotoCropScreenState();
}

class _ProfilePhotoCropScreenState extends State<ProfilePhotoCropScreen> {
  static const double _maxZoom = 4;
  static const int _outputSize = 512;

  ui.Image? _image;
  bool _loadFailed = false;
  bool _saving = false;

  /// 1 = the photo just covers the circle.
  double _zoom = 1;

  /// Photo centre relative to the circle centre, in screen pixels.
  Offset _offset = Offset.zero;

  // Values when a pinch / drag started.
  double _startZoom = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;

  /// Circle diameter on screen; set by the layout.
  double _circle = 280;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  /// Decodes the chosen photo so it can be moved and zoomed.
  Future<void> _decode() async {
    try {
      final bytes = await widget.source.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (e) {
      debugPrint('Crop: could not read the photo: $e');
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  // ---------------------------------------------------------------------
  // Geometry
  // ---------------------------------------------------------------------

  /// Screen pixels per photo pixel.
  double get _scale {
    final image = _image!;
    final cover = _circle / math.min(image.width, image.height);
    return cover * _zoom;
  }

  /// Keeps the photo covering the whole circle (no empty corners).
  Offset _clamp(Offset offset) {
    final image = _image!;
    final maxX = math.max(0.0, (image.width * _scale - _circle) / 2);
    final maxY = math.max(0.0, (image.height * _scale - _circle) / 2);
    return Offset(offset.dx.clamp(-maxX, maxX), offset.dy.clamp(-maxY, maxY));
  }

  /// Remembers the zoom and position when a pinch or drag starts.
  void _onScaleStart(ScaleStartDetails details, Offset centre) {
    _startZoom = _zoom;
    _startOffset = _offset;
    _startFocal = details.localFocalPoint - centre;
  }

  /// Pinch zooms around the fingers; one finger drags.
  void _onScaleUpdate(ScaleUpdateDetails details, Offset centre) {
    final newZoom = (_startZoom * details.scale).clamp(1.0, _maxZoom);
    final focal = details.localFocalPoint - centre;
    // Keep the photo point that was under the fingers under them.
    final offset = focal - (_startFocal - _startOffset) * (newZoom / _startZoom);
    setState(() {
      _zoom = newZoom;
      _offset = _clamp(offset);
    });
  }

  /// Sets the zoom (from the slider or buttons), keeping the photo inside the circle.
  void _setZoom(double zoom) {
    final newZoom = zoom.clamp(1.0, _maxZoom);
    setState(() {
      _offset = _clamp(_offset * (newZoom / _zoom));
      _zoom = newZoom;
    });
  }

  // ---------------------------------------------------------------------
  // Saving
  // ---------------------------------------------------------------------

  /// Cuts out the area inside the circle and closes with the 512 x 512 PNG.
  Future<void> _usePhoto() async {
    final image = _image;
    if (image == null || _saving) return;
    setState(() => _saving = true);
    try {
      // The circle's square, in photo pixels.
      final side = _circle / _scale;
      final source = Rect.fromLTWH(
        image.width / 2 - (_offset.dx + _circle / 2) / _scale,
        image.height / 2 - (_offset.dy + _circle / 2) / _scale,
        side,
        side,
      );

      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        image,
        source,
        Rect.fromLTWH(0, 0, _outputSize.toDouble(), _outputSize.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final cropped = await recorder.endRecording().toImage(_outputSize, _outputSize);
      final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
      cropped.dispose();
      if (png == null) throw StateError('PNG encoding failed');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(png.buffer.asUint8List(), flush: true);
      if (mounted) Navigator.pop(context, file);
    } catch (e) {
      debugPrint('Crop: could not save the photo: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      SnackBarHelper.showError(context, 'Unable to use this photo. Please try another one.');
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: _buildHeader(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildCropCard(),
              ),
            ),
            const SizedBox(height: 16),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  /// Gradient header card, like the other job seeker screens.
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeroIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Cancel',
                onTap: () {
                  if (!_saving) Navigator.pop(context);
                },
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_circle_outlined, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Profile Photo',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Adjust your photo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Drag to move and pinch to zoom. Everything inside the circle is your photo.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  /// White card with the photo and the zoom slider.
  Widget _buildCropCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ColoredBox(color: AppColors.surfaceAlt, child: _buildCropArea()),
              ),
            ),
          ),
          if (_image != null) _buildZoomRow(),
          if (_image == null) const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// The photo with the circle, or a message if it couldn't be opened.
  Widget _buildCropArea() {
    if (_loadFailed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, size: 40, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text(
                'This photo couldn\'t be opened. Please go back and choose another one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }
    final image = _image;
    if (image == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return LayoutBuilder(
      builder: (context, box) {
        // The circle follows the available space (e.g. after rotating).
        // Re-clamp so the photo still covers it; no setState: same frame.
        _circle = math.min(box.maxWidth - 40, box.maxHeight - 40).clamp(120.0, 400.0);
        _offset = _clamp(_offset);
        final centre = Offset(box.maxWidth / 2, box.maxHeight / 2);
        return GestureDetector(
          onScaleStart: (d) => _onScaleStart(d, centre),
          onScaleUpdate: (d) => _onScaleUpdate(d, centre),
          onDoubleTap: () => _setZoom(_zoom > 1.5 ? 1 : 2),
          child: CustomPaint(
            size: Size(box.maxWidth, box.maxHeight),
            painter: _CropPainter(
              image: image,
              scale: _scale,
              offset: _offset,
              circle: _circle,
            ),
          ),
        );
      },
    );
  }

  /// Zoom out / slider / zoom in.
  Widget _buildZoomRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Zoom out',
            onPressed: _saving || _zoom <= 1 ? null : () => _setZoom(_zoom - 0.25),
            icon: const Icon(Icons.zoom_out_rounded),
            color: AppColors.primary,
          ),
          Expanded(
            child: Slider(
              value: _zoom,
              min: 1,
              max: _maxZoom,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.borderSoft,
              onChanged: _saving ? null : _setZoom,
            ),
          ),
          IconButton(
            tooltip: 'Zoom in',
            onPressed: _saving || _zoom >= _maxZoom ? null : () => _setZoom(_zoom + 0.25),
            icon: const Icon(Icons.zoom_in_rounded),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  /// White bar with a soft shadow, like the other screens' bottom bars.
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                style: ProfileButtonStyles.secondary(),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _image == null || _saving ? null : _usePhoto,
                style: ProfileButtonStyles.primary(),
                icon: _saving ? const SizedBox.shrink() : const Icon(Icons.check_rounded),
                label: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Use Photo', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws the photo, softly fades everything outside the circle, and
/// outlines the circle in the app's navy.
class _CropPainter extends CustomPainter {
  final ui.Image image;
  final double scale;
  final Offset offset;
  final double circle;

  _CropPainter({
    required this.image,
    required this.scale,
    required this.offset,
    required this.circle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero) + offset;
    final photo = Rect.fromCenter(
      center: centre,
      width: image.width * scale,
      height: image.height * scale,
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      photo,
      Paint()..filterQuality = FilterQuality.medium,
    );

    final hole = Rect.fromCircle(center: size.center(Offset.zero), radius: circle / 2);
    final fade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(hole);
    canvas.drawPath(fade, Paint()..color = AppColors.surfaceAlt.withValues(alpha: 0.82));
    canvas.drawOval(
      hole,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image || old.scale != scale || old.offset != offset || old.circle != circle;
}
