import '../entities/dashboard_data.dart';
import '../repositories/dashboard_repository.dart';

class GetHomeData {
  const GetHomeData(this._repository);

  final DashboardRepository _repository;

  Future<DashboardData> call() => _repository.getDashboardData();
}
