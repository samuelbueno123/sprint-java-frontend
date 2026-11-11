import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:frontend/core/network/api_client.dart';

class StudentNotificationsDialog extends StatefulWidget {
  const StudentNotificationsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const StudentNotificationsDialog(),
    );
  }

  @override
  State<StudentNotificationsDialog> createState() =>
      _StudentNotificationsDialogState();
}

class _StudentNotificationsDialogState
    extends State<StudentNotificationsDialog> {
  final Dio _dio = ApiClient().dio;
  late Future<void> _loadFuture;

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final res = await _dio.get('/api/students/me/notifications');
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
      await _dio.patch('/api/students/me/notifications/$id/read');
      if (mounted) {
        setState(() {
          final idx = _notifications.indexWhere((n) => n['id'] == id);
          if (idx != -1) {
            _notifications[idx]['read'] = true;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    setState(() => _isLoading = true);
    try {
      await _dio.post('/api/students/me/notifications/read-all');
      if (mounted) {
        setState(() {
          for (final n in _notifications) {
            n['read'] = true;
          }
        });
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
      case 'ANNOUNCEMENT':
        return Icons.campaign_rounded;
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
      case 'ANNOUNCEMENT':
        return Colors.deepPurple;
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
              return const Center(child: CircularProgressIndicator());
            }

            if (_notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 56,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tudo em dia!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Você não possui nenhuma notificação pendente no momento.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
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
                  trailing: !isRead
                      ? IconButton(
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                          ),
                          tooltip: 'Marcar como lida',
                          onPressed: () => _markAsRead(n['id'] as int),
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
