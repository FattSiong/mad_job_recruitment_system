import 'package:flutter/foundation.dart';

/// For controllers whose async work can finish after their screen closed:
/// [notifySafely] does nothing once the controller is disposed, instead of
/// throwing "used after being disposed".
mixin SafeNotifier on ChangeNotifier {
  bool _disposed = false;

  /// True after [dispose]; async work can check it and stop early.
  bool get isDisposed => _disposed;

  /// notifyListeners, unless the controller was already disposed.
  void notifySafely() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
