import 'package:flutter/material.dart';

class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.child,
    this.maxWidth = 460,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
  final Widget child;
  final double maxWidth;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEFF6FF), Colors.white, Color(0xFFF5F3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 56)
                      .clamp(0.0, double.infinity)
                      .toDouble(),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onBack != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: onBack,
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: const Text('Voltar'),
                              style: TextButton.styleFrom(
                                foregroundColor: accentColor,
                              ),
                            ),
                          ),
                        if (onBack != null) const SizedBox(height: 8),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4776E6), Color(0xFF7A4DE8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF5D61CF,
                                ).withValues(alpha: .2),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'D',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Duolinfo IA',
                          style: TextStyle(
                            fontSize: 26,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5,
                            color: Color(0xFF20243A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Aprenda idiomas com inteligência artificial',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF73788B),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                            side: const BorderSide(color: Color(0xFFE7E9F0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Color(0xFF22263A),
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    color: Color(0xFF73788B),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                child,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
