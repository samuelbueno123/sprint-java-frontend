import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'session_store.dart';
import 'sse_stream_stub.dart'
    if (dart.library.js_interop) 'sse_stream_web.dart';

/// Evento recebido via Server-Sent Events (SSE) notificando que dados mudaram no banco de dados.
class RealtimeSyncEvent {
  const RealtimeSyncEvent({
    required this.type,
    required this.timestamp,
    required this.data,
  });

  final String type;
  final int timestamp;
  final Map<String, dynamic> data;

  factory RealtimeSyncEvent.fromJson(Map<String, dynamic> json) {
    return RealtimeSyncEvent(
      type: json['type'] as String? ?? 'UNKNOWN',
      timestamp:
          (json['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      data: (json['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  @override
  String toString() => 'RealtimeSyncEvent(type: $type, data: $data)';
}

/// Serviço cliente para sincronização reativa em tempo real com o backend (via SSE).
/// Mantém a interface sempre atualizada com as alterações ocorridas no banco de dados.
class RealtimeSyncService {
  RealtimeSyncService._();

  static final RealtimeSyncService instance = RealtimeSyncService._();

  final _eventsController = StreamController<RealtimeSyncEvent>.broadcast();
  Stream<RealtimeSyncEvent> get events => _eventsController.stream;

  static const List<String> _knownEventNames = [
    'CONNECTED',
    'NOTIFICATION_ADDED',
    'NOTIFICATION_UPDATED',
    'CLASS_ANNOUNCEMENT',
    'TEACHER_NOTE_ADDED',
    'CLASS_INVITED',
    'EXERCISE_CREATED',
    'EXERCISE_SUBMITTED',
    'SUBMISSION_GRADED',
    'RANKING_UPDATED',
    'PROFILE_UPDATED',
    'ENROLLMENT_UPDATED',
    'INSTITUTION_REQUEST_DECIDED',
    'SRS_REVIEW_COMPLETED',
    'USER_UPDATED',
    'DATA_UPDATED',
  ];

  Dio? _dio;
  CancelToken? _cancelToken;
  NativeSseConnection? _nativeConnection;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _refreshedAfterUnauthorized = false;

  bool get isConnected => _isConnected;

  @visibleForTesting
  void emitEventForTest(RealtimeSyncEvent event) {
    _eventsController.add(event);
  }

  void connect() {
    if (_isConnected || _isConnecting) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectInternal();
  }

  Future<void> _connectInternal() async {
    final token = SessionStore.accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('[Realtime] Sem token ativo. Conexão SSE adiada.');
      return;
    }

    _isConnecting = true;
    final uri = Uri.parse(
      AppConfig.apiBaseUrl,
    ).resolve('/api/realtime/stream');
    final sseUrl = uri.replace(queryParameters: {'token': token}).toString();

    if (supportsNativeEventSource) {
      _nativeConnection?.close();
      _nativeConnection = openNativeEventSource(
        url: sseUrl,
        eventNames: _knownEventNames,
        onOpen: () {
          _isConnected = true;
          _isConnecting = false;
          _reconnectAttempts = 0;
          _refreshedAfterUnauthorized = false;
          debugPrint('[Realtime] EventSource web conectado em tempo real.');
        },
        onEvent: (eventName, rawData) {
          _isConnected = true;
          _isConnecting = false;
          _reconnectAttempts = 0;
          _dispatchRaw(eventName, rawData);
        },
        onError: (err) async {
          _nativeConnection = null;
          _isConnected = false;
          _isConnecting = false;
          if (!_refreshedAfterUnauthorized) {
            _refreshedAfterUnauthorized = true;
            await SessionStore.refreshAccessToken();
          }
          _scheduleReconnect();
        },
      );
      if (_nativeConnection != null) {
        return;
      }
    }

    _cancelToken = CancelToken();

    try {
      debugPrint('[Realtime] Conectando ao canal SSE: $uri');

      _dio ??= Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 35),
          headers: {'Accept': 'text/event-stream', 'Cache-Control': 'no-cache'},
        ),
      );

      final response = await _dio!.get<ResponseBody>(
        sseUrl,
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _refreshedAfterUnauthorized = false;
      debugPrint('[Realtime] Conexão SSE estabelecida com sucesso.');

      String currentEvent = 'MESSAGE';
      final buffer = StringBuffer();

      final stream = response.data?.stream;
      if (stream != null) {
        final lines = stream
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter());
        await for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) {
            if (buffer.isNotEmpty) {
              _dispatchRaw(currentEvent, buffer.toString());
              buffer.clear();
              currentEvent = 'MESSAGE';
            }
            continue;
          }

          if (trimmed.startsWith(':')) {
            // Comentário de keep-alive ping do servidor
            continue;
          }

          if (trimmed.startsWith('event:')) {
            currentEvent = trimmed.substring(6).trim();
          } else if (trimmed.startsWith('data:')) {
            final dataPart = trimmed.substring(5).trim();
            if (buffer.isNotEmpty) buffer.write('\n');
            buffer.write(dataPart);
          }
        }
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if ((status == 401 || status == 403) && !_refreshedAfterUnauthorized) {
        _refreshedAfterUnauthorized = true;
        final nextToken = await SessionStore.refreshAccessToken();
        if (nextToken != null && nextToken.isNotEmpty) {
          debugPrint('[Realtime] Token renovado após $status SSE.');
        }
      } else {
        debugPrint('[Realtime] Conexão SSE finalizada ou com erro: $e');
      }
    } catch (e) {
      debugPrint('[Realtime] Conexão SSE finalizada ou com erro: $e');
    } finally {
      _isConnected = false;
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _dispatchRaw(String eventName, String rawData) {
    try {
      final decoded = jsonDecode(rawData);
      if (decoded is Map<String, dynamic>) {
        final effective = Map<String, dynamic>.from(decoded);
        effective['type'] ??= eventName;
        final event = RealtimeSyncEvent.fromJson(effective);
        _eventsController.add(event);
        debugPrint('[Realtime] Evento recebido e disparado: ${event.type}');
      }
    } catch (e) {
      debugPrint(
        '[Realtime] Falha ao decodificar payload SSE: $e | Raw: $rawData',
      );
    }
  }

  void _scheduleReconnect() {
    if (!SessionStore.hasSession) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 2).clamp(2, 30);
    debugPrint(
      '[Realtime] Reconectando em $delaySeconds segundos (tentativa $_reconnectAttempts)...',
    );
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (SessionStore.hasSession) {
        _connectInternal();
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _nativeConnection?.close();
    _nativeConnection = null;
    _cancelToken?.cancel('Desconectado manualmente.');
    _cancelToken = null;
    _isConnected = false;
    _isConnecting = false;
  }
}
