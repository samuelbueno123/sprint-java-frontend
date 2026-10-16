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

  bool _isLoadingOverview = false;
  String? _overviewError;
  List<_DbTableMeta> _tables = [];
  List<_AdminUserItem> _users = [];

  String? _selectedTableName;
  bool _isLoadingTableData = false;
  String? _tableDataError;
  _DbTableData? _currentTableData;
  final TextEditingController _tableSearchController = TextEditingController();

  final TextEditingController _userSearchController = TextEditingController();
  String _userFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadAdminOverview();
  }

  @override
  void dispose() {
    _tableSearchController.dispose();
    _userSearchController.dispose();
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

  Future<void> _loadAdminOverview({bool keepSelectedTable = true}) async {
    setState(() {
      _isLoadingOverview = true;
      _overviewError = null;
    });

    try {
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
        }
      });

      if (_selectedTableName != null) {
        await _loadTableRows(_selectedTableName!);
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

  Future<void> _loadTableRows(String tableName, {String? search}) async {
    setState(() {
      _selectedTableName = tableName;
      _isLoadingTableData = true;
      _tableDataError = null;
    });

    try {
      final queryText = (search ?? _tableSearchController.text).trim();
      final queryParams = <String, String>{'limit': '250', 'offset': '0'};
      if (queryText.isNotEmpty) {
        queryParams['search'] = queryText;
      }

      final response = await _dio.get<Map<String, dynamic>>(
        _adminUri('/api/admin/tables/$tableName/rows', queryParams).toString(),
      );

      final parsed = _DbTableData.fromJson(response.data ?? const {});
      if (!mounted) return;
      setState(() {
        _currentTableData = parsed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tableDataError = _extractErrorMessage(
          e,
          'Erro ao carregar registros da tabela $tableName.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTableData = false;
        });
      }
    }
  }

  void _openTableInEditor(String tableName) {
    _tableSearchController.clear();
    widget.onSectionSelected('database');
    _loadTableRows(tableName, search: '');
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
        return _buildDatabaseEditorSection(context);
      case 'users':
        return _buildUsersAdminSection(context);
      case 'profile':
      default:
        return _buildOverviewSection(context);
    }
  }

  // ===========================================================================
  // 1. PAINEL GERAL (OVERVIEW)
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
                colors: [Color(0xFFB45309), Color(0xFFD97706), Color(0xFFF59E0B)],
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
                                'PAINEL DE ADMINISTRADOR • ACESSO TOTAL',
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
                      onPressed: () => widget.onSectionSelected('database'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFB45309),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(Icons.storage_rounded, size: 18),
                      label: const Text('Explorar & Editar Tabelas'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => widget.onSectionSelected('users'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.4),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 18,
                      ),
                      label: const Text('Gerir Usuários & ADMs'),
                    ),
                    IconButton(
                      onPressed: () => _loadAdminOverview(),
                      tooltip: 'Atualizar indicadores',
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
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
                final cols = constraints.maxWidth >= 980
                    ? 3
                    : constraints.maxWidth >= 620
                    ? 2
                    : 1;
                final cardWidth =
                    (constraints.maxWidth - (12 * (cols - 1))) / cols;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _tables.map((table) {
                    return SizedBox(
                      width: cardWidth,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openTableInEditor(table.tableName),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFD97706,
                                        ).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.table_chart_rounded,
                                        color: Color(0xFFD97706),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            table.tableName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            table.label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF2563EB,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${table.rowCount} reg.',
                                        style: const TextStyle(
                                          color: Color(0xFF2563EB),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.view_column_rounded,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${table.columns.length} colunas',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.key_rounded,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'PK: ${table.primaryKeys.join(", ")}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.edit_note_rounded,
                                      color: Color(0xFFD97706),
                                      size: 20,
                                    ),
                                  ],
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
  // 2. EXPLORADOR E EDITOR DE TABELAS DO BANCO DE DADOS
  // ===========================================================================

  Widget _buildDatabaseEditorSection(BuildContext context) {
    final tableData = _currentTableData;

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
                        'Editor de Tabelas do Banco (PostgreSQL)',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Selecione qualquer tabela abaixo para consultar, inserir, editar ou excluir registros em tempo real.',
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
                      onPressed: () => _showRowEditorDialog(
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
          // Seletor de tabelas
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _tables.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final t = _tables[index];
                final isSelected = t.tableName == _selectedTableName;
                return ChoiceChip(
                  selected: isSelected,
                  selectedColor: const Color(0xFFD97706).withValues(alpha: 0.18),
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
                              ? const Color(0xFFB45309)
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
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${t.rowCount}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onSelected: (_) => _loadTableRows(t.tableName),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          // Barra de busca na tabela
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tableSearchController,
                  onSubmitted: (val) {
                    if (_selectedTableName != null) {
                      _loadTableRows(_selectedTableName!, search: val);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: _selectedTableName == null
                        ? 'Buscar registros...'
                        : 'Filtrar registros em "$_selectedTableName" (pressione Enter para buscar)...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _tableSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _tableSearchController.clear();
                              if (_selectedTableName != null) {
                                _loadTableRows(_selectedTableName!, search: '');
                              }
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
                  _loadTableRows(_selectedTableName!);
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
                : _buildTableGridCard(context, tableData),
          ),
        ],
      ),
    );
  }

  Widget _buildTableGridCard(BuildContext context, _DbTableData tableData) {
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
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
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
                      tableData.label,
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
                        '${tableData.totalCount} registro(s)',
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Dica: clique em qualquer linha ou no ícone de lápis para editar os campos ali mesmo.',
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
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _showRowEditorDialog(
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
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          rows: tableData.rows.map((row) {
                            return DataRow(
                              onSelectChanged: (_) => _showRowEditorDialog(
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
                                        onPressed: () => _showRowEditorDialog(
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
                                        onPressed: () => _confirmDeleteRow(
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
            color: val ? const Color(0xFF15803D) : Colors.grey.shade700,
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
        nullFlags[col.name] =
            isEditing && initialVal == null && col.nullable;
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
                                      color: Colors.grey.shade300,
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

    for (final c in controllers.values) {
      c.dispose();
    }
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
  // 3. GESTÃO DE USUÁRIOS E PERMISSÕES ADM
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
          return u.isAdmin;
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
                        'Gestão de Usuários & Permissões ADM',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Conceda ou revogue permissões de administrador, crie contas ou edite credenciais.',
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
                  FilledButton.icon(
                    onPressed: () => _showUserDialog(context, existing: null),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
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
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar usuário por nome, e-mail ou ID...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _userSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _userSearchController.clear();
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
          if (filteredUsers.isEmpty)
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
          else
            ...filteredUsers.map((u) => _buildUserAdminCard(context, u)),
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
      onSelected: (_) => setState(() => _userFilter = value),
    );
  }

  Widget _buildUserAdminCard(BuildContext context, _AdminUserItem user) {
    final isCurrentUser =
        user.email.toLowerCase() == widget.data.user.email.toLowerCase();

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
                      ? const Color(0xFFB45309)
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
                        if (user.isAdmin)
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
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_user_rounded,
                                  size: 13,
                                  color: Color(0xFFB45309),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'ADMIN',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ],
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
                            ).withValues(alpha: 0.1),
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
                        if (isCurrentUser)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF15803D,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Você',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
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
                  checkmarkColor: const Color(0xFFB45309),
                  avatar: Icon(
                    user.isAdmin
                        ? Icons.shield_rounded
                        : Icons.shield_outlined,
                    size: 16,
                    color: user.isAdmin
                        ? const Color(0xFFB45309)
                        : Colors.grey.shade700,
                  ),
                  label: Text(
                    user.isAdmin ? 'Permissão ADM Ativa' : 'Tornar ADM',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: user.isAdmin
                          ? const Color(0xFFB45309)
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  onSelected: isCurrentUser && user.isAdmin
                      ? null
                      : (val) => _toggleUserAdmin(user, val),
                ),
                IconButton(
                  tooltip: 'Editar usuário',
                  onPressed: () => _showUserDialog(context, existing: user),
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
                IconButton(
                  tooltip: isCurrentUser
                      ? 'Não é possível excluir a própria conta em uso'
                      : 'Excluir usuário',
                  onPressed: isCurrentUser
                      ? null
                      : () => _confirmDeleteUser(context, user),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: isCurrentUser
                        ? Colors.grey.shade400
                        : const Color(0xFFB42318),
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
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final passwordCtrl = TextEditingController();
    bool isAdmin = existing?.isAdmin ?? true;
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
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        title: const Text(
                          'Conceder Permissão de Administrador (ADM)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: const Text(
                          'Permite acessar e editar todas as tabelas do banco e gerir contas.',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: isAdmin,
                        onChanged: (v) => setDialogState(() => isAdmin = v),
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
                              'isAdmin': isAdmin,
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

    nameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
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
    );
  }

  final String tableName;
  final String label;
  final int rowCount;
  final List<String> primaryKeys;
  final List<_DbColumnMeta> columns;
}

class _DbTableData {
  const _DbTableData({
    required this.tableName,
    required this.label,
    required this.totalCount,
    required this.primaryKeys,
    required this.columns,
    required this.rows,
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
    );
  }

  final String tableName;
  final String label;
  final int totalCount;
  final List<String> primaryKeys;
  final List<_DbColumnMeta> columns;
  final List<Map<String, dynamic>> rows;
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
}
