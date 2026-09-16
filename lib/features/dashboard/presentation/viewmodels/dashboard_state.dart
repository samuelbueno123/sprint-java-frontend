import '../../domain/entities/dashboard_data.dart';

sealed class DashboardState {
  const DashboardState();
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardSuccess extends DashboardState {
  const DashboardSuccess(this.data);

  final DashboardData data;
}

class DashboardError extends DashboardState {
  const DashboardError(this.message, {this.isUnauthorized = false});

  final String message;
  final bool isUnauthorized;
}
