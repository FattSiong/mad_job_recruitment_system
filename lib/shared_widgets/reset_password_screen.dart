import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/session_helper.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

/// "Set a new password" — opened from the reset link in the email.
/// After saving, the user is signed out and logs in with the new password.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  /// Same rule as sign up: 8+ characters, upper and lower case, a special character.
  static String? validate(String password) {
    if (password.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Z]').hasMatch(password)) return 'Add an uppercase letter.';
    if (!RegExp(r'[a-z]').hasMatch(password)) return 'Add a lowercase letter.';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) return 'Add a special character (e.g. ! @ #).';
    return null;
  }

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final AuthService _authService = AuthService();

  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _authService.updatePassword(_password.text);
      await _signOutTo('Password updated. Please log in with your new password.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  /// The reset link signs the user in only to change the password; end that
  /// session and go to the login screen.
  Future<void> _signOutTo(String? message) async {
    SessionHelper.markManualSignOut();
    try {
      await _authService.signOut();
    } catch (_) {}
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isSaving) _signOutTo(null);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 32),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Set a new password',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose a password you haven\'t used here before.',
                        style: TextStyle(color: AppColors.textMuted, height: 1.4),
                      ),
                      const SizedBox(height: 22),
                      _passwordField(
                        controller: _password,
                        label: 'New password',
                        hidden: _hidePassword,
                        onToggle: () => setState(() => _hidePassword = !_hidePassword),
                        validator: (v) => ResetPasswordScreen.validate(v ?? ''),
                      ),
                      const SizedBox(height: 14),
                      _passwordField(
                        controller: _confirm,
                        label: 'Confirm new password',
                        hidden: _hideConfirm,
                        onToggle: () => setState(() => _hideConfirm = !_hideConfirm),
                        validator: (v) => v != _password.text ? 'Passwords do not match.' : null,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'At least 8 characters, with uppercase, lowercase and a special character.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.dangerSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                        ),
                      ],
                      const SizedBox(height: 22),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save new password', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isSaving ? null : () => _signOutTo(null),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool hidden,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: hidden,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted),
        suffixIcon: IconButton(
          icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.textMuted),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
