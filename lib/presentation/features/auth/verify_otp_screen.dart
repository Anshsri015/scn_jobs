import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/core/utils/dev_otp_cache.dart';
import 'package:scn_jobs/presentation/features/auth/auth_controller.dart';
import 'package:scn_jobs/presentation/features/auth/widgets/auth_widgets.dart';
import 'package:scn_jobs/presentation/features/auth/widgets/resend_countdown_button.dart';
import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({required this.phone, required this.email, super.key});
  final String phone;
  final String email;

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final List<TextEditingController> _otpControllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
  List.generate(6, (_) => FocusNode());

  String? _devOtp;
  bool _showSuccess = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _devOtp = DevOtpCache.read(widget.phone);

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  String get _otpText => _otpControllers.map((c) => c.text).join();

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (_otpText.length == 6) {
      _submit();
    }
    setState(() {});
  }

  void _onOtpKey(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpControllers[index].text.isEmpty &&
        index > 0) {
      _otpControllers[index - 1].clear();
      _otpFocusNodes[index - 1].requestFocus();
      setState(() {});
    }
  }

  Future<void> _submit() async {
    final otp = _otpText.trim();
    if (otp.length != 6) {
      _shakeController.forward(from: 0);
      HapticFeedback.mediumImpact();
      return;
    }

    await ref.read(authControllerProvider.notifier).verifyOtp(
      phone: widget.phone,
      otp: otp,
    );

    final state = ref.read(authControllerProvider);
    if (!mounted) return;

    if (state.hasError) {
      _shakeController.forward(from: 0);
      HapticFeedback.mediumImpact();
      for (final c in _otpControllers) {
        c.clear();
      }
      _otpFocusNodes[0].requestFocus();
      return;
    }

    if (state.hasValue && state.value != null) {
      HapticFeedback.lightImpact();
      setState(() => _showSuccess = true);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      // `route_guards.dart`'s authGuard is the single source of truth for
      // "home vs profile-setup" — it watches `shouldForceOnboardingProvider`
      // via `_GoRouterRefreshNotifier` and redirects on its own as soon as
      // that resolves. Deciding it again here raced with that redirect:
      // the guard's check could resolve first and send the user to
      // `/profile-setup/create`, then this screen's own (separately
      // awaited) `mustOnboard` check would resolve a moment later and
      // override it back to `/home` — a 1-2s flash of the wrong screen.
      // Just go home; the guard bounces to profile-setup on its own if
      // onboarding is still needed, with no second competing decision.
      context.go('/home');
    }
  }

  Future<void> _resend() async {
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resendOtp(phone: widget.phone);
      if (mounted) {
        setState(() => _devOtp = DevOtpCache.read(widget.phone));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 10),
                const Text('A new OTP has been sent'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't resend OTP"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _autofillDevOtp() {
    final otp = _devOtp;
    if (otp == null || otp.length != 6) return;
    for (var i = 0; i < 6; i++) {
      _otpControllers[i].text = otp[i];
    }
    _otpFocusNodes[5].requestFocus();
    setState(() {});
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    ref.listen(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {},
      );
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, size: 20),
          ),
        ),
      ),
      body: Stack(
        children: [
          AuthBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    /// Hero illustration area
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primary.withOpacity(0.15),
                              colors.primary.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mark_email_read_outlined,
                          size: 48,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    /// Headline
                    Text(
                      'Verify your email',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),

                    /// Email chip
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mail_outline_rounded,
                                  size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 6),
                              Text(
                                widget.email,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    /// Change email link
                    Center(
                      child: TextButton(
                        onPressed: () => context.pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Change email?',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                    /// Dev OTP chip
                    if (!kReleaseMode && _devOtp != null) ...[
                      const SizedBox(height: 16),
                      Center(
                          child: _DevOtpChip(
                              otp: _devOtp!, onTap: _autofillDevOtp)),
                    ],

                    const SizedBox(height: 32),

                    /// OTP Card
                    AuthCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Enter 6-digit code',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 20),

                          /// 6-Box OTP Input — RESPONSIVE, NO OVERFLOW
                          AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(
                                    _shakeAnimation.value *
                                        (1 - _shakeController.value),
                                    0),
                                child: child,
                              );
                            },
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                const gap = 8.0;
                                final boxWidth = ((constraints.maxWidth -
                                    (gap * 5)) /
                                    6)
                                    .clamp(38.0, 48.0);

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(6, (index) {
                                    return Padding(
                                      padding: EdgeInsets.only(
                                          right: index < 5 ? gap : 0),
                                      child: SizedBox(
                                        width: boxWidth,
                                        height: 56,
                                        child: _OtpBox(
                                          controller: _otpControllers[index],
                                          focusNode: _otpFocusNodes[index],
                                          onChanged: (v) =>
                                              _onOtpChanged(index, v),
                                          onKey: (e) => _onOtpKey(index, e),
                                          isFilled: _otpControllers[index]
                                              .text
                                              .isNotEmpty,
                                          isActive: _otpFocusNodes[index]
                                              .hasFocus,
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 24),

                          /// Resend section
                          Center(
                              child: ResendCountdownButton(onResend: _resend)),

                          const SizedBox(height: 24),

                          /// Verify Button
                          AuthSubmitButton(
                            label: 'Verify & Continue',
                            isLoading: authState.isLoading,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// Help section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 18, color: Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Text(
                                'Didn\'t receive the code?',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Check your spam folder or ensure you have good network coverage. OTP is valid for 10 minutes.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),

          /// Success overlay
          if (_showSuccess)
            Container(
              color: Colors.white.withOpacity(0.95),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 56,
                        color: Colors.green.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Verified!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Taking you to your jobs...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// 6-Box OTP Input Widget — FIXED (Stateful)
/// ─────────────────────────────────────────────
class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKey,
    required this.isFilled,
    required this.isActive,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<RawKeyEvent> onKey;
  final bool isFilled;
  final bool isActive;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  late final FocusNode _keyboardFocusNode;

  @override
  void initState() {
    super.initState();
    _keyboardFocusNode = FocusNode(skipTraversal: true);
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return RawKeyboardListener(
      focusNode: _keyboardFocusNode,
      onKey: widget.onKey,
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: widget.isActive
              ? colors.primary.withOpacity(0.06)
              : Colors.grey.shade50,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: widget.isActive ? colors.primary : Colors.grey.shade300,
              width: widget.isActive ? 2 : 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: widget.isFilled ? colors.primary : Colors.grey.shade300,
              width: widget.isFilled ? 2 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: colors.primary,
              width: 2,
            ),
          ),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: widget.onChanged,
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Dev OTP Chip
/// ─────────────────────────────────────────────
class _DevOtpChip extends StatelessWidget {
  const _DevOtpChip({required this.otp, required this.onTap});

  final String otp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade100, Colors.amber.shade50],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.amber.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.shade100.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bug_report_outlined,
              size: 18,
              color: Colors.amber.shade800,
            ),
            const SizedBox(width: 8),
            Text(
              'DEV OTP: $otp',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.amber.shade900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'TAP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
