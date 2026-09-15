import 'package:flutter/material.dart';

import '../../domain/entities/authenticated_user.dart';

class GoogleAccountCard extends StatelessWidget {
  const GoogleAccountCard({
    super.key,
    required this.user,
    required this.color,
    required this.onSignOut,
  });

  final AuthenticatedUser user;
  final Color color;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: .06),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sessão autenticada', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Text(user.name.isEmpty ? 'Usuário' : user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(user.email),
            const SizedBox(height: 16),
            const Text('As permissões e o perfil foram validados pelo backend.'),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onSignOut, child: const Text('SAIR')),
          ],
        ),
      ),
    );
  }
}
