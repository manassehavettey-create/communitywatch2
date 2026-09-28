import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/auth.dart';
import '../../app/config.dart';
import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../app/sync_controller.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/navigation.dart';
import '../../core/widgets/page.dart';
import '../../data/services/demo_data.dart';
import '../../data/services/export_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  SettingsController get _s => ref.read(settingsProvider.notifier);

  Future<void> _toggleReminders(bool on) async {
    if (on) {
      final granted = await ref.read(notificationsProvider).requestPermission();
      if (!granted && mounted) {
        toast(context, 'Allow notifications for BODYFORGE in your phone settings to get reminders.');
      }
    }
    _s.update((s) => s.copyWith(remindersEnabled: on));
  }

  Future<void> _pickTime() async {
    final current = ref.read(settingsProvider).reminderTime;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) _s.update((s) => s.copyWith(reminderMinutes: picked.hour * 60 + picked.minute));
  }

  Future<void> _export() async {
    final auth = ref.read(authProvider);
    if (auth.userId == null) return;
    setState(() => _busy = true);
    try {
      final json = await ExportService(ref.read(databaseProvider), auth.userId!).toJson();
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${dir.path}/bodyforge-export-$stamp.json');
      await file.writeAsString(json);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/json')], subject: 'My BODYFORGE data'));
    } catch (e) {
      if (mounted) toast(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final pending = await ref.read(databaseProvider).pendingChanges();
    if (!mounted) return;
    final auth = ref.read(authProvider);
    final ok = await confirm(
      context,
      title: auth.isCloud ? 'Sign out?' : 'Remove data from this phone?',
      message: auth.isCloud
          ? (pending > 0
              ? '$pending change${pending == 1 ? ' hasn\'t' : 's haven\'t'} synced yet and will be lost. Connect to the internet first to keep them.'
              : 'Your data is safely backed up. This phone\'s copy will be removed.')
          : 'You don\'t have an account, so everything on this phone will be deleted.',
      confirmLabel: auth.isCloud ? 'Sign out' : 'Delete everything',
      destructive: true,
    );
    if (ok) await ref.read(authProvider.notifier).signOut();
  }

  Future<void> _delete() async {
    final ctl = TextEditingController();
    final auth = ref.read(authProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Delete account & all data'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(auth.isCloud
                ? 'This permanently deletes your account, every workout, record, measurement and achievement — on this phone and on the server. This can\'t be undone.'
                : 'This permanently deletes everything BODYFORGE has stored on this phone.'),
            const SizedBox(height: Space.md),
            const Text('Type DELETE to confirm.'),
            const SizedBox(height: Space.xs),
            TextField(controller: ctl, autofocus: true, onChanged: (_) => setD(() {})),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: ctl.text.trim() == 'DELETE' ? () => Navigator.pop(ctx, true) : null,
              child: Text('Delete forever', style: TextStyle(color: ctx.bf.danger, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).deleteAccount();
    } on AuthFailure catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider);
    final sync = ref.watch(syncProvider);
    final t = Theme.of(context).textTheme;
    final c = context.bf;

    Widget group(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: Space.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Overline(title),
            const SizedBox(height: Space.sm),
            BfCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: children)),
          ]),
        );
    Widget tile(IconData icon, String title, {String? sub, Widget? below, Widget? trailing, VoidCallback? onTap, Color? color}) => ListTile(
          leading: Icon(icon, color: color ?? c.text),
          title: Text(title, style: t.titleSmall?.copyWith(color: color)),
          subtitle: below != null
              ? Padding(padding: const EdgeInsets.only(top: Space.xs), child: Align(alignment: Alignment.centerLeft, child: below))
              : (sub == null ? null : Text(sub, style: t.bodySmall)),
          trailing: trailing,
          onTap: onTap,
        );

    return BfPage(
      title: 'Settings',
      children: [
        group('Appearance', [
          tile(BfIcons.theme, 'Theme',
              below: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: c.primary,
                  selectedForegroundColor: BfPalette.ink,
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => _s.update((x) => x.copyWith(themeMode: v.first)),
              )),
          tile(BfIcons.units, 'Units',
              below: SegmentedButton<UnitSystem>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: c.primary,
                  selectedForegroundColor: BfPalette.ink,
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(value: UnitSystem.metric, label: Text('kg/cm')),
                  ButtonSegment(value: UnitSystem.imperial, label: Text('lb/in')),
                ],
                selected: {s.units},
                onSelectionChanged: (v) => _s.update((x) => x.copyWith(units: v.first)),
              )),
          SwitchListTile(
            secondary: const Icon(BfIcons.vibration),
            title: Text('Haptics', style: t.titleSmall),
            value: s.haptics,
            onChanged: (v) => _s.update((x) => x.copyWith(haptics: v)),
          ),
        ]),
        group('Reminders', [
          SwitchListTile(
            secondary: const Icon(BfIcons.bell),
            title: Text('Training reminders', style: t.titleSmall),
            subtitle: Text('On your training days', style: t.bodySmall),
            value: s.remindersEnabled,
            onChanged: _toggleReminders,
          ),
          tile(BfIcons.time, 'Reminder time', trailing: Text(s.reminderTime.format(context), style: t.titleSmall), onTap: s.remindersEnabled ? _pickTime : null),
          SwitchListTile(
            secondary: const Icon(BfIcons.calendar),
            title: Text('Weekly reality check', style: t.titleSmall),
            subtitle: Text('Sunday evening summary', style: t.bodySmall),
            value: s.weeklyCheckReminder,
            onChanged: (v) => _s.update((x) => x.copyWith(weeklyCheckReminder: v)),
          ),
          SwitchListTile(
            secondary: const Icon(BfIcons.timer),
            title: Text('Rest-over alerts', style: t.titleSmall),
            subtitle: Text('When the app is in the background', style: t.bodySmall),
            value: s.restAlerts,
            onChanged: (v) => _s.update((x) => x.copyWith(restAlerts: v)),
          ),
        ]),
        group('Data', [
          tile(
            auth.isCloud ? BfIcons.cloud : BfIcons.localOnly,
            auth.isCloud ? 'Cloud sync' : 'Stored on this phone',
            sub: auth.isCloud
                ? (sync.lastSynced == null ? 'Waiting to sync' : 'Last synced ${TimeOfDay.fromDateTime(sync.lastSynced!).format(context)}')
                : 'Works fully offline',
            trailing: auth.isCloud ? SyncBadge(status: sync, onTap: () => ref.read(syncProvider.notifier).syncNow()) : null,
          ),
          tile(BfIcons.export, 'Export my data', sub: 'Everything as a JSON file', onTap: _busy ? null : _export),
        ]),
        group('Account', [
          if (!auth.isCloud && AppConfig.cloudEnabled)
            tile(BfIcons.user, 'Create account / log in', sub: 'Back up and sync across phones', onTap: () => context.push('/auth?mode=signup')),
          if (auth.isCloud) tile(BfIcons.user, auth.email ?? 'Signed in'),
          tile(BfIcons.logout, auth.isCloud ? 'Sign out' : 'Reset this phone', onTap: _signOut),
          tile(BfIcons.delete, 'Delete account & all data', color: c.danger, onTap: _busy ? null : _delete),
        ]),
        if (kDebugMode)
          group('Developer (debug builds only)', [
            tile(BfIcons.build, 'Load 5 weeks of demo data', sub: 'Simulated workouts, records and measurements', onTap: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final n = await loadDemoData(ref.read(trainingServiceProvider));
                    _s.update((x) => x.copyWith(demoMode: true));
                    if (context.mounted) toast(context, 'Loaded $n demo workouts');
                    if (mounted) setState(() => _busy = false);
                  }),
          ]),
        Center(
          child: Column(children: [
            Text('BODYFORGE ${AppConfig.appVersion}', style: t.labelMedium),
            const SizedBox(height: 4),
            Text('Free forever. No gym. No equipment. No subscription.', style: t.bodySmall),
            const SizedBox(height: Space.sm),
            Text(
              'BODYFORGE gives general fitness guidance, not medical advice. Stop if anything hurts and see a health professional if unsure.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: c.textFaint),
            ),
          ]),
        ),
      ],
    );
  }
}
