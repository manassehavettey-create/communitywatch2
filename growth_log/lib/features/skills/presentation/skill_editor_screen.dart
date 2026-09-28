import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/app_actions.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/phosphor_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skill_icons.dart';
import '../../../core/widgets/states.dart';
import '../data/skill_repository.dart';

/// Create or edit a skill. In [setupMode] it's the last onboarding step.
class SkillEditorScreen extends ConsumerStatefulWidget {
  const SkillEditorScreen({super.key, this.skillId, this.setupMode = false});

  final int? skillId;
  final bool setupMode;

  @override
  ConsumerState<SkillEditorScreen> createState() => _SkillEditorScreenState();
}

class _SkillEditorScreenState extends ConsumerState<SkillEditorScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _customTarget = TextEditingController();
  String _icon = 'guitar';
  int _color = Palette.skillColors.first.toARGB32();
  double _target = 10000;
  bool _reminder = false;
  int _reminderMinutes = 19 * 60;
  bool _loading = false;
  bool _saving = false;
  Object? _loadError;
  String? _nameError;

  static const _targets = [100.0, 1000.0, 10000.0];

  bool get _editing => widget.skillId != null;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() => _nameError = null));
    if (_editing) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await ref.read(skillRepositoryProvider).getSkill(widget.skillId!);
      if (s == null) throw const ValidationException('This skill no longer exists.');
      _name.text = s.name;
      _desc.text = s.description ?? '';
      _icon = SkillIcons.all.containsKey(s.iconKey) ? s.iconKey : SkillIcons.fallback;
      _color = s.colorValue;
      _target = s.targetHours;
      if (!_targets.contains(_target)) _customTarget.text = _target.round().toString();
      _reminder = s.reminderEnabled;
      _reminderMinutes = s.reminderMinutes;
    } catch (e) {
      _loadError = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _customTarget.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderMinutes ~/ 60, minute: _reminderMinutes % 60),
    );
    if (t != null) setState(() => _reminderMinutes = t.hour * 60 + t.minute);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Give your skill a name');
      return;
    }
    final custom = double.tryParse(_customTarget.text.replaceAll(',', ''));
    final target = _customTarget.text.trim().isEmpty ? _target : (custom ?? -1);
    final draft = SkillDraft(
      name: _name.text,
      description: _desc.text,
      iconKey: _icon,
      colorValue: _color,
      targetHours: target,
      reminderEnabled: _reminder,
      reminderMinutes: _reminderMinutes,
    );
    setState(() => _saving = true);
    final actions = ref.read(appActionsProvider);
    final router = GoRouter.of(context);
    final ok = await guarded(context, () async {
      final id = _editing ? widget.skillId! : await actions.createSkill(draft);
      if (_editing) await actions.updateSkill(id, draft);
      // Asks for notification permission when turning a reminder on.
      if (_reminder) {
        await actions.setSkillReminder(id, enabled: true, minutes: _reminderMinutes);
      }
      if (widget.setupMode) {
        await ref.read(settingsProvider.notifier).completeOnboarding();
      }
      return true;
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok != true) return;
    if (widget.setupMode) {
      router.go(Routes.home);
    } else {
      router.pop();
    }
  }

  Future<void> _skipSetup() async {
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    final color = Color(_color);

    if (_loading) return const Scaffold(body: LoadingState());
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(error: _loadError!),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(Space.gutter, MediaQuery.paddingOf(context).top + Space.sm, Space.gutter, 0),
              child: Row(
                children: [
                  if (!widget.setupMode)
                    CircleIconButton(icon: PhosphorIconsBold.x, tooltip: 'Close', onPressed: () => context.pop()),
                  const Spacer(),
                  if (widget.setupMode) TextButton(onPressed: _skipSetup, child: const Text('Skip for now')),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
              child: DisplayTitle(
                bold: widget.setupMode ? 'Your first' : (_editing ? 'Edit' : 'New'),
                italic: 'skill',
                size: 40,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _preview(color)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            sliver: SliverList.list(
              children: [
                const _Label('Name'),
                TextField(
                  controller: _name,
                  maxLength: SkillLimits.nameMax,
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: !_editing,
                  decoration: InputDecoration(hintText: 'Guitar, Spanish, Drawing…', errorText: _nameError),
                ),
                const _Label('Why it matters (optional)'),
                TextField(
                  controller: _desc,
                  maxLength: SkillLimits.descriptionMax,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Play songs around the campfire'),
                ),
                const _Label('Colour'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in Palette.skillColors)
                      Semantics(
                        button: true,
                        selected: c.toARGB32() == _color,
                        label: 'Colour option',
                        child: Pressable(
                          onTap: () => setState(() => _color = c.toARGB32()),
                          child: AnimatedContainer(
                            duration: Motion.fast,
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: c.toARGB32() == _color ? gl.text : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: c.toARGB32() == _color
                                ? const Icon(PhosphorIconsBold.check, size: 18, color: Palette.ink)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const _Label('Icon'),
                GridView.count(
                  crossAxisCount: 6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final e in SkillIcons.all.entries)
                      Semantics(
                        button: true,
                        selected: e.key == _icon,
                        label: '${e.key} icon',
                        child: Pressable(
                          onTap: () => setState(() => _icon = e.key),
                          child: AnimatedContainer(
                            duration: Motion.fast,
                            decoration: BoxDecoration(
                              color: e.key == _icon ? color : gl.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: e.key == _icon ? color : gl.hairline),
                            ),
                            child: Icon(e.value, size: 22, color: e.key == _icon ? Palette.ink : gl.text),
                          ),
                        ),
                      ),
                  ],
                ),
                const _Label('Target'),
                Row(
                  children: [
                    for (final t in _targets) ...[
                      Expanded(
                        child: _Choice(
                          label: '${Fmt.number(t.round())} h',
                          selected: _customTarget.text.isEmpty && _target == t,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            setState(() {
                              _target = t;
                              _customTarget.clear();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: TextField(
                        controller: _customTarget,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          hintText: 'Custom',
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text('10,000 hours is the classic path to mastery — any goal works.', style: context.text.bodySmall),
                const _Label('Daily reminder'),
                Material(
                  color: gl.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: Radii.cardSmallR,
                    side: BorderSide(color: gl.hairline),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _reminder,
                          title: const Text('Remind me to practise'),
                          onChanged: (v) => setState(() => _reminder = v),
                        ),
                        AnimatedSize(
                          duration: Motion.medium,
                          child: _reminder
                              ? ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Time'),
                                  trailing: Text(Fmt.timeOfDay(_reminderMinutes), style: AppText.subtitle),
                                  onTap: _pickTime,
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Space.xl),
                PillButton(
                  label: widget.setupMode ? "Let's start" : (_editing ? 'Save changes' : 'Create skill'),
                  trailingArrow: true,
                  expand: true,
                  loading: _saving,
                  onPressed: _save,
                ),
                SizedBox(height: MediaQuery.paddingOf(context).bottom + Space.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(Color color) {
    final name = _name.text.trim().isEmpty ? 'Your skill' : _name.text.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xs),
      child: AnimatedContainer(
        duration: Motion.medium,
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(color: color, borderRadius: Radii.heroR),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: Palette.ink, shape: BoxShape.circle),
              child: Icon(SkillIcons.of(_icon), color: color, size: 28),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title.copyWith(color: Palette.ink),
                  ),
                  Text(
                    'Novice · 0 of ${Fmt.number((double.tryParse(_customTarget.text.replaceAll(',', '')) ?? _target).round())} h',
                    style: AppText.caption.copyWith(color: Palette.ink.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xs),
      child: Text(text, style: context.text.titleSmall),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? gl.inverse : gl.surface,
            borderRadius: Radii.pillR,
            border: Border.all(color: selected ? gl.inverse : gl.hairline),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                style: AppText.body.copyWith(fontWeight: FontWeight.w700, color: selected ? gl.onInverse : gl.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
