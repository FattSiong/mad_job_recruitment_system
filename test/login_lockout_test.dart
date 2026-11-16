import 'package:flutter_test/flutter_test.dart';
import 'package:mad_job_recruitment_system/services/login_lockout_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Login lockout (NF-SEC-02)', () {
    test('LL-01 reads the database status', () {
      final s = LoginLockStatus.fromJson({'locked': false, 'seconds_left': 0, 'attempts_left': 3});
      expect(s.locked, isFalse);
      expect(s.attemptsLeft, 3);

      final locked = LoginLockStatus.fromJson({'locked': true, 'seconds_left': 845, 'attempts_left': 0});
      expect(locked.locked, isTrue);
      expect(locked.remaining, const Duration(seconds: 845));
    });

    test('LL-02 a bad or missing reply never locks anyone out', () {
      expect(LoginLockStatus.fromJson(null).locked, isFalse);
      expect(LoginLockStatus.fromJson('oops').attemptsLeft, 5);
      // "locked" with no time left counts as unlocked
      expect(LoginLockStatus.fromJson({'locked': true, 'seconds_left': 0}).locked, isFalse);
    });

    test('LL-03 countdown label', () {
      expect(LoginLockStatus.countdown(const Duration(minutes: 15)), '15:00');
      expect(LoginLockStatus.countdown(const Duration(minutes: 14, seconds: 5)), '14:05');
      expect(LoginLockStatus.countdown(const Duration(seconds: 9)), '0:09');
      expect(LoginLockStatus.countdown(const Duration(seconds: -3)), '0:00');
    });

    test('LL-04 wrong password message shows the tries left', () {
      const four = LoginLockStatus(locked: false, remaining: Duration.zero, attemptsLeft: 4);
      expect(four.wrongPasswordMessage, contains('4 attempts left'));
      const one = LoginLockStatus(locked: false, remaining: Duration.zero, attemptsLeft: 1);
      expect(one.wrongPasswordMessage, contains('1 attempt left'));
      expect(const LoginLockedException(Duration(minutes: 15)).toString(), contains('15:00'));
    });

    test('LL-05 only wrong email/password counts, not other sign-in errors', () {
      expect(LoginLockoutService.isWrongPassword(
          AuthException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials')), isTrue);
      expect(LoginLockoutService.isWrongPassword(AuthException('Invalid login credentials')), isTrue);
      expect(LoginLockoutService.isWrongPassword(
          AuthException('Email not confirmed', code: 'email_not_confirmed')), isFalse);
      expect(LoginLockoutService.isWrongPassword(AuthException('Network request failed')), isFalse);
    });
  });
}
