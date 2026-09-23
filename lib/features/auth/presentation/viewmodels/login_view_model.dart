import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_in_with_password.dart';

/// Estado e ações da tela. Não depende de BuildContext ou widgets.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._signInWithPassword, this._signInWithGoogle);

  final SignInWithPassword _signInWithPassword;
  final SignInWithGoogle _signInWithGoogle;

  bool _isLoading = false;
  String? _errorMessage;
  AuthSession? _session;
  StreamSubscription<GoogleSignInAccount?>? _googleUserSubscription;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthSession? get session => _session;

  /// The GIS button owns the web popup, so web sign-in completes through this
  /// account stream instead of calling GoogleSignIn.signIn().
  void listenForGoogleWebSignIn() {
    _googleUserSubscription ??= _signInWithGoogle.onCurrentUserChanged.listen(
      _onGoogleUserChanged,
      onError: _onGoogleSignInError,
    );
  }

  void _onGoogleUserChanged(GoogleSignInAccount? account) {
    if (account == null || _isLoading || _session != null) return;
    unawaited(_exchangeGoogleIdToken(account));
  }

  Future<void> _exchangeGoogleIdToken(GoogleSignInAccount account) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final idToken = (await account.authentication).idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          'O Google não retornou um token de identidade.',
        );
      }
      _session = await _signInWithGoogle.withIdToken(idToken);
    } catch (error) {
      _errorMessage = authenticationErrorMessage(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onGoogleSignInError(Object error) {
    _errorMessage = authenticationErrorMessage(error);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signInWithPassword(String email, String password) async {
    if (_isLoading || _session != null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = await _signInWithPassword(email, password);
    } catch (error) {
      _errorMessage = authenticationErrorMessage(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    if (_isLoading || _session != null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = await _signInWithGoogle();
    } catch (error) {
      _errorMessage = authenticationErrorMessage(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    final subscription = _googleUserSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }
}
