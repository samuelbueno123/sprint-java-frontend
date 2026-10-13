import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../domain/entities/dashboard_data.dart';
import 'app_user_avatar.dart';
import 'local_image_picker_helper.dart';

class UserSettingsView extends StatefulWidget {
  const UserSettingsView({
    super.key,
    required this.data,
    required this.onBackToProfile,
    required this.onLogout,
  });

  final DashboardData data;
  final VoidCallback onBackToProfile;
  final VoidCallback onLogout;

  @override
  State<UserSettingsView> createState() => _UserSettingsViewState();
}

class _UserSettingsViewState extends State<UserSettingsView> {
  // Notification states (All 4 options)
  bool _notifDaily = true;
  bool _notifAchievement = true;
  bool _notifRanking = false;
  bool _notifUpdates = true;

  // Preferences
  String _language = 'pt';
  String _theme = 'light';

  // Text controllers
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSavingProfile = false;
  bool _isChangingPassword = false;
  bool _isUpdatingPicture = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data.user.name);
    _emailController = TextEditingController(text: widget.data.user.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLocalImage() async {
    try {
      final dataUrl = await LocalImagePickerHelper.pickLocalImage();
      if (dataUrl == null) return;

      setState(() => _isUpdatingPicture = true);
      final ds = DashboardRemoteDataSource(ApiClient().dio);
      await ds.updateUser(
        userId: widget.data.user.id,
        name: widget.data.user.name,
        email: widget.data.user.email,
        googleId: widget.data.user.googleId,
        profilePicture: dataUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil alterada com sucesso!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na foto: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingPicture = false);
    }
  }

  Future<void> _saveProfileData() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSavingProfile = true);
    try {
      final ds = DashboardRemoteDataSource(ApiClient().dio);
      await ds.updateUser(
        userId: widget.data.user.id,
        name: name,
        email: _emailController.text.trim(),
        googleId: widget.data.user.googleId,
        profilePicture: widget.data.user.picture,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados atualizados com sucesso!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar dados: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (currentPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a senha atual.')),
      );
      return;
    }
    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A nova senha deve ter pelo menos 6 caracteres.')),
      );
      return;
    }
    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As senhas não coincidem.')),
      );
      return;
    }

    setState(() => _isChangingPassword = true);
    try {
      final ds = DashboardRemoteDataSource(ApiClient().dio);
      await ds.updateUser(
        userId: widget.data.user.id,
        name: widget.data.user.name,
        email: widget.data.user.email,
        googleId: widget.data.user.googleId,
        profilePicture: widget.data.user.picture,
        currentPassword: currentPass,
        password: newPass,
      );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha alterada com sucesso!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao alterar senha: $e')),
      );
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF5869D8);

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
                    colors: [Color(0xFF5869D8), Color(0xFF7651C8)],
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
                      'Configurações da Conta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gerencie suas preferências de conta no Duolinfo',
                      style: TextStyle(color: Color(0xEFFFFFFF), fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Card 1: Perfil
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
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _isUpdatingPicture ? null : _pickAndUploadLocalImage,
                            child: Stack(
                              children: [
                                AppUserAvatar(
                                  name: widget.data.user.name,
                                  pictureUrl: widget.data.user.picture,
                                  radius: 36,
                                  backgroundColor: brandColor.withValues(alpha: 0.15),
                                  textColor: brandColor,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: brandColor,
                                    child: _isUpdatingPicture
                                        ? const SizedBox.square(
                                            dimension: 12,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
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
                                const SizedBox(height: 4),
                                TextButton.icon(
                                  onPressed: _isUpdatingPicture ? null : _pickAndUploadLocalImage,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.upload_file_rounded, size: 14, color: brandColor),
                                  label: const Text(
                                    'Escolher foto local (JPG/PNG <= 1024x1024)',
                                    style: TextStyle(fontSize: 12, color: brandColor, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('Nome', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                      const SizedBox(height: 6),
                      TextField(controller: _nameController, decoration: _inputDecoration('Nome')),
                      const SizedBox(height: 14),
                      const Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                      const SizedBox(height: 6),
                      TextField(controller: _emailController, decoration: _inputDecoration('Email')),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _isSavingProfile ? null : _saveProfileData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSavingProfile
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card 2: Segurança e Senha (sem decoration fake)
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
                      const Text('Segurança e Senha', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: brandColor)),
                      const SizedBox(height: 16),
                      const Text('Senha Atual', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _currentPasswordController,
                        obscureText: true,
                        decoration: _inputDecoration('Digite sua senha atual'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Nova Senha', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _newPasswordController,
                                  obscureText: true,
                                  decoration: _inputDecoration('Digite a nova senha'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Confirmar Nova Senha', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _confirmPasswordController,
                                  obscureText: true,
                                  decoration: _inputDecoration('Confirme a nova senha'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton(
                        onPressed: _isChangingPassword ? null : _changePassword,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: brandColor,
                          side: const BorderSide(color: brandColor),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isChangingPassword
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Alterar Senha', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card 3: Notificações
              _SettingsCard(
                icon: Icons.notifications_none_rounded,
                title: 'Notificações',
                iconColor: brandColor,
                child: Column(
                  children: [
                    _SwitchRow(
                      title: 'Lembretes de acesso e estudo',
                      subtitle: 'Receba alertas diários para continuar seu aprendizado',
                      value: _notifDaily,
                      activeColor: brandColor,
                      onChanged: (val) => setState(() => _notifDaily = val),
                    ),
                    _SwitchRow(
                      title: 'Novas conquistas',
                      subtitle: 'Alertas quando desbloquear novos níveis e metas',
                      value: _notifAchievement,
                      activeColor: brandColor,
                      onChanged: (val) => setState(() => _notifAchievement = val),
                    ),
                    _SwitchRow(
                      title: 'Atualizações de turmas e ranking',
                      subtitle: 'Notificar sobre atividades e posição na plataforma',
                      value: _notifRanking,
                      activeColor: brandColor,
                      onChanged: (val) => setState(() => _notifRanking = val),
                    ),
                    _SwitchRow(
                      title: 'Comunicados do sistema',
                      subtitle: 'Novidades, avisos de manutenção e atualizações',
                      value: _notifUpdates,
                      activeColor: brandColor,
                      onChanged: (val) => setState(() => _notifUpdates = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card 4: Preferências
              _SettingsCard(
                icon: Icons.palette_outlined,
                title: 'Preferências do Sistema',
                iconColor: brandColor,
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
                                  color: _theme == 'light' ? brandColor : const Color(0xFFE5E8EF),
                                  width: _theme == 'light' ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.wb_sunny_rounded, color: _theme == 'light' ? brandColor : Colors.grey),
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
                                  color: _theme == 'dark' ? brandColor : const Color(0xFFE5E8EF),
                                  width: _theme == 'dark' ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.nightlight_round, color: _theme == 'dark' ? brandColor : Colors.grey),
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
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF5869D8), width: 2)),
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
