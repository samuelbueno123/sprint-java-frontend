import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../domain/entities/dashboard_data.dart';
import 'local_image_picker_helper.dart';

String _parseErrorMsg(Object error, String fallback) {
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

/// Floating modal dialog for editing Name and Email.
class EditProfileDetailsDialog extends StatefulWidget {
  const EditProfileDetailsDialog({
    super.key,
    required this.data,
    required this.onSaved,
  });

  final DashboardData data;
  final VoidCallback onSaved;

  static void show(
    BuildContext context, {
    required DashboardData data,
    required VoidCallback onSaved,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => EditProfileDetailsDialog(data: data, onSaved: onSaved),
    );
  }

  @override
  State<EditProfileDetailsDialog> createState() =>
      _EditProfileDetailsDialogState();
}

class _EditProfileDetailsDialogState extends State<EditProfileDetailsDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  bool _isLoading = false;
  String? _errorMessage;

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
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Informe seu nome completo.');
      return;
    }

    final isGoogle = widget.data.user.googleId.isNotEmpty;
    final email = _emailController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ds = DashboardRemoteDataSource(ApiClient().dio);
      await ds.updateProfileDetails(
        userId: widget.data.user.id,
        name: name,
        email: isGoogle ? null : email,
      );
      widget.onSaved();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados atualizados com sucesso!')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = _parseErrorMsg(e, 'Erro ao atualizar dados pessoais.');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGoogleAccount = widget.data.user.googleId.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: Color(0xFF5869D8)),
                      SizedBox(width: 8),
                      Text(
                        'Editar Dados Pessoais',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Nome completo',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Digite seu nome',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Email',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                readOnly: isGoogleAccount,
                decoration: InputDecoration(
                  hintText: 'Digite seu email',
                  helperText: isGoogleAccount
                      ? 'Contas vinculadas ao Google não podem alterar o e-mail.'
                      : null,
                  suffixIcon: isGoogleAccount
                      ? const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: Color(0xFF8A8FA1),
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0EF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF3C6C2)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Color(0xFFB42318), fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5869D8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Salvar Alterações'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating modal dialog for changing Password.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key, required this.data});

  final DashboardData data;

  static void show(BuildContext context, {required DashboardData data}) {
    showDialog<void>(
      context: context,
      builder: (_) => ChangePasswordDialog(data: data),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (currentPass.isEmpty) {
      setState(() => _errorMessage = 'Informe a senha atual.');
      return;
    }
    if (newPass.length < 6) {
      setState(
        () => _errorMessage = 'A nova senha deve ter pelo menos 6 caracteres.',
      );
      return;
    }
    if (newPass != confirmPass) {
      setState(
        () => _errorMessage =
            "As senhas nos campos 'Nova senha' e 'Confirmar senha' não coincidem.",
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ds = DashboardRemoteDataSource(ApiClient().dio);
      await ds.updatePassword(
        userId: widget.data.user.id,
        currentPassword: currentPass,
        password: newPass,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha alterada com sucesso!')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = _parseErrorMsg(e, 'Erro ao alterar senha.');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_reset_rounded, color: Color(0xFF5869D8)),
                      SizedBox(width: 8),
                      Text(
                        'Alterar Senha',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Senha Atual',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Digite a senha atual',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Nova Senha',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Digite a nova senha (mín. 6 caracteres)',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Confirmar Nova Senha',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Confirme a nova senha',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0EF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF3C6C2)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Color(0xFFB42318), fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5869D8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Alterar Senha'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating modal dialog for selecting/uploading a Profile Picture.
class EditProfilePictureDialog extends StatefulWidget {
  const EditProfilePictureDialog({
    super.key,
    required this.data,
    required this.onSaved,
  });

  final DashboardData data;
  final VoidCallback onSaved;

  static void show(
    BuildContext context, {
    required DashboardData data,
    required VoidCallback onSaved,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => EditProfilePictureDialog(data: data, onSaved: onSaved),
    );
  }

  @override
  State<EditProfilePictureDialog> createState() =>
      _EditProfilePictureDialogState();
}

class _EditProfilePictureDialogState extends State<EditProfilePictureDialog> {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.data.user.picture ?? '';
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickLocalImage() async {
    try {
      final dataUrl = await LocalImagePickerHelper.pickLocalImage();
      if (dataUrl == null) return;

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final ds = DashboardRemoteDataSource(ApiClient().dio);
      await ds.updateProfilePicture(
        userId: widget.data.user.id,
        profilePicture: dataUrl,
      );
      widget.onSaved();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil alterada com sucesso!')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = _parseErrorMsg(e, 'Erro ao carregar foto local.');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveUrlImage() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(
        () => _errorMessage = 'Informe a URL da foto ou selecione um arquivo.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ds = DashboardRemoteDataSource(ApiClient().dio);
      await ds.updateProfilePicture(
        userId: widget.data.user.id,
        profilePicture: url,
      );
      widget.onSaved();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil alterada com sucesso!')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = _parseErrorMsg(e, 'Erro ao atualizar foto de perfil.');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.camera_alt_rounded, color: Color(0xFF5869D8)),
                      SizedBox(width: 8),
                      Text(
                        'Alterar Foto de Perfil',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickLocalImage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5869D8),
                  side: const BorderSide(color: Color(0xFF5869D8)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text(
                  'Escolher foto do computador/dispositivo (JPG/PNG <= 1024x1024)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFFE5E8EF))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'ou informe uma URL',
                      style: TextStyle(color: Color(0xFF73788B), fontSize: 12),
                    ),
                  ),
                  Expanded(child: Divider(color: Color(0xFFE5E8EF))),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'URL da imagem',
                  hintText: 'https://exemplo.com/foto.jpg',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.link_rounded),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0EF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF3C6C2)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Color(0xFFB42318), fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isLoading ? null : _saveUrlImage,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5869D8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Salvar URL'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
