import '../../core/network/api_client.dart';
import '../auth/data/datasources/google_identity_datasource.dart';
import 'data/datasources/dashboard_remote_datasource.dart';
import 'data/repositories/dashboard_repository_impl.dart';
import 'domain/usecases/get_home_data.dart';
import 'domain/usecases/logout.dart';
import 'presentation/viewmodels/dashboard_view_model.dart';

class DashboardDependencies {
  DashboardDependencies._();

  static DashboardViewModel createDashboardViewModel() {
    final remoteDataSource = DashboardRemoteDataSource(ApiClient().dio);
    final googleIdentityDataSource = GoogleIdentityDataSource();
    final repository = DashboardRepositoryImpl(
      remoteDataSource,
      googleIdentityDataSource,
    );

    return DashboardViewModel(
      getHomeData: GetHomeData(repository),
      logout: Logout(repository),
    );
  }
}
