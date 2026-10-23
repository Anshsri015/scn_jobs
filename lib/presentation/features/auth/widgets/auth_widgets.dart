import 'package:flutter/material.dart';

/// Soft decorative background blobs shared across every auth screen.
/// Purely visual — keeps the login/register/otp flow feeling like one
/// cohesive product instead of five separately-styled screens.
class AuthBackground extends StatelessWidget {
  const AuthBackground({required this.child, super.key});

  final Widget child;

  Widget _blob(double size, List<Color> colors) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: colors),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned(
          top: -70,
          right: -50,
          child: _blob(200, [
            colors.primary.withOpacity(0.16),
            colors.primary.withOpacity(0.0),
          ]),
        ),
        Positioned(
          bottom: -110,
          left: -90,
          child: _blob(240, [
            colors.tertiary.withOpacity(0.14),
            colors.tertiary.withOpacity(0.0),
          ]),
        ),
        child,
      ],
    );
  }
}

/// The elevated white card every form sits inside. Shadow instead of a
/// flat border reads as more "designed" and matches the depth used on
/// JobCard/JobDetailScreen elsewhere in the app.
class AuthCard extends StatelessWidget {
  const AuthCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Consistent filled input style for every text field across auth
/// screens — one place to tweak radius/fill colour instead of five.
InputDecoration authInputDecoration(
    BuildContext context, {
      required String label,
      required IconData prefixIcon,
      Widget? suffixIcon,
      String? helperText,
      String? hintText,
    }) {
  final colors = Theme.of(context).colorScheme;
  final radius = BorderRadius.circular(12);

  return InputDecoration(
    labelText: label,
    hintText: hintText,
    helperText: helperText,
    prefixIcon: Icon(prefixIcon, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: colors.surfaceContainerHighest.withOpacity(0.45),
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colors.error, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colors.error, width: 1.5),
    ),
  );
}

/// Full-width gradient-free primary button with a built-in loading
/// state — every screen was hand-rolling "isLoading ? spinner : Text"
/// slightly differently; this is the single version of that pattern.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: colors.primary,
          disabledBackgroundColor: colors.primary.withOpacity(0.6),
          elevation: 0,
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Icon-in-a-circle used for the success/info states (forgot password
/// sent, OTP sent) — a tinted soft circle instead of a bare Icon widget
/// reads as more intentional.
class AuthIconBadge extends StatelessWidget {
  const AuthIconBadge({required this.icon, super.key, this.size = 64});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryContainer.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: size * 0.45, color: colors.primary),
    );
  }
}
