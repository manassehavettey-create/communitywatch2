import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/scripture_ref_field.dart';
import '../../data/db/database.dart';
import '../../data/repos/prayer_repository.dart';
import 'prayer_widgets.dart';

/// Create or edit a prayer ([prayerId] null means new).
class PrayerEditorScreen extends ConsumerStatefulWidget {
  const PrayerEditorScreen({super.key, this.prayerId});

  final String? prayerId;

  @override
  ConsumerState<PrayerEditorScreen> createState() => _PrayerEditorScreenState();
}

class _PrayerEditorScreenState extends ConsumerState<PrayerEditorScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  PrayerCategory _category = PrayerCategory.personal;
  String? _scripture;
  ReminderKind _reminder = ReminderKind.none;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  DateTime _onceAt = DateTime.now().add(const Duration(days: 1));
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    if (widget.prayerId == null) _loaded = true;
  }

  void _load(Prayer p) {
    if (_loaded) return;
    _loaded = true;
    _title.text = p.title;
    _body.text = p.body;
    _category = PrayerCategory.fromName(p.category);
    _scripture = p.scriptureRef;
    _reminder = ReminderKind.fromName(p.reminderKind);
    final v = p.reminderValue;
    if (_reminder == ReminderKind.daily && v != null) {
      _time = TimeOfDay(hour: v ~/ 60, minute: v % 60);
    } else if (_reminder == ReminderKind.once && v != null) {
      _onceAt = DateTime.fromMillisecondsSinceEpoch(v);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final reminders = ref.read(reminderServiceProvider);
    if (_reminder != ReminderKind.none && reminders.supported) {
      final ok = await reminders.requestPermission();
      if (!ok && mounted) {
        toast(
          context,
          'Notifications are off, so the reminder can’t be shown.',
        );
      }
    }
    final value = switch (_reminder) {
      ReminderKind.none => null,
      ReminderKind.daily => _time.hour * 60 + _time.minute,
      ReminderKind.once => _onceAt.toUtc().millisecondsSinceEpoch,
    };
    final repo = ref.read(prayerRepositoryProvider);
    await repo.save(
      PrayerDraft(
        title: _title.text,
        body: _body.text,
        category: _category,
        scriptureRef: _scripture,
        reminderKind: _reminder,
        reminderValue: value,
      ),
      id: widget.prayerId,
    );
    await reminders.syncPrayerReminders(await repo.withReminders());
    if (mounted) context.pop();
  }

  Future<void> _pickOnce() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _onceAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_onceAt),
    );
    if (time == null) return;
    setState(
      () => _onceAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = Motion.of(context);
    if (widget.prayerId != null && !_loaded) {
      final existing = ref
          .watch(prayersProvider)
          .value
          ?.where((x) => x.id == widget.prayerId)
          .firstOrNull;
      if (existing == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      _load(existing);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x3,
                Space.x3,
                Space.gutter,
                0,
              ),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: PhosphorIconsBold.x,
                    tooltip: 'Close',
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  PillButton(
                    label: 'Save',
                    compact: true,
                    busy: _saving,
                    onPressed: _title.text.trim().isEmpty ? null : _save,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Space.gutter),
                children: [
                  AnimatedContainer(
                    duration: m.base,
                    padding: const EdgeInsets.fromLTRB(
                      Space.x5,
                      Space.x4,
                      Space.x5,
                      Space.x4 + 14,
                    ),
                    decoration: ShapeDecoration(
                      color: prayerColor(_category, p),
                      shape: const BubbleBorder(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _title,
                          autofocus: widget.prayerId == null,
                          textCapitalization: TextCapitalization.sentences,
                          style: AppType.titleL.copyWith(color: p.onPastel),
                          decoration: InputDecoration(
                            filled: false,
                            hintText: 'What are you praying for?',
                            hintStyle: AppType.titleL.copyWith(
                              color: p.onPastel.withValues(alpha: 0.45),
                            ),
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                        TextField(
                          controller: _body,
                          minLines: 3,
                          maxLines: 12,
                          textCapitalization: TextCapitalization.sentences,
                          style: AppType.body.copyWith(color: p.onPastel),
                          decoration: InputDecoration(
                            filled: false,
                            hintText: 'Details (optional)',
                            hintStyle: AppType.body.copyWith(
                              color: p.onPastel.withValues(alpha: 0.45),
                            ),
                            contentPadding: const EdgeInsets.only(
                              top: Space.x2,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.x6),
                  Text(
                    'CATEGORY',
                    style: AppType.overline.copyWith(color: p.inkMute),
                  ),
                  const SizedBox(height: Space.x2),
                  Wrap(
                    spacing: Space.x2,
                    runSpacing: Space.x2,
                    children: [
                      for (final c in PrayerCategory.values)
                        ChoiceChip(
                          label: Text(c.label),
                          selected: c == _category,
                          onSelected: (_) => setState(() => _category = c),
                          showCheckmark: false,
                          labelStyle: AppType.label.copyWith(
                            color: c == _category ? p.onPastel : p.ink,
                          ),
                          selectedColor: prayerColor(c, p),
                          backgroundColor: p.paperDeep,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.x6),
                  ScriptureRefField(
                    initialCode: _scripture,
                    onChanged: (c) => _scripture = c,
                  ),
                  const SizedBox(height: Space.x6),
                  Text(
                    'REMINDER',
                    style: AppType.overline.copyWith(color: p.inkMute),
                  ),
                  const SizedBox(height: Space.x2),
                  SegmentedButton<ReminderKind>(
                    segments: const [
                      ButtonSegment(
                        value: ReminderKind.none,
                        label: Text('None'),
                      ),
                      ButtonSegment(
                        value: ReminderKind.once,
                        label: Text('Once'),
                      ),
                      ButtonSegment(
                        value: ReminderKind.daily,
                        label: Text('Daily'),
                      ),
                    ],
                    selected: {_reminder},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _reminder = s.first),
                  ),
                  AnimatedSize(
                    duration: m.base,
                    child: switch (_reminder) {
                      ReminderKind.none => const SizedBox(
                        width: double.infinity,
                      ),
                      ReminderKind.daily => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(PhosphorIconsRegular.clock),
                        title: Text('Every day at ${_time.format(context)}'),
                        trailing: const Icon(PhosphorIconsRegular.caretRight),
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _time,
                          );
                          if (t != null) setState(() => _time = t);
                        },
                      ),
                      ReminderKind.once => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(PhosphorIconsRegular.calendar),
                        title: Text(
                          DateFormat('EEE d MMM, HH:mm').format(_onceAt),
                        ),
                        trailing: const Icon(PhosphorIconsRegular.caretRight),
                        onTap: _pickOnce,
                      ),
                    },
                  ),
                  if (_reminder != ReminderKind.none &&
                      !ref.read(reminderServiceProvider).supported)
                    Text(
                      'Reminders appear on the phone app, not on the web.',
                      style: AppType.caption.copyWith(color: p.inkMute),
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
