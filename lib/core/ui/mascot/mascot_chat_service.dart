import 'package:dio/dio.dart';

import '../../network/api_client.dart';

class MascotChatMessage {
  const MascotChatMessage({
    required this.role,
    required this.content,
    this.inScope = true,
    this.suggestedAction,
    this.timestamp,
  });

  final String role; // 'user' | 'assistant'
  final String content;
  final bool inScope;
  final String? suggestedAction;
  final DateTime? timestamp;

  bool get isUser => role == 'user';
}

class MascotChatReply {
  const MascotChatReply({
    required this.reply,
    this.inScope = true,
    this.suggestedAction,
  });

  final String reply;
  final bool inScope;
  final String? suggestedAction;

  factory MascotChatReply.fromJson(Map<String, dynamic> json) {
    final rawAction = json['suggestedAction']?.toString().trim();
    return MascotChatReply(
      reply: (json['reply'] ?? '').toString().trim(),
      inScope: json['inScope'] is bool ? json['inScope'] as bool : true,
      suggestedAction: (rawAction == null || rawAction.isEmpty)
          ? null
          : rawAction,
    );
  }
}

class MascotChatService {
  MascotChatService({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  Future<MascotChatReply> sendMessage({
    required String message,
    String activeSection = 'home',
    String userRole = 'student',
    String currentLanguage = 'Inglês',
    List<MascotChatMessage> history = const [],
  }) async {
    final recent = history.length > 8
        ? history.sublist(history.length - 8)
        : history;
    final payload = <String, dynamic>{
      'message': message,
      'activeSection': activeSection,
      'userRole': userRole,
      'currentLanguage': currentLanguage,
      'history': recent
          .map((m) => <String, String>{'role': m.role, 'content': m.content})
          .toList(),
    };
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/ai/mascot/chat',
      data: payload,
    );
    return MascotChatReply.fromJson(response.data ?? const {});
  }
}
