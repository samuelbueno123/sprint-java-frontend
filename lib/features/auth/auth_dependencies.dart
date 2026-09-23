import '../../core/network/api_client.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/usecases/sign_in_with_google.dart';
import 'domain/usecases/sign_in_with_password.dart';
import 'presentation/viewmodels/login_view_model.dart';
import 'presentation/viewmodels/registration_view_model.dart';

/// Ponto de composição da feature de autenticação.
class AuthDependencies {
  AuthDependencies._();

  static LoginViewModel createLoginViewModel() {
    final remote = AuthRemoteDataSource(ApiClient().dio);
    final repository = AuthRepositoryImpl(remote);
    return LoginViewModel(
      SignInWithPassword(repository),
      SignInWithGoogle(repository),
    );
  }

  static RegistrationViewModel createRegistrationViewModel() =>
      RegistrationViewModel(AuthRemoteDataSource(ApiClient().dio));
}
