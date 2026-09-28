import '../models/enums.dart';
import '../models/local_date.dart';
import 'program_generator.dart';

/// What Home should say today (spec §26: "What should I do today?").
class MissionDay {
  const MissionDay({
    required this.date,
    required this.planned,
    required this.doneToday,
    this.catchUp,
  });

  final LocalDate date;

  /// Today's planned day type (rest if nothing is planned).
  final DayType planned;
  final bool doneToday;

  /// A recently missed session the user can do today instead of resting.
  final DayType? catchUp;

  bool get isRestDay => planned == DayType.rest;

  /// The day type to build today's mission from, if any.
  DayType? get missionType => !isRestDay ? planned : catchUp;
}

/// Decide today's mission. Missed workouts never pile up: on a rest day the
/// most recent missed session of the last 2 days is offered as a catch-up.
MissionDay planToday({
  required LocalDate today,
  required ProgramSpec? program,
  required LocalDate programStart,
  required Set<LocalDate> sessionDates,
}) {
  final planned = program?.dayTypeFor(today) ?? DayType.fullBody;
  final done = sessionDates.contains(today);
  DayType? catchUp;
  if (program != null && planned == DayType.rest) {
    for (var back = 1; back <= 2; back++) {
      final d = today.addDays(-back);
      if (d.isBefore(programStart)) break;
      final t = program.dayTypeFor(d);
      if (t == DayType.rest || t == DayType.recovery) continue;
      if (!sessionDates.contains(d)) {
        catchUp = t;
        break;
      }
      break; // most recent planned day was done — nothing to catch up
    }
  }
  return MissionDay(date: today, planned: planned, doneToday: done, catchUp: catchUp);
}

/// Greeting for the time of day.
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Good evening';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}
