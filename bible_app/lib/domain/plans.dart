import 'dart:convert';

import '../bible/references.dart';
import 'days.dart';

enum PlanCategory {
  whole('Whole Bible'),
  testament('Testaments'),
  gospels('Gospels'),
  wisdom('Psalms & Proverbs'),
  beginner('Start here'),
  short('Short plans');

  const PlanCategory(this.label);
  final String label;

  static PlanCategory fromName(String n) =>
      PlanCategory.values.firstWhere((c) => c.name == n);
}

/// A reading plan (bundled reference data, also seeded to Supabase).
class PlanDefinition {
  const PlanDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.days,
    required this.minutesPerDay,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final PlanCategory category;

  /// days[0] is day 1; each day is one or more passages.
  final List<List<Passage>> days;
  final int minutesPerDay;

  int get totalDays => days.length;

  List<Passage> readingFor(int day) => days[day - 1];

  String labelFor(int day) => readingFor(day).map((p) => p.label).join(' · ');

  factory PlanDefinition.fromJson(Map<String, dynamic> j) => PlanDefinition(
    id: j['id'] as String,
    title: j['title'] as String,
    subtitle: j['subtitle'] as String,
    description: j['description'] as String,
    category: PlanCategory.fromName(j['category'] as String),
    minutesPerDay: j['minutes'] as int,
    days: [
      for (final d in j['days'] as List)
        [
          for (final p in (d as List).cast<Map<String, dynamic>>())
            Passage.fromJson(p),
        ],
    ],
  );

  static List<PlanDefinition> parseAll(String json) {
    final doc = jsonDecode(json) as Map<String, dynamic>;
    return [
      for (final p in (doc['plans'] as List).cast<Map<String, dynamic>>())
        PlanDefinition.fromJson(p),
    ];
  }
}

enum PlanStatus {
  active,
  paused,
  completed;

  static PlanStatus fromName(String n) =>
      PlanStatus.values.firstWhere((s) => s.name == n);
}

/// Where someone is in a plan, derived from their progress row and
/// completed days. Pure; all dates are local day keys.
class PlanState {
  const PlanState({
    required this.plan,
    required this.status,
    required this.startDate,
    required this.completedDays,
    this.pausedOn,
    this.pausedDays = 0,
  });

  final PlanDefinition plan;
  final PlanStatus status;
  final String startDate;
  final String? pausedOn;

  /// Days spent paused before the current pause (the schedule shifts).
  final int pausedDays;
  final Set<int> completedDays;

  int get totalDays => plan.totalDays;

  int get completedCount =>
      completedDays.where((d) => d >= 1 && d <= totalDays).length;

  double get fraction => totalDays == 0 ? 0 : completedCount / totalDays;

  int get percent => (fraction * 100).floor();

  bool get isFinished => completedCount >= totalDays;

  /// The next day to read: the first day not yet completed.
  int get currentDay {
    for (var d = 1; d <= totalDays; d++) {
      if (!completedDays.contains(d)) return d;
    }
    return totalDays;
  }

  /// The day the calendar says you'd be on, if reading one day per day
  /// (paused time doesn't count).
  int scheduledDay(String today) {
    final asOf = status == PlanStatus.paused && pausedOn != null
        ? pausedOn!
        : today;
    final elapsed = Days.between(startDate, asOf) - pausedDays;
    return (elapsed + 1).clamp(1, totalDays);
  }

  /// Scheduled days (up to and including today's) not yet completed.
  int behindBy(String today) {
    final upTo = scheduledDay(today);
    var missing = 0;
    for (var d = 1; d <= upTo; d++) {
      if (!completedDays.contains(d)) missing++;
    }
    // Today's reading isn't "behind" until tomorrow.
    if (!completedDays.contains(upTo)) missing--;
    return missing < 0 ? 0 : missing;
  }

  /// The calendar date a given plan day is scheduled for.
  String dateOfDay(int day, String today) {
    final shift =
        pausedDays +
        (status == PlanStatus.paused && pausedOn != null
            ? Days.between(pausedOn!, today)
            : 0);
    return Days.add(startDate, day - 1 + shift);
  }

  /// Completed days before the current day, newest first.
  List<int> pastDays() => [
    for (var d = currentDay - 1; d >= 1; d--)
      if (completedDays.contains(d)) d,
  ];

  /// The next [count] days after the current one.
  List<int> upcomingDays({int count = 7}) => [
    for (var d = currentDay + 1; d <= totalDays && d <= currentDay + count; d++)
      d,
  ];

  /// Accumulated paused days after resuming today.
  static int resumedPausedDays({
    required int pausedDays,
    required String pausedOn,
    required String today,
  }) => pausedDays + Days.between(pausedOn, today).clamp(0, 100000);
}
