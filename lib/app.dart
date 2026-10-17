import 'package:flutter/material.dart';

import 'core/theme/app_theme_controller.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'core/network/session_store.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: AppThemeController.mode,
    builder: (context, themeMode, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Duolinfo',
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3579E8)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        cardTheme: const CardThemeData(color: Colors.white),
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
            borderSide: const BorderSide(color: Color(0xFF5869D8), width: 1.5),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
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
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF242A35),
          selectedColor: const Color(0xFF3579E8),
          labelStyle: const TextStyle(color: Colors.white),
          secondaryLabelStyle: const TextStyle(color: Colors.white),
          side: const BorderSide(color: Color(0xFF3A4352)),
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
            borderSide: const BorderSide(color: Color(0xFF8CAEFF), width: 1.5),
          ),
        ),
      ),
      home: SessionStore.hasSession ? const DashboardPage() : const LoginPage(),
    ),
  );
}
