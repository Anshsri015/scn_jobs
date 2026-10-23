import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scn_jobs/domain/repositories/auth_repository.dart';
import 'package:scn_jobs/domain/usecases/resend_otp_usecase.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepo;
  late ResendOtpUseCase useCase;

  setUp(() {
    mockRepo = MockAuthRepository();
    useCase = ResendOtpUseCase(mockRepo);
  });

  test(
      'calls repository.resendOtp with the given phone and returns the dev OTP',
      () async {
    when(() => mockRepo.resendOtp(phone: any(named: 'phone')))
        .thenAnswer((_) async => '654321');

    final result = await useCase(phone: '9876543210');

    expect(result, '654321');
    verify(() => mockRepo.resendOtp(phone: '9876543210')).called(1);
  });

  test('returns null when the backend does not echo a dev OTP (production)',
      () async {
    when(() => mockRepo.resendOtp(phone: any(named: 'phone')))
        .thenAnswer((_) async => null);

    final result = await useCase(phone: '9876543210');

    expect(result, isNull);
  });
}
