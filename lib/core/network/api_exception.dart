import 'package:dio/dio.dart';

/// Exceção padronizada para falhas de comunicação com o backend Duolinfo.
/// Converte respostas de erro estruturadas (ApiErrorResponse) e falhas de rede
/// em mensagens claras para exibição ao usuário.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.error,
    this.path,
    this.correlationId,
    this.validationErrors,
    this.isNetworkError = false,
    this.isTimeout = false,
  });

  final String message;
  final int? statusCode;
  final String? error;
  final String? path;
  final String? correlationId;
  final Map<String, String>? validationErrors;
  final bool isNetworkError;
  final bool isTimeout;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isServerError => (statusCode ?? 0) >= 500;

  /// Retorna o erro específico de um campo de formulário, se houver
  String? fieldError(String fieldName) => validationErrors?[fieldName];

  factory ApiException.fromDioException(DioException dioException) {
    final response = dioException.response;
    final statusCode = response?.statusCode;

    // 1. Falhas de conexão física ou timeout
    if (dioException.type == DioExceptionType.connectionTimeout ||
        dioException.type == DioExceptionType.sendTimeout ||
        dioException.type == DioExceptionType.receiveTimeout) {
      return ApiException(
        message:
            'O servidor demorou muito para responder. Verifique sua conexão e tente novamente.',
        statusCode: statusCode,
        isTimeout: true,
      );
    }

    if (dioException.type == DioExceptionType.connectionError) {
      return ApiException(
        message:
            'Não foi possível conectar ao servidor do Duolinfo. Verifique sua conexão com a internet.',
        statusCode: statusCode,
        isNetworkError: true,
      );
    }

    // 2. Resposta estruturada retornada pelo backend (ApiErrorResponse)
    final data = response?.data;
    if (data is Map<String, dynamic>) {
      final backendMessage = data['message'] as String?;
      final backendError = data['error'] as String?;
      final backendPath = data['path'] as String?;
      final correlationId =
          (data['correlationId'] ?? response?.headers.value('x-correlation-id'))
              as String?;

      Map<String, String>? validationErrors;
      final rawValidation = data['validationErrors'];
      if (rawValidation is Map) {
        validationErrors = rawValidation.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }

      if (backendMessage != null && backendMessage.trim().isNotEmpty) {
        return ApiException(
          message: backendMessage.trim(),
          statusCode: statusCode,
          error: backendError,
          path: backendPath,
          correlationId: correlationId,
          validationErrors: validationErrors,
        );
      }
    }

    // 3. Fallbacks elegantes baseados em códigos de status HTTP
    final fallbackMessage = switch (statusCode) {
      400 => 'Requisição inválida. Verifique os dados informados.',
      401 => 'Sessão expirada ou não autenticada. Faça login novamente.',
      403 => 'Acesso negado. Seu perfil não possui permissão para esta ação.',
      404 => 'O recurso solicitado não foi encontrado.',
      409 =>
        'Conflito de dados. O registro já existe ou foi modificado concorrentemente.',
      413 => 'Arquivo muito grande. O limite máximo permitido foi excedido.',
      429 => 'Muitas requisições em curto período. Aguarde alguns instantes.',
      500 => 'Erro interno no servidor. Nossos engenheiros foram notificados.',
      502 || 503 || 504 =>
        'Serviço temporariamente indisponível. Tente novamente em instantes.',
      _ => 'Ocorreu um erro inesperado ao comunicar com o servidor.',
    };

    return ApiException(
      message: fallbackMessage,
      statusCode: statusCode,
      correlationId: response?.headers.value('x-correlation-id'),
    );
  }

  @override
  String toString() {
    if (correlationId != null &&
        correlationId!.isNotEmpty &&
        correlationId != 'N/A') {
      return '$message (ID: $correlationId)';
    }
    return message;
  }
}
