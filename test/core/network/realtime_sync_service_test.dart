import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/realtime_sync_service.dart';

void main() {
  group('RealtimeSyncEvent', () {
    test('parses correctly from json', () {
      final json = {
        'type': 'EXERCISE_CREATED',
        'timestamp': 1700000000000,
        'data': {'exerciseId': 42, 'title': 'Gramática Inglesa'},
      };

      final event = RealtimeSyncEvent.fromJson(json);

      expect(event.type, 'EXERCISE_CREATED');
      expect(event.timestamp, 1700000000000);
      expect(event.data['exerciseId'], 42);
      expect(event.data['title'], 'Gramática Inglesa');
    });

    test('handles missing or null fields gracefully with fallbacks', () {
      final json = <String, dynamic>{};
      final event = RealtimeSyncEvent.fromJson(json);

      expect(event.type, 'UNKNOWN');
      expect(event.timestamp, isPositive);
      expect(event.data, isEmpty);
    });
  });

  group('RealtimeSyncService', () {
    test('instance is non-null and starts disconnected', () {
      final service = RealtimeSyncService.instance;
      expect(service, isNotNull);
      expect(service.isConnected, isFalse);
    });

    test('disconnect can be called safely without error', () {
      final service = RealtimeSyncService.instance;
      expect(() => service.disconnect(), returnsNormally);
    });
  });
}
