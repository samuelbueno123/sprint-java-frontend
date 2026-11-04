import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/realtime_sync_service.dart';
import '../../domain/entities/user_profile_type.dart';
import '../../domain/usecases/get_home_data.dart';
import '../../domain/usecases/logout.dart';
import 'dashboard_state.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({required this.getHomeData, required this.logout}) {
    loadDashboardData();
    _initRealtimeSync();
  }

  final GetHomeData getHomeData;
  final Logout logout;

  DashboardState _state = const DashboardInitial();
  String _activeSection = 'profile';
  UserProfileType? _activeProfileType;
  StreamSubscription<RealtimeSyncEvent>? _realtimeSubscription;

  DashboardState get state => _state;
  String get activeSection => _activeSection;
  UserProfileType? get activeProfileType => _activeProfileType;

  void _initRealtimeSync() {
    RealtimeSyncService.instance.connect();
    _realtimeSubscription = RealtimeSyncService.instance.events.listen(
      (event) {
        debugPrint(
          '[DashboardViewModel] Notificação em tempo real recebida: ${event.type}',
        );
        switch (event.type) {
          case 'PROFILE_UPDATED':
          case 'ENROLLMENT_UPDATED':
          case 'NOTIFICATION_ADDED':
          case 'SUBMISSION_GRADED':
          case 'EXERCISE_CREATED':
          case 'RANKING_UPDATED':
            // Recarrega os dados em background para manter a interface 100% síncrona
            loadDashboardData(silent: true);
            break;
        }
      },
      onError: (err) {
        debugPrint('[DashboardViewModel] Erro no stream de tempo real: $err');
      },
    );
  }

  void setActiveSection(String section) {
    if (_activeSection != section) {
      _activeSection = section;
      notifyListeners();
    }
  }

  void setActiveProfileType(UserProfileType profileType) {
    final currentState = _state;
    if (currentState is! DashboardSuccess ||
        !currentState.data.availableProfileTypes.contains(profileType)) {
      return;
    }
    if (_activeProfileType == profileType) return;
    _activeProfileType = profileType;
    _activeSection = 'profile';
    notifyListeners();
  }

  Future<void> loadDashboardData({bool silent = false}) async {
    if (!silent) {
      _state = const DashboardLoading();
      notifyListeners();
    }

    try {
      final data = await getHomeData();
      if (_activeProfileType != null &&
          !data.availableProfileTypes.contains(_activeProfileType)) {
        _activeProfileType = null;
      }
      _state = DashboardSuccess(data);
    } on DioException catch (e) {
      if (!silent) {
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
      }
    } catch (e) {
      if (!silent) {
        _state = DashboardError('Erro ao carregar dashboard: $e');
      }
    } finally {
      notifyListeners();
    }
  }

  Future<void> performLogout() async {
    try {
      RealtimeSyncService.instance.disconnect();
      await logout();
    } catch (_) {
      // Ignora falhas de logout no servidor para garantir limpeza do cliente
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
