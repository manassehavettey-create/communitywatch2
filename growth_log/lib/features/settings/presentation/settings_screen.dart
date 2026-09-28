import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/application/app_actions.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/segmented_pills.dart';
import '../../../core/widgets/skill_icons.dart';
import '../../lock/lock_gate.dart';
import '../../skills/application/skill_providers.dart';
import '../data/backup_service.dart';
import '../data/demo_seeder.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;
  bool? _biometricsAvailable;

  @override
  void initState() {
    super.initState();
    ref.read(lockServiceProvider).biometricsAvailable().then((v) {
      if (mounted) setState(() => _biometricsAvailable = v);
    });
  }

  Future<int?> _pickTime(int minutes) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  // ------------------------------------------------------------- lock

  Future<void> _toggleLock(bool enable) async {
    final lock = ref.read(lockServiceProvider);
    final settings = ref.read(settingsProvider.notifier);
    if (enable) {
      final pin = await showCreatePin(context);
      if (pin == null) return;
      await lock.setPin(pin);
      await settings.setLockEnabled(true);
      if (mounted) showSnack(context, 'App lock is on');
    } else {
      if (!await verifyCurrentPin(context)) return;
      await settings.setLockEnabled(false);
      await settings.setBiometricEnabled(false);
      await lock.clearPin();
      if (mounted) showSnack(context, 'App lock is off');
    }
  }

  Future<void> _changePin() async {
    if (!await verifyCurrentPin(context) || !mounted) return;
    final pin = await showCreatePin(context);
    if (pin == null) return;
    await ref.read(lockServiceProvider).setPin(pin);
    if (mounted) showSnack(context, 'PIN updated');
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      final ok = await ref.read(lockServiceProvider).authenticateBiometric();
      if (!ok) {
        if (mounted) showSnack(context, "Couldn't verify biometrics.");
        return;
      }
    }
    await ref.read(settingsProvider.notifier).setBiometricEnabled(enable);
  }

  // ------------------------------------------------------------- data

  Future<void> _export() async {
    setState(() => _busy = true);
    await guarded(context, () async {
      final json = await ref.read(backupServiceProvider).exportJson();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save Growth Log backup',
        fileName: 'growth-log-backup-$stamp.json',
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (mounted && uri != null) showSnack(context, 'Backup saved');
    });
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _import() async {
    final file = await guarded(
      context,
      () => FilePicker.pickFile(
        dialogTitle: 'Choose a Growth Log backup',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      ),
    );
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final json = await file.xFile.readAsString();
      final summary = ref.read(backupServiceProvider).inspect(json);
      if (!mounted) return;
      final ok = await confirm(
        context,
        title: 'Replace all data?',
        message: 'This backup has ${Fmt.plural(summary.skills, 'skill')}, '
            '${Fmt.plural(summary.sessions, 'session')} and '
            '${Fmt.plural(summary.entries, 'entry', 'entries')}.\n\n'
            'Everything currently in the app will be replaced. Consider exporting first.',
        confirmLabel: 'Import',
        destructive: true,
      );
      if (!ok || !mounted) return;
      await ref.read(appActionsProvider).importBackup(json);
      if (mounted) showSnack(context, 'Backup restored');
    } on BackupException catch (e) {
      if (mounted) showSnack(context, e.message);
    } on FormatException {
      if (mounted) showSnack(context, "That file couldn't be read as text.");
    } catch (e) {
      if (mounted) showSnack(context, 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final first = await confirm(
      context,
      title: 'Reset all data?',
      message: 'Every skill, session and journal entry will be permanently deleted. '
          'This cannot be undone.',
      confirmLabel: 'Continue',
      destructive: true,
    );
    if (!first || !mounted) return;
    final controller = TextEditingController();
    final typed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Type RESET to confirm'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setLocal(() {}),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Palette.danger, foregroundColor: Palette.white),
              onPressed: controller.text.trim() == 'RESET' ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Delete everything'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (typed != true || !mounted) return;
    final router = GoRouter.of(context);
    final ok = await guarded(context, () async {
      await ref.read(appActionsProvider).resetAll();
      return true;
    });
    if (ok == true) router.go(Routes.onboarding);
  }

  Future<void> _seed() async {
    setState(() => _busy = true);
    await guarded(context, () async {
      await DemoSeeder(ref.read(databaseProvider), ref.read(clockProvider)).seed();
      await ref.read(appActionsProvider).syncAllReminders();
    });
    if (mounted) {
      setState(() => _busy = false);
      showSnack(context, 'Demo data added');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final actions = ref.read(appActionsProvider);
    final skills = ref.watch(skillsOverviewProvider).value ?? const <SkillStats>[];
    final gl = context.gl;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              MediaQuery.paddingOf(context).top + Space.sm,
              Space.gutter,
              MediaQuery.paddingOf(context).bottom + Space.xxl,
            ),
            children: [
              Row(
                children: [
                  CircleIconButton(
                    icon: PhosphorIconsBold.arrowLeft,
                    tooltip: 'Back',
                    onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              const DisplayTitle(bold: 'Settings', italic: '& privacy', size: 38),
              _Section(
                title: 'Appearance',
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
                    child: SegmentedPills<ThemeMode>(
                      values: ThemeMode.values,
                      selected: s.themeMode,
                      labelOf: (m) => switch (m) {
                        ThemeMode.system => 'Auto',
                        ThemeMode.light => 'Light',
                        ThemeMode.dark => 'Dark',
                      },
                      onChanged: (m) => notifier.setThemeMode(m.name),
                    ),
                  ),
                  _SwitchRow(
                    icon: PhosphorIconsRegular.vibrate,
                    title: 'Haptics',
                    value: s.hapticsEnabled,
                    onChanged: notifier.setHaptics,
                  ),
                  _SwitchRow(
                    icon: PhosphorIconsRegular.calendarBlank,
                    title: 'Week starts on Monday',
                    subtitle: s.weekStartsMonday ? null : 'Weeks start on Sunday',
                    value: s.weekStartsMonday,
                    onChanged: notifier.setWeekStartsMonday,
                  ),
                ],
              ),
              _Section(
                title: 'Reminders',
                children: [
                  _SwitchRow(
                    icon: PhosphorIconsRegular.notebook,
                    title: 'Daily journal reminder',
                    subtitle: s.logReminderEnabled
                        ? '${Fmt.timeOfDay(s.logReminderMinutes)} · a new gentle prompt each day'
                        : 'A gentle nudge to note something good',
                    value: s.logReminderEnabled,
                    onChanged: (v) => guarded(context, () => actions.setLogReminder(enabled: v)),
                    onTapTrailing: s.logReminderEnabled
                        ? () async {
                            final m = await _pickTime(s.logReminderMinutes);
                            if (m != null && context.mounted) {
                              await guarded(context, () => actions.setLogReminder(enabled: true, minutes: m));
                            }
                          }
                        : null,
                  ),
                  for (final st in skills)
                    _SwitchRow(
                      leading: SkillAvatar(skill: st.skill, size: 32),
                      title: st.skill.name,
                      subtitle: st.skill.reminderEnabled
                          ? 'Practice reminder at ${Fmt.timeOfDay(st.skill.reminderMinutes)}'
                          : 'No practice reminder',
                      value: st.skill.reminderEnabled,
                      onChanged: (v) => guarded(
                        context,
                        () => actions.setSkillReminder(st.skill.id, enabled: v),
                      ),
                      onTapTrailing: st.skill.reminderEnabled
                          ? () async {
                              final m = await _pickTime(st.skill.reminderMinutes);
                              if (m != null && context.mounted) {
                                await guarded(
                                  context,
                                  () => actions.setSkillReminder(st.skill.id, enabled: true, minutes: m),
                                );
                              }
                            }
                          : null,
                    ),
                ],
              ),
              _Section(
                title: 'Privacy',
                children: [
                  _SwitchRow(
                    icon: PhosphorIconsRegular.lockSimple,
                    title: 'App lock',
                    subtitle: 'Ask for a PIN when opening the app',
                    value: s.lockEnabled,
                    onChanged: _toggleLock,
                  ),
                  if (s.lockEnabled) ...[
                    if (_biometricsAvailable ?? false)
                      _SwitchRow(
                        icon: PhosphorIconsRegular.fingerprint,
                        title: 'Unlock with biometrics',
                        subtitle: 'Your PIN still works as a fallback',
                        value: s.biometricEnabled,
                        onChanged: _toggleBiometric,
                      ),
                    _ActionRow(
                      icon: PhosphorIconsRegular.password,
                      title: 'Change PIN',
                      onTap: _changePin,
                    ),
                  ],
                ],
              ),
              _Section(
                title: 'Your data',
                footer: 'Everything stays on this device. Backups are plain JSON files you control.',
                children: [
                  _ActionRow(
                    icon: PhosphorIconsRegular.downloadSimple,
                    title: 'Export backup',
                    subtitle: 'Save a JSON file of all your data',
                    onTap: _busy ? null : _export,
                  ),
                  _ActionRow(
                    icon: PhosphorIconsRegular.uploadSimple,
                    title: 'Import backup',
                    subtitle: 'Replace current data from a JSON file',
                    onTap: _busy ? null : _import,
                  ),
                  _ActionRow(
                    icon: PhosphorIconsRegular.trash,
                    title: 'Reset all data',
                    destructive: true,
                    onTap: _busy ? null : _reset,
                  ),
                ],
              ),
              if (kDebugMode)
                _Section(
                  title: 'Developer (debug builds only)',
                  children: [
                    _ActionRow(
                      icon: PhosphorIconsRegular.flask,
                      title: 'Seed demo data',
                      subtitle: 'Adds sample skills, sessions and entries',
                      onTap: _busy ? null : _seed,
                    ),
                  ],
                ),
              const SizedBox(height: Space.xl),
              Center(
                child: Text(
                  'Growth Log 1.0.0 · made for steady progress',
                  style: context.text.bodySmall,
                ),
              ),
              Center(
                child: Text(
                  'Fonts: Urbanist & Archivo (OFL) · Icons: Phosphor',
                  style: context.text.bodySmall?.copyWith(color: gl.muted.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.15),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.footer});

  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
          child: Semantics(header: true, child: Text(title, style: context.text.titleMedium)),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: gl.card,
            borderRadius: Radii.cardR,
            border: Border.all(color: gl.hairline),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 64, color: gl.hairline),
                children[i],
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs, left: Space.xs),
            child: Text(footer!, style: context.text.bodySmall),
          ),
      ],
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble(this.icon, {this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: color ?? context.gl.canvas, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: context.gl.text),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.onTapTrailing,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// When set, tapping the row (not the switch) opens e.g. a time picker.
  final VoidCallback? onTapTrailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 2),
      leading: leading ?? (icon == null ? null : _IconBubble(icon!)),
      title: Text(title, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: context.text.bodySmall),
      onTap: onTapTrailing ?? () => onChanged(!value),
      trailing: Switch.adaptive(value: value, onChanged: onChanged),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Palette.danger : context.gl.text;
    return ListTile(
      enabled: onTap != null,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 2),
      leading: _IconBubble(icon, color: destructive ? Palette.danger.withValues(alpha: 0.12) : null),
      title: Text(title, style: AppText.body.copyWith(fontWeight: FontWeight.w700, color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: context.text.bodySmall),
      trailing: Icon(PhosphorIconsRegular.caretRight, size: 18, color: context.gl.muted),
      onTap: onTap,
    );
  }
}
