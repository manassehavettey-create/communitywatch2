import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/day_key.dart';
import '../../skills/data/skill_repository.dart';

class StoppedTimer {
  const StoppedTimer({required this.skillId, required this.sessionId});
  final int skillId;
  final int? sessionId;
}

/// The live practice timer. The start instant is persisted, so elapsed time
/// is always `now - startedAt` — correct after backgrounding, the app being
/// killed, or a reboot.
class TimerRepository {
  TimerRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Stream<ActiveTimerRow?> watchActive() =>
      _db.select(_db.activeTimers).watchSingleOrNull();

  Future<ActiveTimerRow?> active() =>
      _db.select(_db.activeTimers).getSingleOrNull();

  /// Elapsed time, clamped to 0 if the device clock moved backwards.
  Duration elapsed(ActiveTimerRow timer) {
    final d = _clock.now().difference(timer.startedAt);
    return d.isNegative ? Duration.zero : d;
  }

  Future<ActiveTimerRow> start(int skillId) async {
    final existing = await active();
    if (existing != null) {
      throw const ValidationException(
        'A timer is already running. Stop it first.',
      );
    }
    final skill = await (_db.select(
      _db.skills,
    )..where((s) => s.id.equals(skillId))).getSingleOrNull();
    if (skill == null || skill.archivedAt != null) {
      throw const ValidationException('That skill is not available.');
    }
    final row = ActiveTimerRow(
      id: 1,
      skillId: skillId,
      startedAt: _clock.now(),
    );
    await _db.into(_db.activeTimers).insert(row);
    return row;
  }

  /// Stops the timer and saves a session of [durationSec] (defaults to the
  /// elapsed time). Returns null session when the result is under a minute
  /// and [durationSec] was not given — nothing is saved in that case.
  Future<StoppedTimer?> stop({int? durationSec, String? note}) {
    return _db.transaction(() async {
      final timer = await active();
      if (timer == null) return null;
      final seconds =
          durationSec ??
          elapsed(timer).inSeconds.clamp(0, SkillLimits.maxSessionSec);
      int? sessionId;
      if (seconds >= 60) {
        final clean = note?.trim();
        sessionId = await _db
            .into(_db.practiceSessions)
            .insert(
              PracticeSessionsCompanion.insert(
                skillId: timer.skillId,
                startedAt: timer.startedAt,
                dayKey: Days.keyOf(timer.startedAt),
                durationSec: seconds.clamp(60, SkillLimits.maxSessionSec),
                note: Value(clean == null || clean.isEmpty ? null : clean),
                source: const Value('timer'),
                createdAt: _clock.now(),
              ),
            );
      }
      await _db.delete(_db.activeTimers).go();
      return StoppedTimer(skillId: timer.skillId, sessionId: sessionId);
    });
  }

  Future<void> discard() => _db.delete(_db.activeTimers).go();
}
