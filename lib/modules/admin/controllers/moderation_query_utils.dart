// Small helpers shared by the admin moderation controllers
// (ModerationListController and its subclasses).

/// Search text that is safe inside a database filter: characters that mean
/// something in PostgREST filters (, ( ) * % \ " ' :) become spaces.
String cleanModerationSearch(String text) =>
    text.replaceAll(RegExp(r'[,()*%\\"\x27:]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// The admin's note, or null when it is empty.
String? cleanModerationNote(String? note) {
  final text = note?.trim() ?? '';
  return text.isEmpty ? null : text;
}

/// The [column] values of [rows], each once, in their first order
/// (reports newest first -> items in order of their newest report).
List<String> uniqueIdsInOrder(Iterable<Map<String, dynamic>> rows, String column) {
  final seen = <String>{};
  return [
    for (final r in rows)
      if (seen.add(r[column].toString())) r[column].toString(),
  ];
}

/// Splits IDs into groups so an "in (...)" request address stays short.
Iterable<List<String>> chunkIds(List<String> ids, [int size = 100]) sync* {
  for (var i = 0; i < ids.length; i += size) {
    yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
  }
}
