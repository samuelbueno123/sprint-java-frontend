import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/dashboard_data.dart';
import 'app_user_avatar.dart';
import 'info_stat_card.dart';
import 'responsive_layout.dart';
import 'user_settings_view.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({
    super.key,
    required this.data,
    required this.activeSection,
    required this.onSectionSelected,
    required this.onLogout,
    required this.onRefresh,
  });

  final DashboardData data;
  final String activeSection;
  final ValueChanged<String> onSectionSelected;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  final Dio _dio = ApiClient().dio;

  bool get _isSuperAdmin =>
      widget.data.user.isSuperAdmin ||
      widget.data.user.email.trim().toLowerCase() == 'admin@duolingo.com';

  bool _isLoadingOverview = false;
  String? _overviewError;
  List<_DbTableMeta> _tables = [];
  List<_AdminUserItem> _users = [];

  // Database table state & pagination (10 rows per page)
  static const int _tablePageSize = 10;
  String? _selectedTableName;
  int _tablePage = 0;
  bool _isLoadingTableData = false;
  String? _tableDataError;
  _DbTableData? _currentTableData;
  final TextEditingController _tableSearchController = TextEditingController();
  final ScrollController _tableTabsController = ScrollController();
  final ScrollController _tableVerticalController = ScrollController();
  final ScrollController _tableHorizontalController = ScrollController();
  Timer? _tableSearchDebounce;
  int _tableSearchRequestId = 0;

  // Users management state & pagination (10 users per page)
  static const int _userPageSize = 10;
  int _userPage = 0;
  final TextEditingController _userSearchController = TextEditingController();
  String _userFilter = 'ALL';

  // Notifications state, filter & pagination (10, 20, 30, 50, 100)
  bool _isLoadingNotifications = false;
  String? _notificationError;
  List<_AdminNotification> _notifications = [];
  List<_InstitutionRequest> _institutionRequests = [];
  final TextEditingController _notificationSearchController =
      TextEditingController();
  String _notificationTypeFilter = 'ALL';
  String _notificationReadFilter = 'ALL';
  String _notificationStatusFilter = 'ALL';
  int _notificationPageSize = 10;
  int _notificationPage = 0;

  // Institution Dashboard state
  bool _isLoadingInstDashboard = false;
  String? _instDashboardError;
  Map<String, dynamic>? _instDashboardData;
  List<Map<String, dynamic>> _institutionsList = [];
  int? _selectedInstitutionId;

  // Institution Admins management state (Super Admin only)
  bool _isLoadingTeachers = false;
  String? _teachersError;
  List<Map<String, dynamic>> _allTeachers = [];
  final TextEditingController _instAdminSearchController =
      TextEditingController();
  int? _instAdminInstitutionFilter;

  // Student Achievements management state (Super Admin only)
  bool _isLoadingStudentAchievements = false;
  String? _studentAchievementsError;
  List<Map<String, dynamic>> _studentAchievementsList = [];
  Map<String, dynamic>? _selectedStudentAchievementOverview;
  final TextEditingController _studentAchievementSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAdminOverview();
    _loadNotifications();
    if (!_isSuperAdmin || widget.activeSection == 'institutionDashboard') {
      _loadInstitutionDashboard();
    }
    if (widget.activeSection == 'institutionAdmins' && _isSuperAdmin) {
      _loadTeachersForInstitutionAdmin();
    }
    if (widget.activeSection == 'studentAchievements' && _isSuperAdmin) {
      _loadStudentAchievements();
    }
    if (widget.activeSection == 'tools') {
      _loadCatalogAuxData();
    }
  }

  @override
  void didUpdateWidget(covariant AdminDashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeSection != widget.activeSection) {
      if (widget.activeSection == 'notifications') {
        _loadNotifications();
      } else if (widget.activeSection == 'institutionDashboard') {
        _loadInstitutionDashboard();
      } else if (widget.activeSection == 'institutionAdmins' && _isSuperAdmin) {
        _loadTeachersForInstitutionAdmin();
      } else if (widget.activeSection == 'studentAchievements' &&
          _isSuperAdmin) {
        _loadStudentAchievements();
      } else if (widget.activeSection == 'tools') {
        _loadCatalogAuxData();
      }
    }
  }

  @override
  void dispose() {
    _tableSearchController.dispose();
    _userSearchController.dispose();
    _notificationSearchController.dispose();
    _instAdminSearchController.dispose();
    _studentAchievementSearchController.dispose();
    _tableSearchDebounce?.cancel();
    _tableTabsController.dispose();
    _tableVerticalController.dispose();
    _tableHorizontalController.dispose();
    super.dispose();
  }

  Uri _adminUri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse(AppConfig.apiBaseUrl).resolve(path);
    if (queryParameters == null || queryParameters.isEmpty) {
      return base;
    }
    return base.replace(queryParameters: queryParameters);
  }

  String _extractErrorMessage(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final msg = data['message'] ?? data['error'] ?? data['detail'];
        if (msg != null && msg.toString().trim().isNotEmpty) {
          return msg.toString();
        }
      }
    }
    return fallback;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFB42318)
            : const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatFriendlyDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final parsed = DateTime.tryParse(raw.trim())?.toLocal();
    if (parsed == null) return raw;
    final dd = parsed.day.toString().padLeft(2, '0');
    final mm = parsed.month.toString().padLeft(2, '0');
    final yyyy = parsed.year.toString();
    final hh = parsed.hour.toString().padLeft(2, '0');
    final min = parsed.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy às $hh:$min';
  }

  Future<void> _loadAdminOverview({bool keepSelectedTable = true}) async {
    setState(() {
      _isLoadingOverview = true;
      _overviewError = null;
    });

    try {
      if (_isSuperAdmin) {
        final results = await Future.wait([
          _dio.get<List<dynamic>>(_adminUri('/api/admin/tables').toString()),
          _dio.get<List<dynamic>>(_adminUri('/api/admin/users').toString()),
        ]);

        final rawTables = results[0].data ?? const [];
        final rawUsers = results[1].data ?? const [];

        final parsedTables = rawTables
            .whereType<Map<String, dynamic>>()
            .map(_DbTableMeta.fromJson)
            .toList();

        final parsedUsers = rawUsers
            .whereType<Map<String, dynamic>>()
            .map(_AdminUserItem.fromJson)
            .toList();

        if (!mounted) return;
        setState(() {
          _tables = parsedTables;
          _users = parsedUsers;
          if (!keepSelectedTable ||
              _selectedTableName == null ||
              !_tables.any((t) => t.tableName == _selectedTableName)) {
            _selectedTableName = _tables.isNotEmpty
                ? _tables.first.tableName
                : null;
            _tablePage = 0;
          }
        });

        if (_selectedTableName != null) {
          await _loadTableRows(_selectedTableName!, page: _tablePage);
        }
      } else {
        final usersResp = await _dio.get<List<dynamic>>(
          _adminUri('/api/admin/users').toString(),
        );
        final rawUsers = usersResp.data ?? const [];
        final parsedUsers = rawUsers
            .whereType<Map<String, dynamic>>()
            .map(_AdminUserItem.fromJson)
            .toList();
        if (!mounted) return;
        setState(() {
          _users = parsedUsers;
        });
        await _loadInstitutionDashboard();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _overviewError = _extractErrorMessage(
          e,
          'Não foi possível carregar os dados administrativos.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOverview = false;
        });
      }
    }
  }

  Future<void> _loadTableRows(
    String tableName, {
    String? search,
    int page = 0,
  }) async {
    if (!_isSuperAdmin) return;
    _tableSearchDebounce?.cancel();
    _tableSearchDebounce = null;
    final requestId = ++_tableSearchRequestId;
    final isSameTable = _selectedTableName == tableName;
    final effectivePage = isSameTable ? page : 0;

    setState(() {
      _selectedTableName = tableName;
      _tablePage = effectivePage;
      _isLoadingTableData = true;
      _tableDataError = null;
    });

    try {
      final queryText = (search ?? _tableSearchController.text).trim();
      final queryParams = <String, String>{
        'limit': '$_tablePageSize',
        'offset': '${effectivePage * _tablePageSize}',
      };
      if (queryText.isNotEmpty) {
        queryParams['search'] = queryText;
      }

      final response = await _dio.get<Map<String, dynamic>>(
        _adminUri('/api/admin/tables/$tableName/rows', queryParams).toString(),
      );

      final parsed = _DbTableData.fromJson(response.data ?? const {});
      if (!mounted || requestId != _tableSearchRequestId) return;
      setState(() {
        _currentTableData = parsed;
      });
    } catch (e) {
      if (!mounted || requestId != _tableSearchRequestId) return;
      setState(() {
        _tableDataError = _extractErrorMessage(
          e,
          'Erro ao carregar registros da tabela $tableName.',
        );
      });
    } finally {
      if (mounted && requestId == _tableSearchRequestId) {
        setState(() {
          _isLoadingTableData = false;
        });
      }
    }
  }

  void _scheduleTableSearch(String value) {
    _tableSearchDebounce?.cancel();
    if (mounted) setState(() {});
    final tableName = _selectedTableName;
    if (tableName == null) return;
    _tableSearchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && tableName == _selectedTableName) {
        _loadTableRows(tableName, search: value, page: 0);
      }
    });
  }

  void _openUsersWithFilter(String filter) {
    setState(() {
      _userFilter = filter;
      _userPage = 0;
    });
    widget.onSectionSelected('users');
  }

  void _openTableInEditor(String tableName) {
    _tableSearchController.clear();
    widget.onSectionSelected('database');
    _loadTableRows(tableName, search: '', page: 0);
  }

  String _friendlyTableName(String rawName) {
    final lower = rawName.toLowerCase();
    if (lower.contains('usuario') || lower.contains('user')) return 'Usuários';
    if (lower.contains('estudante') || lower.contains('aluno') || lower.contains('student')) return 'Alunos';
    if (lower.contains('professor') || lower.contains('teacher')) return 'Professores';
    if (lower.contains('instituicao') || lower.contains('institution')) return 'Instituições';
    if (lower.contains('escola') || (lower.contains('school') && !lower.contains('class'))) return 'Escolas';
    if (lower.contains('turma') || lower.contains('class')) return 'Turmas';
    if (lower.contains('matricula') || lower.contains('enrollment')) return 'Matrículas';
    if (lower.contains('atribuicao') || lower.contains('assignment')) return 'Atribuição de Professores';
    if (lower.contains('idioma_estudante') || lower.contains('student_language')) return 'Idiomas dos Alunos';
    if (lower.contains('idioma') || lower.contains('language')) return 'Idiomas';
    if (lower.contains('submissao') || lower.contains('submission')) return 'Entregas de Atividades';
    if (lower.contains('exercicio') || lower.contains('exercise')) return 'Atividades / Lições';
    if (lower.contains('conquista_estudante') || lower.contains('student_achievement')) return 'Conquistas de Alunos';
    if (lower.contains('conquista') || lower.contains('achievement')) return 'Conquistas';
    if (lower.contains('solicitacao') || lower.contains('request')) return 'Solicitações de Cadastro';
    if (lower.contains('redefinicao') || lower.contains('reset')) return 'Redefinições de Senha';

    final clean = rawName.replaceFirst(RegExp(r'^tb_', caseSensitive: false), '').replaceAll('_', ' ');
    return clean.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  IconData _iconForTable(String rawName) {
    final lower = rawName.toLowerCase();
    if (lower.contains('usuario') || lower.contains('user')) return Icons.people_alt_rounded;
    if (lower.contains('estudante') || lower.contains('aluno') || lower.contains('student')) return Icons.school_rounded;
    if (lower.contains('professor') || lower.contains('teacher')) return Icons.psychology_rounded;
    if (lower.contains('instituicao') || lower.contains('institution')) return Icons.account_balance_rounded;
    if (lower.contains('escola') || (lower.contains('school') && !lower.contains('class'))) return Icons.location_city_rounded;
    if (lower.contains('turma') || lower.contains('class')) return Icons.groups_rounded;
    if (lower.contains('matricula') || lower.contains('enrollment')) return Icons.how_to_reg_rounded;
    if (lower.contains('atribuicao') || lower.contains('assignment')) return Icons.assignment_ind_rounded;
    if (lower.contains('idioma') || lower.contains('language')) return Icons.language_rounded;
    if (lower.contains('submissao') || lower.contains('submission')) return Icons.task_alt_rounded;
    if (lower.contains('exercicio') || lower.contains('exercise')) return Icons.menu_book_rounded;
    if (lower.contains('conquista') || lower.contains('achievement')) return Icons.emoji_events_rounded;
    if (lower.contains('solicitacao') || lower.contains('request')) return Icons.mark_email_unread_rounded;
    return Icons.table_chart_rounded;
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.activeSection) {
      case 'settings':
        return UserSettingsView(
          data: widget.data,
          onBackToProfile: () => widget.onSectionSelected('profile'),
          onLogout: widget.onLogout,
          onRefresh: widget.onRefresh,
        );
      case 'database':
        return _isSuperAdmin
            ? _buildDatabaseEditorSection(context)
            : _buildInstitutionDashboardSection(context);
      case 'tools':
        return _isSuperAdmin
            ? _buildFriendlyToolsSection(context)
            : _buildInstitutionDashboardSection(context);
      case 'institutionAdmins':
        return _isSuperAdmin
            ? _buildInstitutionAdminsSection(context)
            : _buildInstitutionDashboardSection(context);
      case 'studentAchievements':
        return _isSuperAdmin
            ? _buildStudentAchievementsSection(context)
            : _buildInstitutionDashboardSection(context);
      case 'institutionDashboard':
        return _buildInstitutionDashboardSection(context);
      case 'users':
        return _buildUsersAdminSection(context);
      case 'notifications':
        return _buildNotificationsSection(context);
      case 'profile':
      default:
        return _isSuperAdmin
            ? _buildOverviewSection(context)
            : _buildInstitutionDashboardSection(context);
    }
  }

  // ===========================================================================
  // NOTIFICAÇÕES COM FILTRO, PAGINAÇÃO (10, 20, 30, 50, 100) E EXPIRAÇÃO
  // ===========================================================================

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoadingNotifications = true;
      _notificationError = null;
    });
    try {
      final responses = await Future.wait([
        _dio.get<List<dynamic>>(
          _adminUri('/api/admin/notifications').toString(),
        ),
        if (_isSuperAdmin)
          _dio.get<List<dynamic>>(
            _adminUri('/api/admin/institution-requests').toString(),
          )
        else
          Future.value(
            Response<List<dynamic>>(
              requestOptions: RequestOptions(),
              data: const [],
            ),
          ),
      ]);
      if (!mounted) return;
      setState(() {
        _notifications = (responses[0].data ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_AdminNotification.fromJson)
            .toList();
        _institutionRequests = (responses[1].data ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_InstitutionRequest.fromJson)
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _notificationError = _extractErrorMessage(
          error,
          'Não foi possível carregar as notificações.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingNotifications = false);
      }
    }
  }

  Future<void> _decideInstitutionRequest(
    _InstitutionRequest request, {
    required bool approve,
  }) async {
    String? institutionName;
    if (approve) {
      institutionName = await _askInstitutionName(request.requestedName);
      if (institutionName == null || !mounted) return;
    }

    try {
      await _dio.patch<void>(
        _adminUri('/api/admin/institution-requests/${request.id}').toString(),
        data: {
          'decision': approve ? 'APPROVE' : 'REJECT',
          if (approve) 'institutionName': institutionName,
        },
      );
      _showSnack(approve ? 'Instituição criada.' : 'Solicitação recusada.');
      await _loadNotifications();
      await _loadAdminOverview();
      widget.onRefresh();
    } catch (error) {
      _showSnack(
        _extractErrorMessage(error, 'Não foi possível processar o pedido.'),
        isError: true,
      );
    }
  }

  Future<void> _decideTeacherRequest(
    int teacherId, {
    required bool approve,
  }) async {
    try {
      await _dio.patch<void>(
        _adminUri('/api/admin/teacher-requests/$teacherId').toString(),
        data: {'decision': approve ? 'APPROVE' : 'REJECT'},
      );
      _showSnack(
        approve
            ? 'Cadastro de professor aprovado com sucesso!'
            : 'Solicitação de professor recusada.',
      );
      await _loadNotifications();
      await _loadAdminOverview();
      widget.onRefresh();
    } catch (error) {
      _showSnack(
        _extractErrorMessage(
          error,
          'Não foi possível processar a solicitação do professor.',
        ),
        isError: true,
      );
    }
  }

  Future<String?> _askInstitutionName(String initialName) async {
    final controller = TextEditingController(text: initialName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprovar instituição'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 150,
          decoration: const InputDecoration(labelText: 'Nome da instituição'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Criar instituição'),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(milliseconds: 400), controller.dispose);
    if (result != null && result.trim().isEmpty) {
      _showSnack('Informe o nome da instituição.', isError: true);
      return null;
    }
    return result;
  }

  _InstitutionRequest? _requestForNotification(
    _AdminNotification notification,
  ) {
    if (notification.referenceType != 'INSTITUTION_REQUEST') return null;
    for (final request in _institutionRequests) {
      if (request.id == notification.referenceId) return request;
    }
    return null;
  }

  Future<void> _markNotificationRead(_AdminNotification notification) async {
    if (notification.isRead) return;
    try {
      await _dio.patch<void>(
        _adminUri(
          '/api/admin/notifications/${notification.id}/read',
        ).toString(),
      );
      await _loadNotifications();
      widget.onRefresh();
    } catch (error) {
      _showSnack(
        _extractErrorMessage(
          error,
          'Não foi possível atualizar a notificação.',
        ),
        isError: true,
      );
    }
  }

  Widget _buildNotificationsSection(BuildContext context) {
    final query = _notificationSearchController.text.trim().toLowerCase();
    final filtered = _notifications.where((n) {
      if (query.isNotEmpty) {
        final matchesText =
            n.title.toLowerCase().contains(query) ||
            n.message.toLowerCase().contains(query);
        if (!matchesText) return false;
      }
      if (_notificationTypeFilter != 'ALL') {
        final effectiveType = n.type.isNotEmpty ? n.type : n.referenceType;
        if (effectiveType != _notificationTypeFilter) return false;
      }
      if (_notificationReadFilter == 'UNREAD' && n.isRead) return false;
      if (_notificationReadFilter == 'READ' && !n.isRead) return false;
      if (_notificationStatusFilter != 'ALL') {
        if ((n.requestStatus ?? '') != _notificationStatusFilter) return false;
      }
      return true;
    }).toList();

    final totalCount = filtered.length;
    final totalPages = totalCount == 0
        ? 1
        : ((totalCount - 1) ~/ _notificationPageSize) + 1;
    final currentPage = _notificationPage.clamp(0, totalPages - 1);
    final startIndex = currentPage * _notificationPageSize;
    final endIndex = (startIndex + _notificationPageSize).clamp(0, totalCount);
    final pageItems = totalCount == 0
        ? const <_AdminNotification>[]
        : filtered.sublist(startIndex, endIndex);

    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Notificações & Solicitações${unreadCount > 0 ? ' ($unreadCount não lidas)' : ''}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Linhas por página:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _notificationPageSize,
                    items: const [10, 20, 30, 50, 100]
                        .map(
                          (count) => DropdownMenuItem<int>(
                            value: count,
                            child: Text('$count'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _notificationPageSize = value;
                        _notificationPage = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Atualizar notificações',
                    onPressed: _loadNotifications,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Filtros de notificações
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _notificationSearchController,
                    onChanged: (_) => setState(() => _notificationPage = 0),
                    decoration: InputDecoration(
                      hintText:
                          'Filtrar notificações por título, professor, instituição ou mensagem...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _notificationSearchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _notificationSearchController.clear();
                                setState(() => _notificationPage = 0);
                              },
                              icon: const Icon(Icons.clear_rounded),
                            )
                          : null,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Tipo:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: _notificationTypeFilter == 'ALL',
                        onSelected: (_) => setState(() {
                          _notificationTypeFilter = 'ALL';
                          _notificationPage = 0;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('Cadastro de Professor'),
                        selected: _notificationTypeFilter == 'TEACHER_REQUEST',
                        onSelected: (_) => setState(() {
                          _notificationTypeFilter = 'TEACHER_REQUEST';
                          _notificationPage = 0;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('Solicitação de Instituição'),
                        selected:
                            _notificationTypeFilter == 'INSTITUTION_REQUEST',
                        onSelected: (_) => setState(() {
                          _notificationTypeFilter = 'INSTITUTION_REQUEST';
                          _notificationPage = 0;
                        }),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Leitura:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Todas'),
                        selected: _notificationReadFilter == 'ALL',
                        onSelected: (_) => setState(() {
                          _notificationReadFilter = 'ALL';
                          _notificationPage = 0;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('Não lidas'),
                        selected: _notificationReadFilter == 'UNREAD',
                        onSelected: (_) => setState(() {
                          _notificationReadFilter = 'UNREAD';
                          _notificationPage = 0;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('Lidas'),
                        selected: _notificationReadFilter == 'READ',
                        onSelected: (_) => setState(() {
                          _notificationReadFilter = 'READ';
                          _notificationPage = 0;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Status da Solicitação:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (final st in const [
                        ('ALL', 'Todos'),
                        ('PENDING', 'Pendentes'),
                        ('APPROVED', 'Aprovadas'),
                        ('REJECTED', 'Recusadas'),
                        ('EXPIRED', 'Expiradas (Log > 1 semana)'),
                      ])
                        ChoiceChip(
                          label: Text(st.$2),
                          selected: _notificationStatusFilter == st.$1,
                          onSelected: (_) => setState(() {
                            _notificationStatusFilter = st.$1;
                            _notificationPage = 0;
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_notificationError != null)
            _buildErrorBanner(_notificationError!, onRetry: _loadNotifications),
          if (_isLoadingNotifications) const LinearProgressIndicator(),
          if (!_isLoadingNotifications && pageItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Nenhuma notificação encontrada para os filtros selecionados.',
                ),
              ),
            ),
          ...pageItems.map((notification) {
            final request = _requestForNotification(notification);
            final isTeacherReq =
                notification.referenceType == 'TEACHER_REQUEST' ||
                notification.type == 'TEACHER_REQUEST';
            final status = notification.requestStatus ?? '';
            final isPending = status == 'PENDING';
            final isExpired = status == 'EXPIRED';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              notification.isRead
                                  ? Icons.notifications_none_rounded
                                  : Icons.notifications_active_rounded,
                              color: notification.isRead
                                  ? Colors.grey
                                  : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                notification.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (status.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              _buildStatusBadge(status),
                            ],
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Recebida em ${_formatFriendlyDateTime(notification.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (notification.expiresAt != null &&
                                notification.expiresAt!.isNotEmpty)
                              Text(
                                isExpired
                                    ? 'Expirou em ${_formatFriendlyDateTime(notification.expiresAt)} (mantida no log)'
                                    : 'Expira em ${_formatFriendlyDateTime(notification.expiresAt)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isExpired
                                      ? const Color(0xFFB42318)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(notification.message),
                    if (!notification.isRead)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _markNotificationRead(notification),
                          icon: const Icon(Icons.done_all_rounded, size: 16),
                          label: const Text('Marcar como lida'),
                        ),
                      ),
                    if (isTeacherReq &&
                        isPending &&
                        notification.referenceId != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _decideTeacherRequest(
                              notification.referenceId!,
                              approve: false,
                            ),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Recusar Cadastro'),
                          ),
                          FilledButton.icon(
                            onPressed: () => _decideTeacherRequest(
                              notification.referenceId!,
                              approve: true,
                            ),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Aprovar Professor(a)'),
                          ),
                        ],
                      ),
                    ],
                    if (request != null &&
                        (isPending || request.status == 'PENDING')) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Solicitante: ${request.requesterName} • ${request.requesterEmail}',
                      ),
                      if (request.city.isNotEmpty || request.state.isNotEmpty)
                        Text(
                          'Local: ${[request.city, request.state].where((v) => v.isNotEmpty).join(' - ')}',
                        ),
                      if (request.message.isNotEmpty)
                        Text('Detalhes: ${request.message}'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _decideInstitutionRequest(
                              request,
                              approve: false,
                            ),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Recusar'),
                          ),
                          FilledButton.icon(
                            onPressed: () => _decideInstitutionRequest(
                              request,
                              approve: true,
                            ),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Aprovar e criar'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          if (totalCount > 0)
            _buildPaginationBar(
              currentPage: currentPage,
              totalPages: totalPages,
              totalItems: totalCount,
              pageSize: _notificationPageSize,
              onPageChanged: (newPage) =>
                  setState(() => _notificationPage = newPage),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final (label, color) = switch (status.toUpperCase()) {
      'PENDING' => ('PENDENTE', const Color(0xFFD97706)),
      'APPROVED' => ('APROVADA', const Color(0xFF15803D)),
      'REJECTED' => ('RECUSADA', const Color(0xFFB42318)),
      'EXPIRED' => ('EXPIRADA (LOG)', const Color(0xFF64748B)),
      _ => (status, const Color(0xFF2563EB)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPaginationBar({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required int pageSize,
    required ValueChanged<int> onPageChanged,
  }) {
    final start = totalItems == 0 ? 0 : (currentPage * pageSize) + 1;
    final end = ((currentPage + 1) * pageSize).clamp(0, totalItems);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Mostrando $start–$end de $totalItems registro(s) • Página ${currentPage + 1} de $totalPages',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: currentPage > 0
                    ? () => onPageChanged(currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                label: const Text('Anterior'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: currentPage + 1 < totalPages
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                label: const Text('Próxima'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. PAINEL GERAL DO ADMIN SUPREMO (OVERVIEW)
  // ===========================================================================

  Widget _buildOverviewSection(BuildContext context) {
    final totalRows = _tables.fold<int>(0, (acc, item) => acc + item.rowCount);
    final adminCount = _users.where((u) => u.isAdmin).length;

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: responsiveBannerPadding(context),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFB45309),
                  Color(0xFFD97706),
                  Color(0xFFF59E0B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppUserAvatar(
                      name: widget.data.user.name,
                      pictureUrl: widget.data.user.picture,
                      radius: 34,
                      backgroundColor: Colors.white.withValues(alpha: 0.22),
                      textColor: Colors.white,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'PAINEL DE ADMINISTRADOR GERAL • ACESSO SUPREMO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.data.user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.data.user.email,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => widget.onSectionSelected('tools'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFB45309),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(
                        Icons.add_business_rounded,
                        size: 18,
                      ),
                      label: const Text('Cadastros Rápidos'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => widget.onSectionSelected('database'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.4),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(Icons.storage_rounded, size: 18),
                      label: const Text('Tabelas (SELECT *)'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          widget.onSectionSelected('institutionAdmins'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.4),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(
                        Icons.supervisor_account_rounded,
                        size: 18,
                      ),
                      label: const Text('ADMs de Instituições'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          widget.onSectionSelected('studentAchievements'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.4),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 18,
                      ),
                      label: const Text('Conquistas de Alunos'),
                    ),
                    IconButton(
                      onPressed: () => _loadAdminOverview(),
                      tooltip: 'Atualizar indicadores',
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_overviewError != null) ...[
            _buildErrorBanner(_overviewError!, onRetry: _loadAdminOverview),
            const SizedBox(height: 16),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              final itemWidth =
                  (constraints.maxWidth - (14 * (columns - 1))) / columns;

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: InfoStatCard(
                      title: 'Tabelas no PostgreSQL',
                      value: '${_tables.length}',
                      subtitle: 'Schema public ativo',
                      icon: Icons.table_view_rounded,
                      accentColor: const Color(0xFFD97706),
                      onTap: () => widget.onSectionSelected('database'),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: InfoStatCard(
                      title: 'Registros Totais',
                      value: '$totalRows',
                      subtitle: 'Soma de todas as tabelas',
                      icon: Icons.dataset_rounded,
                      accentColor: const Color(0xFF2563EB),
                      onTap: () => widget.onSectionSelected('database'),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: InfoStatCard(
                      title: 'Usuários Cadastrados',
                      value: '${_users.length}',
                      subtitle: 'Contas na tabela users',
                      icon: Icons.people_alt_rounded,
                      accentColor: const Color(0xFF7C3AED),
                      onTap: () => _openUsersWithFilter('ALL'),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: InfoStatCard(
                      title: 'Administradores',
                      value: '$adminCount',
                      subtitle: 'Contas com permissão ADM',
                      icon: Icons.shield_rounded,
                      accentColor: const Color(0xFF059669),
                      onTap: () => _openUsersWithFilter('ADMIN'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Icon(
                Icons.storage_rounded,
                color: Color(0xFFD97706),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Acesso Direto às Tabelas do Banco de Dados (${_tables.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => widget.onSectionSelected('database'),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Abrir Editor Completo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingOverview && _tables.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 1000
                    ? 4
                    : constraints.maxWidth >= 720
                    ? 3
                    : constraints.maxWidth >= 480
                    ? 2
                    : 1;
                final cardWidth =
                    (constraints.maxWidth - (10 * (cols - 1))) / cols;

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _tables.map((table) {
                    return SizedBox(
                      width: cardWidth,
                      child: Material(
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openTableInEditor(table.tableName),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD97706).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _iconForTable(table.tableName),
                                    color: const Color(0xFFD97706),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _friendlyTableName(table.tableName),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        table.tableName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${table.rowCount}',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. EXPLORADOR E EDITOR DE TABELAS DO BANCO DE DADOS (SELECT * + PAGINAÇÃO 10)
  // ===========================================================================

  Widget _buildDatabaseEditorSection(BuildContext context) {
    final tableData = _currentTableData;
    final totalCount = tableData?.totalCount ?? 0;
    final totalPages = totalCount == 0
        ? 1
        : ((totalCount - 1) ~/ _tablePageSize) + 1;

    return Padding(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.storage_rounded,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Editor de Tabelas do Banco (SELECT * • PostgreSQL)',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Visualização completa de todas as colunas da tabela (10 entradas por página).',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (tableData != null)
                    FilledButton.icon(
                      onPressed: tableData.readOnly
                          ? null
                          : () => _showRowEditorDialog(
                              context,
                              tableData: tableData,
                              existingRow: null,
                            ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Novo Registro'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () {
                      _loadAdminOverview(keepSelectedTable: true);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Atualizar'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Seletor de tabelas com barra de scroll rebaixada para não dar overlap
          SizedBox(
            height: 68,
            child: Scrollbar(
              controller: _tableTabsController,
              thumbVisibility: true,
              trackVisibility: true,
              child: ListView.separated(
                controller: _tableTabsController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 18),
                itemCount: _tables.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final t = _tables[index];
                  final isSelected = t.tableName == _selectedTableName;
                  return ChoiceChip(
                    selected: isSelected,
                    selectedColor: const Color(
                      0xFFD97706,
                    ).withValues(alpha: 0.18),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.tableName,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFFD97706)
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFD97706)
                                : Colors.grey.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${t.rowCount}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    onSelected: (_) => _loadTableRows(t.tableName, page: 0),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Barra de busca na tabela
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tableSearchController,
                  onChanged: _scheduleTableSearch,
                  decoration: InputDecoration(
                    hintText: _selectedTableName == null
                        ? 'Buscar registros...'
                        : 'Filtrar registros em "$_selectedTableName"...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _tableSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _tableSearchController.clear();
                              _scheduleTableSearch('');
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: _selectedTableName == null
                    ? null
                    : () => _loadTableRows(
                        _selectedTableName!,
                        search: _tableSearchController.text,
                        page: 0,
                      ),
                icon: const Icon(Icons.filter_alt_rounded, size: 18),
                label: const Text('Filtrar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_tableDataError != null) ...[
            _buildErrorBanner(
              _tableDataError!,
              onRetry: () {
                if (_selectedTableName != null) {
                  _loadTableRows(_selectedTableName!, page: _tablePage);
                }
              },
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: _isLoadingTableData
                ? const Center(child: CircularProgressIndicator())
                : tableData == null
                ? const Center(
                    child: Text('Selecione uma tabela para visualizar.'),
                  )
                : _buildTableGridCard(context, tableData, totalPages),
          ),
        ],
      ),
    );
  }

  Widget _buildTableGridCard(
    BuildContext context,
    _DbTableData tableData,
    int totalPages,
  ) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SELECT * FROM ${tableData.tableName} (${tableData.label})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${tableData.totalCount} registro(s) • ${tableData.columns.length} colunas',
                        style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '10 registros por página • Clique em uma linha para editar.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: tableData.rows.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 46,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Nenhum registro encontrado na tabela "${tableData.tableName}".',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: tableData.readOnly
                              ? null
                              : () => _showRowEditorDialog(
                                  context,
                                  tableData: tableData,
                                  existingRow: null,
                                ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Inserir Primeiro Registro'),
                        ),
                      ],
                    ),
                  )
                : Scrollbar(
                    controller: _tableVerticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _tableVerticalController,
                      scrollDirection: Axis.vertical,
                      child: Scrollbar(
                        controller: _tableHorizontalController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        notificationPredicate: (notification) =>
                            notification.metrics.axis == Axis.horizontal,
                        child: SingleChildScrollView(
                          controller: _tableHorizontalController,
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 54,
                            dataRowMinHeight: 46,
                            dataRowMaxHeight: 60,
                            showCheckboxColumn: false,
                            columns: [
                              const DataColumn(
                                label: Text(
                                  'Ações',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              ...tableData.columns.map((col) {
                                return DataColumn(
                                  label: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (col.isPrimaryKey) ...[
                                            const Icon(
                                              Icons.key_rounded,
                                              size: 14,
                                              color: Color(0xFFD97706),
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(
                                            col.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${col.udtName}${col.nullable ? "" : " *"}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            rows: tableData.rows.map((row) {
                              return DataRow(
                                onSelectChanged: tableData.readOnly
                                    ? null
                                    : (_) => _showRowEditorDialog(
                                        context,
                                        tableData: tableData,
                                        existingRow: row,
                                      ),
                                cells: [
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_rounded,
                                            size: 18,
                                            color: Color(0xFF2563EB),
                                          ),
                                          tooltip: 'Editar linha',
                                          onPressed: tableData.readOnly
                                              ? null
                                              : () => _showRowEditorDialog(
                                                  context,
                                                  tableData: tableData,
                                                  existingRow: row,
                                                ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: Color(0xFFB42318),
                                          ),
                                          tooltip: 'Excluir linha',
                                          onPressed: tableData.readOnly
                                              ? null
                                              : () => _confirmDeleteRow(
                                                  context,
                                                  tableData: tableData,
                                                  row: row,
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...tableData.columns.map((col) {
                                    final val = row[col.name];
                                    return DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 260,
                                        ),
                                        child: _buildCellPreview(val),
                                      ),
                                    );
                                  }),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const Divider(height: 1),
          _buildPaginationBar(
            currentPage: _tablePage,
            totalPages: totalPages,
            totalItems: tableData.totalCount,
            pageSize: _tablePageSize,
            onPageChanged: (newPage) {
              if (_selectedTableName != null) {
                _loadTableRows(
                  _selectedTableName!,
                  search: _tableSearchController.text,
                  page: newPage,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCellPreview(Object? val) {
    if (val == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'NULL',
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
        ),
      );
    }
    if (val is bool) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: (val ? const Color(0xFF15803D) : Colors.grey).withValues(
            alpha: 0.14,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          val ? 'true' : 'false',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: val ? const Color(0xFF15803D) : Colors.grey,
          ),
        ),
      );
    }
    return Text(
      val.toString(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13),
    );
  }

  Map<String, dynamic> _extractRowKeys(
    _DbTableData tableData,
    Map<String, dynamic> row,
  ) {
    final keys = <String, dynamic>{};
    final keyCols = tableData.primaryKeys.isNotEmpty
        ? tableData.primaryKeys
        : tableData.columns.map((c) => c.name).toList();
    for (final k in keyCols) {
      keys[k] = row[k];
    }
    return keys;
  }

  Future<void> _showRowEditorDialog(
    BuildContext context, {
    required _DbTableData tableData,
    required Map<String, dynamic>? existingRow,
  }) async {
    final isEditing = existingRow != null;
    final controllers = <String, TextEditingController>{};
    final nullFlags = <String, bool>{};
    final boolValues = <String, bool>{};

    for (final col in tableData.columns) {
      final initialVal = isEditing ? existingRow[col.name] : null;
      final isBool = col.udtName.toLowerCase() == 'bool';

      if (isBool) {
        if (initialVal is bool) {
          boolValues[col.name] = initialVal;
        } else if (initialVal != null) {
          boolValues[col.name] =
              initialVal.toString().toLowerCase() == 'true' ||
              initialVal.toString() == '1';
        } else {
          boolValues[col.name] = false;
        }
      }

      if (isEditing &&
          tableData.tableName == 'users' &&
          col.name == 'password_hash') {
        controllers[col.name] = TextEditingController(text: '');
        nullFlags[col.name] = false;
      } else {
        controllers[col.name] = TextEditingController(
          text: initialVal == null ? '' : initialVal.toString(),
        );
        nullFlags[col.name] = isEditing && initialVal == null && col.nullable;
      }
    }

    bool isSaving = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_note_rounded : Icons.add_box_rounded,
                    color: const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Editar Registro em "${tableData.tableName}"'
                          : 'Novo Registro em "${tableData.tableName}"',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (dialogError != null) ...[
                        _buildErrorBanner(dialogError!),
                        const SizedBox(height: 12),
                      ],
                      ...tableData.columns.map((col) {
                        final isBool = col.udtName.toLowerCase() == 'bool';
                        final isBinaryOrLob =
                            col.udtName.toLowerCase() == 'oid' ||
                            col.udtName.toLowerCase() == 'bytea';
                        final isPasswordCol =
                            tableData.tableName == 'users' &&
                            col.name == 'password_hash';
                        final isNullChecked = nullFlags[col.name] ?? false;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (col.isPrimaryKey) ...[
                                    const Icon(
                                      Icons.key_rounded,
                                      size: 14,
                                      color: Color(0xFFD97706),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    col.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${col.udtName}${col.isAutoIncrement ? " • auto" : ""}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (col.nullable && !isPasswordCol)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: isNullChecked,
                                          visualDensity: VisualDensity.compact,
                                          onChanged: (checked) {
                                            setDialogState(() {
                                              nullFlags[col.name] =
                                                  checked ?? false;
                                            });
                                          },
                                        ),
                                        const Text(
                                          'NULL',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (isBool && !isNullChecked)
                                SwitchListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  dense: true,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  title: Text(
                                    (boolValues[col.name] ?? false)
                                        ? 'Verdadeiro (true)'
                                        : 'Falso (false)',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  value: boolValues[col.name] ?? false,
                                  onChanged: (v) {
                                    setDialogState(() {
                                      boolValues[col.name] = v;
                                    });
                                  },
                                )
                              else
                                TextField(
                                  controller: controllers[col.name],
                                  enabled: !isNullChecked && !isBinaryOrLob,
                                  maxLines:
                                      col.dataType.toLowerCase().contains(
                                        'text',
                                      )
                                      ? 3
                                      : 1,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: isNullChecked
                                        ? 'Valor definido como NULL'
                                        : isPasswordCol && isEditing
                                        ? 'Deixe em branco para manter a senha atual ou digite nova senha'
                                        : col.isAutoIncrement && !isEditing
                                        ? 'Gerado automaticamente se deixado vazio'
                                        : col.defaultValue != null && !isEditing
                                        ? 'Default: ${col.defaultValue}'
                                        : 'Informe ${col.name}',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() {
                            isSaving = true;
                            dialogError = null;
                          });

                          try {
                            final payload = <String, dynamic>{};
                            for (final col in tableData.columns) {
                              final isBinaryOrLob =
                                  col.udtName.toLowerCase() == 'oid' ||
                                  col.udtName.toLowerCase() == 'bytea';
                              if (isBinaryOrLob) continue;

                              final isBool =
                                  col.udtName.toLowerCase() == 'bool';
                              final isPasswordCol =
                                  tableData.tableName == 'users' &&
                                  col.name == 'password_hash';

                              if (nullFlags[col.name] == true) {
                                payload[col.name] = null;
                                continue;
                              }

                              if (isBool) {
                                payload[col.name] =
                                    boolValues[col.name] ?? false;
                                continue;
                              }

                              final textVal =
                                  controllers[col.name]?.text.trim() ?? '';

                              if (isEditing &&
                                  isPasswordCol &&
                                  textVal.isEmpty) {
                                continue;
                              }

                              if (!isEditing &&
                                  (col.isAutoIncrement ||
                                      col.defaultValue != null) &&
                                  textVal.isEmpty) {
                                continue;
                              }

                              if (textVal.isEmpty && col.nullable) {
                                payload[col.name] = null;
                              } else {
                                payload[col.name] = textVal;
                              }
                            }

                            if (isEditing) {
                              final keys = _extractRowKeys(
                                tableData,
                                existingRow,
                              );
                              await _dio.put<Map<String, dynamic>>(
                                _adminUri(
                                  '/api/admin/tables/${tableData.tableName}/rows',
                                ).toString(),
                                data: {'keys': keys, 'values': payload},
                              );
                            } else {
                              await _dio.post<Map<String, dynamic>>(
                                _adminUri(
                                  '/api/admin/tables/${tableData.tableName}/rows',
                                ).toString(),
                                data: payload,
                              );
                            }

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            _showSnack(
                              isEditing
                                  ? 'Registro atualizado com sucesso!'
                                  : 'Registro inserido com sucesso!',
                            );
                            await _loadAdminOverview(keepSelectedTable: true);
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              dialogError = _extractErrorMessage(
                                e,
                                'Erro ao salvar registro.',
                              );
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                  ),
                  icon: isSaving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(isSaving ? 'Salvando...' : 'Salvar Alterações'),
                ),
              ],
            );
          },
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
  }

  Future<void> _confirmDeleteRow(
    BuildContext context, {
    required _DbTableData tableData,
    required Map<String, dynamic> row,
  }) async {
    final keys = _extractRowKeys(tableData, row);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar Exclusão de Registro'),
        content: Text(
          'Deseja realmente excluir o registro (${keys.entries.map((e) => "${e.key}: ${e.value}").join(", ")}) da tabela "${tableData.tableName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir Registro'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _dio.delete<void>(
        _adminUri('/api/admin/tables/${tableData.tableName}/rows').toString(),
        data: keys,
      );
      _showSnack('Registro excluído com sucesso.');
      await _loadAdminOverview(keepSelectedTable: true);
    } catch (e) {
      _showSnack(
        _extractErrorMessage(e, 'Não foi possível excluir o registro.'),
        isError: true,
      );
    }
  }

  // ===========================================================================
  // 3. GESTÃO DE USUÁRIOS E PERMISSÕES ADM (PAGINAÇÃO 10 POR PÁGINA)
  // ===========================================================================

  Widget _buildUsersAdminSection(BuildContext context) {
    final query = _userSearchController.text.trim().toLowerCase();
    final filteredUsers = _users.where((u) {
      final matchesQuery =
          query.isEmpty ||
          u.name.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          u.id.toString() == query;
      if (!matchesQuery) return false;

      switch (_userFilter) {
        case 'ADMIN':
          return u.isAdmin || u.institutionAdmin || u.primaryInstitutionAdmin;
        case 'TEACHER':
          return u.baseProfileType == 'TEACHER';
        case 'STUDENT':
          return u.baseProfileType == 'STUDENT';
        case 'USER':
          return u.baseProfileType == 'USER' && !u.isAdmin;
        default:
          return true;
      }
    }).toList();

    int rolePriority(_AdminUserItem u) {
      if (u.institutionAdmin || u.primaryInstitutionAdmin || u.isAdmin) return 0;
      if (u.baseProfileType == 'TEACHER') return 1;
      if (u.baseProfileType == 'STUDENT') return 2;
      return 3;
    }

    filteredUsers.sort((a, b) {
      final pA = rolePriority(a);
      final pB = rolePriority(b);
      if (pA != pB) return pA.compareTo(pB);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    final totalUsers = filteredUsers.length;
    final totalPages = totalUsers == 0
        ? 1
        : ((totalUsers - 1) ~/ _userPageSize) + 1;
    final currentPage = _userPage.clamp(0, totalPages - 1);
    final startIdx = currentPage * _userPageSize;
    final endIdx = (startIdx + _userPageSize).clamp(0, totalUsers);
    final pageUsers = totalUsers == 0
        ? const <_AdminUserItem>[]
        : filteredUsers.sublist(startIdx, endIdx);

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gestão de Usuários & Permissões ADM (10 por página)',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _isSuperAdmin
                            ? 'Contas de aluno não podem receber cargo ADM. O Admin Geral (admin@duolingo.com) é supremo.'
                            : 'Gerencie os usuários vinculados à sua instituição.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (_isSuperAdmin)
                    FilledButton.icon(
                      onPressed: () => _showUserDialog(context, existing: null),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 18,
                      ),
                      label: const Text('Novo Usuário / ADM'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _loadAdminOverview,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Atualizar'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userSearchController,
                  onChanged: (_) => setState(() => _userPage = 0),
                  decoration: InputDecoration(
                    hintText: 'Buscar usuário por nome, e-mail ou ID...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _userSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _userSearchController.clear();
                              setState(() => _userPage = 0);
                            },
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('ALL', 'Todos (${_users.length})'),
              _buildFilterChip(
                'ADMIN',
                'Administradores (${_users.where((u) => u.isAdmin).length})',
              ),
              _buildFilterChip(
                'TEACHER',
                'Professores (${_users.where((u) => u.baseProfileType == "TEACHER").length})',
              ),
              _buildFilterChip(
                'STUDENT',
                'Estudantes (${_users.where((u) => u.baseProfileType == "STUDENT").length})',
              ),
              _buildFilterChip(
                'USER',
                'Sem Perfil (${_users.where((u) => u.baseProfileType == "USER" && !u.isAdmin).length})',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (pageUsers.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Nenhum usuário encontrado para o filtro selecionado.',
                  ),
                ),
              ),
            )
          else ...[
            ...pageUsers.map((u) => _buildUserAdminCard(context, u)),
            _buildPaginationBar(
              currentPage: currentPage,
              totalPages: totalPages,
              totalItems: totalUsers,
              pageSize: _userPageSize,
              onPageChanged: (newPage) => setState(() => _userPage = newPage),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _userFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFD97706).withValues(alpha: 0.18),
      onSelected: (_) => setState(() {
        _userFilter = value;
        _userPage = 0;
      }),
    );
  }

  Widget _buildUserAdminCard(BuildContext context, _AdminUserItem user) {
    final isCurrentUser =
        user.email.toLowerCase() == widget.data.user.email.toLowerCase();
    final isStudent = user.baseProfileType == 'STUDENT';
    final isSuper =
        user.superAdmin || user.email.toLowerCase() == 'admin@duolingo.com';
    final isPrimaryInstAdmin = user.primaryInstitutionAdmin;
    final canToggleAdmin =
        _isSuperAdmin && !isStudent && !isSuper && !isCurrentUser;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: user.isAdmin
              ? const Color(0xFFD97706).withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.outlineVariant,
          width: user.isAdmin ? 1.4 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppUserAvatar(
                  name: user.name,
                  pictureUrl: user.profilePicture,
                  radius: 22,
                  backgroundColor:
                      (user.isAdmin
                              ? const Color(0xFFD97706)
                              : const Color(0xFF3579E8))
                          .withValues(alpha: 0.16),
                  textColor: user.isAdmin
                      ? const Color(0xFFD97706)
                      : const Color(0xFF3579E8),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'ID #${user.id}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isSuper)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFD97706,
                              ).withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ADMIN GERAL SUPREMO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          )
                        else if (isPrimaryInstAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF7C3AED,
                              ).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ADMIN PRIMÁRIO DA INSTITUIÇÃO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          )
                        else if (user.isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFD97706,
                              ).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Perfil: ${user.baseProfileType}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        if (user.institutionName != null &&
                            user.institutionName!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF059669,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user.institutionName!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  selected: user.isAdmin,
                  selectedColor: const Color(
                    0xFFD97706,
                  ).withValues(alpha: 0.18),
                  checkmarkColor: const Color(0xFFD97706),
                  avatar: Icon(
                    isStudent
                        ? Icons.block_rounded
                        : (user.isAdmin
                              ? Icons.shield_rounded
                              : Icons.shield_outlined),
                    size: 16,
                    color: user.isAdmin
                        ? const Color(0xFFD97706)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    isStudent
                        ? 'Aluno (Bloqueado para ADM)'
                        : isSuper
                        ? 'Admin Geral (Imutável)'
                        : (user.isAdmin ? 'Permissão ADM Ativa' : 'Tornar ADM'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: user.isAdmin
                          ? const Color(0xFFD97706)
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  onSelected: canToggleAdmin
                      ? (val) => _toggleUserAdmin(user, val)
                      : null,
                ),
                if (_isSuperAdmin && !isSuper)
                  IconButton(
                    tooltip: 'Editar usuário',
                    onPressed: () => _showUserDialog(context, existing: user),
                    icon: const Icon(
                      Icons.edit_rounded,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                if (_isSuperAdmin && !isSuper && !isCurrentUser)
                  IconButton(
                    tooltip: 'Excluir usuário',
                    onPressed: () => _confirmDeleteUser(context, user),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFB42318),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleUserAdmin(_AdminUserItem user, bool makeAdmin) async {
    if (user.baseProfileType == 'STUDENT') {
      _showSnack(
        'Contas de aluno não podem receber cargo de administrador.',
        isError: true,
      );
      return;
    }
    try {
      await _dio.patch<Map<String, dynamic>>(
        _adminUri('/api/admin/users/${user.id}/admin').toString(),
        data: {'isAdmin': makeAdmin},
      );
      _showSnack(
        makeAdmin
            ? '${user.name} agora possui permissão de Administrador!'
            : 'Permissão de Administrador removida de ${user.name}.',
      );
      await _loadAdminOverview();
    } catch (e) {
      _showSnack(
        _extractErrorMessage(
          e,
          'Não foi possível alterar a permissão de administrador.',
        ),
        isError: true,
      );
    }
  }

  Future<void> _showUserDialog(
    BuildContext context, {
    required _AdminUserItem? existing,
  }) async {
    final isEditing = existing != null;
    final isStudent = existing?.baseProfileType == 'STUDENT';
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final passwordCtrl = TextEditingController();
    bool isAdmin = isStudent ? false : (existing?.isAdmin ?? true);
    bool isSaving = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isEditing
                    ? 'Editar Usuário #${existing.id}'
                    : 'Criar Novo Usuário / ADM',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dialogError != null) ...[
                        _buildErrorBanner(dialogError!),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Nome completo',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        decoration: InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: isEditing
                              ? 'Nova senha (deixe em branco para manter)'
                              : 'Senha de acesso',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        title: Text(
                          isStudent
                              ? 'Cargo ADM Bloqueado para Alunos'
                              : 'Conceder Permissão de Administrador (ADM)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          isStudent
                              ? 'Contas de aluno não podem receber permissão de administrador.'
                              : 'Permite acessar recursos administrativos.',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: isAdmin,
                        onChanged: isStudent
                            ? null
                            : (v) => setDialogState(() => isAdmin = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final email = emailCtrl.text.trim();
                          final password = passwordCtrl.text;

                          if (name.isEmpty || email.isEmpty) {
                            setDialogState(() {
                              dialogError = 'Nome e e-mail são obrigatórios.';
                            });
                            return;
                          }
                          if (!isEditing && password.trim().isEmpty) {
                            setDialogState(() {
                              dialogError =
                                  'Defina uma senha para o novo usuário.';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            dialogError = null;
                          });

                          try {
                            final body = <String, dynamic>{
                              'name': name,
                              'email': email,
                              'isAdmin': isStudent ? false : isAdmin,
                            };
                            if (password.trim().isNotEmpty) {
                              body['password'] = password;
                            }

                            if (isEditing) {
                              await _dio.put<Map<String, dynamic>>(
                                _adminUri(
                                  '/api/admin/users/${existing.id}',
                                ).toString(),
                                data: body,
                              );
                            } else {
                              await _dio.post<Map<String, dynamic>>(
                                _adminUri('/api/admin/users').toString(),
                                data: body,
                              );
                            }

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            _showSnack(
                              isEditing
                                  ? 'Usuário atualizado com sucesso!'
                                  : 'Usuário criado com sucesso!',
                            );
                            await _loadAdminOverview();
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              dialogError = _extractErrorMessage(
                                e,
                                'Não foi possível salvar o usuário.',
                              );
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(isSaving ? 'Salvando...' : 'Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      nameCtrl.dispose();
      emailCtrl.dispose();
      passwordCtrl.dispose();
    });
  }

  Future<void> _confirmDeleteUser(
    BuildContext context,
    _AdminUserItem user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir Usuário'),
        content: Text(
          'Tem certeza que deseja excluir o usuário "${user.name}" (${user.email})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _dio.delete<void>(
        _adminUri('/api/admin/users/${user.id}').toString(),
      );
      _showSnack('Usuário excluído com sucesso.');
      await _loadAdminOverview();
    } catch (e) {
      _showSnack(
        _extractErrorMessage(e, 'Não foi possível excluir o usuário.'),
        isError: true,
      );
    }
  }

  // ===========================================================================
  // 4. CADASTROS RÁPIDOS E AMIGÁVEIS PARA O ADMIN (FORA DA TELA DE BANCO)
  // ===========================================================================

  List<Map<String, dynamic>> _schoolsList = [];
  List<Map<String, dynamic>> _classesList = [];
  List<Map<String, dynamic>> _teachersList = [];
  List<Map<String, dynamic>> _studentsList = [];

  Future<void> _loadCatalogAuxData() async {
    try {
      final futures = <Future<dynamic>>[
        _dio.get<List<dynamic>>(_adminUri('/api/institutions').toString()),
        _dio.get<List<dynamic>>(_adminUri('/api/schools').toString()),
        _dio.get<List<dynamic>>(_adminUri('/api/classes').toString()),
        _dio.get<List<dynamic>>(_adminUri('/api/teachers').toString()),
        _dio.get<List<dynamic>>(_adminUri('/api/students').toString()),
      ];
      final responses = await Future.wait(
        futures.map((f) => f.catchError((_) => null)),
      );
      if (!mounted) return;
      setState(() {
        if (responses[0]?.data is List) {
          _institutionsList = (responses[0]!.data as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        if (responses[1]?.data is List) {
          _schoolsList = (responses[1]!.data as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        if (responses[2]?.data is List) {
          _classesList = (responses[2]!.data as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        if (responses[3]?.data is List) {
          _teachersList = (responses[3]!.data as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        if (responses[4]?.data is List) {
          _studentsList = (responses[4]!.data as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      });
    } catch (_) {}
  }

  Widget _buildFriendlyToolsSection(BuildContext context) {
    final myInstId = widget.data.teacherProfile?.institutionId ?? _selectedInstitutionId;
    final instName = widget.data.teacherProfile?.institution ??
        _institutionsList.firstWhere(
          (i) => (i['id'] as num?)?.toInt() == myInstId,
          orElse: () => <String, dynamic>{'name': 'sua instituição'},
        )['name'] ??
        'sua instituição';

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_business_rounded,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSuperAdmin
                          ? 'Ferramentas Amigáveis de Cadastro Rápido'
                          : 'Cadastros Rápidos da Instituição',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _isSuperAdmin
                          ? 'Crie instituições, escolas, turmas, conquistas e usuários com formulários guiados fora da tela de tabelas.'
                          : 'Cadastre escolas, turmas, professores, alunos, matrículas e atribuições para $instName de forma autônoma.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadCatalogAuxData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Atualizar listas'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 900 ? 2 : 1;
              final width = (constraints.maxWidth - (16 * (cols - 1))) / cols;

              if (!_isSuperAdmin) {
                // Actions available autonomously to Institution Admins
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: width,
                      child: _buildToolActionCard(
                        icon: Icons.account_balance_rounded,
                        title: 'Nova Escola / Unidade',
                        subtitle:
                            'Cadastre uma nova unidade escolar vinculada à sua instituição ($instName).',
                        buttonLabel: 'Criar Escola',
                        onPressed: () => _openCreateSchoolDialog(context),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _buildToolActionCard(
                        icon: Icons.class_rounded,
                        title: 'Nova Turma',
                        subtitle:
                            'Crie uma nova turma em uma escola da sua instituição com turno e série.',
                        buttonLabel: 'Criar Turma',
                        onPressed: () => _openCreateClassToolDialog(context),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _buildToolActionCard(
                        icon: Icons.badge_rounded,
                        title: 'Novo Professor na Instituição',
                        subtitle:
                            'Cadastre um novo professor vinculado diretamente à sua instituição com biografia e idiomas.',
                        buttonLabel: 'Cadastrar Professor',
                        onPressed: () => _openCreateTeacherDialog(context),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _buildToolActionCard(
                        icon: Icons.person_add_alt_1_rounded,
                        title: 'Novo Aluno na Instituição',
                        subtitle:
                            'Cadastre um estudante associado à sua instituição para inclusão em turmas.',
                        buttonLabel: 'Cadastrar Aluno',
                        onPressed: () => _openCreateStudentDialog(context),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _buildToolActionCard(
                        icon: Icons.assignment_ind_rounded,
                        title: 'Atribuir Professor a Turma',
                        subtitle:
                            'Defina o professor responsável por uma das turmas da sua instituição.',
                        buttonLabel: 'Atribuir Professor',
                        onPressed: () => _openAssignTeacherDialog(context),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _buildToolActionCard(
                        icon: Icons.how_to_reg_rounded,
                        title: 'Matricular Aluno em Turma',
                        subtitle:
                            'Matricule um aluno da sua instituição em uma das turmas ativas.',
                        buttonLabel: 'Matricular Aluno',
                        onPressed: () => _openEnrollStudentDialog(context),
                      ),
                    ),
                  ],
                );
              }

              // Super Admin general actions
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child: _buildToolActionCard(
                      icon: Icons.business_rounded,
                      title: 'Nova Instituição',
                      subtitle:
                          'Cadastre uma nova instituição de ensino com tipo e sigla.',
                      buttonLabel: 'Criar Instituição',
                      onPressed: () => _openCreateInstitutionDialog(context),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildToolActionCard(
                      icon: Icons.account_balance_rounded,
                      title: 'Nova Escola / Unidade',
                      subtitle:
                          'Vincule uma nova unidade escolar a uma instituição existente.',
                      buttonLabel: 'Criar Escola',
                      onPressed: () => _openCreateSchoolDialog(context),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildToolActionCard(
                      icon: Icons.class_rounded,
                      title: 'Nova Turma',
                      subtitle:
                          'Crie uma turma escolhendo a escola, turno, série e ano letivo.',
                      buttonLabel: 'Criar Turma',
                      onPressed: () => _openCreateClassToolDialog(context),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildToolActionCard(
                      icon: Icons.emoji_events_rounded,
                      title: 'Nova Conquista no Catálogo',
                      subtitle:
                          'Adicione uma nova conquista para os alunos desbloquearem ou receberem.',
                      buttonLabel: 'Criar Conquista',
                      onPressed: () => _openCreateAchievementDialog(context),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildToolActionCard(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Novo Administrador Geral / Usuário',
                      subtitle:
                          'Crie rapidamente uma nova conta com privilégios de acesso gerais.',
                      buttonLabel: 'Criar Administrador',
                      onPressed: () => _showUserDialog(context, existing: null),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFFD97706)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateInstitutionDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController(text: 'SP');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Criar Nova Instituição'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome da instituição *',
                      hintText: 'Ex: Universidade Federal ou Colégio Duolinfo',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Código / Sigla única *',
                      hintText: 'Ex: UFD01, USP, DUO_INST',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail de contato institucional *',
                      hintText: 'contato@instituicao.edu.br',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Telefone (opcional)',
                      hintText: '11999999999',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: cityCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Cidade (opcional)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: stateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'UF (opcional)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Criar Instituição'),
            ),
          ],
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    final code = codeCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final city = cityCtrl.text.trim();
    final st = stateCtrl.text.trim();
    Future.delayed(const Duration(milliseconds: 400), () {
      nameCtrl.dispose();
      codeCtrl.dispose();
      emailCtrl.dispose();
      phoneCtrl.dispose();
      cityCtrl.dispose();
      stateCtrl.dispose();
    });

    if (ok != true || name.isEmpty || code.isEmpty || email.isEmpty) {
      if (ok == true) {
        _showSnack('Preencha os campos obrigatórios: Nome, Código e E-mail.', isError: true);
      }
      return;
    }
    try {
      await _dio.post(
        _adminUri('/api/institutions').toString(),
        data: {
          'name': name,
          'code': code.toUpperCase(),
          'email': email,
          'phone': phone.isEmpty ? null : phone,
          'city': city.isEmpty ? null : city,
          'state': st.isEmpty ? null : st,
          'country': 'Brasil',
          'active': true,
        },
      );
      _showSnack('Instituição "$name" criada com sucesso!');
      await _loadCatalogAuxData();
      await _loadAdminOverview();
    } catch (e) {
      _showSnack(
        _extractErrorMessage(e, 'Erro ao criar instituição.'),
        isError: true,
      );
    }
  }

  Future<void> _openCreateSchoolDialog(BuildContext context) async {
    await _loadCatalogAuxData();
    if (!context.mounted) return;
    final nameCtrl = TextEditingController();
    final inepCodeCtrl = TextEditingController();
    final myInstId =
        widget.data.teacherProfile?.institutionId ?? _selectedInstitutionId;
    int? institutionId = !_isSuperAdmin
        ? myInstId
        : (_institutionsList.isNotEmpty
            ? (_institutionsList.first['id'] as num?)?.toInt()
            : null);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Criar Nova Escola / Unidade'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isSuperAdmin) ...[
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Instituição (sua instituição)',
                    ),
                    child: Text(
                      widget.data.teacherProfile?.institution ??
                          'Sua Instituição',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ] else ...[
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: institutionId,
                    decoration: const InputDecoration(
                      labelText: 'Instituição vinculada *',
                    ),
                    items: _institutionsList
                        .map(
                          (inst) => DropdownMenuItem<int>(
                            value: (inst['id'] as num?)?.toInt(),
                            child: Text(
                              '${inst['name'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => institutionId = v),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome da escola / unidade *',
                    hintText: 'Ex: Escola Central de Idiomas',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: inepCodeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código INEP / Identificador (opcional)',
                    hintText: 'Ex: 33012345',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Criar Escola'),
            ),
          ],
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    final inep = inepCodeCtrl.text.trim();
    Future.delayed(const Duration(milliseconds: 400), () {
      nameCtrl.dispose();
      inepCodeCtrl.dispose();
    });

    if (ok != true || name.isEmpty || institutionId == null) {
      if (ok == true && (name.isEmpty || institutionId == null)) {
        _showSnack(
          'Selecione uma instituição e informe o nome da escola.',
          isError: true,
        );
      }
      return;
    }
    try {
      await _dio.post(
        _adminUri('/api/schools/institution/$institutionId').toString(),
        data: {
          'name': name,
          'inepCode': inep.isEmpty ? null : inep,
        },
      );
      _showSnack('Escola "$name" criada com sucesso!');
      await _loadCatalogAuxData();
      await _loadAdminOverview();
    } catch (e) {
      _showSnack(
        _extractErrorMessage(e, 'Erro ao criar escola.'),
        isError: true,
      );
    }
  }

  Future<void> _openCreateClassToolDialog(BuildContext context) async {
    await _loadCatalogAuxData();
    if (!context.mounted) return;
    final myInstId =
        widget.data.teacherProfile?.institutionId ?? _selectedInstitutionId;
    final availableSchools = (!_isSuperAdmin && myInstId != null)
        ? _schoolsList
            .where((s) => (s['institutionId'] as num?)?.toInt() == myInstId)
            .toList()
        : _schoolsList;

    if (availableSchools.isEmpty) {
      _showSnack(
        'Nenhuma escola cadastrada na sua instituição. Crie uma escola primeiro.',
        isError: true,
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final yearCtrl =
        TextEditingController(text: DateTime.now().year.toString());
    final gradeCtrl = TextEditingController(text: 'Geral');
    String shift = 'MANHÃ';
    int? schoolId = (availableSchools.first['id'] as num?)?.toInt();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Criar Nova Turma'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: schoolId,
                  decoration: const InputDecoration(
                    labelText: 'Escola vinculada *',
                  ),
                  items: availableSchools
                      .map(
                        (s) => DropdownMenuItem<int>(
                          value: (s['id'] as num?)?.toInt(),
                          child: Text(
                            '${s['name'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => schoolId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome da turma *',
                    hintText: 'Ex: 1º Ano A',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: yearCtrl,
                  decoration: const InputDecoration(labelText: 'Ano letivo *'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: shift,
                  decoration: const InputDecoration(labelText: 'Turno'),
                  items: const [
                    DropdownMenuItem(value: 'MANHÃ', child: Text('Manhã')),
                    DropdownMenuItem(value: 'TARDE', child: Text('Tarde')),
                    DropdownMenuItem(value: 'NOITE', child: Text('Noite')),
                    DropdownMenuItem(
                      value: 'INTEGRAL',
                      child: Text('Integral'),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => shift = v ?? shift),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: gradeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nível / Série',
                    hintText: 'Ex: 1º Ano ou Intermediário',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Criar Turma'),
            ),
          ],
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    final year = yearCtrl.text.trim();
    final grade = gradeCtrl.text.trim();
    Future.delayed(const Duration(milliseconds: 400), () {
      nameCtrl.dispose();
      yearCtrl.dispose();
      gradeCtrl.dispose();
    });

    if (ok != true || name.isEmpty || schoolId == null) return;
    try {
      await _dio.post(
        _adminUri('/api/classes/school/$schoolId').toString(),
        data: {
          'name': name,
          'schoolYear': year.isEmpty ? DateTime.now().year.toString() : year,
          'shift': shift,
          'gradeLevel': grade.isEmpty ? 'Geral' : grade,
          'active': true,
        },
      );
      _showSnack('Turma "$name" criada com sucesso!');
      await _loadCatalogAuxData();
      await _loadAdminOverview();
    } catch (e) {
      _showSnack(
        _extractErrorMessage(e, 'Erro ao criar turma.'),
        isError: true,
      );
    }
  }

  Future<void> _openCreateTeacherDialog(BuildContext context) async {
    await _loadCatalogAuxData();
    if (!context.mounted) return;
    final myInstId =
        widget.data.teacherProfile?.institutionId ?? _selectedInstitutionId;
    if (myInstId == null) {
      _showSnack('Instituição não identificada.', isError: true);
      return;
    }

    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final langsCtrl = TextEditingController(text: 'Inglês');
    final specsCtrl = TextEditingController(text: 'Geral');
    final bioCtrl = TextEditingController();
    String gender = 'NÃO_INFORMADO';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cadastrar Novo Professor'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo do professor *',
                      hintText: 'Ex: Carlos Mendes',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail institucional *',
                      hintText: 'carlos@instituicao.edu.br',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha de acesso provisória *',
                      hintText: 'Mínimo 6 caracteres',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: gender,
                    decoration: const InputDecoration(labelText: 'Gênero'),
                    items: const [
                      DropdownMenuItem(
                        value: 'MASCULINO',
                        child: Text('Masculino'),
                      ),
                      DropdownMenuItem(
                        value: 'FEMININO',
                        child: Text('Feminino'),
                      ),
                      DropdownMenuItem(value: 'OUTRO', child: Text('Outro')),
                      DropdownMenuItem(
                        value: 'NÃO_INFORMADO',
                        child: Text('Prefiro não informar'),
                      ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => gender = v ?? gender),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: langsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Idiomas lecionados (separados por vírgula)',
                      hintText: 'Ex: Inglês, Espanhol',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: specsCtrl,
                    decoration: const InputDecoration(
                      labelText:
                          'Áreas de especialização (separadas por vírgula)',
                      hintText: 'Ex: Gramática, Conversação',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bioCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Biografia / Perfil (opcional)',
                      hintText: 'Breve currículo ou apresentação...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cadastrar Professor'),
            ),
          ],
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();
    final langs = langsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final specs = specsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final bio = bioCtrl.text.trim();

    Future.delayed(const Duration(milliseconds: 400), () {
      nameCtrl.dispose();
      emailCtrl.dispose();
      passCtrl.dispose();
      langsCtrl.dispose();
      specsCtrl.dispose();
      bioCtrl.dispose();
    });

    if (ok != true || name.isEmpty || email.isEmpty || pass.length < 6) {
      if (ok == true) {
        _showSnack(
          'Preencha nome, email e senha com pelo menos 6 caracteres.',
          isError: true,
        );
      }
      return;
    }

    try {
      await _dio.post(
        _adminUri('/api/teachers').toString(),
        data: {
          'name': name,
          'email': email,
          'password': pass,
          'gender': gender,
          'institutionId': myInstId,
          'taughtLanguages': langs,
          'specializationAreas': specs,
          'bibliography': bio.isEmpty ? null : bio,
        },
      );
      _showSnack('Professor "$name" cadastrado com sucesso!');
      await _loadCatalogAuxData();
      await _loadAdminOverview();
    } catch (e) {
      _showSnack(
        _extractErrorMessage(e, 'Erro ao cadastrar professor.'),
        isError: true,
      );
    }
  }

  Future<void> _openCreateStudentDialog(BuildContext context) async {
    await _loadCatalogAuxData();
    if (!context.mounted) return;
    final myInstId =
        widget.data.teacherProfile?.institutionId ?? _selectedInstitutionId;

    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final langCtrl = TextEditingController(text: 'Inglês');
    String gender = 'NÃO_INFORMADO';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cadastrar Novo Aluno'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo do aluno *',
                      hintText: 'Ex: Maria Oliveira',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail do aluno *',
                      hintText: 'maria@exemplo.com',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha de acesso provisória *',
                      hintText: 'Mínimo 6 caracteres',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: gender,
                    decoration: const InputDecoration(labelText: 'Gênero'),
                    items: const [
                      DropdownMenuItem(
                        value: 'MASCULINO',
                        child: Text('Masculino'),
                      ),
                      DropdownMenuItem(
                        value: 'FEMININO',
                        child: Text('Feminino'),
                      ),
                      DropdownMenuItem(value: 'OUTRO', child: Text('Outro')),
                      DropdownMenuItem(
                        value: 'NÃO_INFORMADO',
                        child: Text('Prefiro não informar'),
                      ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => gender = v ?? gender),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: langCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Idioma inicial de estudo',
                      hintText: 'Ex: Inglês',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cadastrar Aluno'),
            ),
          ],
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();
    final lang = langCtrl.text.trim();

    Future.delayed(const Duration(milliseconds: 400), () {
      nameCtrl.dispose();
      emailCtrl.dispose();
      passCtrl.dispose();
      langCtrl.dispose();
    });

    if (ok != true || name.isEmpty || email.isEmpty || pass.length < 6) {
      if (ok == true) {
        _showSnack(
          'Preencha nome, email e senha com pelo menos 6 caracteres.',
          isError: true,
        );
      }
      return;
    }

    try {
      await _dio.post(
        _adminUri('/api/students').toString(),
        data: {
          'name': name,
          'email': email,
          'password': pass,
          'gender': gender,
          'institutionId': myInstId,
          if (lang.isNotEmpty)
            'languages': [
              {
                'language': lang,
                'proficiencyLevel': 'Básico',
                'active': true,
              }
            ],
        },
      );
      _showSnack('Aluno "$name" cadastrado com sucesso!');
      await _loadCatalogAuxData();
      await _loadAdminOverview();
    } catch (e) {
      _showSnack(
        _extractErrorMessage(e, 'Erro ao cadastrar aluno.'),
        isError: true,
      );
    }
  }

  Future<void> _openAssignTeacherDialog(BuildContext context) async {
    await _loadCatalogAuxData();
    if (!context.mounted) return;
    final myInstId =
        widget.data.teacherProfile?.institutionId ?? _selectedInstitutionId;

    final availableClasses = (!_isSuperAdmin && myInstId != null)
        ? _classesList.where((c) {
            final sId = (c['schoolId'] as num?)?.toInt();
            final s = _schoolsList.firstWhere(
              (sc) => (sc['id'] as num?)?.toInt() == sId,
              orElse: () => <String, dynamic>{},
            );
            return (s['institutionId'] as num?)?.toInt() == myInstId ||
                (c['institutionId'] as num?)?.toInt() == myInstId;
          }).toList()
        : _classesList;

    final availableTeachers = (!_isSuperAdmin && myInstId != null)
        ? _teachersList
            .where((t) => (t['institutionId'] as num?)?.toInt() == myInstId)
            .toList()
        : _teachersList;

    if (availableClasses.isEmpty || availableTeachers.isEmpty) {
      _showSnack(
        availableClasses.isEmpty
            ? 'Cadastre primeiro uma turma para realizar a atribuição.'
            : 'Cadastre primeiro um professor para realizar a atribuição.',
        isError: true,
      );
      return;
    }

    int? classId = (availableClasses.first['id'] as num?)?.toInt();
    int? teacherId = (availableTeachers.first['id'] as num?)?.toInt();
    final reasonCtrl = TextEditingController(text: 'Professor Titular');
    final startCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Atribuir Professor à Turma'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: classId,
                  decoration: const InputDecoration(labelText: 'Turma *'),
                  items: availableClasses
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: (c['id'] as num?)?.toInt(),
                          child: Text(
                            '${c['name'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => classId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: teacherId,
                  decoration: const InputDecoration(labelText: 'Professor *'),
                  items: availableTeachers
                      .map(
                        (t) => DropdownMenuItem<int>(
                          value: (t['id'] as num?)?.toInt(),
                          child: Text(
                            '${t['name'] ?? ''} (${t['email'] ?? ''})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => teacherId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: startCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Data de início (AAAA-MM-DD) *',
                    hintText: '2026-02-01',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Motivo / Cargo da atribuição',
                    hintText: 'Ex: Professor Titular ou Substituto',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar Atribuição'),
            ),
          ],
        ),
      ),
    );

    final reason = reasonCtrl.text.trim();
    final start = startCtrl.text.trim();
    Future.delayed(const Duration(milliseconds: 400), () {
      reasonCtrl.dispose();
      startCtrl.dispose();
    });

    if (ok != true || classId == null || teacherId == null) return;

    try {
      await _dio.post(
        _adminUri('/api/assignments').toString(),
        data: {
          'schoolClassId': classId,
          'teacherId': teacherId,
          'startDate': start.isNotEmpty ? start : null,
          'reason': reason.isNotEmpty ? reason : 'Professor Titular',
        },
      );
      _showSnack('Professor atribuído à turma com sucesso!');
      await _loadCatalogAuxData();
      await _loadAdminOverview();
    } catch (e) {
      _showSnack(
        _extractErrorMessage(e, 'Erro ao atribuir professor à turma.'),
        isError: true,
      );
    }
  }

  Future<void> _openEnrollStudentDialog(BuildContext context) async {
    await _loadCatalogAuxData();
    if (!context.mounted) return;
    final myInstId =
        widget.data.teacherProfile?.institutionId ?? _selectedInstitutionId;

    final availableClasses = (!_isSuperAdmin && myInstId != null)
        ? _classesList.where((c) {
            final sId = (c['schoolId'] as num?)?.toInt();
            final s = _schoolsList.firstWhere(
              (sc) => (sc['id'] as num?)?.toInt() == sId,
              orElse: () => <String, dynamic>{},
            );
            return (s['institutionId'] as num?)?.toInt() == myInstId ||
                (c['institutionId'] as num?)?.toInt() == myInstId;
          }).toList()
        : _classesList;

    final availableStudents = (!_isSuperAdmin && myInstId != null)
        ? _studentsList
            .where((s) => (s['institutionId'] as num?)?.toInt() == myInstId)
            .toList()
        : _studentsList;

    if (availableClasses.isEmpty || availableStudents.isEmpty) {
      _showSnack(
        availableClasses.isEmpty
            ? 'Cadastre primeiro uma turma para realizar matrículas.'
            : 'Cadastre primeiro alunos na instituição para matriculá-los.',
        isError: true,
      );
      return;
    }

    int? classId = (availableClasses.first['id'] as num?)?.toInt();
    int? studentId = (availableStudents.first['id'] as num?)?.toInt();
    final notesCtrl = TextEditingController(text: 'Matrícula regular');
    final enrollDateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Matricular Aluno na Turma'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: classId,
                  decoration: const InputDecoration(labelText: 'Turma *'),
                  items: availableClasses
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: (c['id'] as num?)?.toInt(),
                          child: Text(
                            '${c['name'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => classId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: studentId,
                  decoration: const InputDecoration(labelText: 'Aluno *'),
                  items: availableStudents
                      .map(
                        (s) => DropdownMenuItem<int>(
                          value: (s['id'] as num?)?.toInt(),
                          child: Text(
                            '${s['name'] ?? ''} (${s['email'] ?? ''})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => studentId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: enrollDateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Data da matrícula (AAAA-MM-DD) *',
                    hintText: '2026-02-01',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Observações da matrícula',
                    hintText: 'Ex: Matrícula regular ou bolsista',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Efetivar Matrícula'),
            ),
          ],
        ),
      ),
    );

    final notes = notesCtrl.text.trim();
    final enrollDate = enrollDateCtrl.text.trim();
    Future.delayed(const Duration(milliseconds: 400), () {
      notesCtrl.dispose();
      enrollDateCtrl.dispose();
    });

    if (ok != true || classId == null || studentId == null) return;

    try {
      await _dio.post(
        _adminUri('/api/enrollments').toString(),
        data: {
          'studentId': studentId,
          'schoolClassId': classId,
          'enrollmentDate': enrollDate.isNotEmpty ? enrollDate : null,
          'notes': notes.isNotEmpty ? notes : 'Matrícula regular',
        },
      );
      _showSnack('Aluno matriculado na turma com sucesso!');
      await _loadCatalogAuxData();
      await _loadAdminOverview();
    } catch (e) {
      _showSnack(
        _extractErrorMessage(e, 'Erro ao matricular aluno na turma.'),
        isError: true,
      );
    }
  }

  Future<void> _openCreateAchievementDialog(BuildContext context) async {
    final codeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Especial');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Criar Nova Conquista'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código único (ex.: ALUNO_DESTAQUE) *',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título da conquista *',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descrição *',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Categoria (ex.: Especial, XP, Exercícios) *',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Criar Conquista'),
          ),
        ],
      ),
    );

    final code = codeCtrl.text.trim();
    final title = titleCtrl.text.trim();
    final desc = descCtrl.text.trim();
    final category = categoryCtrl.text.trim();
    Future.delayed(const Duration(milliseconds: 400), () {
      codeCtrl.dispose();
      titleCtrl.dispose();
      descCtrl.dispose();
      categoryCtrl.dispose();
    });

    if (ok != true || code.isEmpty || title.isEmpty || desc.isEmpty) return;
    try {
      await _dio.post(
        _adminUri('/api/achievements').toString(),
        data: {
          'code': code,
          'title': title,
          'description': desc,
          'category': category.isEmpty ? 'Especial' : category,
          'iconName': 'workspace_premium_rounded',
        },
      );
      _showSnack('Conquista "$title" adicionada ao catálogo!');
      await _loadAdminOverview();
    } catch (e) {
      _showSnack(
        _extractErrorMessage(e, 'Erro ao criar conquista.'),
        isError: true,
      );
    }
  }

  // ===========================================================================
  // 5. GESTÃO DE ADMINISTRADORES DE INSTITUIÇÕES (EXCLUSIVO ADMIN GERAL)
  // ===========================================================================

  Future<void> _loadTeachersForInstitutionAdmin() async {
    setState(() {
      _isLoadingTeachers = true;
      _teachersError = null;
    });
    try {
      final responses = await Future.wait([
        _dio.get<List<dynamic>>(_adminUri('/api/teachers').toString()),
        _dio.get<List<dynamic>>(_adminUri('/api/institutions').toString()),
      ]);
      if (!mounted) return;
      setState(() {
        _allTeachers = (responses[0].data ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _institutionsList = (responses[1].data ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _teachersError = _extractErrorMessage(
          e,
          'Erro ao carregar professores e instituições.',
        );
      });
    } finally {
      if (mounted) setState(() => _isLoadingTeachers = false);
    }
  }

  Future<void> _updateTeacherInstitutionAdmin(
    int teacherId, {
    required bool institutionAdmin,
    bool? primaryInstitutionAdmin,
  }) async {
    try {
      await _dio.patch(
        _adminUri('/api/admin/teachers/$teacherId/institution-admin')
            .toString(),
        data: {
          'institutionAdmin': institutionAdmin,
          if (primaryInstitutionAdmin != null)
            'primaryInstitutionAdmin': primaryInstitutionAdmin,
        },
      );
      _showSnack('Permissão de administrador de instituição atualizada!');
      await _loadTeachersForInstitutionAdmin();
      await _loadAdminOverview();
    } catch (e) {
      _showSnack(
        _extractErrorMessage(
          e,
          'Erro ao alterar administrador da instituição.',
        ),
        isError: true,
      );
    }
  }

  Widget _buildInstitutionAdminsSection(BuildContext context) {
    final query = _instAdminSearchController.text.trim().toLowerCase();
    final filtered = _allTeachers.where((t) {
      if (_instAdminInstitutionFilter != null &&
          (t['institutionId'] as num?)?.toInt() !=
              _instAdminInstitutionFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final name = '${t['name'] ?? ''}'.toLowerCase();
      final email = '${t['email'] ?? ''}'.toLowerCase();
      final inst = '${t['institutionName'] ?? ''}'.toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          inst.contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gestão de Administradores de Instituições (Exclusivo Admin Geral)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Somente o administrador geral (admin@duolingo.com) pode promover ou rebaixar administradores de instituições.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadTeachersForInstitutionAdmin,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Atualizar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  controller: _instAdminSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar professor ou instituição...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<int?>(
                  isExpanded: true,
                  initialValue: _instAdminInstitutionFilter,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por Instituição',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'Todas as instituições',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    ..._institutionsList.map(
                      (i) => DropdownMenuItem<int?>(
                        value: (i['id'] as num?)?.toInt(),
                        child: Text(
                          '${i['name'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _instAdminInstitutionFilter = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_teachersError != null)
            _buildErrorBanner(
              _teachersError!,
              onRetry: _loadTeachersForInstitutionAdmin,
            ),
          if (_isLoadingTeachers) const LinearProgressIndicator(),
          if (!_isLoadingTeachers && filtered.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: Text('Nenhum professor encontrado.'),
                ),
              ),
            ),
          ...filtered.map((t) {
            final id = (t['id'] as num?)?.toInt();
            final isInstAdmin = t['institutionAdmin'] == true;
            final isPrimary = t['primaryInstitutionAdmin'] == true;
            final gender = '${t['gender'] ?? ''}'.toUpperCase();
            final label = gender == 'FEMININO' ? 'Professora' : 'Professor';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${t['name'] ?? label}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF7C3AED,
                                ).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${t['institutionName'] ?? 'Sem instituição'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                            ),
                            if (isPrimary) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFD97706,
                                  ).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '1ª CONTA / ADMIN ELEVADO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${t['email'] ?? ''} • $label • Status: ${t['approvalStatus'] ?? 'APPROVED'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (id != null)
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            selected: isInstAdmin,
                            label: Text(
                              isInstAdmin
                                  ? 'ADM da Instituição'
                                  : 'Tornar ADM da Instituição',
                            ),
                            onSelected: (val) => _updateTeacherInstitutionAdmin(
                              id,
                              institutionAdmin: val,
                              primaryInstitutionAdmin: val ? isPrimary : false,
                            ),
                          ),
                          FilterChip(
                            selected: isPrimary,
                            label: const Text('Status Primário Protegido'),
                            onSelected: (val) => _updateTeacherInstitutionAdmin(
                              id,
                              institutionAdmin: val ? true : isInstAdmin,
                              primaryInstitutionAdmin: val,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. DASHBOARD DO ADMINISTRADOR DE INSTITUIÇÃO (ESCOPO DA PRÓPRIA INSTITUIÇÃO)
  // ===========================================================================

  Future<void> _loadInstitutionDashboard({int? institutionId}) async {
    setState(() {
      _isLoadingInstDashboard = true;
      _instDashboardError = null;
    });
    try {
      if (_isSuperAdmin && _institutionsList.isEmpty) {
        final instResp = await _dio.get<List<dynamic>>(
          _adminUri('/api/institutions').toString(),
        );
        _institutionsList = (instResp.data ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      final targetId =
          institutionId ??
          _selectedInstitutionId ??
          widget.data.teacherProfile?.institutionId ??
          (_institutionsList.isNotEmpty
              ? (_institutionsList.first['id'] as num?)?.toInt()
              : null);

      final params = <String, String>{
        if (targetId != null) 'institutionId': '$targetId',
      };
      final response = await _dio.get<Map<String, dynamic>>(
        _adminUri('/api/admin/institution-dashboard', params).toString(),
      );
      if (!mounted) return;
      setState(() {
        _selectedInstitutionId = targetId;
        _instDashboardData = response.data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _instDashboardError = _extractErrorMessage(
          e,
          'Não foi possível carregar o dashboard da instituição.',
        );
      });
    } finally {
      if (mounted) setState(() => _isLoadingInstDashboard = false);
    }
  }

  Widget _buildInstitutionDashboardSection(BuildContext context) {
    final dash = _instDashboardData;
    final inst = dash?['institution'] as Map?;
    final instName =
        inst?['name']?.toString() ??
        widget.data.teacherProfile?.institution ??
        'Minha Instituição';
    final totalTeachers = (dash?['totalTeachers'] as num?)?.toInt() ?? 0;
    final pendingTeachers = (dash?['pendingTeachers'] as num?)?.toInt() ?? 0;
    final totalStudents = (dash?['totalStudents'] as num?)?.toInt() ?? 0;
    final totalClasses = (dash?['totalClasses'] as num?)?.toInt() ?? 0;
    final totalExercises = (dash?['totalExercises'] as num?)?.toInt() ?? 0;

    final teachers = (dash?['teachers'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final students = (dash?['students'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final classes = (dash?['classes'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard da Instituição: $instName',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _isSuperAdmin
                            ? 'Visão consolidada por instituição.'
                            : 'Dados restritos exclusivamente à sua instituição.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSuperAdmin && _institutionsList.isNotEmpty)
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _selectedInstitutionId,
                        decoration: const InputDecoration(
                          labelText: 'Instituição',
                          isDense: true,
                        ),
                        items: _institutionsList
                            .map(
                              (i) => DropdownMenuItem<int>(
                                value: (i['id'] as num?)?.toInt(),
                                child: Text(
                                  '${i['name'] ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            _loadInstitutionDashboard(institutionId: v);
                          }
                        },
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Atualizar',
                    onPressed: () => _loadInstitutionDashboard(
                      institutionId: _selectedInstitutionId,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_instDashboardError != null)
            _buildErrorBanner(
              _instDashboardError!,
              onRetry: _loadInstitutionDashboard,
            ),
          if (_isLoadingInstDashboard) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              final w = (constraints.maxWidth - (14 * (cols - 1))) / cols;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: w,
                    child: InfoStatCard(
                      title: 'Professores da Instituição',
                      value: '$totalTeachers',
                      subtitle: pendingTeachers > 0
                          ? '$pendingTeachers aguardando aprovação'
                          : 'Todos aprovados',
                      icon: Icons.co_present_rounded,
                      accentColor: const Color(0xFF7C3AED),
                      onTap: () => widget.onSectionSelected('notifications'),
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: InfoStatCard(
                      title: 'Estudantes Matriculados',
                      value: '$totalStudents',
                      subtitle: 'Membros da instituição',
                      icon: Icons.school_rounded,
                      accentColor: const Color(0xFF2563EB),
                      onTap: () => widget.onSectionSelected('users'),
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: InfoStatCard(
                      title: 'Turmas da Instituição',
                      value: '$totalClasses',
                      subtitle: 'Turmas ativas e cadastradas',
                      icon: Icons.groups_rounded,
                      accentColor: const Color(0xFF059669),
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: InfoStatCard(
                      title: 'Atividades Publicadas',
                      value: '$totalExercises',
                      subtitle: 'Exercícios nas turmas da instituição',
                      icon: Icons.menu_book_rounded,
                      accentColor: const Color(0xFFD97706),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Professores da Instituição (${teachers.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (teachers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhum professor vinculado a esta instituição.'),
              ),
            )
          else
            ...teachers.map((t) {
              final gender = '${t['gender'] ?? ''}'.toUpperCase();
              final roleLabel =
                  gender == 'FEMININO' ? 'Professora' : 'Professor';
              final status = '${t['approvalStatus'] ?? 'APPROVED'}';
              final teacherId = (t['id'] as num?)?.toInt();
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.co_present_rounded),
                  ),
                  title: Text(
                    '${t['name'] ?? roleLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${t['email'] ?? ''} • $roleLabel • Status: $status',
                  ),
                  trailing: status == 'PENDING' && teacherId != null
                      ? Wrap(
                          spacing: 6,
                          children: [
                            OutlinedButton(
                              onPressed: () => _decideTeacherRequest(
                                teacherId,
                                approve: false,
                              ),
                              child: const Text('Recusar'),
                            ),
                            FilledButton(
                              onPressed: () => _decideTeacherRequest(
                                teacherId,
                                approve: true,
                              ),
                              child: const Text('Aprovar'),
                            ),
                          ],
                        )
                      : _buildStatusBadge(status),
                ),
              );
            }),
          const SizedBox(height: 20),
          Text(
            'Turmas da Instituição (${classes.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (classes.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhuma turma cadastrada nesta instituição.'),
              ),
            )
          else
            ...classes.map(
              (c) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.class_rounded)),
                  title: Text(
                    '${c['name'] ?? 'Turma'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Ano: ${c['schoolYear'] ?? ''} • Turno: ${c['shift'] ?? ''} • Nível: ${c['gradeLevel'] ?? ''}',
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Estudantes da Instituição (${students.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (students.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhum estudante vinculado a esta instituição.'),
              ),
            )
          else
            ...students.map((s) {
              final gender = '${s['gender'] ?? ''}'.toUpperCase();
              final roleLabel = gender == 'FEMININO' ? 'Aluna' : 'Aluno';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.school_rounded),
                  ),
                  title: Text(
                    '${s['name'] ?? roleLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${s['email'] ?? ''} • $roleLabel'),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ===========================================================================
  // 7. GESTÃO DE CONQUISTAS DE ALUNOS (EXCLUSIVO ADMIN GERAL)
  // ===========================================================================

  Future<void> _loadStudentAchievements({String? search}) async {
    setState(() {
      _isLoadingStudentAchievements = true;
      _studentAchievementsError = null;
    });
    try {
      final q = (search ?? _studentAchievementSearchController.text).trim();
      final params = <String, String>{if (q.isNotEmpty) 'search': q};
      final response = await _dio.get<List<dynamic>>(
        _adminUri('/api/admin/students/achievements', params).toString(),
      );
      if (!mounted) return;
      final list = (response.data ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _studentAchievementsList = list;
        if (_selectedStudentAchievementOverview != null) {
          final selectedId = _selectedStudentAchievementOverview!['studentId'];
          final updated = list
              .where((item) => item['studentId'] == selectedId)
              .firstOrNull;
          _selectedStudentAchievementOverview =
              updated ?? (list.isNotEmpty ? list.first : null);
        } else if (list.isNotEmpty) {
          _selectedStudentAchievementOverview = list.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _studentAchievementsError = _extractErrorMessage(
          e,
          'Não foi possível carregar os estudantes e suas conquistas.',
        );
      });
    } finally {
      if (mounted) setState(() => _isLoadingStudentAchievements = false);
    }
  }

  Future<void> _toggleStudentAchievement({
    required int studentId,
    required int achievementId,
    required bool grant,
  }) async {
    try {
      final Response<Map<String, dynamic>> response;
      if (grant) {
        response = await _dio.post<Map<String, dynamic>>(
          _adminUri(
            '/api/admin/students/$studentId/achievements/$achievementId',
          ).toString(),
        );
      } else {
        response = await _dio.delete<Map<String, dynamic>>(
          _adminUri(
            '/api/admin/students/$studentId/achievements/$achievementId',
          ).toString(),
        );
      }
      if (!mounted) return;
      if (response.data != null) {
        setState(() {
          _selectedStudentAchievementOverview = response.data;
        });
      }
      _showSnack(
        grant
            ? 'Conquista concedida ao aluno!'
            : 'Conquista removida do aluno.',
      );
      await _loadStudentAchievements();
    } catch (e) {
      _showSnack(
        _extractErrorMessage(e, 'Erro ao atualizar conquista do estudante.'),
        isError: true,
      );
    }
  }

  Widget _buildStudentAchievementsSection(BuildContext context) {
    final selected = _selectedStudentAchievementOverview;
    final selectedAchievements =
        (selected?['achievements'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Conquistas de Alunos (Dar ou Remover Conquistas)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Pesquise qualquer estudante pelo nome ou e-mail e conceda ou revogue conquistas em tempo real.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadStudentAchievements,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Atualizar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _studentAchievementSearchController,
                  onSubmitted: (v) => _loadStudentAchievements(search: v),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar aluno por nome ou e-mail...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon:
                        _studentAchievementSearchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _studentAchievementSearchController.clear();
                              _loadStudentAchievements(search: '');
                            },
                            icon: const Icon(Icons.clear_rounded),
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _loadStudentAchievements(
                  search: _studentAchievementSearchController.text,
                ),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Buscar Aluno'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_studentAchievementsError != null)
            _buildErrorBanner(
              _studentAchievementsError!,
              onRetry: _loadStudentAchievements,
            ),
          if (_isLoadingStudentAchievements) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          if (_studentAchievementsList.isEmpty &&
              !_isLoadingStudentAchievements)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: Text('Nenhum estudante encontrado para a pesquisa.'),
                ),
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _studentAchievementsList.map((student) {
                final id = (student['studentId'] as num?)?.toInt();
                final isSelected = selected != null &&
                    (selected['studentId'] as num?)?.toInt() == id;
                final list = (student['achievements'] as List? ?? const []);
                final unlockedCount = list
                    .whereType<Map>()
                    .where((a) => a['unlocked'] == true || a['earned'] == true)
                    .length;
                return ChoiceChip(
                  selected: isSelected,
                  label: Text(
                    '${student['studentName'] ?? 'Estudante'} ($unlockedCount/${list.length})',
                  ),
                  onSelected: (_) => setState(() {
                    _selectedStudentAchievementOverview = student;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            if (selected != null) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Menu de Conquistas de ${selected['studentName'] ?? 'Estudante'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${selected['studentEmail'] ?? ''} • Instituição: ${selected['institutionName'] ?? 'Não informada'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...selectedAchievements.map((ach) {
                        final achId = (ach['id'] as num?)?.toInt() ??
                            (ach['achievementId'] as num?)?.toInt() ??
                            0;
                        final studentId =
                            (selected['studentId'] as num?)?.toInt() ?? 0;
                        final isUnlocked =
                            ach['unlocked'] == true || ach['earned'] == true;
                        final grantedByAdmin = ach['grantedByAdmin'] == true;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isUnlocked
                                  ? const Color(
                                      0xFF15803D,
                                    ).withValues(alpha: 0.16)
                                  : Colors.grey.withValues(alpha: 0.15),
                              child: Icon(
                                isUnlocked
                                    ? Icons.emoji_events_rounded
                                    : Icons.lock_outline_rounded,
                                color: isUnlocked
                                    ? const Color(0xFF15803D)
                                    : Colors.grey,
                              ),
                            ),
                            title: Text(
                              '${ach['title'] ?? 'Conquista'} (${ach['category'] ?? 'Geral'})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${ach['description'] ?? ''}'
                              '${isUnlocked ? '\nDesbloqueada${grantedByAdmin ? " pelo Admin" : ""}' : '\nBloqueada'}',
                            ),
                            isThreeLine: true,
                            trailing: isUnlocked
                                ? OutlinedButton.icon(
                                    onPressed: () => _toggleStudentAchievement(
                                      studentId: studentId,
                                      achievementId: achId,
                                      grant: false,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFB42318),
                                    ),
                                    icon: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Tirar Conquista'),
                                  )
                                : FilledButton.icon(
                                    onPressed: () => _toggleStudentAchievement(
                                      studentId: studentId,
                                      achievementId: achId,
                                      grant: true,
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF15803D),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(
                                      Icons.add_task_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Dar Conquista'),
                                  ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message, {VoidCallback? onRetry}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFB42318).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB42318).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB42318)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB42318), fontSize: 13),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
        ],
      ),
    );
  }
}

class _DbColumnMeta {
  const _DbColumnMeta({
    required this.name,
    required this.dataType,
    required this.udtName,
    required this.nullable,
    required this.isPrimaryKey,
    required this.isAutoIncrement,
    this.defaultValue,
  });

  factory _DbColumnMeta.fromJson(Map<String, dynamic> json) {
    return _DbColumnMeta(
      name: json['name']?.toString() ?? '',
      dataType: json['dataType']?.toString() ?? '',
      udtName: json['udtName']?.toString() ?? '',
      nullable: json['nullable'] == true,
      isPrimaryKey: json['isPrimaryKey'] == true,
      isAutoIncrement: json['isAutoIncrement'] == true,
      defaultValue: json['defaultValue']?.toString(),
    );
  }

  final String name;
  final String dataType;
  final String udtName;
  final bool nullable;
  final bool isPrimaryKey;
  final bool isAutoIncrement;
  final String? defaultValue;
}

class _DbTableMeta {
  const _DbTableMeta({
    required this.tableName,
    required this.label,
    required this.rowCount,
    required this.primaryKeys,
    required this.columns,
    required this.readOnly,
  });

  factory _DbTableMeta.fromJson(Map<String, dynamic> json) {
    return _DbTableMeta(
      tableName: json['tableName']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      rowCount: (json['rowCount'] as num?)?.toInt() ?? 0,
      primaryKeys: (json['primaryKeys'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      columns: (json['columns'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_DbColumnMeta.fromJson)
          .toList(),
      readOnly: json['readOnly'] == true,
    );
  }

  final String tableName;
  final String label;
  final int rowCount;
  final List<String> primaryKeys;
  final List<_DbColumnMeta> columns;
  final bool readOnly;
}

class _DbTableData {
  const _DbTableData({
    required this.tableName,
    required this.label,
    required this.totalCount,
    required this.primaryKeys,
    required this.columns,
    required this.rows,
    required this.readOnly,
  });

  factory _DbTableData.fromJson(Map<String, dynamic> json) {
    return _DbTableData(
      tableName: json['tableName']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      primaryKeys: (json['primaryKeys'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      columns: (json['columns'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_DbColumnMeta.fromJson)
          .toList(),
      rows: (json['rows'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      readOnly: json['readOnly'] == true,
    );
  }

  final String tableName;
  final String label;
  final int totalCount;
  final List<String> primaryKeys;
  final List<_DbColumnMeta> columns;
  final List<Map<String, dynamic>> rows;
  final bool readOnly;
}

class _AdminUserItem {
  const _AdminUserItem({
    required this.id,
    required this.name,
    required this.email,
    required this.isAdmin,
    required this.baseProfileType,
    required this.effectiveRole,
    this.googleId,
    this.profilePicture,
    this.gender,
    this.superAdmin = false,
    this.institutionAdmin = false,
    this.primaryInstitutionAdmin = false,
    this.institutionId,
    this.institutionName,
  });

  factory _AdminUserItem.fromJson(Map<String, dynamic> json) {
    return _AdminUserItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      googleId: json['googleId']?.toString(),
      profilePicture: json['profilePicture']?.toString(),
      isAdmin: json['isAdmin'] == true,
      baseProfileType: json['baseProfileType']?.toString() ?? 'USER',
      effectiveRole: json['effectiveRole']?.toString() ?? 'USER',
      gender: json['gender']?.toString(),
      superAdmin: json['superAdmin'] == true,
      institutionAdmin: json['institutionAdmin'] == true,
      primaryInstitutionAdmin: json['primaryInstitutionAdmin'] == true,
      institutionId: (json['institutionId'] as num?)?.toInt(),
      institutionName: json['institutionName']?.toString(),
    );
  }

  final int id;
  final String name;
  final String email;
  final String? googleId;
  final String? profilePicture;
  final bool isAdmin;
  final String baseProfileType;
  final String effectiveRole;
  final String? gender;
  final bool superAdmin;
  final bool institutionAdmin;
  final bool primaryInstitutionAdmin;
  final int? institutionId;
  final String? institutionName;
}

class _AdminNotification {
  const _AdminNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.referenceType,
    required this.referenceId,
    required this.createdAt,
    this.institutionId,
    this.requestStatus,
    this.expiresAt,
  });

  factory _AdminNotification.fromJson(Map<String, dynamic> json) {
    return _AdminNotification(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      isRead: json['read'] == true,
      referenceType: json['referenceType']?.toString() ?? '',
      referenceId: (json['referenceId'] as num?)?.toInt(),
      createdAt: json['createdAt']?.toString() ?? '',
      institutionId: (json['institutionId'] as num?)?.toInt(),
      requestStatus: json['requestStatus']?.toString(),
      expiresAt: json['expiresAt']?.toString(),
    );
  }

  final int id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final String referenceType;
  final int? referenceId;
  final String createdAt;
  final int? institutionId;
  final String? requestStatus;
  final String? expiresAt;
}

class _InstitutionRequest {
  const _InstitutionRequest({
    required this.id,
    required this.requestedName,
    required this.requesterName,
    required this.requesterEmail,
    required this.city,
    required this.state,
    required this.message,
    required this.status,
  });

  factory _InstitutionRequest.fromJson(Map<String, dynamic> json) {
    return _InstitutionRequest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      requestedName: json['requestedName']?.toString() ?? '',
      requesterName: json['requesterName']?.toString() ?? '',
      requesterEmail: json['requesterEmail']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
    );
  }

  final int id;
  final String requestedName;
  final String requesterName;
  final String requesterEmail;
  final String city;
  final String state;
  final String message;
  final String status;
}
