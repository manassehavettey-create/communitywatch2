import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/watch.dart';
import '../../../core/providers.dart';

@immutable
class ActiveTimerView {
  const ActiveTimerView({required this.timer, required this.skill});
  final ActiveTimerRow timer;
  final SkillRow skill;
}

final activeTimerProvider = StreamProvider<ActiveTimerView?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchTables([db.activeTimers, db.skills], () async {
    final t = await db.select(db.activeTimers).getSingleOrNull();
    if (t == null) return null;
    final s = await (db.select(db.skills)..where((s) => s.id.equals(t.skillId)))
        .getSingleOrNull();
    return s == null ? null : ActiveTimerView(timer: t, skill: s);
  });
});
