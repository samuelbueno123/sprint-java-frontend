typedef SseEventCallback = void Function(String eventName, String rawData);
typedef SseVoidCallback = void Function();
typedef SseErrorCallback = void Function(Object error);

/// Handle for an active browser SSE connection (unused on VM/desktop).
abstract class NativeSseConnection {
  void close();
}

bool get supportsNativeEventSource => false;

NativeSseConnection? openNativeEventSource({
  required String url,
  required List<String> eventNames,
  required SseVoidCallback onOpen,
  required SseEventCallback onEvent,
  required SseErrorCallback onError,
}) {
  return null;
}
