import 'dart:math' as math;

import '../../domain/engine/environment.dart';
import '../../domain/engine/player.dart';
import '../../domain/engine/session_builder.dart';
import '../../domain/engine/training_params.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/local_date.dart';
import '../repositories/training_repository.dart';
import 'training_service.dart';

/// DEBUG BUILDS ONLY (Settings → Developer). Simulates ~5 weeks of realistic
/// training so every screen can be reviewed. Never reachable in release.
Future<int> loadDemoData(TrainingService svc, {int weeks = 5}) async {
  final profile = await svc.profiles.getProfile();
  final program = await svc.profiles.getActiveProgram();
  if (profile == null || program == null) return 0;
  final today = svc.ctx.today;
  final start = today.addDays(-7 * weeks);

  // Move the plan and journey start back so the history fits inside them.
  await svc.profiles.activateProgram(program.spec, startedOn: start);
  final j = await svc.training.getJourney();
  if (j != null) {
    await svc.training.saveJourney(JourneyRecord(
        startDate: start, currentWeek: 1, countedWeeks: 0, startNodes: j.startNodes, completedOn: null));
  }

  final rnd = math.Random(7);
  var count = 0;
  var weight = profile.weightKg + 2.4;
  var waist = 92.0;
  for (var d = start; d.isBefore(today); d = d.addDays(1)) {
    if (d.weekday == DateTime.monday) {
      await svc.lifestyle.addMeasurement(MeasurementType.weight, double.parse(weight.toStringAsFixed(1)), date: d);
      await svc.lifestyle.addMeasurement(MeasurementType.waist, double.parse(waist.toStringAsFixed(1)), date: d);
      weight -= 0.3 + rnd.nextDouble() * 0.3;
      waist -= 0.3 + rnd.nextDouble() * 0.4;
    }
    final type = program.spec.dayTypeFor(d);
    if (type == DayType.rest || rnd.nextDouble() < 0.18) continue;
    final params = TrainingParams.from(goals: profile.goals, level: profile.level, daysPerWeek: profile.daysPerWeek);
    final plan = SessionBuilder(SessionInputs(
      dayType: type,
      params: params,
      progress: await svc.training.getProgress(),
      filter: ExerciseFilter(profile.environment, profile.limitations),
      minutes: program.spec.minutes,
      seed: d.daysSince(const LocalDate(2024, 1, 1)),
    )).build();
    final startAt = DateTime(d.year, d.month, d.day, 7, 10);
    var snap = PlayerSnapshot.start('demo-${d.toString()}', plan, startAt);
    var now = startAt;
    final effort = 0.9 + rnd.nextDouble() * 0.3;
    while (!snap.isFinished) {
      now = now.add(const Duration(seconds: 45));
      snap = snap.catchUp(now);
      if (!snap.isFinished && !snap.current!.isClocked) {
        snap = snap.completeWork((snap.current!.target * effort).round(), now);
      }
    }
    final rating = effort > 1.1 ? Rating.tooEasy : (effort > 0.97 ? Rating.good : Rating.hard);
    await svc.completeWorkout(snap, rating);
    count++;
  }
  return count;
}
