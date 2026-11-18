import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Tracks student XP level progression starting at [baseLevelXp] (20 XP for
/// level 1) and scaling the XP required for each subsequent level by
/// [levelMultiplier] (1.5x per level).
@immutable
class XpLevelProgression {
  const XpLevelProgression({
    required this.totalXp,
    required this.level,
    required this.currentLevelXp,
    required this.xpRequiredForNextLevel,
    required this.xpToNextLevel,
    required this.progress,
  });

  static const int baseLevelXp = 20;
  static const double levelMultiplier = 1.5;

  final int totalXp;
  final int level;
  final int currentLevelXp;
  final int xpRequiredForNextLevel;
  final int xpToNextLevel;
  final double progress;

  /// XP required to complete [level] and advance to [level] + 1.
  /// Level 1 = 20, Level 2 = 30, Level 3 = 45, Level 4 = 68, ...
  static int xpRequiredForLevel(int level) {
    final safeLevel = level < 1 ? 1 : level;
    return math.max(
      baseLevelXp,
      (baseLevelXp * math.pow(levelMultiplier, safeLevel - 1)).round(),
    );
  }

  /// Total cumulative XP needed to reach [targetLevel].
  static int cumulativeXpForLevel(int targetLevel) {
    var total = 0;
    for (var lvl = 1; lvl < targetLevel; lvl++) {
      total += xpRequiredForLevel(lvl);
    }
    return total;
  }

  factory XpLevelProgression.fromXp(int rawTotalXp) {
    final safeTotal = rawTotalXp < 0 ? 0 : rawTotalXp;
    var level = 1;
    var remaining = safeTotal;
    while (true) {
      final required = xpRequiredForLevel(level);
      if (remaining < required) {
        final ratio = required > 0
            ? (remaining / required).clamp(0.0, 1.0)
            : 0.0;
        return XpLevelProgression(
          totalXp: safeTotal,
          level: level,
          currentLevelXp: remaining,
          xpRequiredForNextLevel: required,
          xpToNextLevel: required - remaining,
          progress: ratio,
        );
      }
      remaining -= required;
      level++;
    }
  }
}
