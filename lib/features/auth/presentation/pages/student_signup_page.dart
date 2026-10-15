import 'dart:async';

import 'package:flutter/material.dart';

import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../auth_dependencies.dart';
import '../viewmodels/registration_view_model.dart';
import '../widgets/auth_page_frame.dart';

class _SelectedLanguageItem {
  _SelectedLanguageItem({required this.languageName, required this.level});

  final String languageName;
  String level;

  Map<String, String> toJson() => {
    'languageName': languageName,
    'level': level,
  };
}

class StudentSignupPage extends StatefulWidget {
  const StudentSignupPage({super.key, this.initialEmail, this.initialName});

  final String? initialEmail;
  final String? initialName;

  @override
  State<StudentSignupPage> createState() => _StudentSignupPageState();
}

class _StudentSignupPageState extends State<StudentSignupPage> {
  late final RegistrationViewModel _viewModel;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<_SelectedLanguageItem> _selectedLanguages = [];
  String? _selectedDropdownLanguage;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void initState() {
    super.initState();
    _viewModel = AuthDependencies.createRegistrationViewModel();
    unawaited(_viewModel.loadCatalog());
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
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _viewModel.isLoading) return;
    if (_selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um idioma.')),
      );
      return;
    }
    try {
      await _viewModel.registerStudent(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        languages: _selectedLanguages.map((item) => item.toJson()).toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (route) => false,
      );
    } catch (_) {
      // The view model exposes the backend message to the form below.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmailLocked =
        widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty;

    final availableLanguages = _viewModel.availableLanguages
        .where((lang) => !_selectedLanguages.any((s) => s.languageName == lang))
        .toList();

    final dropdownValue = availableLanguages.contains(_selectedDropdownLanguage)
        ? _selectedDropdownLanguage
        : null;

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) => AuthPageFrame(
        title: 'Cadastro de aluno',
        subtitle: 'Crie seu perfil e escolha os idiomas que quer aprender.',
        accentColor: const Color(0xFF3579E8),
        maxWidth: 560,
        onBack: () => Navigator.of(context).pop(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nome completo',
                  hintText: 'Ex.: João Silva',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Informe seu nome.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                readOnly: isEmailLocked,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'aluno@exemplo.com',
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                  suffixIcon: isEmailLocked
                      ? const Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFF8A8FA1),
                          size: 18,
                        )
                      : null,
                  helperText: isEmailLocked
                      ? 'Email vinculado à sua conta'
                      : null,
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
                validator: (value) => (value?.length ?? 0) < 6
                    ? 'Use pelo menos 6 caracteres.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmation,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Confirmar senha',
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _obscureConfirmation = !_obscureConfirmation,
                    ),
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
              const SizedBox(height: 22),
              const Text(
                'Idiomas e Proficiência',
                style: TextStyle(
                  color: Color(0xFF33384A),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Escolha os idiomas em que tem proficiência e selecione o seu nível em cada um.',
                style: TextStyle(color: Color(0xFF73788B), fontSize: 12),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey(availableLanguages.join('|')),
                initialValue: dropdownValue,
                decoration: const InputDecoration(
                  labelText: 'Adicionar idioma com proficiência',
                  hintText: 'Selecione um idioma...',
                  prefixIcon: Icon(Icons.language_rounded),
                ),
                items: availableLanguages
                    .map(
                      (lang) => DropdownMenuItem<String>(
                        value: lang,
                        child: Text(lang),
                      ),
                    )
                    .toList(),
                onChanged:
                    _viewModel.isCatalogLoading ||
                        _viewModel.catalogErrorMessage != null ||
                        _viewModel.proficiencyLevels.isEmpty
                    ? null
                    : (value) {
                        if (value == null) return;

                        setState(() {
                          _selectedLanguages.add(
                            _SelectedLanguageItem(
                              languageName: value,
                              level: _viewModel.proficiencyLevels.first,
                            ),
                          );
                          _selectedDropdownLanguage = null;
                        });
                      },
              ),
              if (_viewModel.isCatalogLoading) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (_viewModel.catalogErrorMessage != null) ...[
                const SizedBox(height: 8),
                _FormError(message: _viewModel.catalogErrorMessage!),
              ],
              const SizedBox(height: 12),
              if (_selectedLanguages.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Nenhum idioma selecionado. Escolha no campo acima.',
                    style: TextStyle(
                      color: Color(0xFF73788B),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ..._selectedLanguages.map((item) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  color: const Color(0xFFF6F8FA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE1E4EC)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.translate_rounded,
                                  size: 18,
                                  color: Color(0xFF3579E8),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.languageName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF33384A),
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedLanguages.remove(item);
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: item.level,
                          decoration: const InputDecoration(
                            labelText: 'Nível de proficiência',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            isDense: true,
                          ),
                          items: _viewModel.proficiencyLevels
                              .map(
                                (lvl) => DropdownMenuItem(
                                  value: lvl,
                                  child: Text(lvl),
                                ),
                              )
                              .toList(),
                          onChanged: _viewModel.proficiencyLevels.isEmpty
                              ? null
                              : (newLevel) {
                                  if (newLevel != null) {
                                    setState(() {
                                      item.level = newLevel;
                                    });
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                );
              }),
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
                    backgroundColor: const Color(0xFF3579E8),
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
                      : const Text('Criar perfil de aluno'),
                ),
              ),
            ],
          ),
        ),
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
