import 'package:flutter/material.dart';

/// Componente seguro para exibição de avatar de usuário.
/// Evita erros HTTP 429 / 403 das fotos do Google aplicando política no-referrer
/// e exibe a inicial do nome caso a imagem falhe ao carregar.
class AppUserAvatar extends StatelessWidget {
  const AppUserAvatar({
    super.key,
    required this.name,
    this.pictureUrl,
    this.radius = 20,
    this.backgroundColor,
    this.textColor = Colors.white,
  });

  final String name;
  final String? pictureUrl;
  final double radius;
  final Color? backgroundColor;
  final Color textColor;

  String get _initial =>
      name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';

  String? get _safePictureUrl {
    if (pictureUrl == null || pictureUrl!.trim().isEmpty) return null;
    var url = pictureUrl!.trim();
    if (url.contains('googleusercontent.com')) {
      if (url.contains('=')) {
        url = url.split('=')[0];
      }
      url = '$url=s96-c';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final url = _safePictureUrl;
    final size = radius * 2;
    final bg = backgroundColor ?? const Color(0xFF5869D8);

    Widget fallback() => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initial,
        style: TextStyle(
          fontSize: radius * 0.85,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );

    if (url == null) return fallback();

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: bg,
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          headers: const {
            'referrer-policy': 'no-referrer',
          },
          errorBuilder: (context, error, stackTrace) => fallback(),
        ),
      ),
    );
  }
}
