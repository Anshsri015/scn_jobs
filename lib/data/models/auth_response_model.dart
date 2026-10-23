import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:scn_jobs/data/models/user_model.dart';

part 'auth_response_model.freezed.dart';
part 'auth_response_model.g.dart';

/// Wraps the `data` object returned by /login, /worker/verify-otp.
@freezed
class AuthResponseModel with _$AuthResponseModel {
  const factory AuthResponseModel({
    required String token,
    required UserModel user,
  }) = _AuthResponseModel;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseModelFromJson(json);
}
