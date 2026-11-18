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

class _CatalogOptionDialog extends StatefulWidget {
  const _CatalogOptionDialog({
    required this.initialType,
    this.existingOption,
    required this.onSaveOption,
  });

  final String initialType;
  final Map<String, dynamic>? existingOption;
  final Future<Map<String, dynamic>> Function(
    Map<String, dynamic> payload,
    dynamic editingId,
  )
  onSaveOption;

  @override
  State<_CatalogOptionDialog> createState() => _CatalogOptionDialogState();
}

class _CatalogOptionDialogState extends State<_CatalogOptionDialog> {
  final TextEditingController _valueCtrl = TextEditingController();
  final TextEditingController _manualFlagCodeCtrl = TextEditingController();
  final TextEditingController _manualFlagUrlCtrl = TextEditingController();

  late String _type;
  late String _flagMode;
  bool _active = true;
  bool _saving = false;
  String? _validationError;

  bool get _isEditing => widget.existingOption != null;
  bool get _isCoreProtectedLanguage {
    final existing = widget.existingOption;
    if (existing == null) return false;
    final rawType = existing['catalogType']?.toString().trim().toUpperCase();
    return rawType == 'LANGUAGE' &&
        SupportedLanguages.isSupported(existing['value']?.toString());
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existingOption;
    if (existing != null) {
      final rawType =
          existing['catalogType']?.toString().trim().toUpperCase() ?? 'LANGUAGE';
      _type = rawType == 'LANGUAGE' ? 'LANGUAGE' : 'PROFICIENCY_LEVEL';
      _valueCtrl.text = existing['value']?.toString() ?? '';
      _active = existing['active'] != false;
      _flagMode =
          existing['flagMode']?.toString().trim().toUpperCase() == 'MANUAL'
          ? 'MANUAL'
          : 'AUTO';
      _manualFlagCodeCtrl.text = existing['flagCode']?.toString() ?? 'br';
      _manualFlagUrlCtrl.text = existing['flagUrl']?.toString() ?? '';
    } else {
      _type = widget.initialType == 'PROFICIENCY_LEVEL'
          ? 'PROFICIENCY_LEVEL'
          : 'LANGUAGE';
      _flagMode = 'AUTO';
      _manualFlagCodeCtrl.text = 'br';
    }
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _manualFlagCodeCtrl.dispose();
    _manualFlagUrlCtrl.dispose();
    super.dispose();
  }

  String _autoPreviewCode() =>
      LanguageFlag.codeString(LanguageFlag.resolveCode(_valueCtrl.text));

  Future<void> _submit() async {
    final val = _valueCtrl.text.trim();
    if (val.isEmpty) {
      setState(() => _validationError = 'Informe o nome da opção.');
      return;
    }
    if (_type == 'LANGUAGE' && _flagMode == 'MANUAL') {
      final code = _manualFlagCodeCtrl.text.trim();
      final url = _manualFlagUrlCtrl.text.trim();
      if (code.isEmpty && url.isEmpty) {
        setState(
          () => _validationError =
              'No modo Manual, selecione/informe uma bandeira ou cole uma URL.',
        );
        return;
      }
      if (url.isNotEmpty &&
          !url.toLowerCase().startsWith('http://') &&
          !url.toLowerCase().startsWith('https://')) {
        setState(
          () => _validationError =
              'URL inválida. Utilize um link http:// ou https://.',
        );
        return;
      }
    }

    setState(() {
      _saving = true;
      _validationError = null;
    });

    final manualCode = _manualFlagCodeCtrl.text.trim();
    final manualUrl = _manualFlagUrlCtrl.text.trim();

    final payload = <String, dynamic>{
      'catalogType': _type,
      'value': _type == 'LANGUAGE'
          ? (SupportedLanguages.normalize(val) ?? val)
          : val,
      'active': _isCoreProtectedLanguage ? true : _active,
      if (_type == 'LANGUAGE') ...{
        'flagMode': _flagMode,
        'flagCode': _flagMode == 'MANUAL' ? manualCode : _autoPreviewCode(),
        'flagUrl': _flagMode == 'MANUAL' && manualUrl.isNotEmpty
            ? manualUrl
            : null,
      },
    };

    try {
      final result = await widget.onSaveOption(
        payload,
        widget.existingOption?['id'],
      );
      if (mounted) {
        Navigator.of(context).pop(result);
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
    final isLanguage = _type == 'LANGUAGE';
    final effectivePreviewCode = _flagMode == 'MANUAL'
        ? _manualFlagCodeCtrl.text.trim()
        : _autoPreviewCode();

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isEditing ? Icons.flag_rounded : Icons.add_circle_outline_rounded,
            color: AdminGeralTheme.indigoMid,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isEditing
                  ? 'Configurar Opção & Bandeira'
                  : 'Nova Opção de Catálogo',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Entrada',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'LANGUAGE',
                    child: Text(
                      'Idioma (LANGUAGE)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'PROFICIENCY_LEVEL',
                    child: Text(
                      'Nível de Proficiência (PROFICIENCY_LEVEL)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: _isEditing
                    ? null
                    : (val) {
                        if (val != null) {
                          setState(() {
                            _type = val;
                            _validationError = null;
                          });
                        }
                      },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _valueCtrl,
                enabled: !_isCoreProtectedLanguage,
                onChanged: (_) {
                  if (isLanguage && _flagMode == 'AUTO') {
                    setState(() {});
                  }
                },
                decoration: InputDecoration(
                  labelText: isLanguage
                      ? 'Nome do idioma (ex: Coreano, Português, Mandarim)'
                      : 'Nome do nível (ex: Intermediário Plus, C1)',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (isLanguage) ...[
                const SizedBox(height: 16),
                const Text(
                  'Bandeira do Idioma',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: const Text('Automática'),
                      selected: _flagMode == 'AUTO',
                      onSelected: (_) => setState(() => _flagMode = 'AUTO'),
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Manual (Admin)'),
                      selected: _flagMode == 'MANUAL',
                      onSelected: (_) {
                        setState(() {
                          _flagMode = 'MANUAL';
                          if (_manualFlagCodeCtrl.text.trim().isEmpty) {
                            _manualFlagCodeCtrl.text = _autoPreviewCode();
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    children: [
                      LanguageFlag.fromMetadata(
                        language: _valueCtrl.text,
                        flagMode: _flagMode,
                        flagCode: effectivePreviewCode,
                        flagUrl: _flagMode == 'MANUAL'
                            ? _manualFlagUrlCtrl.text
                            : null,
                        width: 42,
                        borderRadius: 6,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _flagMode == 'AUTO'
                                  ? 'Detecção Automática Ativa'
                                  : 'Configuração Manual Ativa',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _flagMode == 'AUTO'
                                  ? 'Código detectado: ${effectivePreviewCode.toUpperCase()}'
                                  : 'Código/emoji: ${effectivePreviewCode.isEmpty ? "personalizado" : effectivePreviewCode.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_flagMode == 'MANUAL') ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Escolha rápida de bandeira:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kCatalogFlagPresets.map((preset) {
                      final selected =
                          _manualFlagCodeCtrl.text.trim().toLowerCase() ==
                          preset.code;
                      return ChoiceChip(
                        avatar: LanguageFlag.forLanguage(
                          preset.code,
                          width: 18,
                          borderRadius: 3,
                        ),
                        label: Text(
                          preset.label,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: selected,
                        onSelected: (_) => setState(() {
                          _manualFlagCodeCtrl.text = preset.code;
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _manualFlagCodeCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText:
                          'Código país ou emoji manual (ex: pt, kr, us, gb, 🇧🇷)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _manualFlagUrlCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'URL de imagem da bandeira (opcional)',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
              if (!_isCoreProtectedLanguage) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Disponível Imediatamente (Ativo)'),
                  value: _active,
                  onChanged: (val) => setState(() => _active = val),
                ),
              ],
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
              : Text(_isEditing ? 'Salvar Alterações' : 'Salvar Opção'),
        ),
      ],
    );
  }
}

class AdminCatalogManagementView extends StatefulWidget {
  const AdminCatalogManagementView({super.key, this.dio});

  final Dio? dio;

  @override
  State<AdminCatalogManagementView> createState() =>
      _AdminCatalogManagementViewState();
}

class _AdminCatalogManagementViewState
    extends State<AdminCatalogManagementView> {
  late final Dio _dio = widget.dio ?? ApiClient().dio;

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

  static bool _isLanguageType(dynamic rawType) =>
      rawType?.toString().trim().toUpperCase() == 'LANGUAGE';

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
      if (!mounted) return;
      setState(() {
        _catalogOptions = data
            .map((e) => Map<String, dynamic>.from(e as Map))
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
      final updated = Map<String, dynamic>.from(response.data as Map);
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

  Future<void> _showOptionDialog({Map<String, dynamic>? existingOption}) async {
    final initialType = _selectedType == 'PROFICIENCY_LEVEL'
        ? 'PROFICIENCY_LEVEL'
        : 'LANGUAGE';
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _CatalogOptionDialog(
        initialType: initialType,
        existingOption: existingOption,
        onSaveOption: (payload, editingId) async {
          if (editingId != null) {
            final resp = await _dio.put(
              '/api/admin/catalog/$editingId',
              data: payload,
            );
            return Map<String, dynamic>.from(resp.data as Map);
          }
          final resp = await _dio.post('/api/admin/catalog', data: payload);
          return Map<String, dynamic>.from(resp.data as Map);
        },
      ),
    );
    if (!mounted || saved == null) return;
    SystemSoundService.success();
    setState(() {
      if (existingOption != null) {
        final idx = _catalogOptions.indexWhere(
          (o) => o['id'] == existingOption['id'],
        );
        if (idx != -1) {
          _catalogOptions[idx] = saved;
        }
      } else {
        _catalogOptions.insert(0, saved);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existingOption != null
              ? 'Opção "${saved['value'] ?? ''}" atualizada com sucesso!'
              : 'Opção "${saved['value'] ?? ''}" adicionada com sucesso!',
        ),
        backgroundColor: const Color(0xFF059669),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _catalogOptions.where((opt) {
      if (query.isNotEmpty) {
        final val = (opt['value'] ?? '').toString().toLowerCase();
        final code = (opt['flagCode'] ?? opt['code'] ?? '')
            .toString()
            .toLowerCase();
        if (!val.contains(query) && !code.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    final totalCount = _catalogOptions.length;
    final totalActive = _catalogOptions
        .where((o) => o['active'] == true)
        .length;
    final totalLanguages = _catalogOptions
        .where((o) => _isLanguageType(o['catalogType']))
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
                    Flexible(
                      child: Column(
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
                            'Cadastre idiomas, escolha bandeira automática ou manual e gerencie níveis de proficiência.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
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
                      onPressed: () => _showOptionDialog(),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 600;
              final cards = [
                _buildMetricCard(
                  title: 'Total de Itens',
                  value: '$totalCount',
                  icon: Icons.list_alt_rounded,
                  color: const Color(0xFF0D9488),
                ),
                _buildMetricCard(
                  title: 'Idiomas Registrados',
                  value: '$totalLanguages',
                  icon: Icons.language_rounded,
                  color: const Color(0xFF2563EB),
                ),
                _buildMetricCard(
                  title: 'Opções Ativas',
                  value: '$totalActive',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF059669),
                ),
              ];
              if (stack) {
                return Column(
                  children: [
                    cards[0],
                    const SizedBox(height: 10),
                    cards[1],
                    const SizedBox(height: 10),
                    cards[2],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[2]),
                ],
              );
            },
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText:
                            'Filtrar por idioma, sigla ou bandeira (ex: Coreano, KR, B2)...',
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
                final isLanguage = _isLanguageType(item['catalogType']);
                final isCoreLanguage =
                    isLanguage &&
                    SupportedLanguages.isSupported(item['value']?.toString());
                final isActive = item['active'] == true;
                final flagMode =
                    item['flagMode']?.toString().trim().toUpperCase() ?? 'AUTO';
                final flagCode = item['flagCode']?.toString() ?? '';
                final flagUrl = item['flagUrl']?.toString();

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
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
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
                                  color: AdminGeralTheme.goldMetallic
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                              child: isLanguage
                                  ? LanguageFlag.fromMetadata(
                                      language: item['value']?.toString(),
                                      flagMode: flagMode,
                                      flagCode: flagCode,
                                      flagUrl: flagUrl,
                                      width: 28,
                                    )
                                  : const Icon(
                                      Icons.school_rounded,
                                      color: AdminGeralTheme.purplePrimary,
                                      size: 22,
                                    ),
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
                                      item['value']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
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
                                    if (isLanguage)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: flagMode == 'MANUAL'
                                              ? AdminGeralTheme.goldMetallic
                                                    .withValues(alpha: 0.18)
                                              : const Color(
                                                  0xFF2563EB,
                                                ).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          flagMode == 'MANUAL'
                                              ? 'Bandeira Manual${flagCode.isNotEmpty ? " · ${flagCode.toUpperCase()}" : ""}'
                                              : 'Bandeira Auto${flagCode.isNotEmpty ? " · ${flagCode.toUpperCase()}" : ""}',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: flagMode == 'MANUAL'
                                                ? AdminGeralTheme.goldDark
                                                : AdminGeralTheme.bluePrimary,
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
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _showOptionDialog(existingOption: item),
                              icon: Icon(
                                isLanguage
                                    ? Icons.flag_rounded
                                    : Icons.edit_outlined,
                                size: 15,
                              ),
                              label: Text(
                                isLanguage ? 'Bandeira' : 'Editar',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isCoreLanguage)
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
