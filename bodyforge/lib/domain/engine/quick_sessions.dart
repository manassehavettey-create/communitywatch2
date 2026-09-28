import '../catalog/exercises.dart';
import '../models/enums.dart';
import '../models/workout.dart';
import 'recovery.dart';
import 'session_builder.dart';
import 'time_fitter.dart';

/// "I don't feel like working out" mode (spec §7).
const kLowMotivationMessage = 'Something is better than nothing.';

enum QuickOption {
  five(5, '5 minutes', 'A quick movement session'),
  ten(10, '10 minutes', 'A short full-body workout'),
  fifteen(15, '15 minutes', 'A reduced version of today\'s workout');

  const QuickOption(this.minutes, this.label, this.description);
  final int minutes;
  final String label;
  final String description;
}

const _movementSnack = [
  'march_in_place', 'arm_circles', 'bodyweight_squat', 'good_morning', 'step_jack', 'standing_knee_to_elbow',
  'hip_circles', 'wall_angel', 'quarter_squat', 'leg_swings', 'cat_cow',
];

/// Build a low-motivation session. [todaysDay] is today's planned day type
/// (rest / recovery fall back to full body for the 15-minute option).
WorkoutPlan buildQuickSession(QuickOption option, SessionInputs base, {required DayType todaysDay}) {
  switch (option) {
    case QuickOption.five:
      final list = <PlannedExercise>[];
      for (final id in _movementSnack) {
        if (list.length >= 5) break;
        if (!base.filter.allowsId(id)) continue;
        final ex = exerciseById(id);
        list.add(PlannedExercise(
          exerciseId: id,
          sets: 1,
          amount: ex.isTimed ? 40 : 10,
          restSec: 10,
          role: list.isEmpty ? SlotRole.primary : SlotRole.secondary,
        ));
      }
      final plan = WorkoutPlan(
        title: 'Quick Movement',
        dayType: DayType.fullBody,
        kind: SessionKind.lowMotivation,
        objective: 'Move your body and keep the habit alive',
        difficultyLabel: 'Easy',
        notes: const [kLowMotivationMessage],
        blocks: [PlanBlock(kind: BlockKind.main, exercises: list, circuit: true, rounds: 1)],
      );
      return fitToTime(plan, 5, params: base.params);
    case QuickOption.ten:
      final plan = SessionBuilder(base.copyWith(
        dayType: DayType.fullBody,
        minutes: 10,
        kind: SessionKind.lowMotivation,
        recovery: RecoveryAdjustment.none,
      )).build();
      return plan.copyWith(title: '10-Minute Full Body', notes: [kLowMotivationMessage, ...plan.notes]);
    case QuickOption.fifteen:
      final day = (todaysDay == DayType.rest || todaysDay == DayType.recovery || todaysDay == DayType.benchmark)
          ? DayType.fullBody
          : todaysDay;
      final plan = SessionBuilder(base.copyWith(dayType: day, minutes: 15, kind: SessionKind.lowMotivation)).build();
      return plan.copyWith(title: '15-Minute ${day.label}', notes: [kLowMotivationMessage, ...plan.notes]);
  }
}
