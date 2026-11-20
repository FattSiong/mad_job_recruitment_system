/// Shortens text without cutting an emoji in half.
///
/// Emoji (and some other characters) take two UTF-16 code units. A plain
/// `substring` can keep only the first one, which is invalid text: Flutter
/// throws "string is not well-formed UTF-16" when it draws it, and the
/// database rejects it.
class TextCut {
  TextCut._();

  /// [text] cut to at most [max] code units, never between the two halves
  /// of an emoji.
  static String take(String text, int max) {
    if (text.length <= max) return text;
    var end = max;
    if (end > 0 && _isHighSurrogate(text.codeUnitAt(end - 1))) end--; // keep the pair together
    return text.substring(0, end);
  }

  /// Like [take], with "…" added when the text was cut.
  static String withEllipsis(String text, int max) =>
      text.length <= max ? text : '${take(text, max).trimRight()}…';

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
}
