import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scn_jobs/core/storage/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final fakeBackingStore = <String, String>{};

  setUp(() {
    fakeBackingStore.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'write':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          fakeBackingStore[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          return fakeBackingStore[args['key'] as String];
        case 'delete':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          fakeBackingStore.remove(args['key'] as String);
          return null;
        case 'deleteAll':
          fakeBackingStore.clear();
          return null;
        case 'readAll':
          return fakeBackingStore;
        case 'containsKey':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          return fakeBackingStore.containsKey(args['key'] as String);
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('SecureStorageService', () {
    test('saves and reads back an access token', () async {
      final service = SecureStorageService();

      expect(await service.getAccessToken(), isNull);

      await service.saveAccessToken('sample-jwt-value');
      final result = await service.getAccessToken();

      expect(result, 'sample-jwt-value');
    });

    test(
        'saves and reads back a refresh token independently of the access token',
        () async {
      final service = SecureStorageService();

      await service.saveAccessToken('access-123');
      await service.saveRefreshToken('refresh-456');

      expect(await service.getAccessToken(), 'access-123');
      expect(await service.getRefreshToken(), 'refresh-456');
    });

    test('hasSession is false before login and true after saving a token',
        () async {
      final service = SecureStorageService();

      expect(await service.hasSession, isFalse);

      await service.saveAccessToken('sample-jwt-value');

      expect(await service.hasSession, isTrue);
    });

    test('clearSession removes both tokens', () async {
      final service = SecureStorageService();
      await service.saveAccessToken('access-123');
      await service.saveRefreshToken('refresh-456');

      await service.clearSession();

      expect(await service.getAccessToken(), isNull);
      expect(await service.getRefreshToken(), isNull);
      expect(await service.hasSession, isFalse);
    });
  });
}

// WHY THIS FILE
// Verifies the write→read→clear contract SecureStorageService promises,
// against a fake in-memory backing store behind the same platform
// channel the real plugin uses — so the test exercises the actual
// serialization path (MethodChannel arguments) without needing a real
// Android Keystore, which isn't available in the `flutter test` VM.
// Alternative considered: mocking `FlutterSecureStorage` itself with
// Mockito. Rejected — Mockito can't easily fake a `const` constructor
// default, and channel-mocking here matches how Flutter's own plugin
// test guides recommend testing platform-channel-backed plugins.
// Pitfall a junior would hit: forgetting `tearDown` to clear the mock
// handler — leftover handlers leak between test files run in the same
// process and cause unrelated tests to see stale channel responses.
