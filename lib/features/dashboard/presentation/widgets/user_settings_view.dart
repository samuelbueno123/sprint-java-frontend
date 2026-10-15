import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_data.dart';
import 'app_user_avatar.dart';
import 'edit_profile_dialogs.dart';
import 'app_theme_selector.dart';
import 'responsive_layout.dart';

class UserSettingsView extends StatefulWidget {
  const UserSettingsView({
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
  State<UserSettingsView> createState() => _UserSettingsViewState();
}

class _UserSettingsViewState extends State<UserSettingsView> {
  // Notification states
  bool _notifDaily = true;
  bool _notifAchievement = true;
  bool _notifRanking = false;
  bool _notifUpdates = true;

  // Preferences
  String _language = 'pt';

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF5869D8);
    final isGoogleAccount = widget.data.user.googleId.isNotEmpty;

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner de Cabeçalho Elegante
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5869D8), Color(0xFF7651C8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5869D8).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
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
                      label: Text('Voltar ao Perfil'),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: isCompactLayout(context) ? 220 : 300,
                      child: Text(
                        'Configurações da Conta',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Card 1: Perfil e Foto do Usuário
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: responsiveCardPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_circle_outlined,
                            color: brandColor,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Foto e Identidade Visual',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: brandColor,
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
                            backgroundColor: brandColor.withValues(alpha: .15),
                            textColor: brandColor,
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.data.user.email,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isGoogleAccount
                                        ? const Color(0xFFEAF2FF)
                                        : const Color(0xFFF0F2F6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isGoogleAccount
                                        ? 'Vinculado ao Google'
                                        : 'Conta Duolinfo',
                                    style: TextStyle(
                                      color: isGoogleAccount
                                          ? const Color(0xFF3579E8)
                                          : const Color(0xFF555B6E),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
                          foregroundColor: brandColor,
                          side: const BorderSide(color: brandColor),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: Text('Alterar Foto de Perfil'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card 2: Informações Pessoais
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: responsiveCardPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            color: brandColor,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Informações Pessoais',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: brandColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _DetailRow(
                        label: 'Nome completo',
                        value: widget.data.user.name,
                        icon: Icons.person_outline_rounded,
                      ),
                      const Divider(height: 16, color: Color(0xFFF0F2F6)),
                      _DetailRow(
                        label: 'E-mail',
                        value: widget.data.user.email,
                        icon: Icons.email_outlined,
                        badge: isGoogleAccount ? 'Somente Leitura' : null,
                      ),
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
                          foregroundColor: brandColor,
                          side: const BorderSide(color: brandColor),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 20),
                        label: Text('Editar Nome e E-mail'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card 3: Segurança e Senha
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: responsiveCardPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.security_rounded,
                            color: brandColor,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Segurança e Senha',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: brandColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Mantenha sua conta protegida redefinindo sua senha de acesso periodicamente.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => ChangePasswordDialog.show(
                          context,
                          data: widget.data,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: brandColor,
                          side: const BorderSide(color: brandColor),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.lock_reset_rounded, size: 20),
                        label: Text('Alterar Senha de Acesso'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card 4: Preferências do Aplicativo
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: responsiveCardPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune_rounded, color: brandColor, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Preferências do Aplicativo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: brandColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Idioma da Interface',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _language,
                            decoration: _inputDecoration('Idioma'),
                            items: const [
                              DropdownMenuItem(
                                value: 'pt',
                                child: Text('Português (Brasil)'),
                              ),
                              DropdownMenuItem(
                                value: 'en',
                                child: Text('English'),
                              ),
                              DropdownMenuItem(
                                value: 'es',
                                child: Text('Español'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _language = val);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          const AppThemeSelector(),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Notificações por Email',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _notifDaily,
                        activeColor: brandColor,
                        title: Text(
                          'Lembretes Diários de Estudo',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          'Receba lembretes para manter sua rotina de estudos.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onChanged: (val) => setState(() => _notifDaily = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: _notifAchievement,
                        activeColor: brandColor,
                        title: Text(
                          'Conquistas e Progresso',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          'Acompanhe novas conquistas e seu progresso de aprendizagem.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onChanged: (val) =>
                            setState(() => _notifAchievement = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: _notifRanking,
                        activeColor: brandColor,
                        title: Text(
                          'Atualizações de Ranking e Ligas',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          'Receba atualizações sobre sua posição no ranking.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onChanged: (val) => setState(() => _notifRanking = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: _notifUpdates,
                        activeColor: brandColor,
                        title: Text(
                          'Novidades e Atualizações da Plataforma',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          'Fique por dentro de novidades e melhorias do Duolinfo.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onChanged: (val) => setState(() => _notifUpdates = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Encerramento de sessão
              Center(
                child: TextButton.icon(
                  onPressed: widget.onLogout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                  ),
                  label: Text(
                    'Sair da Conta',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E8EF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E8EF)),
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
  });

  final String label;
  final String value;
  final IconData icon;
  final String? badge;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF5869D8)),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Não informado' : value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    ),
  );
}
