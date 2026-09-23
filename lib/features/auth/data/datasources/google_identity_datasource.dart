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

  static bool get isConfiguredForCurrentPlatform {
    if (kIsWeb) return AppConfig.googleWebClientId.isNotEmpty;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppConfig.googleIosClientId.isNotEmpty &&
          AppConfig.googleServerClientId.isNotEmpty;
    }
    // Android, desktop e dispositivo físico usam a configuração nativa do Google.
    return AppConfig.googleServerClientId.isNotEmpty;
  }

  static String get missingConfigurationMessage {
    if (kIsWeb) {
      return 'Configure GOOGLE_WEB_CLIENT_ID com o mesmo cliente OAuth Web do backend.';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Configure GOOGLE_IOS_CLIENT_ID e GOOGLE_SERVER_CLIENT_ID.';
    }
    return 'Configure GOOGLE_SERVER_CLIENT_ID e as credenciais OAuth nativas.';
  }

  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _googleSignIn.onCurrentUserChanged;

  Future<String?> authenticateAndGetIdToken() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    return (await account.authentication).idToken;
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
