import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns stored Supabase Storage URLs into URLs that can actually be opened.
///
/// Resumes, pre-screening answer files and chat attachments live in PRIVATE
/// buckets, so their stored public-style URLs no longer work directly.
/// [resolve] swaps them for a short-lived signed URL (only works for users the
/// storage policies allow, e.g. the owner, employers/admins, or the two people
/// in a chat). URLs of public buckets are returned unchanged.
class StorageUrlHelper {
  StorageUrlHelper._();

  static const Set<String> privateBuckets = {
    'resumes',
    'answer_files',
    'chat_attachments',
    'offer_letters',
  };

  static final RegExp _storageUrl = RegExp(
    r'/storage/v1/object/(?:public|sign|authenticated)/([^/]+)/([^?]+)',
  );

  /// Bucket and file path of a Supabase Storage URL, or null if it isn't one.
  static ({String bucket, String path})? parse(String url) {
    final match = _storageUrl.firstMatch(url);
    if (match == null) return null;
    return (bucket: match.group(1)!, path: Uri.decodeComponent(match.group(2)!));
  }

  /// Path of the file [url] points to when it is in [bucket] and inside
  /// [userId]'s own folder ("<userId>/..."), otherwise null. Used before
  /// deleting a file, so only the user's own files are ever removed.
  static String? ownedPath(String? url, {required String bucket, required String userId}) {
    if (url == null || url.trim().isEmpty || userId.isEmpty) return null;
    final file = parse(url);
    if (file == null || file.bucket != bucket) return null;
    if (!file.path.startsWith('$userId/') || file.path.contains('..')) return null;
    return file.path;
  }

  /// Deletes the file [url] points to if it is in the user's own folder of
  /// [bucket]. Best effort: a leftover file is harmless, so errors are logged.
  static Future<void> removeOwnFile(String? url, {required String bucket, required String userId}) async {
    final path = ownedPath(url, bucket: bucket, userId: userId);
    if (path == null) return;
    try {
      await Supabase.instance.client.storage.from(bucket).remove([path]);
    } catch (e) {
      debugPrint('Could not delete $bucket/$path: $e');
    }
  }

  static bool isPrivate(String url) {
    final parsed = parse(url);
    return parsed != null && privateBuckets.contains(parsed.bucket);
  }

  /// Signed links already made this session: stored URL -> (signed URL, expiry).
  static final Map<String, ({String url, DateTime expires})> _signedCache = {};

  /// Like [resolve], but reuses a signed link for about an hour, so chat
  /// photos and voice notes don't ask the server again on every rebuild.
  static Future<String> resolveCached(String url) async {
    if (!isPrivate(url)) return url;
    final hit = _signedCache[url];
    if (hit != null && hit.expires.isAfter(DateTime.now())) return hit.url;

    const valid = Duration(hours: 1);
    final signed = await resolve(url, expiresInSeconds: valid.inSeconds);
    if (signed != url) {
      // Stop reusing it a few minutes before it really expires.
      _signedCache[url] = (url: signed, expires: DateTime.now().add(valid - const Duration(minutes: 5)));
    }
    return signed;
  }

  /// A key that stays the same for one file (signed links change every time),
  /// used as the image cache key so photos are downloaded only once.
  static String cacheKey(String url) {
    final parsed = parse(url);
    return parsed == null ? url : '${parsed.bucket}/${parsed.path}';
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
