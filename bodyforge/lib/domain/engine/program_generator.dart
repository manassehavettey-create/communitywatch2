import '../models/enums.dart';
import '../models/local_date.dart';

class ProgramDay {
  const ProgramDay(this.weekday, this.dayType);

  /// 1 = Monday … 7 = Sunday.
  final int weekday;
  final DayType dayType;

  Map<String, Object?> toJson() => {'w': weekday, 'd': dayType.name};
  factory ProgramDay.fromJson(Map<String, Object?> j) =>
      ProgramDay((j['w']! as num).toInt(), enumByName(DayType.values, j['d'] as String?, DayType.fullBody));

  @override
  bool operator ==(Object other) => other is ProgramDay && other.weekday == weekday && other.dayType == dayType;
  @override
  int get hashCode => Object.hash(weekday, dayType);
  @override
  String toString() => '$weekday:${dayType.name}';
}

/// A weekly training template.
class ProgramSpec {
  const ProgramSpec({
    required this.name,
    required this.goals,
    required this.daysPerWeek,
    required this.minutes,
    required this.days,
    this.focus = const {},
    this.custom = false,
  });

  final String name;
  final Set<Goal> goals;
  final int daysPerWeek;
  final int minutes;
  final List<ProgramDay> days;
  final Set<MuscleFocus> focus;
  final bool custom;

  DayType dayTypeFor(LocalDate date) {
    for (final d in days) {
      if (d.weekday == date.weekday) return d.dayType;
    }
    return DayType.rest;
  }

  bool isTrainingDay(LocalDate date) => dayTypeFor(date) != DayType.rest;

  /// Planned sessions per week (recovery sessions included — they count).
  int get sessionsPerWeek => days.length;
}

const Map<int, List<int>> _defaultWeekdays = {
  1: [1],
  2: [1, 4],
  3: [1, 3, 5],
  4: [1, 2, 4, 5],
  5: [1, 2, 3, 4, 5],
  6: [1, 2, 3, 4, 5, 6],
  7: [1, 2, 3, 4, 5, 6, 7],
};

/// Choose weekdays: the user's preferred days when they match the count,
/// otherwise topped up / trimmed using an evenly spread default.
List<int> assignWeekdays(int count, List<int> preferred) {
  final n = count.clamp(1, 7);
  final pref = {...preferred.where((d) => d >= 1 && d <= 7)}.toList()..sort();
  if (pref.length == n) return pref;
  final result = <int>[...pref.take(n)];
  for (final d in _defaultWeekdays[n]!) {
    if (result.length >= n) break;
    if (!result.contains(d)) result.add(d);
  }
  for (var d = 1; result.length < n && d <= 7; d++) {
    if (!result.contains(d)) result.add(d);
  }
  result.sort();
  return result;
}

List<DayType> _rotationForGoals(Set<Goal> goals, int n) {
  final strengthOnly = goals.contains(Goal.getStronger) &&
      !goals.contains(Goal.loseFat) &&
      !goals.contains(Goal.fullTransformation) &&
      !goals.contains(Goal.visibleAbs);
  final fatLossLed = (goals.contains(Goal.loseFat) || goals.contains(Goal.fullTransformation)) &&
      !goals.contains(Goal.getStronger);
  final abs = goals.contains(Goal.visibleAbs);

  var r = switch (n) {
    1 => [DayType.fullBody],
    2 => [DayType.fullBody, DayType.fullBody],
    3 => fatLossLed
        ? [DayType.fullBody, DayType.conditioning, DayType.fullBody]
        : [DayType.fullBody, DayType.upperCore, DayType.lower],
    4 => fatLossLed
        ? [DayType.upper, DayType.lower, DayType.conditioning, DayType.fullBody]
        : [DayType.upper, DayType.lower, DayType.upperCore, DayType.fullBody],
    5 => [DayType.upper, DayType.lower, DayType.recovery, DayType.upperCore, DayType.fullBody],
    6 => [DayType.upper, DayType.lower, DayType.recovery, DayType.upperCore, DayType.fullBody, DayType.conditioning],
    _ => [
        DayType.upper,
        DayType.lower,
        DayType.recovery,
        DayType.upperCore,
        DayType.fullBody,
        DayType.conditioning,
        DayType.recovery,
      ],
  };
  if (strengthOnly) {
    r = [for (final d in r) d == DayType.conditioning ? DayType.fullBody : d];
  }
  if (abs) {
    r = [for (final d in r) d == DayType.upper ? DayType.upperCore : d];
  }
  return r;
}

List<DayType> _rotationForFocus(Set<MuscleFocus> focus, int n) {
  final upperFocus = focus.intersection({MuscleFocus.chest, MuscleFocus.arms, MuscleFocus.shoulders, MuscleFocus.back});
  final types = <DayType>[];
  if (focus.contains(MuscleFocus.fullBody) || focus.isEmpty) types.add(DayType.fullBody);
  if (upperFocus.isNotEmpty && focus.contains(MuscleFocus.core)) {
    types.addAll([DayType.upper, DayType.upperCore]);
  } else if (upperFocus.isNotEmpty) {
    types.add(DayType.upper);
  } else if (focus.contains(MuscleFocus.core)) {
    types.add(DayType.core);
  }
  if (focus.contains(MuscleFocus.legs)) types.add(DayType.lower);
  if (types.isEmpty) types.add(DayType.fullBody);

  final trainingDays = n >= 5 ? n - 1 : n;
  final r = [for (var i = 0; i < trainingDays; i++) types[i % types.length]];
  if (n >= 5) r.insert(2, DayType.recovery);
  return r;
}

String _nameFor(List<DayType> r, bool custom) {
  final set = r.toSet()..remove(DayType.recovery);
  final label = set.length == 1 && set.first == DayType.fullBody
      ? 'Full Body'
      : set.contains(DayType.upper) || set.contains(DayType.upperCore)
          ? (set.contains(DayType.lower) ? 'Upper / Lower' : 'Upper Focus')
          : set.contains(DayType.lower)
              ? 'Lower Focus'
              : set.contains(DayType.core)
                  ? 'Core Focus'
                  : 'Hybrid';
  return '${custom ? 'Custom · ' : ''}$label · ${r.length} days';
}

/// Generates the weekly schedule (spec §4 and §19).
ProgramSpec generateProgram({
  required Set<Goal> goals,
  required int daysPerWeek,
  required int minutes,
  List<int> preferredDays = const [],
  Set<MuscleFocus>? focus,
}) {
  final n = daysPerWeek.clamp(1, 7);
  final custom = focus != null && focus.isNotEmpty;
  final rotation = custom ? _rotationForFocus(focus, n) : _rotationForGoals(goals, n);
  final weekdays = assignWeekdays(n, preferredDays);
  return ProgramSpec(
    name: _nameFor(rotation, custom),
    goals: goals,
    daysPerWeek: n,
    minutes: minutes.clamp(5, 60),
    days: [for (var i = 0; i < n; i++) ProgramDay(weekdays[i], rotation[i])],
    focus: focus ?? const {},
    custom: custom,
  );
}
