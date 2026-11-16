import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Login lockout (NF-SEC-02): after [maxAttempts] wrong passwords in a row,
/// the email is locked for [lockMinutes] minutes. The count is kept in the
/// database (migration 20261116010000_login_lockout.sql), so it also holds
/// after restarting the app or on another phone.
class LoginLockoutService {
  static const int maxAttempts = 5;
  static const int lockMinutes = 15;

  final SupabaseClient _supabase;

  LoginLockoutService([SupabaseClient? client])
      : _supabase = client ?? Supabase.instance.client;

  /// Before signing in. If the check itself fails (e.g. no connection), the
  /// login is not blocked: Supabase sign-in will report the real problem.
  Future<LoginLockStatus> status(String email) =>
      _call('login_lock_status', {'p_email': email});

  /// After a wrong password. Returns the new status (maybe locked now).
  Future<LoginLockStatus> recordFailure(String email) =>
      _call('login_record_failure', {'p_email': email});

  /// After a successful login (clears the user's own count).
  Future<void> clearFailures() async {
    try {
      await _supabase.rpc('login_clear_failures');
    } catch (e) {
      debugPrint('Login lockout: could not clear failures: $e');
    }
  }

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

  const LoginLockStatus({
    required this.locked,
    required this.remaining,
    required this.attemptsLeft,
  });

  /// Used when the database could not be asked.
  static const unknown = LoginLockStatus(
    locked: false,
    remaining: Duration.zero,
    attemptsLeft: LoginLockoutService.maxAttempts,
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
    if (attemptsLeft <= 0) return 'Incorrect email or password.';
    final tries = attemptsLeft == 1 ? '1 attempt' : '$attemptsLeft attempts';
    return 'Incorrect email or password. $tries left before your account '
        'is locked for ${LoginLockoutService.lockMinutes} minutes.';
  }
}

/// Thrown by sign-in while the email is locked.
class LoginLockedException implements Exception {
  final Duration remaining;
  const LoginLockedException(this.remaining);

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
