import '../models/enums.dart';
import '../models/local_date.dart';

const kJourneyWeeks = 12;

enum JourneyWeekStatus {
  /// The week counted toward the journey.
  counted,

  /// Fewer than the required workouts — the week is repeated, not failed.
  repeated,

  /// The week in progress.
  current,
}

class JourneyBlock {
  const JourneyBlock({
    required this.start,
    required this.journeyWeek,
    required this.status,
    required this.workouts,
    required this.required,
  });

  final LocalDate start;
  LocalDate get end => start.addDays(6);

  /// Which journey week this block was (repeats share a number).
  final int journeyWeek;
  final JourneyWeekStatus status;
  final int workouts;
  final int required;
}

class JourneyState {
  const JourneyState({
    required this.currentWeek,
    required this.countedWeeks,
    required this.currentWeekWorkouts,
    required this.requiredPerWeek,
    required this.plannedPerWeek,
    required this.blocks,
    required this.complete,
    this.completedOn,
  });

  /// 1…12 (stays 12 once complete).
  final int currentWeek;

  /// Weeks that met the target (including the current one if already met).
  final int countedWeeks;
  final int currentWeekWorkouts;
  final int requiredPerWeek;
  final int plannedPerWeek;
  final List<JourneyBlock> blocks;
  final bool complete;
  final LocalDate? completedOn;

  JourneyPhase get phase => JourneyPhase.forWeek(currentWeek);
  bool get currentWeekMet => currentWeekWorkouts >= requiredPerWeek;

  /// 0.0–1.0 overall progress, including partial credit for this week.
  double get progress {
    if (complete) return 1;
    final done = countedWeeks - (currentWeekMet ? 1 : 0);
    final partial = plannedPerWeek == 0 ? 0.0 : (currentWeekWorkouts / plannedPerWeek).clamp(0.0, 1.0);
    return ((done + partial) / kJourneyWeeks).clamp(0.0, 1.0);
  }

  int get repeatedWeeks => blocks.where((b) => b.status == JourneyWeekStatus.repeated).length;
}

/// Workouts needed for a week to count: at least half the plan (min 1).
int requiredWorkoutsPerWeek(int planned) => planned <= 1 ? 1 : (planned / 2).ceil();

/// Spec §21. The journey runs in 7-day blocks from [start]. A block counts
/// when at least half of the planned workouts were done; otherwise that week
/// is repeated, so a bad week — or weeks away — pauses the journey instead of
/// breaking it. [workoutDates] are the dates of completed sessions (any kind).
JourneyState computeJourney({
  required LocalDate start,
  required LocalDate today,
  required List<LocalDate> workoutDates,
  required int plannedPerWeek,
}) {
  final required = requiredWorkoutsPerWeek(plannedPerWeek);
  final dates = [...workoutDates]..sort();
  var counted = 0;
  final blocks = <JourneyBlock>[];
  LocalDate? completedOn;
  var currentCount = 0;

  if (today.isBefore(start)) {
    return JourneyState(
      currentWeek: 1,
      countedWeeks: 0,
      currentWeekWorkouts: 0,
      requiredPerWeek: required,
      plannedPerWeek: plannedPerWeek,
      blocks: const [],
      complete: false,
    );
  }

  var blockStart = start;
  while (!blockStart.isAfter(today) && counted < kJourneyWeeks) {
    final blockEnd = blockStart.addDays(6);
    final inBlock = dates.where((d) => !d.isBefore(blockStart) && !d.isAfter(blockEnd)).toList();
    final isCurrent = !today.isAfter(blockEnd);
    final week = counted + 1;
    if (isCurrent) {
      currentCount = inBlock.length;
      final met = inBlock.length >= required;
      if (met) {
        counted++;
        if (counted == kJourneyWeeks) completedOn = inBlock[required - 1];
      }
      blocks.add(JourneyBlock(
          start: blockStart, journeyWeek: week, status: JourneyWeekStatus.current, workouts: inBlock.length, required: required));
    } else {
      final met = inBlock.length >= required;
      if (met) {
        counted++;
        if (counted == kJourneyWeeks) completedOn = inBlock[required - 1];
      }
      blocks.add(JourneyBlock(
        start: blockStart,
        journeyWeek: week,
        status: met ? JourneyWeekStatus.counted : JourneyWeekStatus.repeated,
        workouts: inBlock.length,
        required: required,
      ));
    }
    blockStart = blockStart.addDays(7);
  }

  final complete = counted >= kJourneyWeeks;
  final currentWeek = complete ? kJourneyWeeks : (blocks.isNotEmpty && blocks.last.status == JourneyWeekStatus.current
      ? blocks.last.journeyWeek
      : counted + 1);
  return JourneyState(
    currentWeek: currentWeek.clamp(1, kJourneyWeeks),
    countedWeeks: counted,
    currentWeekWorkouts: complete ? 0 : currentCount,
    requiredPerWeek: required,
    plannedPerWeek: plannedPerWeek,
    blocks: blocks,
    complete: complete,
    completedOn: completedOn,
  );
}

/// Weeks at which a benchmark test is suggested (baseline, end of each phase).
const kBenchmarkWeeks = {1, 4, 8, 12};
