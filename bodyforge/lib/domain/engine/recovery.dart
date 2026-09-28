import '../models/enums.dart';

enum RecoveryMode {
  /// Go ahead as planned.
  full('Full session', 'You\'re ready. Train as planned.'),

  /// Slightly less volume, no finisher.
  trimmed('Slightly trimmed', 'Solid, but not 100%. We trimmed a little volume.'),

  /// Clearly reduced: fewer sets, longer rests, no jumping finisher.
  reduced('Reduced', 'Your body needs a lighter day. Fewer sets and longer rests.'),

  /// Recovery flow instead of the planned workout.
  recovery('Recovery session', 'Low energy and very sore — today is a recovery day. Mobility, not intensity.');

  const RecoveryMode(this.label, this.message);
  final String label;
  final String message;
}

class RecoveryCheck {
  const RecoveryCheck({required this.sleep, required this.soreness, required this.energy});

  final SleepQuality sleep;
  final Soreness soreness;
  final Energy energy;

  /// 0 (wrecked) … 6 (fully ready).
  int get score {
    final s = switch (sleep) { SleepQuality.poor => 0, SleepQuality.okay => 1, SleepQuality.good => 2 };
    final so = switch (soreness) { Soreness.very => 0, Soreness.little => 1, Soreness.none => 2 };
    final e = switch (energy) { Energy.low => 0, Energy.normal => 1, Energy.high => 2 };
    return s + so + e;
  }
}

class RecoveryAdjustment {
  const RecoveryAdjustment({
    required this.mode,
    required this.volumeFactor,
    required this.restBonusSec,
    required this.dropFinisher,
    required this.regressOneLevel,
  });

  final RecoveryMode mode;

  /// Multiply planned sets by this.
  final double volumeFactor;
  final int restBonusSec;
  final bool dropFinisher;

  /// Use one easier variation on path exercises today.
  final bool regressOneLevel;

  String get message => mode.message;
  bool get changesPlan => mode != RecoveryMode.full;

  static const none = RecoveryAdjustment(
      mode: RecoveryMode.full, volumeFactor: 1, restBonusSec: 0, dropFinisher: false, regressOneLevel: false);
}

/// Spec §9: "Low energy + high soreness → reduce intensity or provide a
/// recovery session. Good sleep + high energy → continue as planned."
RecoveryAdjustment adjustForRecovery(RecoveryCheck c) {
  final score = c.score;
  if ((c.energy == Energy.low && c.soreness == Soreness.very) || score <= 1) {
    return const RecoveryAdjustment(
        mode: RecoveryMode.recovery, volumeFactor: 0, restBonusSec: 0, dropFinisher: true, regressOneLevel: true);
  }
  if (score <= 3) {
    return RecoveryAdjustment(
      mode: RecoveryMode.reduced,
      volumeFactor: 0.65,
      restBonusSec: 20,
      dropFinisher: true,
      regressOneLevel: c.soreness == Soreness.very,
    );
  }
  if (score == 4) {
    return RecoveryAdjustment(
      mode: RecoveryMode.trimmed,
      volumeFactor: 0.85,
      restBonusSec: 10,
      dropFinisher: c.soreness == Soreness.very || c.energy == Energy.low,
      regressOneLevel: false,
    );
  }
  return RecoveryAdjustment.none;
}

/// Label for weekly summaries from the average recovery score.
String recoveryLabel(double? averageScore) {
  if (averageScore == null) return 'Not checked';
  if (averageScore >= 4.5) return 'Good';
  if (averageScore >= 2.5) return 'Fair';
  return 'Low';
}
