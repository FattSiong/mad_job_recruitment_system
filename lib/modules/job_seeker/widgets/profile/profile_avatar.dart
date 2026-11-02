import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The job seeker's own photo on the Profile tab. Unlike the shared
/// UserAvatar, it can preview a photo that is picked but not saved yet,
/// and hide a photo the user chose to remove (applied on Save).
class ProfileAvatar extends StatefulWidget {
  final String name;
  final String? imageUrl;
  final File? newPhoto;
  final bool photoRemoved;
  final double radius;

  /// Shows a camera badge that calls this (edit mode).
  final VoidCallback? onEdit;

  const ProfileAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.newPhoto,
    this.photoRemoved = false,
    this.radius = 34,
    this.onEdit,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  /// URL that failed to load; the initial is shown instead of an empty circle.
  String? _failedUrl;

  String get _initial {
    final name = widget.name.trim();
    return name.isEmpty ? 'J' : name[0].toUpperCase();
  }

  ImageProvider? get _image {
    if (widget.newPhoto != null) return FileImage(widget.newPhoto!);
    if (widget.photoRemoved) return null;
    final url = widget.imageUrl;
    if (url == null || url.isEmpty || url == _failedUrl) return null;
    // Cached on disk (no re-download every launch) and decoded at avatar size.
    return ResizeImage(CachedNetworkImageProvider(url), width: 300);
  }

  void _onImageError(Object error, StackTrace? stackTrace) {
    final url = widget.imageUrl;
    debugPrint('Profile photo failed to load ($url): $error');
    if (!mounted || url == null || url == _failedUrl) return;
    setState(() => _failedUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: widget.radius,
          backgroundColor: Colors.white.withValues(alpha: 0.18),
          backgroundImage: image,
          onBackgroundImageError: image == null ? null : _onImageError,
          child: image == null
              ? Text(
                  _initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.radius * 0.76,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        if (widget.onEdit != null)
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: widget.onEdit,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 18),
              ),
            ),
          ),
      ],
    );
  }
}
