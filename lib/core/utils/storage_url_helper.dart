import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns stored Supabase Storage URLs into URLs that can actually be opened.
///
/// Resumes and pre-screening answer files live in PRIVATE buckets, so their
/// stored public-style URLs no longer work directly. [resolve] swaps them for a
/// short-lived signed URL (only works for users the storage policies allow:
/// the owner, employers and admins). URLs of public buckets are returned unchanged.
class StorageUrlHelper {
  StorageUrlHelper._();

  static const Set<String> privateBuckets = {'resumes', 'answer_files'};

  static final RegExp _storageUrl = RegExp(
    r'/storage/v1/object/(?:public|sign|authenticated)/([^/]+)/([^?]+)',
  );

  /// Bucket and file path of a Supabase Storage URL, or null if it isn't one.
  static ({String bucket, String path})? parse(String url) {
    final match = _storageUrl.firstMatch(url);
    if (match == null) return null;
    return (bucket: match.group(1)!, path: Uri.decodeComponent(match.group(2)!));
  }

  static bool isPrivate(String url) {
    final parsed = parse(url);
    return parsed != null && privateBuckets.contains(parsed.bucket);
  }

  /// Signed URL for private files (valid [expiresInSeconds]); any other URL unchanged.
  static Future<String> resolve(String url, {int expiresInSeconds = 600}) async {
    final parsed = parse(url);
    if (parsed == null || !privateBuckets.contains(parsed.bucket)) return url;

    try {
      return await Supabase.instance.client.storage
          .from(parsed.bucket)
          .createSignedUrl(parsed.path, expiresInSeconds);
    } catch (e) {
      debugPrint('Could not sign storage URL: $e');
      return url; // will fail to open, and the caller shows its normal error
    }
  }
}
