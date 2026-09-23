import 'package:flutter/material.dart';

import '../../auth_dependencies.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../viewmodels/registration_view_model.dart';
import '../widgets/auth_page_frame.dart';

class TeacherSignupPage extends StatefulWidget {
  const TeacherSignupPage({super.key, this.initialEmail, this.initialName});

  final String? initialEmail;
  final String? initialName;

  @override
  State<TeacherSignupPage> createState() => _TeacherSignupPageState();
}

class _TeacherSignupPageState extends State<TeacherSignupPage> {
  static const _languages = [
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
  final _institutionIdController = TextEditingController();
  final _specializationController = TextEditingController();
  final _biographyController = TextEditingController();
  final Set<String> _selectedLanguages = {};
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
    _institutionIdController.dispose();
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

  Future<void> _submit() async {
    if (!_profileFormKey.currentState!.validate() || _viewModel.isLoading) {
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
        institutionId: int.parse(_institutionIdController.text.trim()),
        taughtLanguages: _selectedLanguages.toList(),
        specializationAreas: specialties,
        bibliography: _biographyController.text,
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
  Widget build(BuildContext context) => AnimatedBuilder(
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
        child: _profileStep ? _profileForm() : _identityForm(),
      ),
    ),
  );

  Widget _identityForm() => Form(
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
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email institucional',
            hintText: 'professor@instituicao.edu',
            prefixIcon: Icon(Icons.mail_outline_rounded),
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

  Widget _profileForm() => Form(
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
        TextFormField(
          controller: _institutionIdController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'ID da instituição',
            helperText: 'Informe o ID numérico cadastrado no Duolinfo.',
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
          validator: (value) {
            final institutionId = int.tryParse(value?.trim() ?? '');
            if (institutionId == null || institutionId <= 0) {
              return 'Informe um ID numérico válido.';
            }
            return null;
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
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _languages.map((language) {
            final selected = _selectedLanguages.contains(language);
            return FilterChip(
              label: Text(language),
              selected: selected,
              onSelected: (value) => setState(() {
                value
                    ? _selectedLanguages.add(language)
                    : _selectedLanguages.remove(language);
              }),
              selectedColor: const Color(0xFFF0EAFE),
              checkmarkColor: const Color(0xFF7651C8),
              side: BorderSide(
                color: selected
                    ? const Color(0xFFC6B3F0)
                    : const Color(0xFFE1E4EC),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
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
