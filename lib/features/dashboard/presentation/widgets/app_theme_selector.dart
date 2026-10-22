import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale_controller.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/session_store.dart';
import '../../../../core/theme/app_theme_controller.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';

class AppThemeSelector extends StatelessWidget {
  const AppThemeSelector({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: AppThemeController.mode,
    builder: (context, mode, _) => DropdownButtonFormField<ThemeMode>(
      key: ValueKey<ThemeMode>(mode),
      initialValue: mode,
      decoration: InputDecoration(
        labelText: AppLocaleController.tr(
          pt: 'Tema da interface',
          en: 'Interface theme',
          es: 'Tema de la interfaz',
        ),
      ),
      items: [
        DropdownMenuItem(
          value: ThemeMode.light,
          child: Text(
            AppLocaleController.tr(pt: 'Claro', en: 'Light', es: 'Claro'),
          ),
        ),
        DropdownMenuItem(
          value: ThemeMode.dark,
          child: Text(
            AppLocaleController.tr(pt: 'Escuro', en: 'Dark', es: 'Oscuro'),
          ),
        ),
      ],
      onChanged: (value) async {
        if (value == null) return;
        await AppThemeController.setMode(value);
        if (SessionStore.hasSession) {
          try {
            final ds = DashboardRemoteDataSource(ApiClient().dio);
            await ds.updateMyPreferences(
              themeMode: value == ThemeMode.dark ? 'dark' : 'light',
            );
          } catch (_) {
            // Local theme preference remains saved even if offline.
          }
        }
      },
    ),
  );
}
