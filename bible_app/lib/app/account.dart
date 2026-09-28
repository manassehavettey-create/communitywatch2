import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth/auth_service.dart';
import '../data/supabase/supabase_remote_store.dart';
import 'providers.dart';

/// Keeps sync pointed at the signed-in account. Watched once by the app.
final accountBinderProvider = Provider<void>((ref) {
  final auth = ref.watch(authServiceProvider);
  final sync = ref.watch(syncServiceProvider);
  final writer = ref.watch(syncWriterProvider);
  String? lastUserId;

  Future<void> apply(AppUser? user) async {
    if (user?.id == lastUserId) return;
    lastUserId = user?.id;
    final client = auth.client;
    if (user == null || client == null) {
      sync.setAccount(userId: null, remote: null);
      return;
    }
    // Anything written before signing in now belongs to this account.
    await writer.claimLocalRows(user.id);
    sync.setAccount(userId: user.id, remote: SupabaseRemoteStore(client));
  }

  ref.listen(currentUserProvider, (_, next) {
    final user = next.value;
    if (next.hasValue) apply(user);
  }, fireImmediately: true);
});

class AccountActions {
  AccountActions(this.ref);

  final Ref ref;

  /// Uploads what it can, then signs out and removes the account's data
  /// from this device.
  Future<void> signOut() async {
    final sync = ref.read(syncServiceProvider);
    try {
      await sync.syncNow();
    } on Object {
      // Offline: the caller already warned about unsynced changes.
    }
    sync.setAccount(userId: null, remote: null);
    await ref.read(syncWriterProvider).wipeUserData();
    await ref.read(authServiceProvider).signOut();
  }

  /// Deletes the account and all its data on the server, then locally.
  Future<void> deleteAccount() async {
    final client = ref.read(authServiceProvider).client;
    if (client == null) return;
    await client.rpc<void>('delete_my_account');
    ref.read(syncServiceProvider).setAccount(userId: null, remote: null);
    await ref.read(syncWriterProvider).wipeUserData();
    await ref.read(authServiceProvider).signOut();
  }
}

final accountActionsProvider = Provider((ref) => AccountActions(ref));
