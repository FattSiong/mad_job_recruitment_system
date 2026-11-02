/// Thrown by controllers when data can't be loaded (network / server error),
/// so screens can show an error with "Try Again" instead of an empty list.
class DataLoadException implements Exception {
  final String message;

  DataLoadException(this.message);

  @override
  String toString() => message;
}
