import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  final String role;

  const SignUpScreen({super.key, required this.role});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const Color _pageBackground = Color(0xFFF4F7FB);
  static const Color _cardColor = Colors.white;
  static const Color _primary = Color(0xFF163B65);
  static const Color _primarySoft = Color(0xFF335D8A);
  static const Color _textPrimary = Color(0xFF1B2433);
  static const Color _textSecondary = Color(0xFF687588);
  static const Color _inputFill = Color(0xFFF7F9FC);
  static const Color _errorText = Color(0xFFB42318);
  static const Color _successBg = Color(0xFFEAF7EE);
  static const Color _successText = Color(0xFF157347);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _firstNameError;
  String? _lastNameError;
  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _bannerError;
  String? _successMessage;

  bool _isPasswordStrong(String password) {
    final regex = RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[\W_]).{8,}$');
    return regex.hasMatch(password);
  }

  void _clearFieldError(String field) {
    setState(() {
      switch (field) {
        case 'firstName':
          _firstNameError = null;
          break;
        case 'lastName':
          _lastNameError = null;
          break;
        case 'username':
          _usernameError = null;
          break;
        case 'email':
          _emailError = null;
          break;
        case 'password':
          _passwordError = null;
          break;
        case 'confirmPassword':
          _confirmPasswordError = null;
          break;
      }
      _bannerError = null;
      _successMessage = null;
    });
  }

  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final username = _usernameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    String? firstNameError;
    String? lastNameError;
    String? usernameError;
    String? emailError;
    String? passwordError;
    String? confirmPasswordError;

    if (firstName.isEmpty) {
      firstNameError = 'Please enter your first name';
    }
    if (lastName.isEmpty) {
      lastNameError = 'Please enter your last name';
    }
    if (username.isEmpty) {
      usernameError = 'Please choose a username';
    }
    if (email.isEmpty) {
      emailError = 'Please enter your email address';
    }
    if (password.isEmpty) {
      passwordError = 'Please enter your password';
    }
    if (confirmPassword.isEmpty) {
      confirmPasswordError = 'Please confirm your password';
    }

    if (password.isNotEmpty &&
        confirmPassword.isNotEmpty &&
        password != confirmPassword) {
      confirmPasswordError = 'Passwords do not match';
    }

    if (password.isNotEmpty && !_isPasswordStrong(password)) {
      passwordError =
          'Use at least 8 characters with uppercase, lowercase, and a special character.';
    }

    if (firstNameError != null ||
        lastNameError != null ||
        usernameError != null ||
        emailError != null ||
        passwordError != null ||
        confirmPasswordError != null) {
      setState(() {
        _firstNameError = firstNameError;
        _lastNameError = lastNameError;
        _usernameError = usernameError;
        _emailError = emailError;
        _passwordError = passwordError;
        _confirmPasswordError = confirmPasswordError;
        _bannerError = null;
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _firstNameError = null;
      _lastNameError = null;
      _usernameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _bannerError = null;
      _successMessage = null;
    });

    try {
      await _authService.signUpUser(
        email: email,
        password: password,
        username: username,
        firstName: firstName,
        lastName: lastName,
        role: widget.role,
      );

      if (!mounted) return;

      setState(() {
        _successMessage = 'Account created successfully. Please log in.';
      });

      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bannerError = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmployer = widget.role == 'employer';
    final accentColor =
        isEmployer ? const Color(0xFFD97706) : const Color(0xFF1E8F8B);

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    _BackButtonChip(onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Create account',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Container(
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
                    children: [
                      const Text(
                        'Set up your details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Complete the form below to create your account.',
                        style: TextStyle(
                          fontSize: 14,
                          color: _textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_bannerError != null) ...[
                        _buildBanner(
                          message: _bannerError!,
                          color: _errorText,
                          backgroundColor: const Color(0xFFFCEBEC),
                          icon: Icons.error_outline_rounded,
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (_successMessage != null) ...[
                        _buildBanner(
                          message: _successMessage!,
                          color: _successText,
                          backgroundColor: _successBg,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                        const SizedBox(height: 18),
                      ],
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 420;

                          if (!isWide) {
                            return Column(
                              children: [
                                _buildInputField(
                                  controller: _firstNameController,
                                  label: 'First Name',
                                  hint: 'Enter your first name',
                                  icon: Icons.badge_outlined,
                                  errorText: _firstNameError,
                                  onChanged: () => _clearFieldError('firstName'),
                                ),
                                const SizedBox(height: 16),
                                _buildInputField(
                                  controller: _lastNameController,
                                  label: 'Last Name',
                                  hint: 'Enter your last name',
                                  icon: Icons.person_outline_rounded,
                                  errorText: _lastNameError,
                                  onChanged: () => _clearFieldError('lastName'),
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  controller: _firstNameController,
                                  label: 'First Name',
                                  hint: 'Enter your first name',
                                  icon: Icons.badge_outlined,
                                  errorText: _firstNameError,
                                  onChanged: () =>
                                      _clearFieldError('firstName'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildInputField(
                                  controller: _lastNameController,
                                  label: 'Last Name',
                                  hint: 'Enter your last name',
                                  icon: Icons.person_outline_rounded,
                                  errorText: _lastNameError,
                                  onChanged: () => _clearFieldError('lastName'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _usernameController,
                        label: 'Username',
                        hint: 'Choose a public username',
                        icon: Icons.alternate_email_rounded,
                        errorText: _usernameError,
                        onChanged: () => _clearFieldError('username'),
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _emailController,
                        label: 'Email Address',
                        hint: 'name@example.com',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                        onChanged: () => _clearFieldError('email'),
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Create a strong password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        errorText: _passwordError,
                        onChanged: () => _clearFieldError('password'),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Password must have at least 8 characters, one uppercase letter, one lowercase letter, and one special character.',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        hint: 'Re-enter your password',
                        icon: Icons.verified_user_outlined,
                        obscureText: _obscureConfirmPassword,
                        errorText: _confirmPasswordError,
                        onChanged: () =>
                            _clearFieldError('confirmPassword'),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
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
                            onPressed: _isLoading ? null : _handleSignUp,
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
                                : const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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

  Widget _buildBanner({
    required String message,
    required Color color,
    required Color backgroundColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
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

class _BackButtonChip extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButtonChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE1E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF1B2433),
          ),
        ),
      ),
    );
  }
}
