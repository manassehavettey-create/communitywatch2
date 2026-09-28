import 'package:uuid/uuid.dart';

import '../../domain/models/local_date.dart';
import '../local/database.dart';

/// Shared by all repositories: the database, the signed-in (or local) user and
/// a clock (swappable in tests).
class DataContext {
  DataContext({required this.db, required this.userId, Clock? clock}) : clock = clock ?? const SystemClock();

  final AppDatabase db;
  final String userId;
  final Clock clock;

  static const _uuid = Uuid();
  String newId() => _uuid.v4();

  DateTime get nowUtc => clock.now().toUtc();
  LocalDate get today => clock.today();

  /// Stable id for "one row per user per key" tables.
  String keyed(String key) => '$userId:$key';
}
