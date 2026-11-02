import 'package:flutter/material.dart';

import 'storage_image.dart';

/// Black full-screen photo with pinch-to-zoom.
/// Works for public links and private storage files (e.g. chat photos).
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const FullScreenImageViewer({super.key, required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Hero(
            tag: heroTag,
            child: StorageImage(
              url: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_) => const CircularProgressIndicator(color: Colors.white),
              error: (_) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
