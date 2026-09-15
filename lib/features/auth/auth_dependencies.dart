import '../../core/network/api_client.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/datasources/google_identity_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/entities/user_role.dart';
import 'domain/usecases/sign_in_with_google.dart';
import 'domain/usecases/sign_out_from_google.dart';
import 'presentation/viewmodels/login_view_model.dart';

/// Ponto de composição da feature de autenticação.
class AuthDependencies {
  AuthDependencies._();

  static LoginViewModel createLoginViewModel(UserRole role) {
    final remote = AuthRemoteDataSource(ApiClient().dio);
    final repository = AuthRepositoryImpl(GoogleIdentityDataSource(), remote);
    return LoginViewModel(
      role: role,
      signInWithGoogle: SignInWithGoogle(repository),
      signOutFromGoogle: SignOutFromGoogle(repository),
    );
  }
}
