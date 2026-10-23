/// Form-field validators, written as `String? Function(String?)` so they
/// plug directly into `TextFormField.validator` when auth/profile forms
/// are built starting Day 5 — no adapter needed at the call site.
class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Indian mobile numbers: exactly 10 digits, optionally prefixed with
  /// +91 or 0. Anything else (landlines, other countries) is out of
  /// scope for this app per the plan's target audience.
  static final RegExp _indianPhoneRegex = RegExp(r'^(?:\+91|0)?[6-9]\d{9}$');

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }

  static String? indianPhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Phone number is required';
    if (!_indianPhoneRegex.hasMatch(trimmed)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  /// Minimum 6 characters — matches the backend's current password
  /// policy. Tighten here the moment the backend does, so client and
  /// server never disagree on what's "valid".
  static String? password(String? value) {
    final trimmed = value ?? '';
    if (trimmed.isEmpty) return 'Password is required';
    if (trimmed.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static final RegExp _otpRegex = RegExp(r'^\d{6}$');

  /// The forgot-password OTP (and worker-registration OTP) are both
  /// documented as a plain 6-digit numeric code — see
  /// `SCN-Jobs-Forgot-Password` API doc §1/§2.
  static String? otp(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter the 6-digit code';
    if (!_otpRegex.hasMatch(trimmed)) return 'Code must be 6 digits';
    return null;
  }

  static String? required(String? value, {String fieldName = 'This field'}) {
    if ((value?.trim() ?? '').isEmpty) return '$fieldName is required';
    return null;
  }
}

// WHY THIS FILE
// Validation rules live in exactly one place so the login form, register
// form, and profile-edit form (Days 5-14) can't silently drift apart —
// e.g. one screen requiring 8-char passwords while another accepts 6.
// Alternative considered: inlining regex/length checks per-`TextFormField`.
// Rejected — guarantees inconsistency across the ~6 forms this app ships,
// and makes a policy change (e.g. backend now requires 8 chars) a
// multi-file hunt instead of a one-line edit here.
// Pitfall a junior would hit: writing a phone regex that also accepts
// 11-12 digit inputs "to be safe" — that silently lets malformed numbers
// through to the backend, which then rejects them with a less helpful
// server-side error message than this client-side one.