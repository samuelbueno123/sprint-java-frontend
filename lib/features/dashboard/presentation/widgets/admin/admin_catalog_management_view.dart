import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/audio/system_sound_service.dart';
import '../../../../../core/constants/app_feedback_widgets.dart';
import '../../../../../core/constants/supported_languages.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/theme/admin_geral_theme.dart';
import '../../../../../core/ui/language_flag.dart';
import '../../../../../core/ui/motion_kit.dart';
import '../responsive_layout.dart';

class _AddCatalogOptionDialog extends StatefulWidget {
  const _AddCatalogOptionDialog({
    required this.initialType,
    required this.onCreateOption,
  });

  final String initialType;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> payload)
  onCreateOption;

  @override
  State<_AddCatalogOptionDialog> createState() =>
      _AddCatalogOptionDialogState();
}

class _AddCatalogOptionDialogState extends State<_AddCatalogOptionDialog> {
  final TextEditingController _valueCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  late String _type;
  bool _active = true;
  bool _saving = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _type = 'PROFICIENCY_LEVEL';
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final val = _valueCtrl.text.trim();
    if (val.isEmpty) {
      setState(() => _validationError = 'Informe o valor da opção.');
      return;
    }
    if (_type == 'LANGUAGE' && !SupportedLanguages.isSupported(val)) {
      setState(
        () => _validationError =
            'Apenas os 6 idiomas oficiais (${kSupportedLanguages.join(', ')}) são permitidos.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _validationError = null;
    });
    final cd = _codeCtrl.text.trim();
    try {
      final created = await widget.onCreateOption(<String, dynamic>{
        'catalogType': _type,
        'value': _type == 'LANGUAGE'
            ? (SupportedLanguages.normalize(val) ?? val)
            : val,
        'code': cd.isNotEmpty ? cd : null,
        'active': _active,
      });
      if (mounted) {
        Navigator.of(context).pop(created);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar opção: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_circle_outline_rounded, color: AdminGeralTheme.indigoMid),
          SizedBox(width: 8),
          Text('Nova Opção de Catálogo'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Os 6 idiomas base (${kSupportedLanguages.join(', ')}) são estruturais e imutáveis. Adicione abaixo novos Níveis de Proficiência.',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Entrada',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'PROFICIENCY_LEVEL',
                    child: Text('Nível de Proficiência (PROFICIENCY_LEVEL)'),
                  ),
                ],
                onChanged: null,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _valueCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome do nível (ex: Intermediário Plus, C1)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código / Sigla (ex: B2, C1)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                title: const Text('Disponível Imediatamente (Ativo)'),
                value: _active,
                onChanged: (val) => setState(() => _active = val),
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _validationError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: AdminGeralTheme.filledButtonStyle(),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Salvar Opção'),
        ),
      ],
    );
  }
}

class AdminCatalogManagementView extends StatefulWidget {
  const AdminCatalogManagementView({super.key});

  @override
  State<AdminCatalogManagementView> createState() =>
      _AdminCatalogManagementViewState();
}

class _AdminCatalogManagementViewState
    extends State<AdminCatalogManagementView> {
  final Dio _dio = ApiClient().dio;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _catalogOptions = [];

  String _selectedType = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _types = ['ALL', 'LANGUAGE', 'PROFICIENCY_LEVEL'];

  @override
  void initState() {
    super.initState();
    _loadCatalogOptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogOptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final queryParams = <String, dynamic>{};
      if (_selectedType != 'ALL') {
        queryParams['type'] = _selectedType;
      }

      final response = await _dio.get(
        '/api/admin/catalog',
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data is List ? response.data : [];
      setState(() {
        _catalogOptions = data
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Falha ao carregar catálogo: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleOptionActive(Map<String, dynamic> option) async {
    final id = option['id'];
    final currentActive = option['active'] == true;
    try {
      final response = await _dio.patch('/api/admin/catalog/$id/toggle');
      final updated = Map<String, dynamic>.from(response.data);
      if (!mounted) return;
      setState(() {
        final index = _catalogOptions.indexWhere((o) => o['id'] == id);
        if (index != -1) {
          _catalogOptions[index] = updated;
        }
      });
      SystemSoundService.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Opção "${option['value']}" ${!currentActive ? 'ativada' : 'desativada'} com sucesso!',
          ),
          backgroundColor: !currentActive
              ? const Color(0xFF059669)
              : AdminGeralTheme.indigoMid,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao alterar status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteOption(Map<String, dynamic> option) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Opção de Catálogo'),
        content: Text(
          'Deseja realmente excluir "${option['value']}" do catálogo? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final id = option['id'];
    try {
      await _dio.delete('/api/admin/catalog/$id');
      if (!mounted) return;
      SystemSoundService.success();
      setState(() {
        _catalogOptions.removeWhere((o) => o['id'] == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opção "${option['value']}" excluída com sucesso!'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir opção: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showAddOptionDialog() async {
    final initialType = _selectedType == 'PROFICIENCY_LEVEL'
        ? 'PROFICIENCY_LEVEL'
        : 'LANGUAGE';
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AddCatalogOptionDialog(
        initialType: initialType,
        onCreateOption: (payload) async {
          final resp = await _dio.post('/api/admin/catalog', data: payload);
          return Map<String, dynamic>.from(resp.data as Map);
        },
      ),
    );
    if (!mounted || created == null) return;
    SystemSoundService.success();
    setState(() {
      _catalogOptions.insert(0, created);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Opção "${created['value'] ?? ''}" adicionada com sucesso!',
        ),
        backgroundColor: const Color(0xFF059669),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleOptions = _catalogOptions.where((opt) {
      if (opt['catalogType'] == 'LANGUAGE') {
        return SupportedLanguages.isSupported(opt['value']?.toString());
      }
      return true;
    }).toList();

    final query = _searchController.text.trim().toLowerCase();
    final filtered = visibleOptions.where((opt) {
      if (query.isNotEmpty) {
        final val = (opt['value'] ?? '').toString().toLowerCase();
        final code = (opt['code'] ?? '').toString().toLowerCase();
        if (!val.contains(query) && !code.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    final totalCount = visibleOptions.length;
    final totalActive = visibleOptions.where((o) => o['active'] == true).length;
    final totalLanguages = visibleOptions
        .where((o) => o['catalogType'] == 'LANGUAGE')
        .length;

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Container(
            padding: responsiveBannerPadding(context),
            decoration: AdminGeralTheme.heroDecoration(
              context: context,
              borderRadius: 22,
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.category_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Catálogo & Idiomas Oficiais',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Gerencie idiomas suportados, níveis e taxonomias com impacto imediato.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F766E),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: _showAddOptionDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nova Opção'),
                    ),
                    IconButton(
                      tooltip: 'Atualizar Catálogo',
                      onPressed: _loadCatalogOptions,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 20),

          // Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Total de Itens',
                  value: '$totalCount',
                  icon: Icons.list_alt_rounded,
                  color: const Color(0xFF0D9488),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Idiomas Registrados',
                  value: '$totalLanguages',
                  icon: Icons.language_rounded,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Opções Ativas',
                  value: '$totalActive',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF059669),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Search & Filter Bar
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText:
                                'Filtrar por nome ou sigla (ex: Inglês, ES, B2)...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _selectedType,
                        underline: const SizedBox(),
                        items: _types
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                  t == 'ALL'
                                      ? 'Todos os Tipos'
                                      : t == 'LANGUAGE'
                                      ? 'Idiomas'
                                      : 'Níveis de Proficiência',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedType = val;
                            });
                            _loadCatalogOptions();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFB42318),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadCatalogOptions,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: AppLoader(
                message: 'Carregando catálogo oficial...',
                accentColor: AdminGeralTheme.indigoMid,
              ),
            )
          else if (filtered.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const AppEmptyIllustration(
                      icon: Icons.category_outlined,
                      size: 76,
                      accentColor: AdminGeralTheme.indigoMid,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Nenhuma opção de catálogo encontrada',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tente ajustar seus filtros ou cadastre um novo item.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = filtered[index];
                final isLanguage = item['catalogType'] == 'LANGUAGE';
                final isActive = item['active'] == true;
                final code = item['code']?.toString() ?? '';

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isLanguage
                                    ? AdminGeralTheme.bluePrimary
                                    : AdminGeralTheme.purplePrimary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AdminGeralTheme.goldMetallic.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                          child: isLanguage
                              ? LanguageFlag.forLanguage(
                                  item['value']?.toString(),
                                  width: 24,
                                )
                              : const Icon(
                                  Icons.school_rounded,
                                  color: AdminGeralTheme.purplePrimary,
                                  size: 22,
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    item['value']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (code.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        code,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLanguage
                                          ? const Color(
                                              0xFF0D9488,
                                            ).withValues(alpha: 0.12)
                                          : const Color(
                                              0xFF6366F1,
                                            ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isLanguage ? 'Idioma' : 'Proficiência',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isLanguage
                                            ? const Color(0xFF0D9488)
                                            : const Color(0xFF6366F1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tipo: ${item['catalogType']} • ID #${item['id']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Status badge & Toggle (protegido para os 6 idiomas oficiais)
                        if (isLanguage &&
                            SupportedLanguages.isSupported(
                              item['value']?.toString(),
                            ))
                          Tooltip(
                            message:
                                'Os 6 idiomas base do aplicativo são estruturais e permanentes.',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF0D9488,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(
                                    0xFF0D9488,
                                  ).withValues(alpha: 0.35),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_rounded,
                                    size: 14,
                                    color: Color(0xFF0F766E),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Idioma Oficial Fixo',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F766E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          FilterChip(
                            selected: isActive,
                            selectedColor: const Color(
                              0xFF059669,
                            ).withValues(alpha: 0.18),
                            checkmarkColor: const Color(0xFF059669),
                            avatar: Icon(
                              isActive
                                  ? Icons.check_circle_rounded
                                  : Icons.pause_circle_rounded,
                              size: 16,
                              color: isActive
                                  ? const Color(0xFF059669)
                                  : Colors.grey,
                            ),
                            label: Text(
                              isActive ? 'Ativo' : 'Inativo',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: isActive
                                    ? const Color(0xFF059669)
                                    : Colors.grey,
                              ),
                            ),
                            onSelected: (_) => _toggleOptionActive(item),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Excluir opção',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFB42318),
                              size: 20,
                            ),
                            onPressed: () => _deleteOption(item),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final numeric = double.tryParse(value.trim());
    return InteractiveMotionCard(
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (numeric != null)
                      AnimatedMetricCounter(
                        value: numeric,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
