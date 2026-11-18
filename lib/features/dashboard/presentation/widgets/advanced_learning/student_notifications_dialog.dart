import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:frontend/core/constants/app_feedback_widgets.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/realtime_sync_service.dart';
import 'package:frontend/core/ui/mascot/mascot.dart';

class StudentNotificationsDialog extends StatefulWidget {
  const StudentNotificationsDialog({
    super.key,
    this.onUpdated,
    this.endpointPrefix = '/api/students/me/notifications',
    this.dio,
    this.onNavigateAction,
  });

  final VoidCallback? onUpdated;
  final String endpointPrefix;
  final Dio? dio;
  final void Function(String? actionUrl, String? type)? onNavigateAction;

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onUpdated,
    Dio? dio,
    void Function(String? actionUrl, String? type)? onNavigateAction,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => StudentNotificationsDialog(
        onUpdated: onUpdated,
        dio: dio,
        onNavigateAction: onNavigateAction,
      ),
    );
  }

  static Future<void> showForTeacher(
    BuildContext context, {
    VoidCallback? onUpdated,
    Dio? dio,
    void Function(String? actionUrl, String? type)? onNavigateAction,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => StudentNotificationsDialog(
        endpointPrefix: '/api/teachers/me/notifications',
        onUpdated: onUpdated,
        dio: dio,
        onNavigateAction: onNavigateAction,
      ),
    );
  }

  @override
  State<StudentNotificationsDialog> createState() =>
      _StudentNotificationsDialogState();
}

class _StudentNotificationsDialogState
    extends State<StudentNotificationsDialog> {
  late final Dio _dio = widget.dio ?? ApiClient().dio;
  late Future<void> _loadFuture;
  StreamSubscription<RealtimeSyncEvent>? _realtimeSub;

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _fetchNotifications();
    _realtimeSub = RealtimeSyncService.instance.events.listen((event) {
      if (!mounted) return;
      switch (event.type) {
        case 'NOTIFICATION_ADDED':
        case 'NOTIFICATION_UPDATED':
        case 'CLASS_ANNOUNCEMENT':
        case 'TEACHER_NOTE_ADDED':
        case 'CLASS_INVITED':
        case 'EXERCISE_CREATED':
        case 'EXERCISE_SUBMITTED':
        case 'SUBMISSION_GRADED':
          _fetchNotifications();
          break;
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    try {
      final res = await _dio.get(widget.endpointPrefix);
      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(res.data ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar notificações: $e')),
        );
      }
    }
  }

  Future<void> _markAsRead(int id) async {
    try {
      await _dio.patch('${widget.endpointPrefix}/$id/read');
      if (mounted) {
        setState(() {
          final idx = _notifications.indexWhere((n) => n['id'] == id);
          if (idx != -1) {
            _notifications[idx]['read'] = true;
          }
        });
        widget.onUpdated?.call();
      }
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    setState(() => _isLoading = true);
    try {
      await _dio.post('${widget.endpointPrefix}/read-all');
      if (mounted) {
        setState(() {
          for (final n in _notifications) {
            n['read'] = true;
          }
        });
        widget.onUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao marcar como lidas: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getIconForType(String? type) {
    switch (type?.toUpperCase()) {
      case 'CORRECTION_PENDING':
        return Icons.fact_check_rounded;
      case 'ANNOUNCEMENT':
        return Icons.campaign_rounded;
      case 'TEACHER_NOTE':
        return Icons.sticky_note_2_rounded;
      case 'CLASS_INVITE':
        return Icons.group_add_rounded;
      case 'NEW_EXERCISE':
        return Icons.assignment_rounded;
      case 'EXERCISE_GRADED':
        return Icons.grading_rounded;
      case 'DEADLINE':
        return Icons.alarm_rounded;
      case 'STREAK':
        return Icons.local_fire_department_rounded;
      case 'ACHIEVEMENT':
        return Icons.emoji_events_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String? type) {
    switch (type?.toUpperCase()) {
      case 'CORRECTION_PENDING':
        return const Color(0xFFD97706);
      case 'ANNOUNCEMENT':
        return Colors.deepPurple;
      case 'TEACHER_NOTE':
        return const Color(0xFF7651C8);
      case 'CLASS_INVITE':
        return const Color(0xFF10B981);
      case 'NEW_EXERCISE':
        return const Color(0xFF2563EB);
      case 'EXERCISE_GRADED':
        return const Color(0xFF059669);
      case 'DEADLINE':
        return Colors.redAccent;
      case 'STREAK':
        return Colors.orange;
      case 'ACHIEVEMENT':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF3579E8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(
            Icons.notifications_active_rounded,
            color: Color(0xFF3579E8),
          ),
          const SizedBox(width: 8),
          const Text('Central de Notificações'),
          const Spacer(),
          if (_notifications.any((n) => n['read'] == false))
            TextButton.icon(
              icon: const Icon(Icons.done_all_rounded, size: 16),
              label: const Text(
                'Marcar todas como lidas',
                style: TextStyle(fontSize: 12),
              ),
              onPressed: _isLoading ? null : _markAllAsRead,
            ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 480,
        child: FutureBuilder(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoader(message: 'Buscando suas notificações...');
            }

            if (_notifications.isEmpty) {
              return const MascotEmptyIllustration(
                state: MascotState.idle,
                title: 'Tudo em dia!',
                message:
                    'Você não possui nenhuma notificação pendente no momento.',
                size: 84,
              );
            }

            return ListView.separated(
              itemCount: _notifications.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = _notifications[index];
                final isRead = n['read'] == true;
                final type = n['type'] as String? ?? 'GENERAL';
                final color = _getColorForType(type);
                final icon = _getIconForType(type);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  onTap: () {
                    if (!isRead && n['id'] is num) {
                      _markAsRead((n['id'] as num).toInt());
                    }
                    final actionUrl = n['actionUrl']?.toString();
                    if (widget.onNavigateAction != null &&
                        (actionUrl != null || type == 'CORRECTION_PENDING')) {
                      final navigator = Navigator.of(context);
                      if (navigator.canPop()) {
                        navigator.pop();
                      }
                      widget.onNavigateAction!(actionUrl, type);
                    }
                  },
                  tileColor: isRead
                      ? null
                      : color.withValues(alpha: isDark ? 0.15 : 0.06),
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  title: Text(
                    n['title'] ?? '',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      n['message'] ?? '',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  trailing: !isRead && n['id'] is num
                      ? IconButton(
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                          ),
                          tooltip: 'Marcar como lida',
                          onPressed: () =>
                              _markAsRead((n['id'] as num).toInt()),
                        )
                      : null,
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
