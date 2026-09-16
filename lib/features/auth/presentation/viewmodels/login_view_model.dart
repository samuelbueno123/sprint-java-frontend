import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out_from_google.dart';

/// Estado e ações da tela. Não depende de BuildContext ou widgets.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({
    required this._role,
    required this._signInWithGoogle,
    required this._signOutFromGoogle,
  }) {
    if (kIsWeb) {
      _userSubscription = _signInWithGoogle.onCurrentUserChanged.listen((
        account,
      ) async {
        if (account != null) {
          try {
            final auth = await account.authentication;
            if (auth.idToken != null) {
              await signInWithIdToken(auth.idToken!);
            }
          } catch (e) {
            _errorMessage = authenticationErrorMessage(e);
            notifyListeners();
          }
        }
      });
    }
  }

  final UserRole _role;
  final SignInWithGoogle _signInWithGoogle;
  final SignOutFromGoogle _signOutFromGoogle;

  StreamSubscription? _userSubscription;

  bool _isLoading = false;
  String? _errorMessage;
  AuthSession? _session;

  UserRole get role => _role;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthSession? get session => _session;

  Future<void> signInWithIdToken(String idToken) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = await _signInWithGoogle.withIdToken(idToken, _role);
    } catch (error) {
      _errorMessage = authenticationErrorMessage(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
