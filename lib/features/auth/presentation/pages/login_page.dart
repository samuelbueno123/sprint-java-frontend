import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../auth_dependencies.dart';
import '../../domain/entities/user_role.dart';
import '../viewmodels/login_view_model.dart';
import '../widgets/google_account_card.dart';
import '../widgets/google_sign_in_button_stub.dart'
    if (dart.library.html) '../widgets/google_sign_in_button_web.dart';

import '../../../dashboard/presentation/pages/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.role,
    required this.primaryColor,
    required this.icon,
  });

  final UserRole role;
  final Color primaryColor;
  final IconData icon;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final LoginViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AuthDependencies.createLoginViewModel(widget.role);
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (_viewModel.session != null && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) => Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _viewModel.session == null
                    ? _loginCard()
                    : GoogleAccountCard(
                        user: _viewModel.session!.user,
                        color: widget.primaryColor,
                        onSignOut: _viewModel.signOut,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginCard() => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(widget.icon, color: widget.primaryColor, size: 64),
          const SizedBox(height: 20),
          Text(
            'Entrar como ${widget.role.label}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Text(
            'Continue com Google. A identidade, o perfil e as permissões são validados pelo backend.',
            textAlign: TextAlign.center,
          ),
          if (!AppConfig.hasValidApiBaseUrl) ...[
            const SizedBox(height: 20),
            const Text(
              'Defina API_BASE_URL para este ambiente antes de autenticar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ],
          if (_viewModel.errorMessage != null) ...[
            const SizedBox(height: 20),
            Text(
              _viewModel.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 28),
          kIsWeb
              ? Center(child: buildGoogleSignInWebButton())
              : FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed:
                      _viewModel.isLoading || !AppConfig.hasValidApiBaseUrl
                      ? null
                      : _viewModel.signIn,
                  icon: _viewModel.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'G',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                  label: Text(
                    _viewModel.isLoading
                        ? 'AUTENTICANDO...'
                        : 'CONTINUAR COM GOOGLE',
                  ),
                ),
        ],
      ),
    ),
  );
}
