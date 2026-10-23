import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/core/error/api_failure.dart';
import 'package:scn_jobs/core/theme/app_theme.dart';
import 'package:scn_jobs/presentation/features/auth/auth_controller.dart';
import 'package:scn_jobs/presentation/features/auth/widgets/auth_widgets.dart';
import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  // Guards the error listener below — see its doc for why this is
  // needed at all.
  bool _loggingIn = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _loggingIn = true;
    await ref.read(authControllerProvider.notifier).login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    final state = ref.read(authControllerProvider);
    if (state.hasValue && state.value != null && mounted) {
      // See the matching comment in `verify_otp_screen.dart` — the
      // authGuard redirect (route_guards.dart) already decides home vs.
      // profile-setup off `shouldForceOnboardingProvider`. Checking it
      // again here raced with that redirect and could flash the wrong
      // screen for a moment before this call's own (separately awaited)
      // result overrode it. Just go home; the guard bounces to
      // profile-setup on its own if it's still needed.
      context.go('/home');
    }
    _loggingIn = false;
  }

  /// Shows the backend's own message (e.g. "This account has been
  /// deleted. Please contact support.") instead of one hardcoded
  /// string for every failure. Falls back to the generic text only
  /// when there is no usable message.
  String _loginErrorMessage(Object error) {
    const fallback = "Couldn't log in. Check your email and password.";
    final failure = error is DioException ? error.error : error;
    if (failure is ApiFailure && failure.message.trim().isNotEmpty) {
      return failure.message;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    ref.listen(authControllerProvider, (previous, next) {
      // `authControllerProvider` is shared across login, register,
      // verify-otp, and resend-otp (see `AuthController`) — any of
      // those setting an error state would fire this listener even
      // while LoginScreen sits inertly underneath another screen on
      // the nav stack (pushed screens don't dispose what's beneath
      // them). Without this guard, a REGISTER error (e.g. "Email
      // already registered" while resubmitting from `/register`)
      // showed this screen's "Couldn't log in" snackbar on top of
      // whatever screen the user was actually on — confusing, and
      // wrong, since nothing about login failed. Only show it for an
      // error this screen's own `_submit()` caused.
      if (!_loggingIn) return;
      next.whenOrNull(
        error: (error, _) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_loginErrorMessage(error)),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red.shade700,
            margin: const EdgeInsets.all(16),
          ),
        ),
      );
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  // Hero logo — plain logo, no navy container.
                  Center(
                    child: Image.asset(
                      'assets/images/final.png',
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) {
                        debugPrint('LOGO ERROR: $error');
                        return Icon(
                          Icons.work_outline_rounded,
                          color: AppTheme.navy,
                          size: 64,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Headline
                  Text(
                    'Welcome Back!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Find work near you',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade500,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Log in',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _ImprovedTextField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'Enter your email',
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Enter a valid email'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _ImprovedTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'Enter your password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscure,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: Colors.grey.shade500,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Minimum 6 characters'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  context.push('/forgot-password'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: AppTheme.navy,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _PrimaryButton(
                            label: 'Log in',
                            isLoading: authState.isLoading,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Bottom Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          'Register',
                          style: TextStyle(
                            color: AppTheme.navy,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== WIDGETS ====================

class _ImprovedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;

  const _ImprovedTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: (_) => onSubmitted?.call(),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 14,
        ),
        labelStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          prefixIcon,
          size: 20,
          color: Colors.grey.shade500,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppTheme.navy,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: AppTheme.navy.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: isLoading
            ? const SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
