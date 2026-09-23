import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../auth_dependencies.dart';
import '../../domain/entities/auth_session.dart';
import '../viewmodels/login_view_model.dart';
import '../widgets/auth_page_frame.dart';
import '../widgets/google_sign_in_button.dart' as google_sign_in_button;
import 'registration_choice_page.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final LoginViewModel _viewModel;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  AuthSession? _handledSession;

  @override
  void initState() {
    super.initState();
    _viewModel = AuthDependencies.createLoginViewModel();
    _viewModel.addListener(_onViewModelChanged);
    if (kIsWeb &&
        AppConfig.googleWebClientId.isNotEmpty &&
        AppConfig.hasValidApiBaseUrl) {
      _viewModel.listenForGoogleWebSignIn();
    }
  }

  void _onViewModelChanged() {
    final session = _viewModel.session;
    if (session == null || identical(session, _handledSession) || !mounted) {
      return;
    }
    _handledSession = session;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardPage()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    if (!_formKey.currentState!.validate() || _viewModel.isLoading) return;
    await _viewModel.signInWithPassword(
      _emailController.text,
      _passwordController.text,
    );
  }

  Future<void> _submitGoogle() async {
    if (_viewModel.isLoading || !AppConfig.hasValidApiBaseUrl) return;
    await _viewModel.signInWithGoogle();
  }

  Widget _buildGoogleButton() {
    if (_viewModel.isLoading) {
      return const Center(
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (kIsWeb &&
        AppConfig.googleWebClientId.isNotEmpty &&
        AppConfig.hasValidApiBaseUrl) {
      return google_sign_in_button.buildGoogleSignInWebButton();
    }

    return OutlinedButton.icon(
      onPressed: !AppConfig.hasValidApiBaseUrl ? null : _submitGoogle,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF303442),
        side: const BorderSide(color: Color(0xFFDDE1EA)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const _GoogleGlyph(),
      label: const Text('Continuar com Google'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) => AuthPageFrame(
        title: 'Entrar',
        subtitle: 'Acesse sua conta com email, senha ou Google.',
        accentColor: const Color(0xFF5869D8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'seu@email.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Informe seu email.';
                  if (!email.contains('@') || !email.contains('.')) {
                    return 'Informe um email válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submitPassword(),
                decoration: InputDecoration(
                  labelText: 'Senha',
                  hintText: 'Sua senha',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Mostrar senha'
                        : 'Ocultar senha',
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
                    (value?.isEmpty ?? true) ? 'Informe sua senha.' : null,
              ),
              if (!AppConfig.hasValidApiBaseUrl) ...[
                const SizedBox(height: 14),
                const _InlineMessage(
                  message: 'A API ainda não está configurada neste ambiente.',
                  isError: true,
                ),
              ],
              if (_viewModel.errorMessage != null) ...[
                const SizedBox(height: 14),
                _InlineMessage(
                  message: _viewModel.errorMessage!,
                  isError: true,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed:
                      _viewModel.isLoading || !AppConfig.hasValidApiBaseUrl
                      ? null
                      : _submitPassword,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5869D8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _viewModel.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login_rounded, size: 19),
                  label: Text(_viewModel.isLoading ? 'Entrando…' : 'Entrar'),
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFFE7E9F0))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'ou continue com',
                      style: TextStyle(color: Color(0xFF8A8FA1), fontSize: 12),
                    ),
                  ),
                  Expanded(child: Divider(color: Color(0xFFE7E9F0))),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(height: 50, child: _buildGoogleButton()),
              const SizedBox(height: 20),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Ainda não tem perfil? ',
                      style: TextStyle(color: Color(0xFF73788B), fontSize: 13),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegistrationChoicePage(),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF5869D8),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Cadastre-se',
                        style: TextStyle(fontWeight: FontWeight.w700),
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

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    child: Text(
      'G',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFB42318) : const Color(0xFF21845A);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Text(message, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}
