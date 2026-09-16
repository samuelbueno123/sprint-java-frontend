import '../repositories/dashboard_repository.dart';

class Logout {
  const Logout(this._repository);

  final DashboardRepository _repository;

  Future<void> call() => _repository.logout();
}
