import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:scn_jobs/domain/entities/user.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    required String role,
    String? phone,
    bool? phoneVerified,
    bool? isActive,
  }) = _UserModel;
  const UserModel._();

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  User toEntity() => User(
        id: id,
        email: email,
        role: userRoleFromString(role),
        phone: phone,
        phoneVerified: phoneVerified,
        isActive: isActive,
      );
}
