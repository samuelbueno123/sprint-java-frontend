import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_data.dart';
import 'app_user_avatar.dart';
import 'edit_profile_dialogs.dart';

class StudentSettingsView extends StatefulWidget {
  const StudentSettingsView({
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
  State<StudentSettingsView> createState() => _StudentSettingsViewState();
}

class _StudentSettingsViewState extends State<StudentSettingsView> {
  // Notification states
  bool _notifDaily = true;
  bool _notifAchievement = true;
  bool _notifRanking = false;
  bool _notifTeacher = true;

  // Preferences
  String _language = 'pt';
  String _theme = 'light';
  String _dailyGoal = '10';

  @override
  Widget build(BuildContext context) {
    const blueColor = Color(0xFF3579E8);
    final isGoogleAccount = widget.data.user.googleId.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner de Cabeçalho Elegante (Azul)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3579E8), Color(0xFF1E52A8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3579E8).withValues(alpha: 0.25),
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
                      label: const Text('Voltar ao Perfil'),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Configurações do Aluno',
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

              // Card 1: Perfil do Estudante
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE5E8EF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.school_rounded,
                            color: blueColor,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Perfil do Estudante',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: blueColor,
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
                            backgroundColor: blueColor.withValues(alpha: .15),
                            textColor: blueColor,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.data.user.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: Color(0xFF252A3D),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.data.user.email,
                                  style: const TextStyle(
                                    color: Color(0xFF73788B),
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
                                    color: const Color(0xFFEAF2FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Estudante Ativo',
                                    style: TextStyle(
                                      color: blueColor,
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
                          foregroundColor: blueColor,
                          side: const BorderSide(color: blueColor),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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

              // Card 2: Informações Pessoais
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE5E8EF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            color: blueColor,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Informações Pessoais',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: blueColor,
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
                          foregroundColor: blueColor,
                          side: const BorderSide(color: blueColor),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 20),
                        label: const Text('Editar Nome e E-mail'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card 3: Segurança e Senha
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE5E8EF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.security_rounded,
                            color: blueColor,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Segurança e Senha',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: blueColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Altere sua senha de acesso a qualquer momento.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF73788B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => ChangePasswordDialog.show(
                          context,
                          data: widget.data,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: blueColor,
                          side: const BorderSide(color: blueColor),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.lock_reset_rounded, size: 20),
                        label: const Text('Alterar Senha de Acesso'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card 4: Preferências de Estudo
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE5E8EF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune_rounded, color: blueColor, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Preferências de Estudo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: blueColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Meta Diária de Estudos',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF252A3D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _dailyGoal,
                        decoration: _inputDecoration('Meta'),
                        items: const [
                          DropdownMenuItem(
                            value: '5',
                            child: Text('5 minutos / dia (Casual)'),
                          ),
                          DropdownMenuItem(
                            value: '10',
                            child: Text('10 minutos / dia (Regular)'),
                          ),
                          DropdownMenuItem(
                            value: '15',
                            child: Text('15 minutos / dia (Sério)'),
                          ),
                          DropdownMenuItem(
                            value: '20',
                            child: Text('20 minutos / dia (Intenso)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _dailyGoal = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Idioma da Interface',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF252A3D),
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
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'es', child: Text('Español')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _language = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card 5: Notificações
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE5E8EF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            color: blueColor,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Notificações por Email',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: blueColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _notifDaily,
                        activeColor: blueColor,
                        title: const Text(
                          'Lembretes Diários de Estudo',
                          style: TextStyle(fontSize: 14),
                        ),
                        onChanged: (val) => setState(() => _notifDaily = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: _notifAchievement,
                        activeColor: blueColor,
                        title: const Text(
                          'Conquistas e Progresso',
                          style: TextStyle(fontSize: 14),
                        ),
                        onChanged: (val) =>
                            setState(() => _notifAchievement = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: _notifTeacher,
                        activeColor: blueColor,
                        title: const Text(
                          'Notificações das Turmas',
                          style: TextStyle(fontSize: 14),
                        ),
                        onChanged: (val) => setState(() => _notifTeacher = val),
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
                  label: const Text(
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
        Icon(icon, size: 18, color: const Color(0xFF3579E8)),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF73788B), fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Não informado' : value,
            style: const TextStyle(
              color: Color(0xFF252A3D),
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
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF73788B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    ),
  );
}
