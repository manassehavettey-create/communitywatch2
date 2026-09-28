import 'dart:async';

import 'package:drift/drift.dart';

import 'database.dart';

extension WatchTables on AppDatabase {
  /// Runs [load] now and again whenever any of [tables] changes.
  ///
  /// Used for aggregate queries that span several tables, where a single
  /// drift `.watch()` would miss updates to the joined tables. Overlapping
  /// changes are coalesced into one reload.
  Stream<T> watchTables<T>(
    Iterable<ResultSetImplementation<dynamic, dynamic>> tables,
    Future<T> Function() load,
  ) {
    late final StreamController<T> controller;
    StreamSubscription<Set<TableUpdate>>? sub;
    var running = false;
    var dirty = false;

    Future<void> run() async {
      if (running) {
        dirty = true;
        return;
      }
      running = true;
      do {
        dirty = false;
        try {
          final value = await load();
          if (!controller.isClosed) controller.add(value);
        } catch (e, st) {
          if (!controller.isClosed) controller.addError(e, st);
        }
      } while (dirty && !controller.isClosed);
      running = false;
    }

    controller = StreamController<T>(
      onListen: () {
        sub = tableUpdates(TableUpdateQuery.onAllTables(tables))
            .listen((_) => run());
        run();
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }
}
