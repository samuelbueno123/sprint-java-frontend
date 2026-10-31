import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale_controller.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme_controller.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../domain/entities/dashboard_data.dart';
import 'app_theme_selector.dart';
import 'app_user_avatar.dart';
import 'edit_profile_dialogs.dart';
import 'responsive_layout.dart';

class TeacherSettingsView extends StatefulWidget {
  const TeacherSettingsView({
    super.key,
    required this.data,
    required this.onBackToProfile,
    required this.onLogout,
    this.onRefresh,
  });

  final DashboardData data;
  final VoidCallback onBackToProfile;
  final VoidCallback onLogout;
  final VoidCallback? onRefresh;

  @override
  State<TeacherSettingsView> createState() => _TeacherSettingsViewState();
}

class _TeacherSettingsViewState extends State<TeacherSettingsView> {
  // Notification states
  bool _notifAssignments = true;
  bool _notifStudents = true;
  bool _notifDaily = true;

  // Preferences
  String _language = AppLocaleController.languageCode.value;
  bool _externalEmailConfigured = false;
  String? _channelNotice;
  bool _savingPrefs = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final ds = DashboardRemoteDataSource(ApiClient().dio);
      final prefs = await ds.getMyPreferences();
      if (!mounted || prefs.isEmpty) return;
      final lang = AppLocaleController.normalizeCode(
        prefs['uiLanguage']?.toString(),
      );
      final externalEmail = prefs['externalEmailConfigured'] == true;
      final themeStr = prefs['themeMode']?.toString().toLowerCase();
      if (themeStr == 'dark' || themeStr == 'light') {
        await AppThemeController.setMode(
          themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light,
        );
      }
      await AppLocaleController.setLanguageCode(lang);
      if (!mounted) return;
      setState(() {
        _language = lang;
        _externalEmailConfigured = externalEmail;
        _notifAssignments = prefs['notifClassUpdates'] != false;
        _notifStudents = prefs['notifAchievements'] != false;
        _notifDaily = prefs['notifDailyReminders'] != false;
        _channelNotice = prefs['notificationChannelNotice']?.toString();
      });
    } catch (_) {
      // Keep current local state if offline.
    }
  }

  Future<void> _savePreferences({
    String? uiLanguage,
    bool? notifDailyReminders,
    bool? notifAchievements,
    bool? notifClassUpdates,
  }) async {
    setState(() => _savingPrefs = true);
    try {
      final ds = DashboardRemoteDataSource(ApiClient().dio);
      final updated = await ds.updateMyPreferences(
        uiLanguage: uiLanguage,
        notifDailyReminders: notifDailyReminders,
        notifAchievements: notifAchievements,
        notifClassUpdates: notifClassUpdates,
      );
      if (mounted) {
        setState(() {
          if (updated['externalEmailConfigured'] != null) {
            _externalEmailConfigured =
                updated['externalEmailConfigured'] == true;
          }
          if (updated['notificationChannelNotice'] != null) {
            _channelNotice = updated['notificationChannelNotice']?.toString();
          }
        });
      }
      widget.onRefresh?.call();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar a preferência no servidor.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  InputDecoration _inputDecoration(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const purpleColor = Color(0xFF7651C8);
    final isGoogleAccount = widget.data.user.googleId.isNotEmpty;
    final roleWord = widget.data.isFemale ? 'Professora' : 'Professor';
    final institutionName = widget.data.teacherProfile?.institution;
    final taughtLanguages = widget.data.teacherProfile?.taughtLanguages ?? const [];

    final cardBg = isDark
        ? const Color(0xFF1E293B)
        : Theme.of(context).cardTheme.color ?? Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF334155)
        : Theme.of(context).colorScheme.outlineVariant;
    final primaryTextColor = isDark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final secondaryTextColor = isDark ? const Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant;

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Floating Header Banner
              Container(
                padding: responsiveBannerPadding(context),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7651C8), Color(0xFF4C2A9B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7651C8).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onBackToProfile,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text(
                        AppLocaleController.tr(
                          pt: 'Voltar',
                          en: 'Back',
                          es: 'Volver',
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocaleController.tr(
                              pt: 'Configurações de $roleWord',
                              en: 'Teacher Settings',
                              es: 'Configuración Docente',
                            ),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Gerencie seu perfil docente, idioma, tema e alertas.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_savingPrefs)
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Salvo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Card 1: Perfil do Professor
              Card(
                elevation: 0,
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: cardBorder),
                ),
                child: Padding(
                  padding: responsiveCardPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.co_present_rounded,
                            color: purpleColor,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Perfil de $roleWord',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: purpleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          AppUserAvatar(
                            name: widget.data.user.name,
                            pictureUrl: widget.data.user.picture,
                            radius: 38,
                            backgroundColor: purpleColor.withValues(alpha: .15),
                            textColor: purpleColor,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.data.user.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.data.user.email,
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? purpleColor.withValues(alpha: 0.22)
                                            : const Color(0xFFF0EAFE),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$roleWord Credenciado(a)',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : purpleColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        widget.data.isFemale ? 'Tratamento: Feminino' : 'Tratamento: Masculino',
                                        style: TextStyle(
                                          color: secondaryTextColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () => EditProfilePictureDialog.show(
                          context,
                          data: widget.data,
                          onSaved: () {
                            setState(() {});
                            widget.onRefresh?.call();
                          },
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: purpleColor,
                          side: const BorderSide(color: purpleColor),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('Alterar Foto de Perfil'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card 2: Informações Pessoais & Instituição
              Card(
                elevation: 0,
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: cardBorder),
                ),
                child: Padding(
                  padding: responsiveCardPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            color: purpleColor,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Informações Docentes',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: purpleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _DetailRow(
                        label: 'Nome completo',
                        value: widget.data.user.name,
                        icon: Icons.person_outline_rounded,
                        isDark: isDark,
                      ),
                      Divider(height: 16, color: cardBorder),
                      _DetailRow(
                        label: 'E-mail',
                        value: widget.data.user.email,
                        icon: Icons.email_outlined,
                        badge: isGoogleAccount ? 'Somente Leitura' : null,
                        isDark: isDark,
                      ),
                      Divider(height: 16, color: cardBorder),
                      _DetailRow(
                        label: 'Gênero / Tratamento',
                        value: widget.data.isFemale ? 'Feminino (Professora)' : 'Masculino (Professor)',
                        icon: Icons.person_search_rounded,
                        isDark: isDark,
                      ),
                      if (institutionName != null && institutionName.isNotEmpty) ...[
                        Divider(height: 16, color: cardBorder),
                        _DetailRow(
                          label: 'Instituição',
                          value: institutionName,
                          icon: Icons.account_balance_rounded,
                          isDark: isDark,
                        ),
                      ],
                      if (taughtLanguages.isNotEmpty) ...[
                        Divider(height: 16, color: cardBorder),
                        _DetailRow(
                          label: 'Idiomas lecionados',
                          value: taughtLanguages.join(', '),
                          icon: Icons.translate_rounded,
                          isDark: isDark,
                        ),
                      ],
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () => EditProfileDetailsDialog.show(
                          context,
                          data: widget.data,
                          onSaved: () {
                            setState(() {});
                            widget.onRefresh?.call();
                          },
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: purpleColor,
                          side: const BorderSide(color: purpleColor),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 20),
                        label: const Text('Editar Nome, E-mail e Gênero'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card 3: Segurança e Senha
              Card(
                elevation: 0,
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: cardBorder),
                ),
                child: Padding(
                  padding: responsiveCardPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.security_rounded,
                            color: purpleColor,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Segurança e Senha',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: purpleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isGoogleAccount
                            ? 'Sua conta docente está vinculada ao Google Identity.'
                            : 'Altere sua senha de acesso a qualquer momento.',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => ChangePasswordDialog.show(
                              context,
                              data: widget.data,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: purpleColor,
                              side: const BorderSide(color: purpleColor),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.lock_reset_rounded, size: 20),
                            label: Text(
                              isGoogleAccount
                                  ? 'Definir Senha Alternativa'
                                  : 'Alterar Senha de Acesso',
                            ),
                          ),
                          if (!isGoogleAccount)
                            TextButton.icon(
                              onPressed: () => ForgotPasswordDialog.show(
                                context,
                                initialEmail: widget.data.user.email,
                              ),
                              icon: const Icon(Icons.vpn_key_outlined, size: 18),
                              label: const Text('Recuperar ou Redefinir Senha'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card 4: Preferências de Interface
              Card(
                elevation: 0,
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: cardBorder),
                ),
                child: Padding(
                  padding: responsiveCardPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.palette_outlined, color: purpleColor, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Preferências da Interface',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: purpleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocaleController.tr(
                          pt: 'Idioma da Interface',
                          en: 'Interface Language',
                          es: 'Idioma de la Interfaz',
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: ValueKey<String>('lang_$_language'),
                        initialValue: _language,
                        isExpanded: true,
                        decoration: _inputDecoration(context, 'Idioma'),
                        items: const [
                          DropdownMenuItem(
                            value: 'pt',
                            child: Text('Português (Brasil)'),
                          ),
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'es', child: Text('Español')),
                        ],
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() => _language = val);
                            await AppLocaleController.setLanguageCode(val);
                            await _savePreferences(uiLanguage: val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      const AppThemeSelector(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card 5: Notificações & Conectividade Docente
              Card(
                elevation: 0,
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: cardBorder),
                ),
                child: Padding(
                  padding: responsiveCardPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            color: purpleColor,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Notificações & Alertas Docentes',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: purpleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _externalEmailConfigured
                              ? (isDark
                                  ? const Color(0xFF065F46).withValues(alpha: 0.3)
                                  : const Color(0xFFECFDF5))
                              : (isDark
                                  ? const Color(0xFF78350F).withValues(alpha: 0.3)
                                  : const Color(0xFFFFFBEB)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _externalEmailConfigured
                                ? (isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0))
                                : (isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _externalEmailConfigured
                                  ? Icons.mark_email_read_rounded
                                  : Icons.info_outline_rounded,
                              size: 20,
                              color: _externalEmailConfigured
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _externalEmailConfigured
                                        ? 'Serviço de e-mail externo ativo'
                                        : 'Notificações salvas na plataforma',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white
                                          : (_externalEmailConfigured
                                              ? const Color(0xFF065F46)
                                              : const Color(0xFF92400E)),
                                    ),
                                  ),
                                  if (_channelNotice != null &&
                                      _channelNotice!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _channelNotice!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        value: _notifAssignments,
                        activeThumbColor: purpleColor,
                        title: Text(
                          'Novas Entregas de Alunos',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                        subtitle: Text(
                          'Receba alertas quando os estudantes enviarem respostas das tarefas.',
                          style: TextStyle(color: secondaryTextColor, fontSize: 12),
                        ),
                        onChanged: (val) {
                          setState(() => _notifAssignments = val);
                          _savePreferences(notifClassUpdates: val);
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      Divider(height: 8, color: cardBorder),
                      SwitchListTile(
                        value: _notifStudents,
                        activeThumbColor: purpleColor,
                        title: Text(
                          'Conquistas e Marcos das Turmas',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                        subtitle: Text(
                          'Notificações sobre o progresso e conquistas dos estudantes.',
                          style: TextStyle(color: secondaryTextColor, fontSize: 12),
                        ),
                        onChanged: (val) {
                          setState(() => _notifStudents = val);
                          _savePreferences(notifAchievements: val);
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      Divider(height: 8, color: cardBorder),
                      SwitchListTile(
                        value: _notifDaily,
                        activeThumbColor: purpleColor,
                        title: Text(
                          'Lembretes Diários do Sistema',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                        subtitle: Text(
                          'Resumo diário de atividades pendentes de correção.',
                          style: TextStyle(color: secondaryTextColor, fontSize: 12),
                        ),
                        onChanged: (val) {
                          setState(() => _notifDaily = val);
                          _savePreferences(notifDailyReminders: val);
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Ações da Conta: Logout e Exclusão
              Card(
                elevation: 0,
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: cardBorder),
                ),
                child: Padding(
                  padding: responsiveCardPadding(context),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.onLogout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: Text(
                          AppLocaleController.tr(
                            pt: 'Sair da Conta',
                            en: 'Sign Out',
                            es: 'Cerrar Sesión',
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => DeleteAccountDialog.show(
                          context,
                          data: widget.data,
                          onAccountDeleted: widget.onLogout,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFFFCA5A5) : Colors.red.shade700,
                        ),
                        icon: const Icon(Icons.delete_forever_rounded, size: 18),
                        label: Text(
                          AppLocaleController.tr(
                            pt: 'Excluir Conta Permanentemente',
                            en: 'Delete Account Permanently',
                            es: 'Eliminar Cuenta Permanentemente',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.badge,
    required this.isDark,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? badge;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF7651C8)),
        const SizedBox(width: 12),
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Não informado' : value,
            style: TextStyle(
              color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF0F2F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    ),
  );
}
