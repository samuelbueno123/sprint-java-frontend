import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:frontend/core/network/api_client.dart';

class ClassAnnouncementsView extends StatefulWidget {
  const ClassAnnouncementsView({
    super.key,
    required this.classId,
    required this.className,
    required this.isTeacher,
  });

  final int classId;
  final String className;
  final bool isTeacher;

  static Future<void> show(
    BuildContext context, {
    required int classId,
    required String className,
    required bool isTeacher,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: ClassAnnouncementsView(
          classId: classId,
          className: className,
          isTeacher: isTeacher,
        ),
      ),
    );
  }

  @override
  State<ClassAnnouncementsView> createState() => _ClassAnnouncementsViewState();
}

class _ClassAnnouncementsViewState extends State<ClassAnnouncementsView> {
  final Dio _dio = ApiClient().dio;
  late Future<void> _loadFuture;

  List<Map<String, dynamic>> _announcements = [];
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    try {
      final res = await _dio.get(
        '/api/classes/${widget.classId}/announcements',
      );
      if (mounted) {
        setState(() {
          _announcements = List<Map<String, dynamic>>.from(res.data ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar comunicados da turma: $e')),
        );
      }
    }
  }

  Future<void> _showNewAnnouncementDialog() async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String priority = 'NORMAL';
    bool pinned = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Novo Comunicado para a Turma'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título do Aviso',
                    hintText: 'Ex: Data da Prova Semestral',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mensagem / Instruções',
                    hintText: 'Digite o conteúdo detalhado do aviso...',
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Prioridade'),
                  items: const [
                    DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                    DropdownMenuItem(
                      value: 'HIGH',
                      child: Text('Alta (Destaque Vermelho)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => priority = val);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fixar no topo do mural'),
                  value: pinned,
                  onChanged: (val) => setDialogState(() => pinned = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Publicar'),
            ),
          ],
        ),
      ),
    );

    if (result == true &&
        titleCtrl.text.trim().isNotEmpty &&
        contentCtrl.text.trim().isNotEmpty) {
      setState(() => _isPublishing = true);
      try {
        await _dio.post(
          '/api/classes/${widget.classId}/announcements',
          data: {
            'title': titleCtrl.text.trim(),
            'content': contentCtrl.text.trim(),
            'priority': priority,
            'pinned': pinned,
          },
        );
        _fetchAnnouncements();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Comunicado publicado com notificação para todos os estudantes!',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao publicar comunicado: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isPublishing = false);
      }
    }
  }

  Future<void> _deleteAnnouncement(int id) async {
    try {
      await _dio.delete('/api/classes/announcements/$id');
      _fetchAnnouncements();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir comunicado: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Mural de Avisos: ${widget.className}'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: widget.isTeacher
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('Novo Comunicado'),
              onPressed: _isPublishing ? null : _showNewAnnouncementDialog,
            )
          : null,
      body: FutureBuilder(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_announcements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhum comunicado publicado',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isTeacher
                        ? 'Clique em "Novo Comunicado" para enviar recados e avisos para a turma.'
                        : 'Avisos e prazos publicados pelo professor aparecerão aqui.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _announcements.length,
            itemBuilder: (context, index) {
              final a = _announcements[index];
              final isPinned = a['pinned'] == true;
              final priority = a['priority'] as String? ?? 'NORMAL';
              final isHigh = priority.toUpperCase() == 'HIGH';
              final title = a['title'] as String? ?? '';
              final content = a['content'] as String? ?? '';
              final teacherName = a['teacherName'] as String? ?? 'Professor';
              final createdAt = a['createdAt'] as String? ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isHigh
                        ? Colors.redAccent
                        : (isPinned
                              ? const Color(0xFF7651C8)
                              : theme.colorScheme.outlineVariant),
                    width: isPinned || isHigh ? 1.5 : 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isPinned) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF7651C8,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.push_pin_rounded,
                                    size: 14,
                                    color: Color(0xFF7651C8),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Fixado',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7651C8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (isHigh) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'URGENTE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            'Por $teacherName • ${createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const Spacer(),
                          if (widget.isTeacher)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                              ),
                              tooltip: 'Excluir comunicado',
                              onPressed: () =>
                                  _deleteAnnouncement(a['id'] as int),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        content,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
