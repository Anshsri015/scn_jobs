/// The three roles the backend recognizes (see API docs §1.4).
enum UserRole { worker, recruiter, superAdmin }

UserRole userRoleFromString(String value) {
  switch (value) {
    case 'worker':
      return UserRole.worker;
    case 'recruiter':
      return UserRole.recruiter;
    case 'super_admin':
      return UserRole.superAdmin;
    default:
      throw ArgumentError('Unknown role: $value');
  }
}

/// Pure-Dart auth entity. No JSON, no freezed — this is what the rest
/// of the app (usecases, controllers, widgets) should depend on.
///
/// Fields are nullable beyond id/email/role because the backend's
/// /login, /verify-otp, and /me responses don't all include the same
/// shape: worker responses carry phone/phoneVerified, recruiter
/// responses carry isActive, and neither always includes the other.
class User {
  const User({
    required this.id,
    required this.email,
    required this.role,
    this.phone,
    this.phoneVerified,
    this.isActive,
  });

  final String id;
  final String email;
  final UserRole role;
  final String? phone;
  final bool? phoneVerified;
  final bool? isActive;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          id == other.id &&
          email == other.email &&
          role == other.role &&
          phone == other.phone &&
          phoneVerified == other.phoneVerified &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      Object.hash(id, email, role, phone, phoneVerified, isActive);
}
