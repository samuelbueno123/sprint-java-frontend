import 'dart:js_interop';

import 'package:web/web.dart' as web;

typedef SseEventCallback = void Function(String eventName, String rawData);
typedef SseVoidCallback = void Function();
typedef SseErrorCallback = void Function(Object error);

abstract class NativeSseConnection {
  void close();
}

bool get supportsNativeEventSource => true;

class _BrowserEventSourceConnection implements NativeSseConnection {
  _BrowserEventSourceConnection(this._eventSource);

  final web.EventSource _eventSource;
  bool _closed = false;

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _eventSource.close();
  }
}

NativeSseConnection? openNativeEventSource({
  required String url,
  required List<String> eventNames,
  required SseVoidCallback onOpen,
  required SseEventCallback onEvent,
  required SseErrorCallback onError,
}) {
  final source = web.EventSource(url, web.EventSourceInit(withCredentials: true));
  final connection = _BrowserEventSourceConnection(source);

  source.onopen = ((web.Event _) {
    onOpen();
  }).toJS;

  void dispatchMessage(String name, web.MessageEvent event) {
    final data = event.data;
    final raw = data != null && data.isA<JSString>()
        ? (data as JSString).toDart
        : (data?.dartify()?.toString() ?? '');
    if (raw.isNotEmpty) {
      onEvent(name, raw);
    }
  }

  source.onmessage = ((web.MessageEvent event) {
    dispatchMessage('MESSAGE', event);
  }).toJS;

  for (final name in eventNames) {
    source.addEventListener(
      name,
      ((web.Event rawEvent) {
        if (rawEvent.isA<web.MessageEvent>()) {
          dispatchMessage(name, rawEvent as web.MessageEvent);
        }
      }).toJS,
    );
  }

  source.onerror = ((web.Event _) {
    connection.close();
    onError(StateError('EventSource connection closed or errored'));
  }).toJS;

  return connection;
}
