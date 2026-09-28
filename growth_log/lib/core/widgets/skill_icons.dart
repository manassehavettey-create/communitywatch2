import 'package:flutter/material.dart';

import '../db/database.dart';
import '../theme/phosphor_icons.dart';
import '../theme/tokens.dart';

/// Icons a skill can use. Keys are stored in the database, so never rename
/// an existing key.
abstract final class SkillIcons {
  static const Map<String, IconData> all = {
    'guitar': PhosphorIconsRegular.guitar,
    'piano': PhosphorIconsRegular.pianoKeys,
    'music': PhosphorIconsRegular.musicNotes,
    'mic': PhosphorIconsRegular.microphone,
    'headphones': PhosphorIconsRegular.headphones,
    'paint': PhosphorIconsRegular.paintBrush,
    'palette': PhosphorIconsRegular.palette,
    'pencil': PhosphorIconsRegular.pencilSimple,
    'pen': PhosphorIconsRegular.penNib,
    'camera': PhosphorIconsRegular.camera,
    'code': PhosphorIconsRegular.code,
    'terminal': PhosphorIconsRegular.terminalWindow,
    'cpu': PhosphorIconsRegular.cpu,
    'translate': PhosphorIconsRegular.translate,
    'book': PhosphorIconsRegular.bookOpen,
    'grad': PhosphorIconsRegular.graduationCap,
    'brain': PhosphorIconsRegular.brain,
    'chef': PhosphorIconsRegular.chefHat,
    'barbell': PhosphorIconsRegular.barbell,
    'run': PhosphorIconsRegular.personSimpleRun,
    'bike': PhosphorIconsRegular.bicycle,
    'swim': PhosphorIconsRegular.swimmingPool,
    'yoga': PhosphorIconsRegular.flowerLotus,
    'yinyang': PhosphorIconsRegular.yinYang,
    'soccer': PhosphorIconsRegular.soccerBall,
    'basketball': PhosphorIconsRegular.basketball,
    'tennis': PhosphorIconsRegular.tennisBall,
    'game': PhosphorIconsRegular.gameController,
    'strategy': PhosphorIconsRegular.strategy,
    'keyboard': PhosphorIconsRegular.keyboard,
    'math': PhosphorIconsRegular.calculator,
    'atom': PhosphorIconsRegular.atom,
    'flask': PhosphorIconsRegular.flask,
    'work': PhosphorIconsRegular.briefcase,
    'chat': PhosphorIconsRegular.chatCircle,
    'globe': PhosphorIconsRegular.globe,
    'plant': PhosphorIconsRegular.plant,
    'target': PhosphorIconsRegular.target,
    'idea': PhosphorIconsRegular.lightbulb,
    'heart': PhosphorIconsRegular.heart,
    'mountain': PhosphorIconsRegular.mountains,
    'hammer': PhosphorIconsRegular.hammer,
    'scissors': PhosphorIconsRegular.scissors,
    'dna': PhosphorIconsRegular.dna,
    'star': PhosphorIconsRegular.star,
  };

  static const fallback = 'star';

  static IconData of(String key) => all[key] ?? all[fallback]!;
}

/// Coloured circle with the skill's icon.
class SkillAvatar extends StatelessWidget {
  const SkillAvatar({
    super.key,
    required this.skill,
    this.size = 44,
    this.inverted = false,
  });

  final SkillRow skill;
  final double size;

  /// Ink circle with a coloured icon (for use on the skill's own colour).
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final color = Color(skill.colorValue);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: inverted ? Palette.ink : color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          SkillIcons.of(skill.iconKey),
          size: size * 0.5,
          color: inverted ? color : Palette.ink,
        ),
      ),
    );
  }
}
