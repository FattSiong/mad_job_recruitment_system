import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opening web links that users typed themselves (LinkedIn, GitHub, ...).
class LinkHelper {
  LinkHelper._();

  /// "linkedin.com/in/aisyah" -> https://linkedin.com/in/aisyah.
  /// Returns null when the text isn't a usable web address
  /// (e.g. "my linkedin", "http://", "abc").
  static Uri? toWebUri(String input) {
    final text = input.trim();
    if (text.isEmpty || text.contains(' ')) return null;

    final withScheme = RegExp(r'^https?://', caseSensitive: false).hasMatch(text)
        ? text
        : 'https://$text';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty || !uri.host.contains('.')) {
      return null;
    }
    return uri;
  }

  /// The link as it is saved: "linkedin.com/in/aisyah" and
  /// "http://linkedin.com/in/aisyah" -> "https://linkedin.com/in/aisyah".
  /// Null when empty. Text that isn't a web address is returned trimmed
  /// (the profile form doesn't let it through).
  static String? toSavedLink(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    if (toWebUri(text) == null) return text;
    return 'https://${text.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')}';
  }

  /// Form validator for a profile link that must be on [site]
  /// (e.g. 'linkedin.com'). Empty is allowed. "linkedin.com/in/aisyah" and
  /// "www.linkedin.com/in/aisyah" pass; "linkedin.com.fake.site" does not.
  static String? validateSiteLink(String? value, {required String site, required String name}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = toWebUri(text);
    if (uri == null) return 'Enter a valid $name link';
    final host = uri.host.toLowerCase();
    if (host != site && !host.endsWith('.$site')) return 'Use a $site link';
    return null;
  }

  /// Opens [input] in the browser or app. Returns false if the link is not
  /// valid or nothing on the phone can open it (never throws).
  static Future<bool> openExternal(String input) async {
    final uri = toWebUri(input);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open link "$input": $e');
      return false;
    }
  }
}
