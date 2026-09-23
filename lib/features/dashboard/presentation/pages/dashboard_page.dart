import 'package:flutter/material.dart';

import '../../../auth/presentation/pages/login_page.dart';
import '../../dashboard_dependencies.dart';
import '../viewmodels/dashboard_state.dart';
import '../viewmodels/dashboard_view_model.dart';
import '../widgets/dashboard_error_state.dart';
import '../widgets/dashboard_shell.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = DashboardDependencies.createDashboardViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    try {
      await _viewModel.performLogout();
    } catch (_) {
      // A saída local deve continuar disponível mesmo se a rede falhar.
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        final state = _viewModel.state;

        if (state is DashboardLoading || state is DashboardInitial) {
          return const Scaffold(
            backgroundColor: Color(0xFFF7F9FA),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF58CC02),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Carregando seu painel Duolinfo...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is DashboardError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF7F9FA),
            body: DashboardErrorState(
              message: state.message,
              onRetry: _viewModel.loadDashboardData,
              onBackToLogin: _handleLogout,
            ),
          );
        }

        if (state is DashboardSuccess) {
          return DashboardShell(
            data: state.data,
            activeSection: _viewModel.activeSection,
            onSectionSelected: _viewModel.setActiveSection,
            onLogout: _handleLogout,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
