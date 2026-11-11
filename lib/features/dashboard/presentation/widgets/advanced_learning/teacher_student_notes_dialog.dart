import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:frontend/core/network/api_client.dart';

class TeacherStudentNotesDialog extends StatefulWidget {
  const TeacherStudentNotesDialog({
    super.key,
    required this.studentId,
    required this.studentName,
    this.classId,
  });

  final int studentId;
  final String studentName;
  final int? classId;

  static Future<void> show(
    BuildContext context, {
    required int studentId,
    required String studentName,
    int? classId,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => TeacherStudentNotesDialog(
        studentId: studentId,
        studentName: studentName,
        classId: classId,
      ),
    );
  }

  @override
  State<TeacherStudentNotesDialog> createState() =>
      _TeacherStudentNotesDialogState();
}

class _TeacherStudentNotesDialogState extends State<TeacherStudentNotesDialog> {
  final Dio _dio = ApiClient().dio;
  late Future<void> _loadFuture;

  List<Map<String, dynamic>> _notes = [];
  final TextEditingController _noteCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _fetchNotes();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchNotes() async {
    try {
      final res = await _dio.get(
        '/api/teachers/me/notes',
        queryParameters: {'studentId': widget.studentId},
      );
      if (mounted) {
        setState(() {
          _notes = List<Map<String, dynamic>>.from(res.data ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar anotações: $e')),
        );
      }
    }
  }

  Future<void> _addNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _dio.post(
        '/api/teachers/me/notes',
        data: {
          'studentId': widget.studentId,
          'schoolClassId': widget.classId,
          'note': text,
        },
      );
      _noteCtrl.clear();
      _fetchNotes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar anotação: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteNote(int id) async {
    try {
      await _dio.delete('/api/teachers/me/notes/$id');
      _fetchNotes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao excluir anotação: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.sticky_note_2_rounded, color: Color(0xFF7651C8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Anotações Privadas: ${widget.studentName}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 480,
        child: Column(
          children: [
            // Note composer
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'Escreva uma anotação pedagógica confidencial (ex: dificuldades com preposições, ritmo de fala)...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7651C8),
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 16,
                    ),
                  ),
                  onPressed: _isSaving ? null : _addNote,
                  child: const Text('Salvar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),

            // Notes list
            Expanded(
              child: FutureBuilder(
                future: _loadFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (_notes.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhuma anotação registrada ainda para este estudante.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final n = _notes[index];
                      final noteText = n['note'] as String? ?? '';
                      final createdAt = n['createdAt'] as String? ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    createdAt.length > 10
                                        ? createdAt.substring(0, 10)
                                        : createdAt,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    tooltip: 'Excluir anotação',
                                    onPressed: () =>
                                        _deleteNote(n['id'] as int),
                                  ),
                                ],
                              ),
                              Text(
                                noteText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
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
