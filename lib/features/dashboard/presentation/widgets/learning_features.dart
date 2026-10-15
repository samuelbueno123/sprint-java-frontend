import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/student_enrollment.dart';

String parseLearningError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      for (final key in ['message', 'error', 'detail']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value;
      }
    }
    return error.response?.statusCode == 401 ||
            error.response?.statusCode == 403
        ? 'Sua sessão expirou. Entre novamente.'
        : 'Não foi possível concluir a operação. Tente novamente.';
  }
  return 'Ocorreu um erro. Tente novamente.';
}

void showLearningError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(parseLearningError(error))));
}

class LessonExecutionPage extends StatefulWidget {
  const LessonExecutionPage({super.key});

  @override
  State<LessonExecutionPage> createState() => _LessonExecutionPageState();
}

class _Question {
  const _Question(
    this.prompt,
    this.answer,
    this.options, {
    this.wordOrder = false,
    this.input = false,
  });
  final String prompt;
  final String answer;
  final List<String> options;
  final bool wordOrder;
  final bool input;
}

class _LessonExecutionPageState extends State<LessonExecutionPage> {
  final _questions = const [
    _Question('Como se diz “good morning” em português?', 'bom dia', [
      'boa noite',
      'bom dia',
      'obrigado',
    ]),
    _Question('Monte: “I like apples”', 'I like apples', [
      'apples',
      'I',
      'like',
    ], wordOrder: true),
    _Question('Traduza: “thank you”', 'obrigado', [], input: true),
    _Question('Como se diz “please”?', 'por favor', [
      'com licença',
      'por favor',
      'até logo',
    ]),
    _Question('Monte: “she is a teacher”', 'she is a teacher', [
      'teacher',
      'she',
      'a',
      'is',
    ], wordOrder: true),
  ];
  int _index = 0, _hearts = 3, _xp = 0, _correct = 0;
  String? _selection;
  final _answerController = TextEditingController();
  bool _checked = false, _finished = false;
  List<String> _words = [];
  _Question get _question => _questions[_index];

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _submit() {
    final answer = _question.input
        ? _answerController.text.trim()
        : _question.wordOrder
        ? _words.join(' ')
        : (_selection ?? '');
    if (answer.isEmpty) return;
    final matches = answer.toLowerCase() == _question.answer.toLowerCase();
    setState(() {
      _checked = true;
      if (matches) {
        _correct++;
        _xp += 10;
      } else {
        _hearts--;
      }
    });
  }

  void _next() {
    if (_hearts == 0 || _index == _questions.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _selection = null;
      _words = [];
      _checked = false;
      _answerController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _completion();
    final q = _question;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      appBar: AppBar(
        title: const Text('Lição de inglês'),
        backgroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.red),
                const SizedBox(width: 6),
                Text('$_hearts'),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: (_index + 1) / _questions.length,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFF58CC02),
                ),
                const SizedBox(height: 12),
                Text(
                  'Questão ${_index + 1}/${_questions.length}',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 32),
                Text(
                  q.prompt,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                if (q.input)
                  TextField(
                    controller: _answerController,
                    enabled: !_checked,
                    decoration: const InputDecoration(
                      labelText: 'Sua tradução',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (q.wordOrder)
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final word in q.options)
                        ActionChip(
                          label: Text(word),
                          onPressed: _checked
                              ? null
                              : () => setState(() => _words.add(word)),
                        ),
                      if (_words.isNotEmpty)
                        OutlinedButton(
                          onPressed: _checked
                              ? null
                              : () => setState(() => _words.removeLast()),
                          child: const Text('Desfazer'),
                        ),
                    ],
                  ),
                if (q.wordOrder)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      _words.join('  '),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (!q.input && !q.wordOrder)
                  ...q.options.map(
                    (option) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton(
                        onPressed: _checked
                            ? null
                            : () => setState(() => _selection = option),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _selection == option
                              ? const Color(0xFFEAF2FF)
                              : Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                        child: Text(option),
                      ),
                    ),
                  ),
                const Spacer(),
                if (_checked)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          (_hearts == 0 ||
                              (_question.input
                                      ? _answerController.text
                                            .trim()
                                            .toLowerCase()
                                      : _question.wordOrder
                                      ? _words.join(' ').toLowerCase()
                                      : _selection?.toLowerCase()) !=
                                  _question.answer.toLowerCase())
                          ? const Color(0xFFFFE5E5)
                          : const Color(0xFFE5F8D7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      (_hearts == 0 ||
                              (_question.input
                                      ? _answerController.text
                                            .trim()
                                            .toLowerCase()
                                      : _question.wordOrder
                                      ? _words.join(' ').toLowerCase()
                                      : _selection?.toLowerCase()) !=
                                  _question.answer.toLowerCase())
                          ? 'Resposta correta: ${q.answer}'
                          : 'Excelente! +10 XP',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _checked ? _next : _submit,
                  child: Text(
                    _checked
                        ? (_hearts == 0 || _index == _questions.length - 1
                              ? 'Concluir'
                              : 'Continuar')
                        : 'Verificar',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _completion() => Scaffold(
    backgroundColor: const Color(0xFFF7F9FA),
    body: Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events,
                color: Color(0xFFFFC400),
                size: 72,
              ),
              const Text(
                'Lição concluída!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                '$_xp XP ganhos  •  Precisão ${(_correct * 100 ~/ _questions.length)}%',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class StudentLanguageManager extends StatefulWidget {
  const StudentLanguageManager({super.key, required this.data});
  final DashboardData data;
  @override
  State<StudentLanguageManager> createState() => _StudentLanguageManagerState();
}

class _StudentLanguageManagerState extends State<StudentLanguageManager> {
  final _name = TextEditingController();
  String _level = 'Iniciante';
  bool _busy = false;
  final _levels = const [
    'Iniciante',
    'Básico',
    'Intermediário',
    'Avançado',
    'Fluente',
  ];
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = widget.data.studentProfile;
    if (profile?.id == null || _name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final languages = [
        ...profile!.languages.map((v) {
          final parts = v.split(':');
          return {
            'languageName': parts.first.trim(),
            'level': parts.length > 1 ? parts.last.trim() : 'Iniciante',
            'score': 0,
          };
        }),
      ];
      final existing = languages.indexWhere(
        (v) =>
            (v['languageName'] as String).toLowerCase() ==
            _name.text.trim().toLowerCase(),
      );
      final item = {
        'languageName': _name.text.trim(),
        'level': _level,
        'score': 0,
      };
      if (existing >= 0) {
        languages[existing] = item;
      } else {
        languages.add(item);
      }
      await ApiClient().dio.put(
        '${AppConfig.studentsEndpoint}/${profile.id}',
        data: {
          'name': profile.name,
          'email': profile.email,
          'googleId': profile.googleId,
          'languages': languages,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showLearningError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    title: const Text('Adicionar ou editar idioma'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Idioma'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _level,
          decoration: const InputDecoration(labelText: 'Proficiência'),
          items: _levels
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => setState(() => _level = v ?? _level),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Salvando...' : 'Salvar'),
      ),
    ],
  );
}

class StudentClassesView extends StatelessWidget {
  const StudentClassesView({
    super.key,
    required this.data,
    required this.onRefresh,
  });
  final DashboardData data;
  final VoidCallback onRefresh;

  Future<void> _requestEnrollment(BuildContext context) async {
    final studentId = data.studentProfile?.id;
    if (studentId == null) return;
    final search = TextEditingController();
    try {
      final results = await Future.wait([
        ApiClient().dio.get<List<dynamic>>(
          '${AppConfig.apiBaseUrl}/api/classes',
        ),
        ApiClient().dio.get<List<dynamic>>(
          '${AppConfig.apiBaseUrl}/api/schools',
        ),
      ]);
      final classes = results[0];
      final schools = (results[1].data ?? [])
          .whereType<Map>()
          .fold<Map<int, String>>({}, (map, school) {
            final id = (school['id'] as num?)?.toInt();
            if (id != null) map[id] = '${school['name'] ?? 'Escola'}';
            return map;
          });
      if (!context.mounted) return;
      final rows = (classes.data ?? [])
          .whereType<Map>()
          .where((c) => c['active'] != false)
          .toList();
      final selected = await showDialog<Map?>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text('Solicitar matrícula'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: search,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por escola, turma ou ano',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 300,
                    child: ListView(
                      children: rows
                          .where(
                            (c) =>
                                '${c['name']} ${schools[(c['schoolId'] as num?)?.toInt()] ?? ''} ${c['schoolYear']}'
                                    .toLowerCase()
                                    .contains(search.text.toLowerCase()),
                          )
                          .map(
                            (c) => ListTile(
                              title: Text('${c['name'] ?? 'Turma'}'),
                              subtitle: Text(
                                '${schools[(c['schoolId'] as num?)?.toInt()] ?? 'Escola'} • ${c['schoolYear'] ?? ''} • ${c['shift'] ?? ''} • ${c['gradeLevel'] ?? ''}',
                              ),
                              onTap: () => Navigator.pop(ctx, c),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      );
      if (selected == null || !context.mounted) return;
      await ApiClient().dio.post(
        '${AppConfig.apiBaseUrl}/api/enrollments',
        data: {
          'studentId': studentId,
          'schoolClassId': selected['id'],
          'enrollmentDate': DateTime.now().toIso8601String().substring(0, 10),
        },
      );
      onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação de matrícula enviada.')),
      );
    } catch (e) {
      if (context.mounted) showLearningError(context, e);
    } finally {
      search.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Minhas turmas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _requestEnrollment(context),
            icon: const Icon(Icons.add),
            label: const Text('Solicitar matrícula'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (data.studentEnrollments.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Você ainda não possui turmas ativas.'),
          ),
        ),
      ...data.studentEnrollments.map(
        (e) => _EnrollmentCard(enrollment: e, onRefresh: onRefresh),
      ),
    ],
  );
}

class _EnrollmentCard extends StatelessWidget {
  const _EnrollmentCard({required this.enrollment, required this.onRefresh});
  final StudentEnrollment enrollment;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.groups)),
      title: Text(enrollment.schoolClassName),
      subtitle: Text('${enrollment.status} • ${enrollment.enrollmentDate}'),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          try {
            if (v == 'cancel')
              await ApiClient().dio.post(
                '${AppConfig.apiBaseUrl}/api/enrollments/${enrollment.id}/cancel',
              );
            if (v == 'transfer') {
              final idController = TextEditingController();
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  title: const Text('Solicitar transferência'),
                  content: TextField(
                    controller: idController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ID da nova turma',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Solicitar'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ApiClient().dio.post(
                  '${AppConfig.apiBaseUrl}/api/enrollments/student/${enrollment.studentId}/transfer',
                  data: {
                    'newSchoolClassId': int.tryParse(idController.text),
                    'transferDate': DateTime.now().toIso8601String().substring(
                      0,
                      10,
                    ),
                    'notes': 'Transferência solicitada pelo estudante',
                  },
                );
              }
              idController.dispose();
            }
            onRefresh();
          } catch (e) {
            if (context.mounted) showLearningError(context, e);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'transfer',
            child: Text('Solicitar transferência'),
          ),
          PopupMenuItem(value: 'cancel', child: Text('Cancelar matrícula')),
        ],
      ),
    ),
  );
}

class TeacherClassManagementView extends StatelessWidget {
  const TeacherClassManagementView({
    super.key,
    required this.data,
    required this.onRefresh,
  });
  final DashboardData data;
  final VoidCallback onRefresh;
  Future<void> _create(BuildContext context) async {
    final school = TextEditingController();
    final name = TextEditingController();
    final year = TextEditingController(text: DateTime.now().year.toString());
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Criar turma'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: school,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ID da escola'),
              ),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nome da turma'),
              ),
              TextField(
                controller: year,
                decoration: const InputDecoration(labelText: 'Ano letivo'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (result != true) return;
    try {
      final response = await ApiClient().dio.post<Map<String, dynamic>>(
        '${AppConfig.apiBaseUrl}/api/classes/school/${school.text}',
        data: {
          'name': name.text,
          'schoolYear': year.text,
          'shift': 'MANHÃ',
          'gradeLevel': 'Geral',
          'active': true,
        },
      );
      final classId = response.data?['id'];
      final teacherId = data.teacherProfile?.id;
      if (classId != null && teacherId != null) {
        await ApiClient().dio.post(
          '${AppConfig.apiBaseUrl}/api/class-teacher-assignments',
          data: {
            'schoolClassId': classId,
            'teacherId': teacherId,
            'startDate': DateTime.now().toIso8601String().substring(0, 10),
            'reason': 'Turma criada pelo professor',
          },
        );
      }
      onRefresh();
    } catch (e) {
      if (context.mounted) showLearningError(context, e);
    }
    school.dispose();
    name.dispose();
    year.dispose();
  }

  Future<void> _showStudents(BuildContext context, int? classId) async {
    if (classId == null) return;
    try {
      final responses = await Future.wait([
        ApiClient().dio.get<List<dynamic>>(
          '${AppConfig.apiBaseUrl}/api/students/class/$classId/active',
        ),
        ApiClient().dio.get<List<dynamic>>(
          '${AppConfig.apiBaseUrl}/api/enrollments/class/$classId',
        ),
      ]);
      final students = (responses[0].data ?? []).whereType<Map>().toList();
      final enrollments = (responses[1].data ?? []).whereType<Map>().toList();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('Estudantes ativos'),
          content: SizedBox(
            width: 500,
            height: 360,
            child: students.isEmpty
                ? const Center(
                    child: Text('Esta turma ainda não tem estudantes.'),
                  )
                : ListView(
                    children: students.map((s) {
                      final matching = enrollments.where(
                        (e) => e['studentId'] == s['id'],
                      );
                      final enrollment = matching.isEmpty
                          ? null
                          : matching.first;
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text('${s['name'] ?? 'Estudante'}'),
                        subtitle: Text(
                          '${s['email'] ?? ''} • ${enrollment?['status'] ?? 'Ativo'}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (enrollment?['id'] == null) return;
                            final newStatus = switch (action) {
                              'approve' || 'resume' => 'ACTIVE',
                              'suspend' => 'SUSPENDED',
                              _ => 'CANCELLED',
                            };
                            try {
                              await ApiClient().dio.put(
                                '${AppConfig.apiBaseUrl}/api/enrollments/${enrollment!['id']}/status',
                                data: {
                                  'status': newStatus,
                                  'notes': 'Atualizado pelo professor',
                                },
                              );
                              Navigator.pop(ctx);
                              onRefresh();
                            } catch (e) {
                              if (context.mounted)
                                showLearningError(context, e);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'approve',
                              child: Text('Aprovar / ativar'),
                            ),
                            PopupMenuItem(
                              value: 'suspend',
                              child: Text('Trancar matrícula'),
                            ),
                            PopupMenuItem(
                              value: 'resume',
                              child: Text('Reativar matrícula'),
                            ),
                            PopupMenuItem(
                              value: 'remove',
                              child: Text('Remover da turma'),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) showLearningError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Gestão de turmas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _create(context),
            icon: const Icon(Icons.add),
            label: const Text('Criar turma'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (data.teacherAssignments.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Nenhuma turma atribuída.'),
          ),
        ),
      ...data.teacherAssignments.map(
        (a) => Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.class_)),
            title: Text(a.schoolClassName),
            subtitle: Text('Desde ${a.startDate}'),
            trailing: IconButton(
              tooltip: 'Ver estudantes',
              icon: const Icon(Icons.people),
              onPressed: () => _showStudents(context, a.schoolClassId),
            ),
          ),
        ),
      ),
    ],
  );
}
