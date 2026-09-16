import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/config/app_config.dart';

/// Isola as particularidades do SDK Google por plataforma fora da UI e da feature.
class GoogleIdentityDataSource {
  GoogleIdentityDataSource()
    : _googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile', 'openid'],
        clientId: kIsWeb
            ? AppConfig.googleWebClientId
            : defaultTargetPlatform == TargetPlatform.iOS
            ? AppConfig.googleIosClientId
            : null,
        serverClientId: kIsWeb ? null : AppConfig.googleServerClientId,
      );

  final GoogleSignIn _googleSignIn;

  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _googleSignIn.onCurrentUserChanged;

  bool get isConfigured {
    if (AppConfig.googleServerClientId.isEmpty) return false;
    if (kIsWeb) return AppConfig.googleWebClientId.isNotEmpty;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppConfig.googleIosClientId.isNotEmpty;
    }
    // Android, desktop e dispositivo físico usam a configuração nativa do Google.
    return true;
  }

  Future<String?> authenticateAndGetIdToken() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    return (await account.authentication).idToken;
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
