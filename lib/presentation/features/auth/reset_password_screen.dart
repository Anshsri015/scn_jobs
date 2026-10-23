import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/core/error/api_failure.dart';
import 'package:scn_jobs/core/theme/app_theme.dart';
import 'package:scn_jobs/core/utils/validators.dart';
import 'package:scn_jobs/presentation/features/auth/auth_controller.dart';
import 'package:scn_jobs/presentation/features/auth/widgets/resend_countdown_button.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.initialEmail});

  /// Pre-fills (and locks in) the email — set when arriving from
  /// `ForgotPasswordScreen` right after requesting a code. Left blank
  /// when the worker reaches this screen directly ("I already have a
  /// code"), in which case they type it in themselves.
  final String? initialEmail;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  double _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
    if (value == null || value.isEmpty) return 'Please re-enter your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    // Only take a paste that actually looks like the 6-digit code —
    // pasting something else (e.g. a copied password) into this field
    // by accident shouldn't silently overwrite it with junk.
    if (RegExp(r'^\d{6}$').hasMatch(text)) {
      _otpController.text = text;
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).resetPassword(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
        newPassword: _passwordController.text,
      );

      final state = ref.read(authControllerProvider);
      if (!mounted) return;

      if (state.hasError) {
        final error = state.error;
        // Use the backend's actual message where we have one (e.g.
        // "Invalid or expired OTP", "No account found with this
        // email", or a password-policy validation message) instead of
        // one hard-coded string that only ever described the OTP case.
        final message = error is ApiFailure
            ? error.message
            : 'Something went wrong. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(message)),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red.shade700,
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }

      // Show success state briefly, then auto-dismiss and redirect —
      // previously this dialog had no timer/close call, so it just sat
      // there forever showing "Redirecting to login..." without ever
      // actually redirecting.
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          });
          return const _SuccessDialog();
        },
      );

      if (mounted) {
        context.go('/login');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Reset password',
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // Illustration
              Center(
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade100,
                        Colors.orange.shade50,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_reset_rounded,
                    size: 56,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Create a strong password',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the code from your email and choose a new password.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 18, color: AppTheme.navy),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tip: Use a mix of letters, numbers & symbols',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.navy.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
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
                      // Email — pre-filled (and effectively locked in,
                      // since editing it after requesting a code would
                      // mean the code was sent to a different address
                      // than what's about to be submitted) when we
                      // arrived here from ForgotPasswordScreen; empty
                      // and editable for the direct "I already have a
                      // code" entry point.
                      _ImprovedTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'your@email.com',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        readOnly: widget.initialEmail != null &&
                            widget.initialEmail!.isNotEmpty,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 16),
                      // OTP field with Paste
                      TextFormField(
                        controller: _otpController,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        decoration: _inputDecoration(
                          label: 'Verification code',
                          hint: '6-digit code from your email',
                          prefixIcon: Icons.vpn_key_outlined,
                          suffixIcon: TextButton(
                            onPressed: _pasteFromClipboard,
                            child: Text(
                              'Paste',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.navy,
                              ),
                            ),
                          ),
                        ).copyWith(counterText: ''),
                        validator: Validators.otp,
                      ),
                      if (_emailController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ResendCountdownButton(
                            onResend: () async {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .forgotPassword(
                                email: _emailController.text.trim(),
                              );
                              final state = ref.read(authControllerProvider);
                              if (!mounted) return;
                              final failed = state.hasError;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    failed
                                        ? (state.error is ApiFailure
                                        ? (state.error as ApiFailure).message
                                        : "Couldn't resend. Try again.")
                                        : 'Code resent.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: failed
                                      ? Colors.red.shade700
                                      : null,
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _ImprovedTextField(
                        controller: _passwordController,
                        label: 'New password',
                        hint: 'Minimum 6 characters',
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
                        label: 'Confirm new password',
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
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.navy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: AppTheme.navy.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _submitting
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
                                'Update Password',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.check_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton.icon(
                  onPressed: () => context.pop(),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  label: Text(
                    'Back to login',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: Icon(prefixIcon, size: 20, color: Colors.grey.shade500),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
    );
  }
}

class _ImprovedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextInputType? keyboardType;
  final bool readOnly;

  const _ImprovedTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: readOnly ? Colors.grey.shade600 : null,
      ),
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

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 40,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Password Updated!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your password has been reset successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Redirecting to login...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
