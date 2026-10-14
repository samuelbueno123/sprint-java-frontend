import 'package:dio/dio.dart';
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
  // Notification states
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
      await ds.updateProfilePicture(
        userId: widget.data.user.id,
        profilePicture: dataUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil alterada com sucesso!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_parseErrorMessage(e, 'Erro na foto de perfil.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingPicture = false);
    }
  }

  Future<void> _saveProfileData() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe seu nome.')),
      );
      return;
    }

    final isGoogle = widget.data.user.googleId.isNotEmpty;
    final email = _emailController.text.trim();

    setState(() => _isSavingProfile = true);
    try {
      final ds = DashboardRemoteDataSource(ApiClient().dio);
      await ds.updateProfileDetails(
        userId: widget.data.user.id,
        name: name,
        email: isGoogle ? null : email,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados atualizados com sucesso!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_parseErrorMessage(e, 'Erro ao atualizar dados.')),
        ),
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
        const SnackBar(
          content: Text(
            "As senhas nos campos 'Nova senha' e 'Confirmar senha' não coincidem.",
          ),
        ),
      );
      return;
    }

    setState(() => _isChangingPassword = true);
    try {
      final ds = DashboardRemoteDataSource(ApiClient().dio);
      await ds.updatePassword(
        userId: widget.data.user.id,
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
        SnackBar(
          content: Text(_parseErrorMessage(e, 'Erro ao alterar senha.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF5869D8);
    final isGoogleAccount = widget.data.user.googleId.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho da página de Configurações
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onBackToProfile,
                    icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF252A3D)),
                    tooltip: 'Voltar ao Perfil',
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Configurações da Conta',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF252A3D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Card 1: Perfil Público e Dados Pessoais
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
                      const Text(
                        'Perfil Público e Informações Pessoais',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: brandColor),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Stack(
                            children: [
                              AppUserAvatar(
                                name: widget.data.user.name,
                                pictureUrl: widget.data.user.picture,
                                radius: 36,
                                backgroundColor: brandColor.withValues(alpha: .15),
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
                                    'Escolher foto local',
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
                      TextField(
                        controller: _emailController,
                        readOnly: isGoogleAccount,
                        decoration: _inputDecoration(
                          'Email',
                          helperText: isGoogleAccount
                              ? 'Contas vinculadas ao Google não podem alterar o e-mail.'
                              : null,
                          suffixIcon: isGoogleAccount
                              ? const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF8A8FA1))
                              : null,
                        ),
                      ),
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

              // Card 2: Segurança e Senha
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
                      ElevatedButton(
                        onPressed: _isChangingPassword ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isChangingPassword
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Alterar Senha', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card 3: Preferências e Notificações
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
                      const Text('Preferências do Aplicativo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: brandColor)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Idioma da Interface', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _language,
                                  decoration: _inputDecoration('Idioma'),
                                  items: const [
                                    DropdownMenuItem(value: 'pt', child: Text('Português (Brasil)')),
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tema', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _theme,
                                  decoration: _inputDecoration('Tema'),
                                  items: const [
                                    DropdownMenuItem(value: 'light', child: Text('Claro')),
                                    DropdownMenuItem(value: 'dark', child: Text('Escuro')),
                                    DropdownMenuItem(value: 'system', child: Text('Padrão do Sistema')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _theme = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('Notificações por Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF252A3D))),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _notifDaily,
                        activeColor: brandColor,
                        title: const Text('Lembretes Diários de Estudo', style: TextStyle(fontSize: 14)),
                        onChanged: (val) => setState(() => _notifDaily = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: _notifAchievement,
                        activeColor: brandColor,
                        title: const Text('Conquistas e Progresso', style: TextStyle(fontSize: 14)),
                        onChanged: (val) => setState(() => _notifAchievement = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: _notifRanking,
                        activeColor: brandColor,
                        title: const Text('Atualizações de Ranking e Ligas', style: TextStyle(fontSize: 14)),
                        onChanged: (val) => setState(() => _notifRanking = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: _notifUpdates,
                        activeColor: brandColor,
                        title: const Text('Novidades e Atualizações da Plataforma', style: TextStyle(fontSize: 14)),
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
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  label: const Text('Sair da Conta', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {String? helperText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      helperText: helperText,
      suffixIcon: suffixIcon,
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

  String _parseErrorMessage(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final msg = data['message'] ?? data['detail'] ?? data['error'];
        if (msg != null && msg.toString().trim().isNotEmpty) {
          return msg.toString().trim();
        }
      } else if (data is String && data.trim().isNotEmpty) {
        return data.trim();
      }
    }
    return fallback;
  }
}
