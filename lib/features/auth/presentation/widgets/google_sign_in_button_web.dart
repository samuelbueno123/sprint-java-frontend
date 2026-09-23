import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

Widget buildGoogleSignInWebButton() {
  return web.renderButton(
    configuration: web.GSIButtonConfiguration(
      locale: 'pt-BR',
      text: web.GSIButtonText.continueWith,
      theme: web.GSIButtonTheme.outline,
      shape: web.GSIButtonShape.rectangular,
      size: web.GSIButtonSize.large,
    ),
  );
}
