import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/table_constants.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

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
        // Step B: Use TableConstants.user here
        await _supabase.from(TableConstants.user).insert({
          'userID': userId,
          'email': email,
          'username': username,
          'role': role,
        });

        final String fullName = '${firstName.trim()} ${lastName.trim()}';

        // Step C: Use TableConstants.employer and TableConstants.jobSeeker here
        if (role == 'employer') {
          await _supabase.from(TableConstants.employer).insert({
            'employerID': userId,
            'fullName': fullName,
          });
        } else if (role == 'job_seeker') {
          await _supabase.from(TableConstants.jobSeeker).insert({
            'seekerID': userId,
            'fullName': fullName,
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
  Future<String?> signInAndGetRole({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final String? userId = response.user?.id;

      if (userId != null) {
        // Query using TableConstants.user
        final userData = await _supabase
            .from(TableConstants.user)
            .select('role')
            .eq('userID', userId)
            .single();

        return userData['role'] as String?;
      }
      return null;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // 3. Password Reset Function
  Future<void> resetPassword({required String email}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to send reset email: $e');
    }
  }

  // 4. Sign Out Function
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}