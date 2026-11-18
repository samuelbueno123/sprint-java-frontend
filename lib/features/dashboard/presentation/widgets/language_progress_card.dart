import 'package:flutter/material.dart';

import '../../../../core/ui/language_flag.dart';
import '../../../../core/xp/xp_level_progression.dart';
import '../../domain/entities/student_language_entity.dart';

class LanguageProgressCard extends StatelessWidget {
  const LanguageProgressCard({super.key, required this.language});

  final StudentLanguageEntity language;

  @override
  Widget build(BuildContext context) {
    const studentGreen = Color(0xFF58CC02);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final levelInfo = XpLevelProgression.fromXp(language.score);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF343B49) : Colors.grey.shade200,
        ),
      ),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: studentGreen.withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: LanguageFlag.forLanguage(
                    language.languageName,
                    width: 30,
                    borderRadius: 5,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    language.languageName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    'Nv. ${levelInfo.level} • ${language.level}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: studentGreen,
                    ),
                  ),
                  backgroundColor: studentGreen.withValues(
                    alpha: isDark ? 0.22 : 0.12,
                  ),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Nível ${levelInfo.level} • ${levelInfo.currentLevelXp}/${levelInfo.xpRequiredForNextLevel} XP',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${language.score} XP total',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: studentGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: levelInfo.progress,
                backgroundColor: isDark ? Colors.white12 : Colors.grey.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(studentGreen),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
