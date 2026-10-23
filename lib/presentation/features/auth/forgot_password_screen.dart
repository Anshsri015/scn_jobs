import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/core/error/api_failure.dart';
import 'package:scn_jobs/core/theme/app_theme.dart';
import 'package:scn_jobs/core/utils/validators.dart';
import 'package:scn_jobs/presentation/features/auth/auth_controller.dart';
import 'package:scn_jobs/presentation/features/auth/widgets/resend_countdown_button.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _submitting = false;
  bool _requestSent = false;
  // The email the code was actually sent to — kept separate from the
  // (still-visible-until-success) `_emailController` so the success
  // card and the next screen always show/use exactly what was
  // submitted, not whatever's currently typed in the field.
  String _sentEmail = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Shared by the initial submit and by the success card's resend
  /// button. Returns true on success so callers can decide what to do
  /// next (advance the screen vs. just show a snackbar).
  Future<bool> _requestOtp(String email) async {
    await ref.read(authControllerProvider.notifier).forgotPassword(
      email: email,
    );

    final state = ref.read(authControllerProvider);
    if (!mounted) return false;

    if (!state.hasError) return true;

    final error = state.error;
    // ✅ CONFIRMED (API doc) — unlike a typical forgot-password flow,
    // this backend genuinely returns 404 for an unregistered email and
    // the doc says to show that directly, so it's not treated as a
    // generic failure here.
    if (error is ServerFailure && error.statusCode == 404) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.red.shade700,
          margin: const EdgeInsets.all(16),
        ),
      );
      return false;
    }

    if (error is NetworkFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text("Couldn't connect. Check your internet and try again."),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.orange.shade700,
          margin: const EdgeInsets.all(16),
        ),
      );
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is ApiFailure ? error.message : 'Something went wrong.',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.red.shade700,
        margin: const EdgeInsets.all(16),
      ),
    );
    return false;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final email = _emailController.text.trim();
      final ok = await _requestOtp(email);
      if (ok && mounted) {
        setState(() {
          _sentEmail = email;
          _requestSent = true;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Forgot password',
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
          child: _requestSent ? _buildSuccessState(theme) : _buildFormState(theme),
        ),
      ),
    );
  }

  Widget _buildFormState(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Illustration
        Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mark_email_unread_outlined,
              size: 64,
              color: AppTheme.navy.withOpacity(0.8),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Forgot your password?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 26,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "No worries! Enter your email and we'll send you a 6-digit code to reset your password.",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.grey.shade500,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        // Info bullets
        _InfoBullet(
          icon: Icons.email_outlined,
          text: "We'll email you a 6-digit verification code",
        ),
        const SizedBox(height: 10),
        _InfoBullet(
          icon: Icons.timer_outlined,
          text: "Code expires in 10 minutes",
        ),
        const SizedBox(height: 32),
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
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _inputDecoration(
                    label: 'Email',
                    hint: 'your@email.com',
                    prefixIcon: Icons.mail_outline_rounded,
                  ),
                  validator: Validators.email,
                  onFieldSubmitted: (_) => _submit(),
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
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Send code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.send_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 48,
              color: Colors.green.shade600,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Check your email',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 26,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade500,
              height: 1.6,
            ),
            children: [
              const TextSpan(text: "We've sent a 6-digit code to "),
              TextSpan(
                text: _sentEmail,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const TextSpan(text: '. It expires in 10 minutes.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: () => context.push(
              Uri(
                path: '/reset-password',
                queryParameters: {'email': _sentEmail},
              ).toString(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.navy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Enter code',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Didn't receive it?",
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Check your spam folder\n• Make sure your email is correct\n• Wait a few minutes',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ResendCountdownButton(
                  onResend: () async {
                    final ok = await _requestOtp(_sentEmail);
                    if (ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Code resent.'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_rounded,
                size: 18, color: Colors.grey.shade600),
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
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: Icon(prefixIcon, size: 20, color: Colors.grey.shade500),
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

class _InfoBullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppTheme.navy.withOpacity(0.8),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}