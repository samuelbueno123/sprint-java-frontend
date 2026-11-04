import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'session_store.dart';

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
      timestamp: (json['timestamp'] as num?)?.toInt() ??
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

  Dio? _dio;
  CancelToken? _cancelToken;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  bool get isConnected => _isConnected;

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
    _cancelToken = CancelToken();

    try {
      final uri = Uri.parse(AppConfig.apiBaseUrl).resolve('/api/realtime/stream');
      final sseUrl = uri.replace(queryParameters: {'token': token}).toString();

      debugPrint('[Realtime] Conectando ao canal SSE: $sseUrl');

      _dio ??= Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 35),
          headers: {
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final response = await _dio!.get<ResponseBody>(
        sseUrl,
        cancelToken: _cancelToken,
        options: Options(responseType: ResponseType.stream),
      );

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      debugPrint('[Realtime] Conexão SSE estabelecida com sucesso.');

      String currentEvent = 'MESSAGE';
      final buffer = StringBuffer();

      final stream = response.data?.stream;
      if (stream != null) {
        await for (final chunk in stream.cast<List<int>>()) {
          final text = utf8.decode(chunk, allowMalformed: true);
          final lines = const LineSplitter().convert(text);

          for (final line in lines) {
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
        final event = RealtimeSyncEvent.fromJson(decoded);
        _eventsController.add(event);
        debugPrint('[Realtime] Evento recebido e disparado: ${event.type}');
      }
    } catch (e) {
      debugPrint('[Realtime] Falha ao decodificar payload SSE: $e | Raw: $rawData');
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
    _cancelToken?.cancel('Desconectado manualmente.');
    _cancelToken = null;
    _isConnected = false;
    _isConnecting = false;
  }
}
