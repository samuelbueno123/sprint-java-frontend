import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_data.dart';

class StudentSettingsView extends StatefulWidget {
  const StudentSettingsView({
    super.key,
    required this.data,
    required this.onBackToProfile,
    required this.onLogout,
  });

  final DashboardData data;
  final VoidCallback onBackToProfile;
  final VoidCallback onLogout;

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

  // Text controllers
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final nameParts = widget.data.user.name.split(' ');
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    _firstNameController = TextEditingController(text: firstName);
    _lastNameController = TextEditingController(text: lastName);
    _emailController = TextEditingController(text: widget.data.user.email);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blueColor = Color(0xFF3579E8);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3579E8), Color(0xFF1D52B4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onBackToProfile,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Voltar ao Perfil'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Configurações',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gerencie sua conta, notificações e preferências de estudo',
                      style: TextStyle(color: Color(0xEFFFFFFF), fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Card 1: Perfil
              _SettingsCard(
                icon: Icons.person_outline_rounded,
                title: 'Perfil do Estudante',
                iconColor: blueColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: blueColor.withValues(alpha: 0.15),
                              backgroundImage: widget.data.user.picture != null && widget.data.user.picture!.isNotEmpty
                                  ? NetworkImage(widget.data.user.picture!)
                                  : null,
                              child: (widget.data.user.picture == null || widget.data.user.picture!.isEmpty)
                                  ? Text(
                                      widget.data.user.name.isNotEmpty ? widget.data.user.name[0].toUpperCase() : 'A',
                                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: blueColor),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: blueColor,
                                child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.data.user.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF252A3D)),
                              ),
                              Text(
                                widget.data.user.email,
                                style: const TextStyle(color: Color(0xFF73788B), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nome', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _firstNameController,
                                decoration: _inputDecoration('Nome'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sobrenome', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _lastNameController,
                                decoration: _inputDecoration('Sobrenome'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      decoration: _inputDecoration('Email'),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Perfil atualizado com sucesso!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card 2: Segurança
              _SettingsCard(
                icon: Icons.shield_outlined,
                title: 'Segurança',
                iconColor: blueColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Senha Atual', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                    const SizedBox(height: 6),
                    TextField(obscureText: true, decoration: _inputDecoration('••••••••')),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nova Senha', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                              const SizedBox(height: 6),
                              TextField(obscureText: true, decoration: _inputDecoration('••••••••')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Confirmar Senha', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                              const SizedBox(height: 6),
                              TextField(obscureText: true, decoration: _inputDecoration('••••••••')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Solicitação de alteração de senha enviada.')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: blueColor,
                        side: const BorderSide(color: blueColor),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Alterar Senha', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card 3: Notificações
              _SettingsCard(
                icon: Icons.notifications_none_rounded,
                title: 'Notificações',
                iconColor: blueColor,
                child: Column(
                  children: [
                    _SwitchRow(
                      title: 'Lembrete diário de estudo',
                      subtitle: 'Receba um lembrete para estudar todos os dias',
                      value: _notifDaily,
                      activeColor: blueColor,
                      onChanged: (val) => setState(() => _notifDaily = val),
                    ),
                    _SwitchRow(
                      title: 'Novas conquistas',
                      subtitle: 'Notificar quando desbloquear uma conquista',
                      value: _notifAchievement,
                      activeColor: blueColor,
                      onChanged: (val) => setState(() => _notifAchievement = val),
                    ),
                    _SwitchRow(
                      title: 'Atualizações de ranking',
                      subtitle: 'Quando sua posição no ranking mudar',
                      value: _notifRanking,
                      activeColor: blueColor,
                      onChanged: (val) => setState(() => _notifRanking = val),
                    ),
                    _SwitchRow(
                      title: 'Feedback do professor',
                      subtitle: 'Quando o professor enviar aviso ou feedback',
                      value: _notifTeacher,
                      activeColor: blueColor,
                      onChanged: (val) => setState(() => _notifTeacher = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card 4: Preferências
              _SettingsCard(
                icon: Icons.palette_outlined,
                title: 'Preferências de Estudo',
                iconColor: blueColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tema do Aplicativo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _theme = 'light'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _theme == 'light' ? const Color(0xFFEAF2FF) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _theme == 'light' ? blueColor : const Color(0xFFE5E8EF),
                                  width: _theme == 'light' ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.wb_sunny_rounded, color: _theme == 'light' ? blueColor : Colors.grey),
                                  const SizedBox(width: 10),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Claro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text('Fundo claro', style: TextStyle(color: Color(0xFF73788B), fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _theme = 'dark'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _theme == 'dark' ? const Color(0xFFEAF2FF) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _theme == 'dark' ? blueColor : const Color(0xFFE5E8EF),
                                  width: _theme == 'dark' ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.nightlight_round, color: _theme == 'dark' ? blueColor : Colors.grey),
                                  const SizedBox(width: 10),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Escuro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text('Fundo escuro', style: TextStyle(color: Color(0xFF73788B), fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Idioma do App', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _language,
                                decoration: _inputDecoration(''),
                                items: const [
                                  DropdownMenuItem(value: 'pt', child: Text('Português')),
                                  DropdownMenuItem(value: 'en', child: Text('English')),
                                  DropdownMenuItem(value: 'es', child: Text('Español')),
                                ],
                                onChanged: (val) => setState(() => _language = val ?? 'pt'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Meta Diária', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _dailyGoal,
                                decoration: _inputDecoration(''),
                                items: const [
                                  DropdownMenuItem(value: '5', child: Text('5 XP — Casual')),
                                  DropdownMenuItem(value: '10', child: Text('10 XP — Regular')),
                                  DropdownMenuItem(value: '20', child: Text('20 XP — Intenso')),
                                  DropdownMenuItem(value: '50', child: Text('50 XP — Máximo')),
                                ],
                                onChanged: (val) => setState(() => _dailyGoal = val ?? '10'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card 5: Zona de Perigo
              _SettingsCard(
                icon: Icons.delete_outline_rounded,
                title: 'Zona de Perigo',
                iconColor: Colors.redAccent,
                child: Column(
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sair da Conta', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Para excluir sua conta, entre em contato com o suporte.')),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade300,
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: const Text('Excluir Conta'),
                    ),
                  ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E8EF))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E8EF))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3579E8), width: 2)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
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
            Row(
              children: [
                Icon(icon, color: iconColor, size: 21),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: iconColor),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF252A3D))),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Color(0xFF73788B), fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
