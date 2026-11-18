import 'package:flutter/material.dart';

class _VividColorPair {
  const _VividColorPair(this.light, this.dark);

  final Color light;
  final Color dark;

  Color resolve(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// Centralized semantic palette ensuring icons across dashboards, sidebars,
/// metrics, achievements, and quick actions render with vivid, high-contrast
/// domain colors in both light and dark modes.
class VividIconPalette {
  VividIconPalette._();

  static const Color yellow = Color(0xFFEAB308);
  static const Color yellowBright = Color(0xFFFACC15);
  static const Color orange = Color(0xFFF97316);
  static const Color orangeBright = Color(0xFFFB923C);
  static const Color green = Color(0xFF16A34A);
  static const Color greenBright = Color(0xFF4ADE80);
  static const Color blue = Color(0xFF2563EB);
  static const Color sky = Color(0xFF0284C7);
  static const Color indigo = Color(0xFF4F46E5);
  static const Color purple = Color(0xFF7C3AED);
  static const Color violet = Color(0xFF9333EA);
  static const Color pink = Color(0xFFDB2777);
  static const Color cyan = Color(0xFF0891B2);
  static const Color teal = Color(0xFF0D9488);
  static const Color red = Color(0xFFDC2626);
  static const Color rose = Color(0xFFE11D48);
  static const Color amber = Color(0xFFD97706);

  static const _trophyPair = _VividColorPair(yellow, yellowBright);
  static const _firePair = _VividColorPair(orange, orangeBright);
  static const _successPair = _VividColorPair(green, greenBright);
  static const _boltPair = _VividColorPair(purple, Color(0xFFA78BFA));
  static const _languagePair = _VividColorPair(sky, Color(0xFF38BDF8));
  static const _studyPair = _VividColorPair(blue, Color(0xFF60A5FA));
  static const _communityPair = _VividColorPair(indigo, Color(0xFF818CF8));
  static const _aiPair = _VividColorPair(violet, Color(0xFFC084FC));
  static const _voicePair = _VividColorPair(pink, Color(0xFFF472B6));
  static const _analyticsPair = _VividColorPair(cyan, Color(0xFF22D3EE));
  static const _tealPair = _VividColorPair(teal, Color(0xFF2DD4BF));
  static const _errorPair = _VividColorPair(red, Color(0xFFF87171));
  static const _alertActivePair = _VividColorPair(rose, Color(0xFFFB7185));
  static const _amberPair = _VividColorPair(amber, Color(0xFFFBBF24));

  static const List<_VividColorPair> _fallbackCycle = [
    _studyPair,
    _firePair,
    _successPair,
    _trophyPair,
    _aiPair,
    _analyticsPair,
    _voicePair,
    _tealPair,
  ];

  static final Map<int, _VividColorPair> _byCodePoint = <int, _VividColorPair>{
    // Troféus, medalhas, ranking, conquistas -> amarelo/ouro vívido
    Icons.emoji_events_rounded.codePoint: _trophyPair,
    Icons.emoji_events_outlined.codePoint: _trophyPair,
    Icons.military_tech_rounded.codePoint: _trophyPair,
    Icons.workspace_premium_rounded.codePoint: _trophyPair,
    Icons.workspace_premium_outlined.codePoint: _trophyPair,
    Icons.star_rounded.codePoint: _trophyPair,
    Icons.star_outline_rounded.codePoint: _trophyPair,
    Icons.stars_rounded.codePoint: _trophyPair,
    Icons.leaderboard_rounded.codePoint: _amberPair,

    // Fogo, sequência, progresso crescente -> laranja vívido
    Icons.local_fire_department_rounded.codePoint: _firePair,
    Icons.local_fire_department_outlined.codePoint: _firePair,
    Icons.whatshot_rounded.codePoint: _firePair,
    Icons.trending_up_rounded.codePoint: _firePair,

    // XP / energia / velocidade
    Icons.bolt_rounded.codePoint: _boltPair,
    Icons.electric_bolt_rounded.codePoint: _boltPair,
    Icons.flash_on_rounded.codePoint: _boltPair,

    // Acertos, concluídas, saúde, validação -> verde vívido
    Icons.task_alt_rounded.codePoint: _successPair,
    Icons.check_circle_rounded.codePoint: _successPair,
    Icons.check_circle_outline_rounded.codePoint: _successPair,
    Icons.check_circle_outline.codePoint: _successPair,
    Icons.check_rounded.codePoint: _successPair,
    Icons.verified_rounded.codePoint: _successPair,
    Icons.verified_user_rounded.codePoint: _successPair,
    Icons.fact_check_rounded.codePoint: _successPair,
    Icons.fact_check_outlined.codePoint: _successPair,
    Icons.assignment_turned_in_rounded.codePoint: _successPair,
    Icons.done_all_rounded.codePoint: _successPair,
    Icons.gps_fixed_rounded.codePoint: _successPair,
    Icons.track_changes_rounded.codePoint: _successPair,
    Icons.monitor_heart_rounded.codePoint: _successPair,
    Icons.health_and_safety_rounded.codePoint: _successPair,
    Icons.add_circle_outline_rounded.codePoint: _successPair,
    Icons.post_add_rounded.codePoint: _successPair,
    Icons.add_rounded.codePoint: _successPair,

    // Idiomas e tradução -> azul ciano vívido
    Icons.language_rounded.codePoint: _languagePair,
    Icons.translate_rounded.codePoint: _languagePair,
    Icons.public_rounded.codePoint: _languagePair,
    Icons.history_rounded.codePoint: _languagePair,
    Icons.schedule_rounded.codePoint: _languagePair,
    Icons.search_rounded.codePoint: _languagePair,
    Icons.mail_outline_rounded.codePoint: _languagePair,

    // Ensino, turmas, leitura -> azul real e índigo vívidos
    Icons.school_rounded.codePoint: _studyPair,
    Icons.school_outlined.codePoint: _studyPair,
    Icons.menu_book_rounded.codePoint: _studyPair,
    Icons.menu_book_outlined.codePoint: _studyPair,
    Icons.auto_stories_rounded.codePoint: _studyPair,
    Icons.library_books_outlined.codePoint: _studyPair,
    Icons.library_books_rounded.codePoint: _studyPair,
    Icons.class_rounded.codePoint: _studyPair,
    Icons.co_present_rounded.codePoint: _studyPair,
    Icons.assignment_outlined.codePoint: _studyPair,
    Icons.assignment_rounded.codePoint: _studyPair,
    Icons.home_rounded.codePoint: _studyPair,
    Icons.home_outlined.codePoint: _studyPair,

    // Grupos, comunidade e pessoas
    Icons.groups_rounded.codePoint: _communityPair,
    Icons.groups_outlined.codePoint: _communityPair,
    Icons.groups_2_outlined.codePoint: _communityPair,
    Icons.people_alt_rounded.codePoint: _communityPair,
    Icons.people_outline_rounded.codePoint: _communityPair,
    Icons.diversity_3_rounded.codePoint: _communityPair,
    Icons.person_rounded.codePoint: _communityPair,
    Icons.person_outline_rounded.codePoint: _communityPair,
    Icons.settings_rounded.codePoint: _communityPair,
    Icons.menu_rounded.codePoint: _communityPair,
    Icons.wc_rounded.codePoint: _communityPair,

    // IA, prática cognitiva e administração
    Icons.smart_toy_rounded.codePoint: _aiPair,
    Icons.auto_awesome_rounded.codePoint: _aiPair,
    Icons.psychology_rounded.codePoint: _aiPair,
    Icons.psychology_alt_rounded.codePoint: _aiPair,
    Icons.psychology_outlined.codePoint: _aiPair,
    Icons.security_rounded.codePoint: _boltPair,
    Icons.shield_rounded.codePoint: _boltPair,
    Icons.admin_panel_settings_rounded.codePoint: _boltPair,
    Icons.manage_accounts_rounded.codePoint: _boltPair,
    Icons.supervisor_account_rounded.codePoint: _boltPair,
    Icons.dashboard_customize_rounded.codePoint: _boltPair,
    Icons.dashboard_rounded.codePoint: _boltPair,
    Icons.dashboard_outlined.codePoint: _boltPair,
    Icons.lock_outline_rounded.codePoint: _boltPair,
    Icons.lock_reset_rounded.codePoint: _boltPair,

    // Pronúncia / voz / afeto -> magenta vívido
    Icons.record_voice_over_rounded.codePoint: _voicePair,
    Icons.mic_rounded.codePoint: _voicePair,
    Icons.volume_up_rounded.codePoint: _voicePair,
    Icons.favorite_rounded.codePoint: _voicePair,

    // Analytics / gráficos / métricas
    Icons.insights_rounded.codePoint: _analyticsPair,
    Icons.insights_outlined.codePoint: _analyticsPair,
    Icons.query_stats_rounded.codePoint: _analyticsPair,
    Icons.show_chart_rounded.codePoint: _analyticsPair,
    Icons.auto_graph_rounded.codePoint: _analyticsPair,
    Icons.speed_rounded.codePoint: _analyticsPair,
    Icons.storage_rounded.codePoint: _analyticsPair,
    Icons.table_view_rounded.codePoint: _analyticsPair,
    Icons.dataset_rounded.codePoint: _analyticsPair,

    // Trilhas / instituições / estrutura -> turquesa vívido
    Icons.route_rounded.codePoint: _tealPair,
    Icons.flag_rounded.codePoint: _tealPair,
    Icons.account_balance_rounded.codePoint: _tealPair,
    Icons.account_balance_outlined.codePoint: _tealPair,
    Icons.add_business_rounded.codePoint: _tealPair,
    Icons.widgets_rounded.codePoint: _tealPair,
    Icons.widgets_outlined.codePoint: _tealPair,

    // Notificações, anotações e catálogo -> âmbar/rosa vívidos
    Icons.notifications_active_rounded.codePoint: _alertActivePair,
    Icons.notifications_none_rounded.codePoint: _amberPair,
    Icons.notifications_rounded.codePoint: _amberPair,
    Icons.sticky_note_2_rounded.codePoint: _amberPair,
    Icons.celebration_rounded.codePoint: _amberPair,
    Icons.category_rounded.codePoint: _amberPair,
    Icons.folder_shared_rounded.codePoint: _amberPair,

    // Erros / avisos
    Icons.rule_folder_rounded.codePoint: _errorPair,
    Icons.error_outline_rounded.codePoint: _errorPair,
    Icons.warning_amber_rounded.codePoint: _amberPair,
  };

  /// Returns a vivid semantic color for [icon], adapting automatically for
  /// contrast across light and dark themes.
  static Color colorFor(
    IconData icon, {
    Brightness brightness = Brightness.light,
  }) {
    final pair =
        _byCodePoint[icon.codePoint] ??
        _fallbackCycle[icon.codePoint.abs() % _fallbackCycle.length];
    return pair.resolve(brightness);
  }

  /// Soft translucent badge tint paired with [colorFor].
  static Color containerColorFor(
    IconData icon, {
    Brightness brightness = Brightness.light,
  }) {
    final c = colorFor(icon, brightness: brightness);
    return c.withValues(alpha: brightness == Brightness.dark ? 0.24 : 0.14);
  }
}
