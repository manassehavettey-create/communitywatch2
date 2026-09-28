import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/app_actions.dart';
import '../../../core/providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/phosphor_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/day_key.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skill_icons.dart';
import '../../../core/widgets/states.dart';
import '../../skills/application/skill_providers.dart';
import '../application/log_providers.dart';
import '../data/entry_repository.dart';
import 'entry_card.dart';

const _moods = ['😊', '🥰', '😌', '🤩', '💪', '🔥', '🙏', '🥹', '😐', '😔'];

const _winPrompts = [
  'What went well today?',
  'What did you finish, fix or figure out?',
  'What are you proud of right now?',
  'What progress did you make?',
];

class EntryEditorScreen extends ConsumerStatefulWidget {
  const EntryEditorScreen({
    super.key,
    this.entryId,
    this.initialType = EntryType.gratitude,
    this.initialSkillId,
  });

  final int? entryId;
  final EntryType initialType;
  final int? initialSkillId;

  @override
  ConsumerState<EntryEditorScreen> createState() => _EntryEditorScreenState();
}

class _EntryEditorScreenState extends ConsumerState<EntryEditorScreen> {
  final _body = TextEditingController();
  final _tagInput = TextEditingController();
  late EntryType _type = widget.initialType;
  String? _mood;
  int? _skillId;
  final List<String> _tags = [];
  late DayKey _day = ref.read(todayProvider);
  EntryView? _existing;
  bool _loading = false;
  bool _saving = false;
  Object? _loadError;

  bool get _editing => widget.entryId != null;

  @override
  void initState() {
    super.initState();
    _skillId = widget.initialSkillId;
    _body.addListener(() => setState(() {}));
    if (_editing) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final v = await ref.read(entryRepositoryProvider).getEntry(widget.entryId!);
      if (v == null) throw Exception('This entry no longer exists.');
      _existing = v;
      _type = v.type;
      _body.text = v.entry.body;
      _mood = v.entry.mood;
      _skillId = v.entry.skillId;
      _tags.addAll(v.tags);
      _day = v.entry.dayKey;
    } catch (e) {
      _loadError = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _body.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final t = TagNames.normalize(raw);
    _tagInput.clear();
    if (t == null || _tags.contains(t)) return;
    if (_tags.length >= EntryLimits.tagsPerEntry) {
      showSnack(context, 'Up to ${EntryLimits.tagsPerEntry} tags per entry.');
      return;
    }
    setState(() => _tags.add(t));
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
    if (_tagInput.text.trim().isNotEmpty) _addTag(_tagInput.text);
    final draft = EntryDraft(
      type: _type,
      body: _body.text,
      dayKey: _day,
      mood: _mood,
      skillId: _skillId,
      tags: _tags,
    );
    setState(() => _saving = true);
    final actions = ref.read(appActionsProvider);
    final router = GoRouter.of(context);
    final ok = await guarded(context, () async {
      if (_editing) {
        await actions.updateEntry(widget.entryId!, draft);
      } else {
        await actions.addEntry(draft);
      }
      return true;
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == true) router.pop();
  }

  Future<void> _delete() async {
    final v = _existing;
    if (v == null) return;
    final ok = await confirm(
      context,
      title: 'Delete this entry?',
      message: 'This removes it from your log.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final actions = ref.read(appActionsProvider);
    final router = GoRouter.of(context);
    final done = await guarded(context, () async {
      await actions.deleteEntry(v);
      return true;
    });
    if (done == true) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingState());
    if (_loadError != null) {
      return Scaffold(appBar: AppBar(), body: ErrorState(error: _loadError!));
    }
    final color = entryColor(_type);
    final today = ref.watch(todayProvider);
    final prompt = _type == EntryType.gratitude
        ? promptForDay(_day)
        : _winPrompts[Days.between(20240101, _day).abs() % _winPrompts.length];
    final skills = ref.watch(skillsOverviewProvider).value ?? const <SkillStats>[];
    final allTags = ref.watch(allTagsProvider).value ?? const [];
    final suggestions = allTags.where((t) => !_tags.contains(t.name)).take(8).toList();
    final canSave = _body.text.trim().isNotEmpty && !_saving;
    const white = Color(0x99FFFFFF);

    return Scaffold(
        backgroundColor: color,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
                child: Row(
                  children: [
                    CircleIconButton(
                      icon: PhosphorIconsBold.x,
                      tooltip: 'Close',
                      background: Palette.white,
                      foreground: Palette.ink,
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    if (_editing)
                      CircleIconButton(
                        icon: PhosphorIconsRegular.trash,
                        tooltip: 'Delete entry',
                        background: Palette.white,
                        foreground: Palette.danger,
                        onPressed: _delete,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.lg),
                  children: [
                    Row(
                      children: [
                        for (final t in EntryType.values) ...[
                          if (t != EntryType.values.first) const SizedBox(width: Space.xs),
                          Expanded(
                            child: Semantics(
                              selected: _type == t,
                              button: true,
                              child: Pressable(
                                onTap: () => setState(() => _type = t),
                                child: AnimatedContainer(
                                  duration: Motion.medium,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _type == t ? Palette.ink : white,
                                    borderRadius: Radii.pillR,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        t == EntryType.win ? PhosphorIconsFill.trophy : PhosphorIconsFill.heart,
                                        size: 18,
                                        color: _type == t ? color : Palette.ink,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        t.label,
                                        style: AppText.button.copyWith(color: _type == t ? Palette.white : Palette.ink),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    AnimatedSwitcher(
                      duration: Motion.medium,
                      child: Text(
                        prompt,
                        key: ValueKey(prompt),
                        style: AppText.display.copyWith(color: Palette.ink, fontSize: 32, height: 1.05),
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    TextField(
                      controller: _body,
                      autofocus: !_editing,
                      minLines: 4,
                      maxLines: 12,
                      maxLength: EntryLimits.bodyMax,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppText.subtitle.copyWith(color: Palette.ink, fontWeight: FontWeight.w500),
                      cursorColor: Palette.ink,
                      decoration: InputDecoration(
                        hintText: _type == EntryType.win ? 'Shipped the thing…' : 'The sunshine on my walk…',
                        fillColor: white,
                        hintStyle: AppText.subtitle.copyWith(color: Palette.ink.withValues(alpha: 0.4)),
                        counterStyle: AppText.caption.copyWith(color: Palette.ink.withValues(alpha: 0.6)),
                        border: const OutlineInputBorder(borderRadius: Radii.cardR, borderSide: BorderSide.none),
                        enabledBorder:
                            const OutlineInputBorder(borderRadius: Radii.cardR, borderSide: BorderSide.none),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: Radii.cardR,
                          borderSide: BorderSide(color: Palette.ink, width: 1.4),
                        ),
                      ),
                    ),
                    _label('Mood'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final m in _moods)
                          Semantics(
                            button: true,
                            selected: _mood == m,
                            label: 'Mood $m',
                            child: Pressable(
                              onTap: () => setState(() => _mood = _mood == m ? null : m),
                              child: AnimatedContainer(
                                duration: Motion.fast,
                                width: 46,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _mood == m ? Palette.ink : white,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(m, style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                          ),
                      ],
                    ),
                    _label('Tags'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final t in _tags)
                          InputChip(
                            label: Text('#$t'),
                            labelStyle: AppText.caption.copyWith(color: Palette.white, fontWeight: FontWeight.w700),
                            backgroundColor: Palette.ink,
                            deleteIconColor: Palette.white,
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            onDeleted: () => setState(() => _tags.remove(t)),
                          ),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _tagInput,
                            textInputAction: TextInputAction.done,
                            onSubmitted: _addTag,
                            onChanged: (v) {
                              if (v.endsWith(',') || v.endsWith(' ')) _addTag(v);
                            },
                            style: AppText.body.copyWith(color: Palette.ink),
                            decoration: InputDecoration(
                              hintText: '+ add tag',
                              isDense: true,
                              fillColor: white,
                              hintStyle: AppText.body.copyWith(color: Palette.ink.withValues(alpha: 0.45)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: const OutlineInputBorder(borderRadius: Radii.pillR, borderSide: BorderSide.none),
                              enabledBorder:
                                  const OutlineInputBorder(borderRadius: Radii.pillR, borderSide: BorderSide.none),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: Radii.pillR,
                                borderSide: BorderSide(color: Palette.ink),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: Space.xs),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in suggestions)
                            Pressable(
                              onTap: () => _addTag(s.name),
                              semanticLabel: 'Add tag ${s.name}',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: Radii.pillR,
                                  border: Border.all(color: Palette.ink.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '#${s.name}',
                                  style: AppText.caption.copyWith(color: Palette.ink, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (skills.isNotEmpty) ...[
                      _label('Linked skill'),
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _SkillChip(
                              label: 'None',
                              selected: _skillId == null,
                              onTap: () => setState(() => _skillId = null),
                            ),
                            for (final s in skills)
                              _SkillChip(
                                label: s.skill.name,
                                selected: _skillId == s.skill.id,
                                leading: SkillAvatar(skill: s.skill, size: 30),
                                onTap: () => setState(() => _skillId = s.skill.id),
                              ),
                          ],
                        ),
                      ),
                    ],
                    _label('Date'),
                    Pressable(
                      onTap: _pickDate,
                      semanticLabel: 'Date ${Fmt.dayLabel(_day, today)}. Change',
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: const BoxDecoration(color: white, borderRadius: Radii.pillR),
                        child: Row(
                          children: [
                            const Icon(PhosphorIconsRegular.calendarBlank, color: Palette.ink, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                Fmt.dayLabel(_day, today),
                                style: AppText.body.copyWith(color: Palette.ink, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Icon(PhosphorIconsRegular.caretRight, color: Palette.ink, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
                child: PillButton(
                  label: _editing ? 'Save changes' : 'Save to log',
                  trailingArrow: true,
                  expand: true,
                  loading: _saving,
                  background: Palette.ink,
                  foreground: Palette.white,
                  onPressed: canSave ? _save : null,
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xs),
        child: Text(text, style: AppText.subtitle.copyWith(color: Palette.ink)),
      );
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.label, required this.selected, required this.onTap, this.leading});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Semantics(
        button: true,
        selected: selected,
        child: Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.fast,
            padding: EdgeInsets.fromLTRB(leading == null ? 16 : 6, 6, 16, 6),
            decoration: BoxDecoration(
              color: selected ? Palette.ink : const Color(0x99FFFFFF),
              borderRadius: Radii.pillR,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Text(
                  label,
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? Palette.white : Palette.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
