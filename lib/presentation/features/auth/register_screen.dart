import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/core/error/api_failure.dart';
import 'package:scn_jobs/core/theme/app_theme.dart';
import 'package:scn_jobs/core/utils/legal_links.dart';
import 'package:scn_jobs/core/utils/validators.dart';
import 'package:scn_jobs/presentation/features/auth/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = false;
  bool _submitting = false;

  double _passwordStrength = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String value) {
    double strength = 0;
    if (value.length >= 6) strength += 0.25;
    if (value.length >= 8) strength += 0.25;
    if (value.contains(RegExp(r'[0-9]'))) strength += 0.25;
    if (value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.25;
    setState(() => _passwordStrength = strength);
  }

  String? _confirmPasswordMatch(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please re-enter your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String? _acceptTerms(bool? value) {
    if (!_acceptedTerms) {
      return 'Please accept the Terms to continue';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    try {
      await ref.read(authControllerProvider.notifier).register(
        email: email,
        password: _passwordController.text,
        phone: phone,
        name: _nameController.text.trim(),
      );

      final state = ref.read(authControllerProvider);
      if (state.hasError) {
        // Happens when the worker submitted this exact phone/email
        // once already (creating a pending, unverified registration),
        // then pressed back from `/verify-otp` and hit "Create
        // Account" again without changing anything. The backend
        // rejects the resubmit as a phone/email-uniqueness violation
        // — not a real error, just "this registration already
        // exists" — so instead of dead-ending the worker behind that
        // message (which they can only escape by changing the
        // number), resend the OTP for the existing registration and
        // continue on to verify-otp exactly like a fresh success
        // would.
        if (_isDuplicateRegistrationError(state.error)) {
          final resent = await _resendForExistingRegistration(phone);
          if (!resent) {
            if (mounted) _showErrorFromState(state);
            return;
          }
        } else {
          _showErrorFromState(state);
          return;
        }
      }

      if (mounted) {
        // `extra` (not the URL) used to carry phone/email — but `extra`
        // is transient, in-memory data tied to this specific push. When
        // OTP verification succeeds, `verifyOtp()` invalidates
        // `authStateProvider`, which `_GoRouterRefreshNotifier` reacts to
        // by calling `notifyListeners()` — that rebuilds the CURRENT
        // route (still `/verify-otp`, mid-way through its own 1.5s
        // "Verified!" delay) and `state.extra` doesn't survive that
        // rebuild, so the route's `extra is! (...)` fallback kicked in
        // and briefly rendered `RegisterScreen` before the screen's own
        // `context.go('/home')` fired a moment later — a 1-2s flash of
        // the register form. Query parameters live in the URL itself,
        // so they survive that rebuild; only genuinely fresh
        // navigations (or a killed-and-restored app) miss them.
        context.push(
          Uri(
            path: '/verify-otp',
            queryParameters: {
              'phone': phone,
              'email': email,
            },
          ).toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// True when [error] is the backend's "phone/email already
  /// registered" uniqueness failure rather than a genuine validation
  /// problem — i.e. this exact phone/email already has a pending,
  /// unverified registration from an earlier submit.
  ///
  /// Doc-confirmed (device log, 12 Sep): this backend's "already
  /// registered" error doesn't name a `field` at all (just a bare
  /// `{message: "Email already registered"}`), so this checks the
  /// message text itself — both the top-level [ApiFailure.message]
  /// and every `fieldErrors` value — rather than trying to match a
  /// specific field key that may not exist.
  bool _isDuplicateRegistrationError(Object? error) {
    if (error is! ApiFailure) return false;
    final pattern = RegExp('already|exist|registered', caseSensitive: false);
    if (pattern.hasMatch(error.message)) return true;
    if (error is ValidationFailure && error.fieldErrors != null) {
      return error.fieldErrors!.values.any((v) => pattern.hasMatch(v));
    }
    return false;
  }

  /// Resends the OTP for the existing pending registration instead of
  /// re-registering. Returns whether it succeeded — on failure the
  /// caller falls back to showing the original register error, so the
  /// worker isn't left on a screen with no feedback at all.
  Future<bool> _resendForExistingRegistration(String phone) async {
    try {
      await ref.read(authControllerProvider.notifier).resendOtp(phone: phone);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _showErrorFromState(AsyncValue<dynamic> state) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final error = state.error;
    var message = "Couldn't register. Check your details.";
    if (error is ValidationFailure && error.fieldErrors != null) {
      final entries = error.fieldErrors!.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      // Backend error items without a real `field` name get a
      // positional placeholder key like `error_0` (see
      // ErrorInterceptor._extractFieldErrors) just so the message
      // isn't silently dropped. That placeholder is internal
      // bookkeeping, not something the worker should ever see —
      // showing "error_0: Email already registered" instead of
      // just "Email already registered" reads as a broken/garbled
      // error. Strip it and show the plain message for those.
      final placeholderKey = RegExp(r'^error_\d+$');
      message = entries
          .map((e) => placeholderKey.hasMatch(e.key)
          ? e.value
          : '${e.key}: ${e.value}')
          .join('\n');
    } else if (error is ServerFailure) {
      message = error.message;
    } else if (error is NetworkFailure) {
      message = error.message;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.red.shade700,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isLoading = authState.isLoading || _submitting;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Create account',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.grey.shade700),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Stepper
              Row(
                children: [
                  _StepDot(isActive: true, label: 'Details'),
                  _StepLine(isActive: false),
                  _StepDot(isActive: false, label: 'Verify'),
                  _StepLine(isActive: false),
                  _StepDot(isActive: false, label: 'Done'),
                ],
              ),
              const SizedBox(height: 28),
              // Headline
              Text(
                'Find your dream job!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Join lakhs of job seekers. Fill in your details to get started.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
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
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // WHY THIS FIELD WAS ADDED: `POST
                      // /auth/worker/register` accepts an optional
                      // `name`, but nothing in the app ever collected
                      // or sent it — so `PersonalDetailsScreen` had no
                      // way to prefill the worker's name later
                      // (`GET /auth/me` never returns it either, only
                      // this one registration call does). Required
                      // here so it's always captured once, up front.
                      _ImprovedTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        hint: 'Ansh Srivastava',
                        prefixIcon: Icons.person_outline_rounded,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter your full name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _ImprovedTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'your@email.com',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 16),
                      _ImprovedTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Create a strong password',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: Colors.grey.shade500,
                          ),
                          onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        validator: Validators.password,
                        onChanged: _checkPasswordStrength,
                      ),
                      const SizedBox(height: 8),
                      // Password Strength Indicator
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _passwordStrength,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _passwordStrength <= 0.25
                                      ? Colors.red.shade400
                                      : _passwordStrength <= 0.5
                                      ? Colors.orange.shade400
                                      : _passwordStrength <= 0.75
                                      ? Colors.yellow.shade600
                                      : Colors.green.shade500,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _passwordStrength <= 0.25
                                ? 'Weak'
                                : _passwordStrength <= 0.5
                                ? 'Fair'
                                : _passwordStrength <= 0.75
                                ? 'Good'
                                : 'Strong',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _passwordStrength <= 0.25
                                  ? Colors.red.shade400
                                  : _passwordStrength <= 0.5
                                  ? Colors.orange.shade400
                                  : _passwordStrength <= 0.75
                                  ? Colors.yellow.shade700
                                  : Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ImprovedTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm password',
                        hint: 'Re-enter password',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscureConfirm,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: Colors.grey.shade500,
                          ),
                          onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                        validator: _confirmPasswordMatch,
                      ),
                      const SizedBox(height: 16),
                      // Phone with +91 prefix
                      Row(
                        children: [
                          Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '🇮🇳',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '+91',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ImprovedTextField(
                              controller: _phoneController,
                              label: 'Phone',
                              hint: '9876543210',
                              prefixIcon: Icons.phone_iphone_rounded,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              validator: Validators.indianPhone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Terms Checkbox
                      FormField<bool>(
                        initialValue: false,
                        validator: _acceptTerms,
                        builder: (stateField) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _acceptedTerms = !_acceptedTerms;
                                  });
                                  stateField.didChange(_acceptedTerms);
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _acceptedTerms
                                        ? AppTheme.navy.withOpacity(0.06)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: stateField.hasError
                                          ? Colors.red.shade300
                                          : _acceptedTerms
                                          ? AppTheme.navy.withOpacity(0.2)
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: Checkbox(
                                          value: _acceptedTerms,
                                          onChanged: (v) {
                                            setState(() {
                                              _acceptedTerms = v ?? false;
                                            });
                                            stateField
                                                .didChange(_acceptedTerms);
                                          },
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(6),
                                          ),
                                          activeColor: AppTheme.navy,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Wrap(
                                          crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              'I agree to the ',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => LegalLinks.open(
                                                context,
                                                LegalLinks.terms,
                                              ),
                                              child: Text(
                                                'Terms of Service',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppTheme.navy,
                                                  fontWeight: FontWeight.w700,
                                                  decoration:
                                                  TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              ' and ',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => LegalLinks.open(
                                                context,
                                                LegalLinks.privacy,
                                              ),
                                              child: Text(
                                                'Privacy Policy',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppTheme.navy,
                                                  fontWeight: FontWeight.w700,
                                                  decoration:
                                                  TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (stateField.hasError)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    top: 8,
                                  ),
                                  child: Text(
                                    stateField.errorText!,
                                    style: TextStyle(
                                      color: Colors.red.shade500,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.navy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: AppTheme.navy.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                              : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          "We'll send an OTP to verify your email",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  TextButton(
                    onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/login'),
                    child: Text(
                      'Log in',
                      style: TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
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
  final void Function(String)? onChanged;
  final TextCapitalization textCapitalization;

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
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Icon(prefixIcon, size: 20, color: Colors.grey.shade500),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
          borderSide: BorderSide(color: AppTheme.navy, width: 2),
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

class _StepDot extends StatelessWidget {
  final bool isActive;
  final String label;

  const _StepDot({required this.isActive, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.navy : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: isActive
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isActive ? AppTheme.navy : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool isActive;

  const _StepLine({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: isActive ? AppTheme.navy : Colors.grey.shade200,
      ),
    );
  }
}
