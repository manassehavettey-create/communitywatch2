import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/account.dart';
import '../../app/demo_data.dart';
import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/layout.dart';
import '../../data/db/database.dart';
import '../../data/sync/sync_service.dart';
import '../audio/audio_catalog.dart';
import '../reader/reader_sheets.dart';
import 'sync_label.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const readingReminderKey = 'reminder.reading';
  static const readingReminderTimeKey = 'reminder.reading.minutes';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final prefs = ref.watch(prefsValueProvider);
    final translation = ref.watch(currentTranslationProvider).value;
    final user = ref.watch(currentUserProvider).value;
    final auth = ref.watch(authServiceProvider);
    final sync =
        ref.watch(syncStatusProvider).value ??
        const SyncStatus(SyncPhase.localOnly);
    final reminderOn =
        ref.watch(localSettingProvider(readingReminderKey)).value == 'on';
    final reminderMinutes =
        int.tryParse(
          ref.watch(localSettingProvider(readingReminderTimeKey)).value ?? '',
        ) ??
        7 * 60;
    final reminders = ref.read(reminderServiceProvider);
    final db = ref.read(databaseProvider);

    Future<void> setReminder(bool on, int minutes) async {
      if (on) {
        final ok = await reminders.requestPermission();
        if (!ok) {
          if (context.mounted) {
            toast(
              context,
              'Allow notifications in system settings to get reminders.',
            );
          }
          return;
        }
        await reminders.scheduleReading(minutes);
      } else {
        await reminders.cancelReading();
      }
      await db.setValue(readingReminderKey, on ? 'on' : 'off');
      await db.setValue(readingReminderTimeKey, '$minutes');
    }

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.x5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: Space.x2),
            child: Text(
              title.toUpperCase(),
              style: AppType.overline.copyWith(color: p.inkMute),
            ),
          ),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: children),
          ),
        ],
      ),
    );

    Widget row(
      IconData icon,
      String title, {
      String? subtitle,
      Widget? trailing,
      VoidCallback? onTap,
    }) => ListTile(
      leading: Icon(icon, color: p.ink),
      title: Text(title, style: AppType.body.copyWith(color: p.ink)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: AppType.caption.copyWith(color: p.inkMute)),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 16,
                  color: p.inkMute,
                )),
      onTap: onTap,
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.x14),
          children: [
            ScreenHeader(
              title: 'Settings',
              leading: CircleIconButton(
                icon: PhosphorIconsBold.caretLeft,
                tooltip: 'Back',
                onPressed: () => context.pop(),
              ),
            ),
            section('Appearance', [
              RadioGroup<AppThemeMode>(
                groupValue: prefs.appTheme,
                onChanged: (v) => ref
                    .read(preferencesRepositoryProvider)
                    .update(PreferencesCompanion(appTheme: Value(v!.name))),
                child: Column(
                  children: [
                    for (final m in AppThemeMode.values)
                      RadioListTile<AppThemeMode>(
                        value: m,
                        title: Text(
                          m.label,
                          style: AppType.body.copyWith(color: p.ink),
                        ),
                        subtitle: m == AppThemeMode.dark
                            ? Text(
                                'Warm dark colours designed for reading at night',
                                style: AppType.caption.copyWith(
                                  color: p.inkMute,
                                ),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ]),
            section('Reading', [
              row(
                PhosphorIconsRegular.translate,
                'Translation',
                subtitle: translation?.name,
                onTap: () => showAppSheet(
                  context,
                  builder: (_) => const TranslationSheet(),
                ),
              ),
              row(
                PhosphorIconsRegular.textAa,
                'Text size, spacing and page',
                subtitle: '${prefs.font.label} · ${prefs.fontSize.round()} pt',
                onTap: () => showAppSheet(
                  context,
                  builder: (_) => const ReaderSettingsSheet(),
                ),
              ),
            ]),
            section('Reminders', [
              SwitchListTile.adaptive(
                secondary: Icon(PhosphorIconsRegular.bell, color: p.ink),
                title: Text(
                  'Daily reading reminder',
                  style: AppType.body.copyWith(color: p.ink),
                ),
                subtitle: Text(
                  reminders.supported
                      ? TimeOfDay(
                          hour: reminderMinutes ~/ 60,
                          minute: reminderMinutes % 60,
                        ).format(context)
                      : 'Available in the phone app',
                  style: AppType.caption.copyWith(color: p.inkMute),
                ),
                value: reminderOn,
                onChanged: reminders.supported
                    ? (v) => setReminder(v, reminderMinutes)
                    : null,
              ),
              if (reminderOn)
                row(
                  PhosphorIconsRegular.clock,
                  'Reminder time',
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: reminderMinutes ~/ 60,
                        minute: reminderMinutes % 60,
                      ),
                    );
                    if (t != null) {
                      await setReminder(true, t.hour * 60 + t.minute);
                    }
                  },
                ),
              row(
                PhosphorIconsRegular.handsPraying,
                'Prayer reminders',
                subtitle: 'Set on each prayer',
                onTap: () => context.go('/prayer'),
              ),
            ]),
            section('Audio', [
              row(
                PhosphorIconsRegular.headphones,
                'Audio Bible',
                subtitle: licensedAudioSources.isEmpty
                    ? 'Not available yet — no licensed recordings confirmed'
                    : '${licensedAudioSources.length} licensed recordings',
              ),
            ]),
            section('Privacy', [
              row(
                PhosphorIconsRegular.lockSimple,
                'Your data',
                subtitle:
                    'Your journal, prayers and notes are private. They are stored on this device and, '
                    'when you sign in, in your own account — no one else can read them.',
              ),
              row(
                PhosphorIconsRegular.bookOpen,
                'Scripture works offline',
                subtitle: 'All translations are stored in the app. Reading never needs a connection.',
              ),
            ]),
            section('Account', [
              if (!auth.available)
                row(
                  PhosphorIconsRegular.cloudSlash,
                  'Sync isn’t set up in this build',
                  subtitle: 'Everything is saved on this device.',
                )
              else if (user == null)
                row(
                  PhosphorIconsRegular.signIn,
                  'Sign in or create an account',
                  subtitle: 'Sync across your devices',
                  onTap: () => context.push('/auth'),
                )
              else ...[
                row(
                  PhosphorIconsRegular.userCircle,
                  user.email ?? 'Signed in',
                  subtitle: syncLabel(sync, signedIn: true, available: true),
                  trailing: sync.phase == SyncPhase.syncing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          tooltip: 'Sync now',
                          icon: const Icon(
                            PhosphorIconsRegular.arrowsClockwise,
                          ),
                          onPressed: () =>
                              ref.read(syncServiceProvider).syncNow(),
                        ),
                ),
                row(
                  PhosphorIconsRegular.signOut,
                  'Sign out',
                  onTap: () async {
                    final pending = sync.pending;
                    final ok = await confirmDestructive(
                      context,
                      title: 'Sign out?',
                      message: pending > 0 && sync.phase == SyncPhase.offline
                          ? 'You have $pending changes that haven’t synced yet. Signing out now removes them from this device.'
                          : 'Your data stays in your account and is removed from this device.',
                      confirmLabel: 'Sign out',
                    );
                    if (ok) await ref.read(accountActionsProvider).signOut();
                  },
                ),
                row(
                  PhosphorIconsRegular.trash,
                  'Delete account',
                  onTap: () async {
                    final ok = await confirmDestructive(
                      context,
                      title: 'Delete your account?',
                      message:
                          'This permanently deletes your account and everything in it — notes, highlights, '
                          'journal, prayers and plans — from every device. It can’t be undone.',
                      confirmLabel: 'Delete forever',
                    );
                    if (!ok) return;
                    try {
                      await ref.read(accountActionsProvider).deleteAccount();
                      if (context.mounted) {
                        toast(context, 'Your account was deleted.');
                      }
                    } on Object catch (e) {
                      if (context.mounted) {
                        toast(context, 'Couldn’t delete the account: $e');
                      }
                    }
                  },
                ),
              ],
            ]),
            section('About', [
              row(
                PhosphorIconsRegular.info,
                'Translations, fonts and credits',
                onTap: () => context.push('/about'),
              ),
            ]),
            if (kDebugMode)
              section('Developer (debug builds only)', [
                row(
                  PhosphorIconsRegular.flask,
                  'Load demo data',
                  onTap: () async {
                    await ref.read(demoDataProvider).load();
                    if (context.mounted) toast(context, 'Demo data added');
                  },
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
