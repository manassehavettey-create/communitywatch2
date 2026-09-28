import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/application/app_actions.dart';
import '../../../core/db/database.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/day_key.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skill_icons.dart';
import '../application/skill_providers.dart';
import '../data/skill_repository.dart';
import 'level_up.dart';

/// Manual practice entry (new) or editing an existing session.
Future<void> showSessionSheet(
  BuildContext context, {
  int? skillId,
  SessionRow? existing,
}) {
  return showAppSheet<void>(
    context,
    builder: (_) => SessionSheet(skillId: skillId ?? existing?.skillId, existing: existing),
  );
}

class SessionSheet extends ConsumerStatefulWidget {
  const SessionSheet({super.key, this.skillId, this.existing});

  final int? skillId;
  final SessionRow? existing;

  @override
  ConsumerState<SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends ConsumerState<SessionSheet> {
  int? _skillId;
  late DayKey _day;
  late int _minutes;
  late final TextEditingController _note;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _skillId = widget.skillId;
    _day = e?.dayKey ?? ref.read(todayProvider);
    _minutes = e == null ? 30 : (e.durationSec / 60).round().clamp(1, 24 * 60);
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _add(int m) {
    ref.read(hapticsProvider).tap();
    setState(() => _minutes = (_minutes + m).clamp(1, 24 * 60));
  }

  Future<void> _pickDate() async {
    final today = ref.read(todayProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: Days.dateOf(_day),
      firstDate: DateTime(2000),
      lastDate: Days.dateOf(today),
    );
    if (picked != null) setState(() => _day = Days.keyOf(picked));
  }

  Future<void> _save() async {
    final skillId = _skillId;
    if (skillId == null) {
      showSnack(context, 'Pick a skill first.');
      return;
    }
    setState(() => _saving = true);
    final actions = ref.read(appActionsProvider);
    final navigator = Navigator.of(context);
    final root = rootNavigatorKey.currentContext;
    final result = await guarded(context, () {
      if (_editing) {
        return actions.updateSession(
          widget.existing!,
          skillId: skillId,
          dayKey: _day,
          durationSec: _minutes * 60,
          note: _note.text,
        );
      }
      return actions.logSession(
        skillId: skillId,
        dayKey: _day,
        durationSec: _minutes * 60,
        note: _note.text,
      );
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == null) return;
    navigator.pop();
    if (root != null && root.mounted) {
      if (result.isEmpty) {
        showSnack(root, _editing ? 'Session updated' : 'Logged ${Fmt.duration(_minutes * 60)}');
      }
      await celebrate(root, result);
    }
  }

  Future<void> _delete() async {
    final row = widget.existing!;
    final ok = await confirm(
      context,
      title: 'Delete this session?',
      message: '${Fmt.duration(row.durationSec)} on ${Fmt.shortDate(row.dayKey)} will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final actions = ref.read(appActionsProvider);
    final navigator = Navigator.of(context);
    final root = rootNavigatorKey.currentContext;
    final done = await guarded(context, () async {
      await actions.deleteSession(row);
      return true;
    });
    if (done != true) return;
    navigator.pop();
    if (root != null && root.mounted) {
      showSnack(
        root,
        'Session deleted',
        actionLabel: 'Undo',
        onAction: () => actions.restoreSession(row),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final skills = ref.watch(skillsOverviewProvider).value ?? const <SkillStats>[];
    final today = ref.watch(todayProvider);
    final gl = context.gl;

    if (skills.isEmpty && !_editing) {
      return SheetScaffold(
        title: 'Log practice',
        primaryLabel: 'Create a skill',
        onPrimary: () {
          Navigator.pop(context);
          GoRouter.of(rootNavigatorKey.currentContext!).push(Routes.newSkill);
        },
        child: Text(
          'Add a skill first — then every minute you practise counts toward it.',
          style: context.text.bodyMedium?.copyWith(color: gl.muted),
        ),
      );
    }

    _skillId ??= skills.isNotEmpty ? skills.first.skill.id : null;
    final hours = _minutes ~/ 60;
    final mins = _minutes % 60;

    return SheetScaffold(
      title: _editing ? 'Edit session' : 'Log practice',
      primaryLabel: _editing ? 'Save changes' : 'Save session',
      primaryLoading: _saving,
      onPrimary: _save,
      secondary: _editing
          ? TextButton.icon(
              onPressed: _delete,
              icon: const Icon(PhosphorIconsRegular.trash, color: Palette.danger),
              label: const Text('Delete session', style: TextStyle(color: Palette.danger)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: skills.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
              itemBuilder: (_, i) {
                final s = skills[i].skill;
                final sel = s.id == _skillId;
                return Pressable(
                  onTap: () => setState(() => _skillId = s.id),
                  semanticLabel: s.name,
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
                    decoration: BoxDecoration(
                      color: sel ? Color(s.colorValue) : gl.surface,
                      borderRadius: Radii.pillR,
                      border: Border.all(color: sel ? Color(s.colorValue) : gl.hairline),
                    ),
                    child: Row(
                      children: [
                        SkillAvatar(skill: s, size: 36, inverted: sel),
                        const SizedBox(width: 8),
                        Text(
                          s.name,
                          style: AppText.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: sel ? Palette.ink : gl.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: Space.lg),
          Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: const BoxDecoration(
              color: Palette.lime,
              borderRadius: Radii.cardR,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _Stepper(
                      icon: PhosphorIconsBold.minus,
                      label: 'Less time',
                      onTap: _minutes > 1 ? () => _add(_minutes > 15 ? -15 : -1) : null,
                    ),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        label: 'Duration ${Fmt.duration(_minutes * 60)}',
                        child: ExcludeSemantics(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text.rich(
                              TextSpan(children: [
                                if (hours > 0) ...[
                                  TextSpan(text: '$hours', style: AppText.display.copyWith(color: Palette.ink, fontSize: 52)),
                                  TextSpan(text: 'h ', style: AppText.displayItalic.copyWith(color: Palette.ink, fontSize: 30)),
                                ],
                                TextSpan(text: '$mins', style: AppText.display.copyWith(color: Palette.ink, fontSize: 52)),
                                TextSpan(text: 'm', style: AppText.displayItalic.copyWith(color: Palette.ink, fontSize: 30)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _Stepper(
                      icon: PhosphorIconsBold.plus,
                      label: 'More time',
                      onTap: _minutes < 24 * 60 ? () => _add(15) : null,
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final m in const [15, 30, 45, 60, 90, 120])
                      Pressable(
                        onTap: () => setState(() => _minutes = m),
                        semanticLabel: Fmt.duration(m * 60),
                        child: AnimatedContainer(
                          duration: Motion.fast,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _minutes == m ? Palette.ink : Palette.white.withValues(alpha: 0.6),
                            borderRadius: Radii.pillR,
                          ),
                          child: Text(
                            Fmt.duration(m * 60),
                            style: AppText.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _minutes == m ? Palette.lime : Palette.ink,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          Pressable(
            onTap: _pickDate,
            semanticLabel: 'Date: ${Fmt.dayLabel(_day, today)}. Change date',
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: gl.surface,
                borderRadius: Radii.cardSmallR,
                border: Border.all(color: gl.hairline),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIconsRegular.calendarBlank, color: gl.text, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(Fmt.dayLabel(_day, today), style: AppText.body)),
                  Icon(PhosphorIconsRegular.caretRight, color: gl.muted, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
          TextField(
            controller: _note,
            maxLength: SkillLimits.noteMax,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What did you work on? (optional)',
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: icon,
      tooltip: label,
      onPressed: onTap,
      background: Palette.ink,
      foreground: Palette.lime,
      size: 48,
    );
  }
}
