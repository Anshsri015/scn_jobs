import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:scn_jobs/core/storage/secure_storage_service.dart';
import 'package:scn_jobs/data/datasources/auth_remote_datasource.dart';
import 'package:scn_jobs/data/models/auth_response_model.dart';
import 'package:scn_jobs/data/models/user_model.dart';
import 'package:scn_jobs/data/repositories/auth_repository_impl.dart';
import 'package:scn_jobs/domain/entities/user.dart';

import 'auth_repository_impl_test.mocks.dart';

@GenerateMocks([AuthRemoteDataSource, SecureStorageService])
void main() {
  late MockAuthRemoteDataSource mockRemoteDataSource;
  late MockSecureStorageService mockSecureStorageService;
  late AuthRepositoryImpl repository;

  setUp(() {
    mockRemoteDataSource = MockAuthRemoteDataSource();
    mockSecureStorageService = MockSecureStorageService();
    repository = AuthRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      secureStorageService: mockSecureStorageService,
    );
  });

  group('login', () {
    const userModel = UserModel(
      id: 'u1',
      email: 'worker@example.com',
      role: 'worker',
      phone: '9876543210',
      phoneVerified: true,
    );
    const authResponse = AuthResponseModel(token: 'jwt-token', user: userModel);

    test('maps AuthResponseModel to AuthSession and persists token', () async {
      when(
        mockRemoteDataSource.login(
          email: anyNamed('email'),
          password: anyNamed('password'),
        ),
      ).thenAnswer((_) async => authResponse);
      when(mockSecureStorageService.saveAccessToken(any))
          .thenAnswer((_) async {});

      final session = await repository.login(
        email: 'worker@example.com',
        password: 'secret123',
      );

      expect(session.token, 'jwt-token');
      expect(session.user.id, 'u1');
      expect(session.user.role, UserRole.worker);
      verify(mockSecureStorageService.saveAccessToken('jwt-token')).called(1);
    });
  });

  group('currentUser', () {
    test('returns null when no session exists', () async {
      when(mockSecureStorageService.hasSession).thenAnswer((_) async => false);

      final user = await repository.currentUser();

      expect(user, isNull);
      verifyNever(mockRemoteDataSource.me());
    });

    test('fetches and maps /me when a session exists', () async {
      when(mockSecureStorageService.hasSession).thenAnswer((_) async => true);
      when(mockRemoteDataSource.me()).thenAnswer(
        (_) async => {
          'id': 'u2',
          'email': 'recruiter@example.com',
          'role': 'recruiter',
          'isActive': true,
        },
      );

      final user = await repository.currentUser();

      expect(user, isNotNull);
      expect(user!.id, 'u2');
      expect(user.role, UserRole.recruiter);
    });
  });

  group('logout', () {
    test('calls remote logout and clears local session', () async {
      when(mockRemoteDataSource.logout()).thenAnswer((_) async {});
      when(mockSecureStorageService.clearSession()).thenAnswer((_) async {});

      await repository.logout();

      verify(mockRemoteDataSource.logout()).called(1);
      verify(mockSecureStorageService.clearSession()).called(1);
    });
  });
}
