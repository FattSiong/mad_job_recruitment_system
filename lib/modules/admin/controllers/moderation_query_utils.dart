// Small helpers shared by the admin moderation controllers
// (AdminCommunityController, AdminJobModerationController).

/// Search text that is safe inside a database filter: characters that mean
/// something in PostgREST filters (, ( ) * % \ " ' :) become spaces.
String cleanModerationSearch(String text) =>
    text.replaceAll(RegExp(r'[,()*%\\"\x27:]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// The admin's note, or null when it is empty.
String? cleanModerationNote(String? note) {
  final text = note?.trim() ?? '';
  return text.isEmpty ? null : text;
}

/// Splits IDs into groups so an "in (...)" request address stays short.
Iterable<List<String>> chunkIds(List<String> ids, [int size = 100]) sync* {
  for (var i = 0; i < ids.length; i += size) {
    yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
  }
}
