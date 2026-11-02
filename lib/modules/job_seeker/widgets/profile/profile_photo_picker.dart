import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_picker_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../screens/profile_photo_crop_screen.dart';

/// What the user chose in the profile photo sheet.
sealed class ProfilePhotoResult {}

/// A new, cropped photo (not uploaded yet: that happens on Save).
class ProfilePhotoPicked extends ProfilePhotoResult {
  final File file;
  ProfilePhotoPicked(this.file);
}

/// "Remove photo" (applied on Save).
class ProfilePhotoRemoved extends ProfilePhotoResult {}

/// Camera / library / remove sheet, then the app's Adjust Photo screen
/// (512 x 512, shown as a circle).
/// Returns null if cancelled. Problems are shown as snackbars.
Future<ProfilePhotoResult?> pickProfilePhoto(BuildContext context, {required bool hasPhoto}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Profile Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
                title: const Text('Remove photo', style: TextStyle(color: AppColors.errorRed)),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    ),
  );

  if (choice == null || !context.mounted) return null;
  if (choice == 'remove') return ProfilePhotoRemoved();

  final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
  final file = await _pickAndCrop(context, source);
  return file == null ? null : ProfilePhotoPicked(file);
}

Future<File?> _pickAndCrop(BuildContext context, ImageSource source) async {
  final XFile? picked;
  try {
    picked = await ImagePicker().pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1600, // the Adjust Photo screen then makes the final 512px image
      maxHeight: 1600,
    );
  } catch (e) {
    debugPrint('Image picker error: $e');
    if (context.mounted) {
      SnackBarHelper.showError(
        context,
        source == ImageSource.camera
            ? 'Unable to open the camera. Please allow camera access in Settings.'
            : 'Unable to open your photos. Please allow photo access in Settings.',
      );
    }
    return null;
  }
  final path = picked?.path;
  if (path == null) return null;

  if (!context.mounted) return null;
  final cropped = await cropProfilePhoto(context, File(path));
  if (cropped == null) return null;

  final sizeError = await FilePickerHelper.checkSize(cropped, FileLimits.imageMB);
  if (sizeError != null) {
    if (context.mounted) SnackBarHelper.showError(context, sizeError);
    return null;
  }
  return cropped;
}
