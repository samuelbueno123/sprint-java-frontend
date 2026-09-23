import 'package:flutter/material.dart';

import '../../auth_dependencies.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../viewmodels/registration_view_model.dart';
import '../widgets/auth_page_frame.dart';

class StudentSignupPage extends StatefulWidget {
  const StudentSignupPage({super.key, this.initialEmail, this.initialName});

  final String? initialEmail;
  final String? initialName;

  @override
  State<StudentSignupPage> createState() => _StudentSignupPageState();
}

class _StudentSignupPageState extends State<StudentSignupPage> {
  static const _languages = [
    'Inglês',
    'Espanhol',
    'Francês',
    'Alemão',
    'Italiano',
    'Japonês',
  ];

  late final RegistrationViewModel _viewModel;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final Set<String> _selectedLanguages = {};
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

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
        languages: _selectedLanguages.toList(),
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
  Widget build(BuildContext context) => AnimatedBuilder(
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
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Informe seu nome.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'aluno@exemplo.com',
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
              'Idiomas de interesse',
              style: TextStyle(
                color: Color(0xFF33384A),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Escolha um ou mais idiomas para seu perfil.',
              style: TextStyle(color: Color(0xFF73788B), fontSize: 12),
            ),
            const SizedBox(height: 10),
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
                  selectedColor: const Color(0xFFE7F0FF),
                  checkmarkColor: const Color(0xFF3579E8),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF8FB5F5)
                        : const Color(0xFFE1E4EC),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
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
