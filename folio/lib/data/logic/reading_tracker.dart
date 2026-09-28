/// Measures real reading while the reader is open.
///
/// * Time only accrues while the app is in the foreground and the reader has
///   seen an interaction (scroll, tap, page turn) within [idleTimeout].
/// * A page counts as "read" once it has been the current page for at least
///   [minDwell] of active time; each page counts once per session.
///
/// Pure Dart (clock is passed in) so it's unit-testable.
class ReadingTracker {
  ReadingTracker({
    required int startPage,
    required DateTime now,
    this.idleTimeout = const Duration(minutes: 3),
    this.minDwell = const Duration(seconds: 5),
  })  : _currentPage = startPage,
        startPage = startPage,
        _lastTick = now,
        _lastInteraction = now;

  final Duration idleTimeout;
  final Duration minDwell;
  final int startPage;

  int _currentPage;
  DateTime _lastTick;
  DateTime _lastInteraction;
  bool _paused = false;
  Duration _active = Duration.zero;
  Duration _dwell = Duration.zero;
  final Set<int> _countedPages = {};

  // Totals not yet written to storage.
  Duration _unflushedActive = Duration.zero;
  int _unflushedPages = 0;

  int get currentPage => _currentPage;
  Duration get activeTime => _active;
  int get pagesRead => _countedPages.length;
  bool get isPaused => _paused;

  void _advance(DateTime now) {
    if (!_paused) {
      final idleUntil = _lastInteraction.add(idleTimeout);
      final end = now.isBefore(idleUntil) ? now : idleUntil;
      if (end.isAfter(_lastTick)) {
        final delta = end.difference(_lastTick);
        _active += delta;
        _unflushedActive += delta;
        _dwell += delta;
        if (_dwell >= minDwell && _countedPages.add(_currentPage)) {
          _unflushedPages++;
        }
      }
    }
    _lastTick = now;
  }

  /// Call on a timer (e.g. every second) to accrue time.
  void tick(DateTime now) => _advance(now);

  /// Any user interaction keeps the session active.
  void interaction(DateTime now) {
    _advance(now);
    _lastInteraction = now;
  }

  void pageChanged(int page, DateTime now) {
    _advance(now);
    _lastInteraction = now;
    if (page != _currentPage) {
      _currentPage = page;
      _dwell = Duration.zero;
    }
  }

  void pause(DateTime now) {
    _advance(now);
    _paused = true;
  }

  void resume(DateTime now) {
    _lastTick = now;
    _lastInteraction = now;
    _paused = false;
  }

  /// Returns and clears the totals accumulated since the last flush.
  ({Duration active, int pages}) takeUnflushed(DateTime now) {
    _advance(now);
    final r = (active: _unflushedActive, pages: _unflushedPages);
    _unflushedActive = Duration.zero;
    _unflushedPages = 0;
    return r;
  }
}
