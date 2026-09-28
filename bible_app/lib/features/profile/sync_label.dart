import '../../data/sync/sync_service.dart';

/// One line describing where the user's data lives right now.
String syncLabel(
  SyncStatus s, {
  required bool signedIn,
  required bool available,
}) {
  if (!available) return 'Saved on this device';
  if (!signedIn) return 'Saved on this device · sign in to sync';
  final pending = s.pending > 0 ? ' · ${s.pending} to upload' : '';
  return switch (s.phase) {
    SyncPhase.localOnly => 'Saved on this device',
    SyncPhase.offline => 'Offline — changes are saved and will sync$pending',
    SyncPhase.syncing => 'Syncing…',
    SyncPhase.error => 'Sync will retry shortly$pending',
    SyncPhase.idle =>
      s.lastSynced == null
          ? 'Synced$pending'
          : 'Synced ${_ago(s.lastSynced!)}$pending',
  };
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}
