import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:scn_jobs/domain/entities/auth_session.dart';
import 'package:scn_jobs/domain/entities/register_result.dart';
import 'package:scn_jobs/domain/entities/user.dart';
import 'package:scn_jobs/domain/repositories/auth_repository.dart';
import 'package:scn_jobs/presentation/features/auth/auth_controller.dart';
import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(mockRepo)],
    );
  });

  tearDown(() => container.dispose());

  test('login success sets AsyncData with session', () async {
    const user = User(
      id: 'u1',
      email: 'a@a.com',
      role: UserRole.worker,
      phone: '9876543210',
      phoneVerified: true,
    );
    const session = AuthSession(user: user, token: 't');

    when(
      () => mockRepo.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => session);

    await container.read(authControllerProvider.notifier).login(
          email: 'a@a.com',
          password: 'secret1',
        );

    final state = container.read(authControllerProvider);
    expect(state.hasValue, true);
    expect(state.value, session);
  });

  test('login failure sets AsyncError', () async {
    when(
      () => mockRepo.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(Exception('Invalid credentials'));

    await container.read(authControllerProvider.notifier).login(
          email: 'a@a.com',
          password: 'wrong',
        );

    expect(container.read(authControllerProvider).hasError, true);
  });

  test('register returns RegisterResult with userId and devOtp on success',
      () async {
    when(
      () => mockRepo.registerWorker(
        email: any(named: 'email'),
        password: any(named: 'password'),
        phone: any(named: 'phone'),
      ),
    ).thenAnswer(
      (_) async => const RegisterResult(userId: 'user-123', devOtp: '482193'),
    );

    final result =
        await container.read(authControllerProvider.notifier).register(
              email: 'a@a.com',
              password: 'secret1',
              phone: '9876543210',
            );

    expect(result?.userId, 'user-123');
    expect(result?.devOtp, '482193');
  });

  test('register returns null devOtp on a production-like backend response',
      () async {
    when(
      () => mockRepo.registerWorker(
        email: any(named: 'email'),
        password: any(named: 'password'),
        phone: any(named: 'phone'),
      ),
    ).thenAnswer(
      (_) async => const RegisterResult(userId: 'user-456'),
    );

    final result =
        await container.read(authControllerProvider.notifier).register(
              email: 'a@a.com',
              password: 'secret1',
              phone: '9876543210',
            );

    expect(result?.userId, 'user-456');
    expect(result?.devOtp, isNull);
  });
}
