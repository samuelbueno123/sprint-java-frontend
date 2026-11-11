import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionStore.clear();
  });

  tearDown(() async {
    await SessionStore.clear();
  });

  group('SessionStore', () {
    test('initializes with no active session when storage is empty', () async {
      await SessionStore.initialize();
      expect(SessionStore.hasSession, isFalse);
      expect(SessionStore.accessToken, isNull);
    });

    test('initializes with active session from stored preferences', () async {
      SharedPreferences.setMockInitialValues({
        'session.active': true,
        'session.accessToken': 'stored-access-token',
        'session.refreshToken': 'stored-refresh-token',
      });

      await SessionStore.initialize();
      expect(SessionStore.hasSession, isTrue);
      expect(SessionStore.accessToken, equals('stored-access-token'));
    });

    test('setSession persists tokens and updates in-memory state', () async {
      await SessionStore.setSession(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      );

      expect(SessionStore.hasSession, isTrue);
      expect(SessionStore.accessToken, equals('access-123'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('session.active'), isTrue);
      expect(prefs.getString('session.accessToken'), equals('access-123'));
      expect(prefs.getString('session.refreshToken'), equals('refresh-456'));
    });

    test('clear removes all session keys and resets memory state', () async {
      await SessionStore.setSession(
        accessToken: 'access-abc',
        refreshToken: 'refresh-xyz',
      );

      expect(SessionStore.hasSession, isTrue);

      await SessionStore.clear();

      expect(SessionStore.hasSession, isFalse);
      expect(SessionStore.accessToken, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('session.active'), isNull);
      expect(prefs.getString('session.accessToken'), isNull);
      expect(prefs.getString('session.refreshToken'), isNull);
    });

    test('setSession with empty tokens clears active state', () async {
      await SessionStore.setSession(accessToken: '', refreshToken: '');
      expect(SessionStore.hasSession, isFalse);
      expect(SessionStore.accessToken, isNull);
    });
  });
}
