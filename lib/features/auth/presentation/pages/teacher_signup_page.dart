import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../auth_dependencies.dart';
import '../../data/models/institution_model.dart';
import '../viewmodels/registration_view_model.dart';
import '../widgets/auth_page_frame.dart';

class _TeacherDocumentItem {
  _TeacherDocumentItem({
    required this.fileName,
    required this.contentType,
    required this.fileSize,
    required this.fileBytes,
  });

  final String fileName;
  final String contentType;
  final int fileSize;
  final Uint8List fileBytes;

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024)
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'contentType': contentType,
    'fileSize': fileSize,
    'fileData': base64Encode(fileBytes),
  };
}

class TeacherSignupPage extends StatefulWidget {
  const TeacherSignupPage({super.key, this.initialEmail, this.initialName});

  final String? initialEmail;
  final String? initialName;

  @override
  State<TeacherSignupPage> createState() => _TeacherSignupPageState();
}

class _TeacherSignupPageState extends State<TeacherSignupPage> {
  static const _availableLanguages = [
    'Inglês',
    'Espanhol',
    'Francês',
    'Alemão',
    'Italiano',
    'Japonês',
  ];

  late final RegistrationViewModel _viewModel;
  final _identityFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _specializationController = TextEditingController();
  final _biographyController = TextEditingController();
  final List<String> _selectedLanguages = [];
  String? _selectedLanguageDropdown;
  final List<_TeacherDocumentItem> _attachedDocuments = [];
  InstitutionModel? _selectedInstitution;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _profileStep = false;

  @override
  void initState() {
    super.initState();
    _viewModel = AuthDependencies.createRegistrationViewModel();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _specializationController.dispose();
    _biographyController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_identityFormKey.currentState!.validate() || _viewModel.isLoading) {
      return;
    }
    setState(() => _profileStep = true);
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final ext = file.extension?.toLowerCase() ?? 'pdf';
          String mimeType = 'application/pdf';
          if (ext == 'doc') mimeType = 'application/msword';
          if (ext == 'docx') {
            mimeType =
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          }

          setState(() {
            _attachedDocuments.add(
              _TeacherDocumentItem(
                fileName: file.name,
                contentType: mimeType,
                fileSize: file.size,
                fileBytes: file.bytes!,
              ),
            );
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao selecionar arquivo: $e')));
    }
  }

  Future<void> _submit() async {
    if (!_profileFormKey.currentState!.validate() || _viewModel.isLoading) {
      return;
    }
    if (_selectedInstitution == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecione uma instituição válida da pesquisa de resultados.',
          ),
        ),
      );
      return;
    }
    if (_selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um idioma.')),
      );
      return;
    }
    final specialties = _specializationController.text
        .split(RegExp(r'[,;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    try {
      await _viewModel.registerTeacher(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        institutionId: _selectedInstitution!.id,
        taughtLanguages: _selectedLanguages,
        specializationAreas: specialties,
        bibliography: _biographyController.text,
        documents: _attachedDocuments.map((doc) => doc.toJson()).toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (route) => false,
      );
    } catch (_) {
      // The view model exposes the backend message below the form.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmailLocked =
        widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty;

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) => AuthPageFrame(
        title: _profileStep ? 'Perfil de professor' : 'Cadastro de professor',
        subtitle: _profileStep
            ? 'Complete os dados profissionais vinculados ao seu perfil.'
            : 'Crie sua conta para continuar com o cadastro docente.',
        accentColor: const Color(0xFF7651C8),
        maxWidth: 560,
        onBack: () => Navigator.of(context).pop(),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _profileStep
              ? _profileForm()
              : _identityForm(isEmailLocked: isEmailLocked),
        ),
      ),
    );
  }

  Widget _identityForm({required bool isEmailLocked}) => Form(
    key: _identityFormKey,
    child: Column(
      key: const ValueKey('teacher-identity'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Nome completo',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          validator: (value) =>
              (value?.trim().isEmpty ?? true) ? 'Informe seu nome.' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _emailController,
          readOnly: isEmailLocked,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Email institucional',
            hintText: 'professor@instituicao.edu',
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            suffixIcon: isEmailLocked
                ? const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFF8A8FA1),
                    size: 18,
                  )
                : null,
            helperText: isEmailLocked ? 'Email vinculado à sua conta' : null,
          ),
          validator: _validateEmail,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Senha',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (value) =>
              (value?.length ?? 0) < 6 ? 'Use pelo menos 6 caracteres.' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmation,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _continue(),
          decoration: InputDecoration(
            labelText: 'Confirmar senha',
            prefixIcon: const Icon(Icons.lock_reset_rounded),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureConfirmation = !_obscureConfirmation),
              icon: Icon(
                _obscureConfirmation
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (value) => value != _passwordController.text
              ? 'As senhas não coincidem.'
              : null,
        ),
        if (_viewModel.errorMessage != null) ...[
          const SizedBox(height: 16),
          _FormError(message: _viewModel.errorMessage!),
        ],
        const SizedBox(height: 22),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _viewModel.isLoading ? null : _continue,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7651C8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _viewModel.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.arrow_forward_rounded, size: 19),
            label: Text(_viewModel.isLoading ? 'Verificando…' : 'Continuar'),
          ),
        ),
      ],
    ),
  );

  Widget _profileForm() {
    final availableLanguages = _availableLanguages
        .where((lang) => !_selectedLanguages.contains(lang))
        .toList();

    final dropdownValue = availableLanguages.contains(_selectedLanguageDropdown)
        ? _selectedLanguageDropdown
        : null;

    return Form(
      key: _profileFormKey,
      child: Column(
        key: const ValueKey('teacher-profile'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _viewModel.isLoading
                  ? null
                  : () => setState(() => _profileStep = false),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Dados da conta'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7651C8),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          _InstitutionSearchField(
            viewModel: _viewModel,
            selectedInstitution: _selectedInstitution,
            onSelected: (institution) {
              setState(() => _selectedInstitution = institution);
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Idiomas lecionados',
            style: TextStyle(
              color: Color(0xFF33384A),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Escolha um ou mais idiomas que você leciona.',
            style: TextStyle(color: Color(0xFF73788B), fontSize: 12),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey(availableLanguages.join('|')),
            initialValue: dropdownValue,
            decoration: const InputDecoration(
              labelText: 'Adicionar idioma lecionado',
              hintText: 'Selecione um idioma...',
              prefixIcon: Icon(Icons.language_rounded),
            ),
            items: availableLanguages
                .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  if (!_selectedLanguages.contains(value)) {
                    _selectedLanguages.add(value);
                  }
                  _selectedLanguageDropdown = null;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          if (_selectedLanguages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6.0),
              child: Text(
                'Nenhum idioma selecionado. Escolha no campo acima.',
                style: TextStyle(
                  color: Color(0xFF73788B),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedLanguages.map((language) {
              return Chip(
                avatar: const Icon(
                  Icons.translate_rounded,
                  size: 16,
                  color: Color(0xFF7651C8),
                ),
                label: Text(language),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () {
                  setState(() {
                    _selectedLanguages.remove(language);
                  });
                },
                backgroundColor: const Color(0xFFF0EAFE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFC6B3F0)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 17),
          TextFormField(
            controller: _specializationController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Áreas de especialização',
              hintText: 'Conversação, Gramática',
              helperText: 'Separe as áreas por vírgulas.',
              prefixIcon: Icon(Icons.workspace_premium_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _biographyController,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Biografia profissional',
              hintText: 'Conte um pouco sobre sua experiência…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Documentos e Comprovantes',
            style: TextStyle(
              color: Color(0xFF33384A),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Anexe diplomas, certificados ou currículo em formato PDF, DOC ou DOCX.',
            style: TextStyle(color: Color(0xFF73788B), fontSize: 12),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickDocument,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7651C8),
              side: const BorderSide(color: Color(0xFF7651C8)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.attach_file_rounded, size: 20),
            label: const Text('Anexar diploma / currículo'),
          ),
          const SizedBox(height: 10),
          ..._attachedDocuments.map(
            (doc) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: const Color(0xFFF6F8FA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE1E4EC)),
              ),
              child: ListTile(
                dense: true,
                leading: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF7651C8),
                ),
                title: Text(
                  doc.fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF33384A),
                  ),
                ),
                subtitle: Text(
                  doc.formattedSize,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF73788B),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _attachedDocuments.remove(doc);
                    });
                  },
                ),
              ),
            ),
          ),
          if (_viewModel.errorMessage != null) ...[
            const SizedBox(height: 16),
            _FormError(message: _viewModel.errorMessage!),
          ],
          const SizedBox(height: 22),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _viewModel.isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7651C8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _viewModel.isLoading
                  ? const SizedBox.square(
                      dimension: 19,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Criar perfil de professor'),
            ),
          ),
        ],
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Informe seu email.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Informe um email válido.';
    }
    return null;
  }
}

class _InstitutionSearchField extends StatefulWidget {
  const _InstitutionSearchField({
    required this.viewModel,
    required this.selectedInstitution,
    required this.onSelected,
  });

  final RegistrationViewModel viewModel;
  final InstitutionModel? selectedInstitution;
  final ValueChanged<InstitutionModel?> onSelected;

  @override
  State<_InstitutionSearchField> createState() =>
      _InstitutionSearchFieldState();
}

class _InstitutionSearchFieldState extends State<_InstitutionSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  List<InstitutionModel> _searchResults = [];
  bool _isSearching = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.selectedInstitution?.name ?? '',
    );
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    final results = await widget.viewModel.searchInstitutions(query);
    final list = List<InstitutionModel>.from(results);

    if (!list.any((item) => item.name.toLowerCase() == query.toLowerCase())) {
      list.add(
        InstitutionModel(
          id: -1,
          name: query,
          code: 'NOVA',
          city: 'Nova instituição',
        ),
      );
    }

    setState(() {
      _searchResults = list;
      _isSearching = false;
    });
  }

  Future<void> _handleSelectOption(
    InstitutionModel option,
    ValueChanged<InstitutionModel> onSelectedOption,
  ) async {
    if (option.id == -1) {
      setState(() => _isCreating = true);
      final created = await widget.viewModel.createInstitution(option.name);
      setState(() => _isCreating = false);
      if (created != null) {
        _controller.text = created.name;
        widget.onSelected(created);
        setState(() => _searchResults = []);
      }
    } else {
      _controller.text = option.name;
      widget.onSelected(option);
      setState(() => _searchResults = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<InstitutionModel>(
          textEditingController: _controller,
          focusNode: _focusNode,
          displayStringForOption: (option) => option.name,
          optionsBuilder: (textEditingValue) {
            return _searchResults;
          },
          onSelected: (option) {
            _handleSelectOption(option, (opt) {});
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (_) => _performSearch(),
              decoration: InputDecoration(
                labelText: 'Nome da instituição',
                hintText: 'Digite o nome e pressione Enter…',
                helperText: widget.selectedInstitution != null
                    ? 'Instituição selecionada: ${widget.selectedInstitution!.name}'
                    : 'Pressione Enter ou a lupa para buscar a instituição.',
                prefixIcon: _isSearching || _isCreating
                    ? const SizedBox.square(
                        dimension: 20,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.account_balance_outlined),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.selectedInstitution != null ||
                        controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          controller.clear();
                          widget.onSelected(null);
                          setState(() => _searchResults = []);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.search_rounded, size: 20),
                      tooltip: 'Pesquisar instituição',
                      onPressed: _performSearch,
                    ),
                  ],
                ),
              ),
              validator: (value) {
                if (widget.selectedInstitution == null) {
                  return 'Pressione Enter para pesquisar e selecione a instituição.';
                }
                return null;
              },
            );
          },
          optionsViewBuilder: (context, onSelectedOption, options) {
            if (options.isEmpty) return const SizedBox.shrink();

            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: constraints.maxWidth,
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E4EC)),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF0F2F6)),
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      final isNewOption = option.id == -1;

                      if (isNewOption) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.add_business_rounded,
                            color: Color(0xFF7651C8),
                            size: 20,
                          ),
                          title: Text(
                            'Cadastrar "${option.name}" como nova instituição',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7651C8),
                            ),
                          ),
                          onTap: () {
                            onSelectedOption(option);
                            _handleSelectOption(option, onSelectedOption);
                          },
                        );
                      }

                      final location = option.locationString;

                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.school_outlined,
                          color: Color(0xFF7651C8),
                          size: 20,
                        ),
                        title: Text(
                          option.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF252A3D),
                          ),
                        ),
                        subtitle: location.isNotEmpty
                            ? Text(
                                location,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF73788B),
                                ),
                              )
                            : null,
                        onTap: () => onSelectedOption(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FormError extends StatelessWidget {
  const _FormError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0EF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFF3C6C2)),
    ),
    child: Text(
      message,
      style: const TextStyle(color: Color(0xFFB42318), fontSize: 13),
    ),
  );
}
