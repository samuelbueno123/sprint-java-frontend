import 'package:flutter/foundation.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out_from_google.dart';

/// Estado e ações da tela. Não depende de BuildContext ou widgets.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({
    required UserRole role,
    required SignInWithGoogle signInWithGoogle,
    required SignOutFromGoogle signOutFromGoogle,
  })  : _role = role,
        _signInWithGoogle = signInWithGoogle,
        _signOutFromGoogle = signOutFromGoogle;

  final UserRole _role;
  final SignInWithGoogle _signInWithGoogle;
  final SignOutFromGoogle _signOutFromGoogle;

  bool _isLoading = false;
  String? _errorMessage;
  AuthSession? _session;

  UserRole get role => _role;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthSession? get session => _session;

  Future<void> signIn() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = await _signInWithGoogle(_role);
    } catch (error) {
      _errorMessage = authenticationErrorMessage(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _signOutFromGoogle();
    _session = null;
    _errorMessage = null;
    notifyListeners();
  }
}
