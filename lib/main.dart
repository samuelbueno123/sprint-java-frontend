import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/localization/app_locale_controller.dart';
import 'core/network/session_store.dart';
import 'core/theme/app_theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionStore.initialize();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // `--dart-define` remains available for builds that do not ship a .env.
  }
  try {
    await AppThemeController.load();
    await AppLocaleController.load();
  } catch (_) {
    // Use default theme/locale if local preference storage is unavailable.
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const App();
}
