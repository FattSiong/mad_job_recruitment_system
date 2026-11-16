import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/table_constants.dart';
import 'login_lockout_service.dart';
import 'password_recovery_service.dart';
import 'push_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LoginLockoutService _lockout = LoginLockoutService();

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
      );

      final String? userId = response.user?.id;

      if (userId != null) {
        // Step B: Insert into the master User table
        await _supabase.from(TableConstants.user).insert({
          'userID': userId,
          'email': email,
          'username': username,
          'role': role,
        });

        final String fullName = '${firstName.trim()} ${lastName.trim()}';

        // Step C: Insert into the specific Role table, NOW INCLUDING THE EMAIL
        if (role == 'employer') {
          await _supabase.from(TableConstants.employer).insert({
            'employerID': userId,
            'fullName': fullName,
            'email': email, // 👉 ADDED EMAIL HERE
          });
        } else if (role == 'job_seeker') {
          await _supabase.from(TableConstants.jobSeeker).insert({
            'seekerID': userId,
            'fullName': fullName,
            'email': email, // 👉 ADDED EMAIL HERE
          });
        }
      }
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
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
            .single();

        return userData['role'] as String?;
      }
      return null;
    } on AuthException catch (e) {
      if (LoginLockoutService.isWrongPassword(e)) {
        final after = await _lockout.recordFailure(email);
        if (after.locked) throw LoginLockedException(after.remaining, accountWide: after.accountWide);
        throw WrongPasswordException(after);
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
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
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to send reset email: $e');
    }
  }

  // Sets the new password after the user opened the reset link.
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      // The owner proved it's them: remove any login lock on the account
      await _lockout.clearAllFailures();
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  // 4. Sign Out Function
  Future<void> signOut() async {
    // Stop this phone from receiving the user's chat notifications.
    await PushService.unregisterCurrentDevice();
    await _supabase.auth.signOut();
  }
}