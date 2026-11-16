import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../services/login_lockout_service.dart';
// Import your other screens here once they are built:
import '../modules/job_seeker/screens/seeker_dashboard.dart';
import 'forgot_password_screen.dart';
import 'role_selection_screen.dart';
import '../modules/employer/screens/employer_dashboard.dart';
import '../modules/admin/screens/admin_dashboard.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _pageBackground = Color(0xFFF4F7FB);
  static const Color _cardColor = Colors.white;
  static const Color _primary = Color(0xFF163B65);
  static const Color _primarySoft = Color(0xFF335D8A);
  static const Color _textPrimary = Color(0xFF1B2433);
  static const Color _textSecondary = Color(0xFF687588);
  static const Color _inputFill = Color(0xFFF7F9FC);
  static const Color _errorText = Color(0xFFB42318);
  static const Color _errorBg = Color(0xFFFEF3F2);
  static const Color _successBg = Color(0xFFEAF7EE);
  static const Color _successText = Color(0xFF157347);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  String? _successMessage;

  // Login lockout (5 wrong passwords -> 15 minutes)
  DateTime? _lockedUntil;
  Timer? _lockTimer;

  bool get _isLocked => _lockedUntil != null && _lockedUntil!.isAfter(DateTime.now());

  Duration get _lockLeft =>
      _isLocked ? _lockedUntil!.difference(DateTime.now()) : Duration.zero;

  void _startLock(Duration remaining) {
    _lockTimer?.cancel();
    setState(() {
      _lockedUntil = DateTime.now().add(remaining);
      _passwordError = null;
    });
    // Ticks the countdown; ends the lock on screen when the time is up
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isLocked) {
        timer.cancel();
        _lockedUntil = null;
      }
      setState(() {});
    });
  }

  void _clearLock() {
    if (_lockedUntil == null) return;
    _lockTimer?.cancel();
    setState(() => _lockedUntil = null);
  }

  void _clearSuccessMessage() {
    if (_successMessage == null) return;
    setState(() {
      _successMessage = null;
    });
  }

  void _setValidationErrors({
    String? emailError,
    String? passwordError,
  }) {
    if (!mounted) return;
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
  }

  Future<void> _handleLogin() async {
    if (_isLocked) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    String? emailError;
    String? passwordError;

    if (email.isEmpty) {
      emailError = 'Please enter your email address';
    }
    if (password.isEmpty) {
      passwordError = 'Please enter your password';
    }

    if (emailError != null || passwordError != null) {
      _setValidationErrors(
        emailError: emailError,
        passwordError: passwordError,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _emailError = null;
      _passwordError = null;
      _successMessage = null;
    });

    try {
      // Calls the service we built in Step 1
      final role = await _authService.signInAndGetRole(
        email: email,
        password: password,
      );

      if (!mounted) return;

      // Navigate based on the fetched role
      if (role == 'employer') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const EmployerDashboard()));
      } else if (role == 'job_seeker') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SeekerDashboard()));
      } else if (role == 'admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
      } else {
        _setValidationErrors(
          passwordError: 'Unknown user role found in database.',
        );
      }
    } on LoginLockedException catch (e) {
      if (mounted) _startLock(e.remaining);
    } on WrongPasswordException catch (e) {
      _setValidationErrors(passwordError: e.toString());
    } catch (e) {
      _setValidationErrors(
        passwordError: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    _setValidationErrors();
    _clearSuccessMessage();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(initialEmail: _emailController.text.trim()),
      ),
    );
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: Center(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Login to your account',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use your registered email and password to continue.',
                        style: TextStyle(
                          fontSize: 14,
                          color: _textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_successMessage != null) ...[
                        _buildSuccessBanner(),
                        const SizedBox(height: 18),
                      ],
                      _buildInputField(
                        controller: _emailController,
                        label: 'Email Address',
                        hint: 'name@example.com',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                        onChanged: () {
                          // The lock is for one email: the server checks again on Login
                          _clearLock();
                          if (_emailError != null || _successMessage != null) {
                            setState(() {
                              _emailError = null;
                              _successMessage = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Enter your password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        errorText: _passwordError,
                        onChanged: () {
                          if (_passwordError != null || _successMessage != null) {
                            setState(() {
                              _passwordError = null;
                              _successMessage = null;
                            });
                          }
                        },
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _handleForgotPassword,
                          style: TextButton.styleFrom(
                            foregroundColor: _primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isLocked) ...[
                        _buildLockBanner(),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_primary, _primarySoft],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: _primary.withValues(alpha: 0.22),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading || _isLocked ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _isLocked
                                        ? 'Try again in ${LoginLockStatus.countdown(_lockLeft)}'
                                        : 'Login',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account?",
                            style: TextStyle(color: _textSecondary),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RoleSelectionScreen(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: _primary,
                            ),
                            child: const Text(
                              'Sign up',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? errorText,
    VoidCallback? onChanged,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged?.call(),
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: errorText != null ? _errorText : _primary,
        ),
        suffixIcon: suffixIcon,
        errorText: errorText,
        errorMaxLines: 3,
        filled: true,
        fillColor: _inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        labelStyle: const TextStyle(color: _textSecondary),
        hintStyle: const TextStyle(color: _textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _primary, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _errorText, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _errorText, width: 1.4),
        ),
        errorStyle: const TextStyle(
          color: _errorText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Shown while the email is locked after too many wrong passwords.
  Widget _buildLockBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _errorBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _errorText.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_clock_outlined, color: _errorText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Too many failed attempts. For your security, login for this '
              'account is locked for ${LoginLockoutService.lockMinutes} minutes '
              '(${LoginLockStatus.countdown(_lockLeft)} left). '
              'Forgot your password? You can reset it above.',
              style: const TextStyle(
                color: _errorText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _successBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _successText.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: _successText,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _successMessage!,
              style: const TextStyle(
                color: _successText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
