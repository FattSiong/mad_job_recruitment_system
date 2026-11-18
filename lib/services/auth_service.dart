import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/table_constants.dart';
import 'login_lockout_service.dart';
import 'password_recovery_service.dart';
import 'push_service.dart';

/// The login worked but the account has no profile and it couldn't be
/// finished (the screen shows [message]).
class AccountSetupException implements Exception {
  final String message;
  AccountSetupException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LoginLockoutService _lockout = LoginLockoutService();

  static const String _noConnection =
      'No internet connection. Please check your connection and try again.';

  /// True for "no connection" errors (they arrive as SocketException,
  /// TimeoutException, or an AuthException / ClientException whose text
  /// names the socket error).
  static bool isNetworkError(Object e) {
    if (e is SocketException || e is TimeoutException) return true;
    final text = (e is AuthException ? e.message : e.toString()).toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('clientexception') ||
        text.contains('connection refused') ||
        text.contains('network is unreachable');
  }

  /// A message that is safe to show instead of [e] (never raw error text).
  static String _friendly(Object e, String fallback) {
    if (isNetworkError(e)) return _noConnection;
    if (e is AuthException && e.message.trim().isNotEmpty) return e.message;
    return fallback;
  }

  // 1. Sign Up Function
  Future<void> signUpUser({
    required String email,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    try {
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        // Kept on the login account as well: if creating the profile rows
        // below fails (no connection, email confirmation on), the first
        // login creates them from these (see _createMissingProfile).
        data: {
          'username': username,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'role': role,
        },
      );

      final String? userId = response.user?.id;

      // No session yet when email confirmation is on: the profile is then
      // created at the first login.
      if (userId != null && response.session != null) {
        await _createProfile(
          userId: userId,
          email: email,
          username: username,
          fullName: '${firstName.trim()} ${lastName.trim()}',
          role: role,
        );
      }
    } on AuthException catch (e) {
      throw Exception(_friendly(e, 'Sign up failed. Please try again.'));
    } catch (e) {
      debugPrint('Sign up failed: $e');
      throw Exception(_friendly(e, 'Sign up failed. Please try again.'));
    }
  }

  /// The "User" row and the role's own row (JobSeeker / Employer).
  Future<void> _createProfile({
    required String userId,
    required String email,
    required String username,
    required String fullName,
    required String role,
  }) async {
    await _supabase.from(TableConstants.user).insert({
      'userID': userId,
      'email': email,
      'username': username,
      'role': role,
    });
    if (role == 'employer') {
      await _supabase.from(TableConstants.employer).insert({
        'employerID': userId,
        'fullName': fullName,
        'email': email,
      });
    } else if (role == 'job_seeker') {
      await _supabase.from(TableConstants.jobSeeker).insert({
        'seekerID': userId,
        'fullName': fullName,
        'email': email,
      });
    }
  }

  /// Creates the profile of an account whose sign-up stopped half way (the
  /// login account exists but its "User" row doesn't), from the details
  /// saved on the account at sign-up. Returns the role, or null.
  Future<String?> _createMissingProfile(User user) async {
    final meta = user.userMetadata ?? const {};
    final role = meta['role']?.toString();
    final email = user.email;
    if (role == null || email == null || (role != 'job_seeker' && role != 'employer')) return null;
    final username = (meta['username']?.toString().trim().isNotEmpty ?? false)
        ? meta['username'].toString().trim()
        : email.split('@').first;
    final fullName = '${meta['first_name'] ?? ''} ${meta['last_name'] ?? ''}'.trim();
    await _createProfile(
      userId: user.id,
      email: email,
      username: username,
      fullName: fullName.isEmpty ? username : fullName,
      role: role,
    );
    return role;
  }

  // 2. Sign In & Fetch Role
  // 5 wrong passwords in a row lock the email for 15 minutes (NF-SEC-02):
  // throws LoginLockedException while locked, WrongPasswordException after a
  // wrong password (with the attempts left).
  Future<String?> signInAndGetRole({
    required String email,
    required String password,
  }) async {
    final lock = await _lockout.status(email);
    if (lock.locked) throw LoginLockedException(lock.remaining, accountWide: lock.accountWide);

    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final String? userId = response.user?.id;

      if (userId != null) {
        await _lockout.clearFailures();
        final userData = await _supabase
            .from(TableConstants.user)
            .select('role')
            .eq('userID', userId)
            .maybeSingle();

        var role = userData?['role'] as String?;
        if (userData == null) {
          // Sign-up stopped before the profile was saved: finish it now
          try {
            role = await _createMissingProfile(response.user!);
          } catch (e) {
            debugPrint('Could not finish the profile at login: $e');
            role = null;
          }
          if (role == null) {
            await _signOutQuietly(); // don't stay logged in without a profile
            throw AccountSetupException('Your account setup did not finish. Please contact support.');
          }
        }
        return role;
      }
      return null;
    } on AuthException catch (e) {
      if (LoginLockoutService.isWrongPassword(e)) {
        final after = await _lockout.recordFailure(email);
        if (after.locked) throw LoginLockedException(after.remaining, accountWide: after.accountWide);
        throw WrongPasswordException(after);
      }
      throw Exception(_friendly(e, 'Unable to log in. Please try again.'));
    } on AccountSetupException {
      rethrow;
    } catch (e) {
      debugPrint('Login failed: $e');
      if (!isNetworkError(e)) await _signOutQuietly(); // signed in, but the profile can't be read
      throw Exception(_friendly(e, 'Unable to log in. Please try again.'));
    }
  }

  Future<void> _signOutQuietly() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {}
  }

  // 3. Password Reset Function
  Future<void> resetPassword({required String email}) async {
    try {
      // The link opens the app (myapp://reset-password), not the Site URL.
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: PasswordRecoveryService.redirectUrl,
      );
    } on AuthException catch (e) {
      throw Exception(_friendly(e, 'Unable to send the reset email. Please try again.'));
    } catch (e) {
      debugPrint('Reset email failed: $e');
      throw Exception(_friendly(e, 'Unable to send the reset email. Please try again.'));
    }
  }

  // Sets the new password after the user opened the reset link.
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      // The owner proved it's them: remove any login lock on the account
      await _lockout.clearAllFailures();
    } on AuthException catch (e) {
      throw Exception(_friendly(e, 'Unable to change the password. Please try again.'));
    } catch (e) {
      debugPrint('Password change failed: $e');
      throw Exception(_friendly(e, 'Unable to change the password. Please try again.'));
    }
  }

  // 4. Sign Out Function
  Future<void> signOut() async {
    // Stop this phone from receiving the user's chat notifications.
    await PushService.unregisterCurrentDevice();
    await _supabase.auth.signOut();
  }
}