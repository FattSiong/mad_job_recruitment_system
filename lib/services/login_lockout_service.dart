import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Login lockout (NF-SEC-02), kept in the database
/// (migrations 20261116010000 + 20261116030000):
/// * [maxAttempts] wrong passwords in a row lock the email on THIS PHONE for
///   [lockMinutes] minutes (someone else can't lock you out from their phone);
/// * 20 wrong passwords within an hour from any phones lock the account for
///   an hour;
/// * resetting the password clears every lock on the account.
class LoginLockoutService {
  static const int maxAttempts = 5;
  static const int lockMinutes = 15;

  static String? _deviceId;

  /// A random ID for this phone, kept in the app's own files (not personal
  /// data). Made once; a new one after reinstalling the app.
  static Future<String> deviceId() async {
    final cached = _deviceId;
    if (cached != null) return cached;
    String id;
    try {
      final file = File('${(await getApplicationSupportDirectory()).path}/login_device_id');
      if (await file.exists()) {
        id = (await file.readAsString()).trim();
      } else {
        id = '';
      }
      if (id.isEmpty) {
        id = _randomId();
        await file.writeAsString(id, flush: true);
      }
    } catch (e) {
      debugPrint('Login lockout: could not keep the phone ID: $e');
      id = _randomId(); // still works until the app is closed
    }
    return _deviceId = id;
  }

  /// 32 random hex characters.
  static String _randomId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  final SupabaseClient _supabase;

  LoginLockoutService([SupabaseClient? client])
      : _supabase = client ?? Supabase.instance.client;

  /// Before signing in. If the check itself fails (e.g. no connection), the
  /// login is not blocked: Supabase sign-in will report the real problem.
  Future<LoginLockStatus> status(String email) async =>
      _call('login_lock_status', {'p_email': email, 'p_device': await deviceId()});

  /// After a wrong password. Returns the new status (maybe locked now).
  Future<LoginLockStatus> recordFailure(String email) async =>
      _call('login_record_failure', {'p_email': email, 'p_device': await deviceId()});

  /// After a successful login (clears this phone's count for the user).
  Future<void> clearFailures() async {
    try {
      await _supabase.rpc('login_clear_failures', params: {'p_device': await deviceId()});
    } catch (e) {
      debugPrint('Login lockout: could not clear failures: $e');
    }
  }

  /// After resetting the password: the owner proved it's them, so every
  /// lock on the account is removed.
  Future<void> clearAllFailures() async {
    try {
      await _supabase.rpc('login_clear_all_failures');
    } catch (e) {
      debugPrint('Login lockout: could not clear the account lock: $e');
    }
  }

  /// Calls a lockout database function. On any error the status is
  /// "unknown", so the login is never blocked by a failed check.
  Future<LoginLockStatus> _call(String function, Map<String, dynamic> params) async {
    try {
      final data = await _supabase.rpc(function, params: params);
      return LoginLockStatus.fromJson(data);
    } catch (e) {
      debugPrint('Login lockout: $function failed: $e');
      return LoginLockStatus.unknown;
    }
  }

  /// A wrong email or password (as opposed to no connection, unconfirmed
  /// email, ...). Only these count towards the lock.
  static bool isWrongPassword(AuthException e) =>
      e.code == 'invalid_credentials' ||
      e.message.toLowerCase().contains('invalid login credentials');
}

/// What the database says about one email.
class LoginLockStatus {
  final bool locked;
  final Duration remaining;
  final int attemptsLeft;

  /// False when the database could not be asked (then no count is shown).
  final bool known;

  /// The whole account is locked (too many wrong passwords from many
  /// phones), not just this phone.
  final bool accountWide;

  const LoginLockStatus({
    required this.locked,
    required this.remaining,
    required this.attemptsLeft,
    this.known = true,
    this.accountWide = false,
  });

  /// Used when the database could not be asked.
  static const unknown = LoginLockStatus(
    locked: false,
    remaining: Duration.zero,
    attemptsLeft: LoginLockoutService.maxAttempts,
    known: false,
  );

  factory LoginLockStatus.fromJson(dynamic json) {
    if (json is! Map) return unknown;
    int toInt(dynamic v, int fallback) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? fallback;
    final seconds = toInt(json['seconds_left'], 0);
    return LoginLockStatus(
      locked: json['locked'] == true && seconds > 0,
      remaining: Duration(seconds: seconds < 0 ? 0 : seconds),
      attemptsLeft: toInt(json['attempts_left'], LoginLockoutService.maxAttempts),
      accountWide: json['scope'] == 'account',
    );
  }

  /// "14:05" (minutes:seconds) for the countdown.
  static String countdown(Duration d) {
    final total = d.isNegative ? 0 : d.inSeconds;
    final minutes = total ~/ 60;
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Message under the password field after a wrong password.
  String get wrongPasswordMessage {
    // Don't promise "5 attempts left" when the count couldn't be checked
    if (!known || attemptsLeft <= 0) return 'Incorrect email or password.';
    final tries = attemptsLeft == 1 ? '1 attempt' : '$attemptsLeft attempts';
    return 'Incorrect email or password. $tries left before login on this phone '
        'is locked for ${LoginLockoutService.lockMinutes} minutes.';
  }
}

/// Thrown by sign-in while the email is locked.
class LoginLockedException implements Exception {
  final Duration remaining;

  /// Locked for every phone (see [LoginLockStatus.accountWide]).
  final bool accountWide;

  const LoginLockedException(this.remaining, {this.accountWide = false});

  @override
  String toString() =>
      'Too many failed attempts. Please try again in ${LoginLockStatus.countdown(remaining)}.';
}

/// Thrown by sign-in after a wrong password that did not lock the account.
class WrongPasswordException implements Exception {
  final LoginLockStatus status;
  const WrongPasswordException(this.status);

  @override
  String toString() => status.wrongPasswordMessage;
}
