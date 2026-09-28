import '../models/enums.dart';
import '../models/local_date.dart';
import 'program_generator.dart';

enum DayStatus {
  completed('Workout completed'),
  modified('Modified workout'),
  recovery('Recovery'),
  rest('Rest'),
  missed('Missed'),
  planned('Planned'),
  today('Today');

  const DayStatus(this.label);
  final String label;
}

class CalendarEntry {
  const CalendarEntry({required this.kind, required this.dayType});
  final SessionKind kind;
  final DayType dayType;
}

class CalendarDay {
  const CalendarDay(this.date, this.status, {this.planned});
  final LocalDate date;
  final DayStatus status;
  final DayType? planned;
}

/// Spec §18: a 30-day view of completed, modified, recovery and rest days.
/// Missed planned days are shown softly — one missed day doesn't erase the
/// pattern. [programStart] stops "missed" appearing before the user joined.
List<CalendarDay> buildCalendar({
  required LocalDate today,
  required Map<LocalDate, List<CalendarEntry>> sessions,
  required ProgramSpec? program,
  required LocalDate programStart,
  int days = 30,
}) {
  final out = <CalendarDay>[];
  final first = today.addDays(-(days - 1));
  for (var i = 0; i < days; i++) {
    final date = first.addDays(i);
    final done = sessions[date] ?? const [];
    final planned = program?.dayTypeFor(date);
    final plannedTraining = planned != null && planned != DayType.rest && !date.isBefore(programStart);
    DayStatus status;
    if (done.isNotEmpty) {
      if (done.any((e) => e.kind != SessionKind.recovery && !e.kind.isModified && e.dayType != DayType.recovery)) {
        status = DayStatus.completed;
      } else if (done.any((e) => e.kind.isModified)) {
        status = DayStatus.modified;
      } else {
        status = DayStatus.recovery;
      }
    } else if (date == today) {
      status = plannedTraining ? DayStatus.today : DayStatus.rest;
    } else if (date.isAfter(today)) {
      status = plannedTraining ? DayStatus.planned : DayStatus.rest;
    } else {
      status = plannedTraining ? DayStatus.missed : DayStatus.rest;
    }
    out.add(CalendarDay(date, status, planned: plannedTraining ? planned : null));
  }
  return out;
}

/// Consistency % over a window: completed sessions ÷ planned sessions.
double consistency({
  required LocalDate from,
  required LocalDate to,
  required List<LocalDate> sessionDates,
  required ProgramSpec? program,
  required LocalDate programStart,
}) {
  if (program == null) return 0;
  var planned = 0;
  for (var d = from; !d.isAfter(to); d = d.addDays(1)) {
    if (d.isBefore(programStart)) continue;
    if (program.isTrainingDay(d)) planned++;
  }
  final done = {for (final d in sessionDates) if (!d.isBefore(from) && !d.isAfter(to)) d}.length;
  if (planned == 0) return done > 0 ? 1 : 0;
  return (done / planned).clamp(0.0, 1.0);
}

/// Current streak of weeks where at least one workout happened (a kinder
/// streak than daily — rest days are part of training).
int activeWeekStreak(LocalDate today, List<LocalDate> sessionDates) {
  final weeks = {for (final d in sessionDates) d.startOfWeek};
  var w = today.startOfWeek;
  // The current week counts only if something happened; otherwise start from last week.
  if (!weeks.contains(w)) w = w.addDays(-7);
  var n = 0;
  while (weeks.contains(w)) {
    n++;
    w = w.addDays(-7);
  }
  return n;
}
