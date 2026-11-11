import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/localization/app_locale_controller.dart';
import 'core/theme/app_theme_controller.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'core/network/session_store.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: AppThemeController.mode,
    builder: (context, themeMode, _) => ValueListenableBuilder<String>(
      valueListenable: AppLocaleController.languageCode,
      builder: (context, langCode, _) => ShadApp(
        key: ValueKey<String>('app_locale_$langCode'),
        debugShowCheckedModeBanner: false,
        title: 'Duolinfo',
        themeMode: themeMode,
        theme: ShadThemeData(
          brightness: Brightness.light,
          colorScheme: const ShadSlateColorScheme.light(
            primary: Color(0xFF3579E8),
            background: Color(0xFFF7F8FC),
            card: Colors.white,
            border: Color(0xFFE1E4EC),
          ),
          radius: const BorderRadius.all(Radius.circular(12)),
        ),
        darkTheme: ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: const ShadSlateColorScheme.dark(
            primary: Color(0xFF7DA7FF),
            background: Color(0xFF10131A),
            card: Color(0xFF1B202A),
            border: Color(0xFF343B49),
          ),
          radius: const BorderRadius.all(Radius.circular(12)),
        ),
        materialThemeBuilder: (context, currentTheme) {
          final isDark = currentTheme.brightness == Brightness.dark;
          return isDark
              ? ThemeData(
                  brightness: Brightness.dark,
                  colorScheme:
                      ColorScheme.fromSeed(
                        seedColor: const Color(0xFF7DA7FF),
                        brightness: Brightness.dark,
                        surface: const Color(0xFF1B202A),
                      ).copyWith(
                        onSurface: Colors.white,
                        onSurfaceVariant: const Color(0xFFE2E8F0),
                        onPrimaryContainer: Colors.white,
                        onSecondaryContainer: Colors.white,
                      ),
                  useMaterial3: true,
                  scaffoldBackgroundColor: const Color(0xFF10131A),
                  cardTheme: const CardThemeData(color: Color(0xFF1B202A)),
                  dividerColor: const Color(0xFF343B49),
                  iconTheme: const IconThemeData(color: Colors.white),
                  textTheme: ThemeData.dark().textTheme.apply(
                    bodyColor: Colors.white,
                    displayColor: Colors.white,
                  ),
                  chipTheme: const ChipThemeData(
                    backgroundColor: Color(0xFF242A35),
                    selectedColor: Color(0xFF3579E8),
                    labelStyle: TextStyle(color: Colors.white),
                    secondaryLabelStyle: TextStyle(color: Colors.white),
                    side: BorderSide(color: Color(0xFF3A4352)),
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: const Color(0xFF242A35),
                    labelStyle: const TextStyle(color: Color(0xFFE2E8F0)),
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3A4352)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3A4352)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF8CAEFF),
                        width: 1.5,
                      ),
                    ),
                  ),
                  filledButtonTheme: FilledButtonThemeData(
                    style: ButtonStyle(
                      elevation: WidgetStateProperty.resolveWith(
                        (states) =>
                            states.contains(WidgetState.hovered) ? 6 : 1,
                      ),
                      shadowColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.hovered)
                            ? const Color(0xFF7DA7FF).withValues(alpha: 0.4)
                            : Colors.black45,
                      ),
                      mouseCursor: WidgetStateProperty.all(
                        SystemMouseCursors.click,
                      ),
                      shape: WidgetStateProperty.resolveWith(
                        (states) => RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: states.contains(WidgetState.hovered)
                              ? const BorderSide(
                                  color: Color(0xFF8CAEFF),
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  outlinedButtonTheme: OutlinedButtonThemeData(
                    style: ButtonStyle(
                      mouseCursor: WidgetStateProperty.all(
                        SystemMouseCursors.click,
                      ),
                      side: WidgetStateProperty.resolveWith(
                        (states) => BorderSide(
                          color: states.contains(WidgetState.hovered)
                              ? const Color(0xFF8CAEFF)
                              : const Color(0xFF3A4352),
                          width: states.contains(WidgetState.hovered)
                              ? 1.5
                              : 1.0,
                        ),
                      ),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                )
              : ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFF3579E8),
                  ),
                  useMaterial3: true,
                  scaffoldBackgroundColor: const Color(0xFFF7F8FC),
                  cardTheme: const CardThemeData(color: Colors.white),
                  filledButtonTheme: FilledButtonThemeData(
                    style: ButtonStyle(
                      elevation: WidgetStateProperty.resolveWith(
                        (states) =>
                            states.contains(WidgetState.hovered) ? 6 : 1,
                      ),
                      shadowColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.hovered)
                            ? const Color(0xFF3579E8).withValues(alpha: 0.35)
                            : Colors.black12,
                      ),
                      mouseCursor: WidgetStateProperty.all(
                        SystemMouseCursors.click,
                      ),
                      shape: WidgetStateProperty.resolveWith(
                        (states) => RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: states.contains(WidgetState.hovered)
                              ? const BorderSide(
                                  color: Color(0xFF3579E8),
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  outlinedButtonTheme: OutlinedButtonThemeData(
                    style: ButtonStyle(
                      mouseCursor: WidgetStateProperty.all(
                        SystemMouseCursors.click,
                      ),
                      side: WidgetStateProperty.resolveWith(
                        (states) => BorderSide(
                          color: states.contains(WidgetState.hovered)
                              ? const Color(0xFF3579E8)
                              : const Color(0xFFE1E4EC),
                          width: states.contains(WidgetState.hovered)
                              ? 1.5
                              : 1.0,
                        ),
                      ),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: const Color(0xFFF8F9FC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE1E4EC)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE1E4EC)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF5869D8),
                        width: 1.5,
                      ),
                    ),
                  ),
                );
        },
        home: SessionStore.hasSession
            ? const DashboardPage()
            : const LoginPage(),
      ),
    ),
  );
}
