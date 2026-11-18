import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/realtime_sync_service.dart';
import '../../../../core/localization/app_locale_controller.dart';
import '../../../../core/theme/app_theme_controller.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
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
  final List<String> _sectionHistory = <String>[];
  UserProfileType? _activeProfileType;
  StreamSubscription<RealtimeSyncEvent>? _realtimeSubscription;
  bool _disposed = false;

  DashboardState get state => _state;
  String get activeSection => _activeSection;
  bool get canGoBack => _sectionHistory.isNotEmpty || _activeSection != 'profile';
  UserProfileType? get activeProfileType => _activeProfileType;

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

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
          case 'NOTIFICATION_UPDATED':
          case 'CLASS_ANNOUNCEMENT':
          case 'TEACHER_NOTE_ADDED':
          case 'CLASS_INVITED':
          case 'SUBMISSION_GRADED':
          case 'EXERCISE_CREATED':
          case 'EXERCISE_SUBMITTED':
          case 'RANKING_UPDATED':
          case 'SRS_REVIEW_COMPLETED':
          case 'INSTITUTION_REQUEST_DECIDED':
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
      if (_sectionHistory.length >= 20) {
        _sectionHistory.removeAt(0);
      }
      _sectionHistory.add(_activeSection);
      _activeSection = section;
      _notifySafely();
    }
  }

  bool goBack() {
    if (_sectionHistory.isNotEmpty) {
      _activeSection = _sectionHistory.removeLast();
      _notifySafely();
      return true;
    }
    if (_activeSection != 'profile') {
      _activeSection = 'profile';
      _notifySafely();
      return true;
    }
    return false;
  }

  void setActiveProfileType(UserProfileType profileType) {
    final currentState = _state;
    if (currentState is! DashboardSuccess ||
        !currentState.data.availableProfileTypes.contains(profileType)) {
      return;
    }
    if (_activeProfileType == profileType) return;
    _activeProfileType = profileType;
    _sectionHistory.clear();
    _activeSection = 'profile';
    _notifySafely();
  }

  Future<void> loadDashboardData({bool silent = false}) async {
    if (!silent) {
      _state = const DashboardLoading();
      _notifySafely();
    }

    try {
      final data = await getHomeData();
      if (_activeProfileType != null &&
          !data.availableProfileTypes.contains(_activeProfileType)) {
        _activeProfileType = null;
      }
      _state = DashboardSuccess(data);
      unawaited(_syncUserPreferences());
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
      _notifySafely();
    }
  }

  Future<void> _syncUserPreferences() async {
    try {
      final prefs = await DashboardRemoteDataSource(
        ApiClient().dio,
      ).getMyPreferences();
      final themeStr = prefs['themeMode']?.toString().toLowerCase();
      if (themeStr == 'dark' || themeStr == 'light') {
        await AppThemeController.setMode(
          themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light,
        );
      }
      final lang = prefs['uiLanguage']?.toString();
      if (lang != null && lang.isNotEmpty) {
        await AppLocaleController.setLanguageCode(
          AppLocaleController.normalizeCode(lang),
        );
      }
    } catch (_) {
      // Ignora falha de sincronização de preferências em background
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
    _disposed = true;
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
