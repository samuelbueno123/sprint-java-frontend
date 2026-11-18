import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/local_image_picker_helper.dart';
import 'app_user_avatar.dart';
import 'edit_profile_dialogs.dart';

/// Compact reusable photo selector widget used inside Institution & Class creation/edit forms.
class FormEntityPhotoPicker extends StatelessWidget {
  const FormEntityPhotoPicker({
    super.key,
    required this.entityName,
    required this.pictureUrl,
    required this.onChanged,
    this.label = 'Foto / Brasão (opcional)',
  });

  final String entityName;
  final String? pictureUrl;
  final ValueChanged<String?> onChanged;
  final String label;

  Future<void> _pickDeviceImage(BuildContext context) async {
    try {
      final dataUrl = await LocalImagePickerHelper.pickLocalImage();
      if (dataUrl != null && dataUrl.isNotEmpty) {
        onChanged(dataUrl);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível selecionar a imagem: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editUrlDialog(BuildContext context) async {
    final ctrl = TextEditingController(
      text: (pictureUrl != null && !pictureUrl!.startsWith('data:image/'))
          ? pictureUrl!
          : '',
    );
    final url = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Informar URL da imagem'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Link HTTPS da imagem',
            hintText: 'https://exemplo.com/imagem.png',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(milliseconds: 300), ctrl.dispose);
    if (url == null || url.isEmpty || !context.mounted) return;
    final normalized = normalizeProfilePictureInputUrl(url);
    if (normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe uma URL HTTP/HTTPS válida.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    onChanged(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final hasPic = pictureUrl != null && pictureUrl!.trim().isNotEmpty;
    final previewName = entityName.trim().isNotEmpty ? entityName.trim() : 'I';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          AppUserAvatar(
            name: previewName,
            pictureUrl: hasPic ? pictureUrl : null,
            radius: 26,
            backgroundColor: const Color(0xFF4F46E5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickDeviceImage(context),
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: const Text('Dispositivo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _editUrlDialog(context),
                      icon: const Icon(Icons.link_rounded, size: 16),
                      label: const Text('URL'),
                    ),
                    if (hasPic)
                      TextButton.icon(
                        onPressed: () => onChanged(null),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          'Remover',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for updating or removing the photo of an Institution or SchoolClass via backend API.
class EntityPicturePickerDialog extends StatefulWidget {
  const EntityPicturePickerDialog({
    super.key,
    required this.title,
    required this.entityName,
    required this.endpointPath,
    this.initialPictureUrl,
    this.dio,
    this.onSaved,
  });

  final String title;
  final String entityName;
  final String endpointPath;
  final String? initialPictureUrl;
  final Dio? dio;
  final ValueChanged<String?>? onSaved;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String entityName,
    required String endpointPath,
    String? initialPictureUrl,
    Dio? dio,
    ValueChanged<String?>? onSaved,
  }) {
    return showDialog<String?>(
      context: context,
      builder: (_) => EntityPicturePickerDialog(
        title: title,
        entityName: entityName,
        endpointPath: endpointPath,
        initialPictureUrl: initialPictureUrl,
        dio: dio,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<EntityPicturePickerDialog> createState() =>
      _EntityPicturePickerDialogState();
}

class _EntityPicturePickerDialogState extends State<EntityPicturePickerDialog> {
  final _urlCtrl = TextEditingController();
  String? _selectedDataOrUrl;
  bool _saving = false;
  String? _error;

  Dio get _dio => widget.dio ?? ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _selectedDataOrUrl = widget.initialPictureUrl;
    if (widget.initialPictureUrl != null &&
        !widget.initialPictureUrl!.startsWith('data:image/')) {
      _urlCtrl.text = widget.initialPictureUrl!;
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeviceImage() async {
    try {
      final dataUrl = await LocalImagePickerHelper.pickLocalImage();
      if (!mounted || dataUrl == null) return;
      await _submitPicture(dataUrl);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível ler o arquivo de imagem.');
    }
  }

  Future<void> _saveFromInput() async {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) {
      if (_selectedDataOrUrl != null && _selectedDataOrUrl!.isNotEmpty) {
        await _submitPicture(_selectedDataOrUrl);
      } else {
        setState(
          () => _error = 'Escolha uma imagem do dispositivo ou informe uma URL.',
        );
      }
      return;
    }
    final normalized = normalizeProfilePictureInputUrl(raw);
    if (normalized.isEmpty) {
      setState(() => _error = 'Informe uma URL HTTP/HTTPS ou Data URI válida.');
      return;
    }
    await _submitPicture(normalized);
  }

  Future<void> _submitPicture(String? pictureUrl) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        widget.endpointPath,
        data: {'pictureUrl': pictureUrl ?? ''},
      );
      final savedUrl = res.data?['pictureUrl']?.toString();
      if (!mounted) return;
      widget.onSaved?.call(savedUrl);
      Navigator.of(context).pop(savedUrl ?? '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (savedUrl == null || savedUrl.isEmpty)
                ? 'Foto removida com sucesso.'
                : 'Foto atualizada com sucesso!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final serverMsg = (e.response?.data is Map)
          ? (e.response!.data as Map)['message']?.toString()
          : null;
      setState(
        () => _error =
            serverMsg ??
            'Sem permissão ou erro ao atualizar a foto (${e.response?.statusCode ?? ''}).',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Erro inesperado ao salvar a foto.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = (_urlCtrl.text.trim().isNotEmpty
            ? normalizeProfilePictureInputUrl(_urlCtrl.text)
            : _selectedDataOrUrl) ??
        _selectedDataOrUrl;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          const Icon(Icons.photo_camera_rounded, color: Color(0xFF4F46E5)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppUserAvatar(
                name: widget.entityName,
                pictureUrl: preview,
                radius: 44,
                backgroundColor: const Color(0xFF4F46E5),
              ),
              const SizedBox(height: 8),
              Text(
                widget.entityName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _pickDeviceImage,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Escolher Imagem do Dispositivo'),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _urlCtrl,
                enabled: !_saving,
                onChanged: (_) => setState(() => _error = null),
                decoration: const InputDecoration(
                  labelText: 'Ou cole uma URL pública de imagem',
                  hintText: 'https://exemplo.com/brasao.png',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (preview != null && preview.isNotEmpty)
          TextButton.icon(
            onPressed: _saving ? null : () => _submitPicture(''),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
            label: const Text(
              'Remover foto',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _saveFromInput,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Salvar Foto'),
        ),
      ],
    );
  }
}
