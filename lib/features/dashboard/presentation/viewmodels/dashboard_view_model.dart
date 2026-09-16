import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/usecases/get_home_data.dart';
import '../../domain/usecases/logout.dart';
import 'dashboard_state.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({required this.getHomeData, required this.logout}) {
    loadDashboardData();
  }

  final GetHomeData getHomeData;
  final Logout logout;

  DashboardState _state = const DashboardInitial();
  String _activeSection = 'home';

  DashboardState get state => _state;
  String get activeSection => _activeSection;

  void setActiveSection(String section) {
    if (_activeSection != section) {
      _activeSection = section;
      notifyListeners();
    }
  }

  Future<void> loadDashboardData() async {
    _state = const DashboardLoading();
    notifyListeners();

    try {
      final data = await getHomeData();
      _state = DashboardSuccess(data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        _state = const DashboardError(
          'Sessão expirada ou não autorizada. Por favor, acesse novamente.',
          isUnauthorized: true,
        );
      } else {
        _state = const DashboardError(
          'Falha na conexão com o servidor. Verifique a API.',
        );
      }
    } catch (e) {
      _state = DashboardError('Erro ao carregar dashboard: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> performLogout() async {
    try {
      await logout();
    } catch (_) {
      // Ignora falhas de logout no servidor para garantir limpeza do cliente
    }
  }
}
