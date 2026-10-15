import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_controller.dart';

class AppThemeSelector extends StatelessWidget {
  const AppThemeSelector({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: AppThemeController.mode,
    builder: (context, mode, _) => DropdownButtonFormField<ThemeMode>(
      initialValue: mode,
      decoration: const InputDecoration(labelText: 'Tema da interface'),
      items: const [
        DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
        DropdownMenuItem(value: ThemeMode.dark, child: Text('Escuro')),
      ],
      onChanged: (value) {
        if (value != null) AppThemeController.setMode(value);
      },
    ),
  );
}
