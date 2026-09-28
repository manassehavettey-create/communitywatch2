import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/icons.dart';

import '../../app/providers.dart';
import '../../bible/references.dart';
import '../../core/haptics.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/layout.dart';
import '../../data/repos/prayer_repository.dart';
import '../reader/reader_screen.dart';
import 'prayer_widgets.dart';

class PrayerDetailScreen extends ConsumerWidget {
  const PrayerDetailScreen({super.key, required this.prayerId});

  final String prayerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final prayer = ref
        .watch(prayersProvider)
        .value
        ?.where((x) => x.id == prayerId)
        .firstOrNull;
    if (prayer == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            'This prayer was deleted.',
            style: AppType.body.copyWith(color: p.inkSoft),
          ),
        ),
      );
    }
    final repo = ref.read(prayerRepositoryProvider);
    final cat = PrayerCategory.fromName(prayer.category);
    final answered = prayer.status == 'answered';
    VerseRange? scripture;
    if (prayer.scriptureRef != null) {
      try {
        scripture = VerseRange.parseCode(prayer.scriptureRef!);
      } on Object {
        scripture = null;
      }
    }
    final fmt = DateFormat('d MMMM y');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x3,
            Space.gutter,
            Space.x10,
          ),
          children: [
            Row(
              children: [
                CircleIconButton(
                  icon: PhosphorIconsBold.caretLeft,
                  tooltip: 'Back',
                  onPressed: () => context.pop(),
                ),
                const Spacer(),
                CircleIconButton(
                  icon: PhosphorIconsRegular.pencilSimple,
                  tooltip: 'Edit',
                  onPressed: () => context.push('/prayer/$prayerId/edit'),
                ),
                const SizedBox(width: Space.x2),
                CircleIconButton(
                  icon: PhosphorIconsRegular.trash,
                  tooltip: 'Delete',
                  onPressed: () async {
                    if (await confirmDestructive(
                      context,
                      title: 'Delete prayer?',
                      message: 'This removes it from all your devices.',
                    )) {
                      await repo.delete(prayerId);
                      final reminders = ref.read(reminderServiceProvider);
                      await reminders.syncPrayerReminders(
                        await repo.withReminders(),
                      );
                      if (context.mounted) context.pop();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: Space.x5),
            Container(
              padding: const EdgeInsets.fromLTRB(
                Space.x5,
                Space.x5,
                Space.x5,
                Space.x5 + 14,
              ),
              decoration: ShapeDecoration(
                color: answered ? p.paperDeep : prayerColor(cat, p),
                shape: const BubbleBorder(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.label.toUpperCase(),
                    style: AppType.overline.copyWith(
                      color: answered ? p.inkMute : p.onPastel,
                    ),
                  ),
                  const SizedBox(height: Space.x2),
                  Text(
                    prayer.title,
                    style: AppType.displayS.copyWith(
                      color: answered ? p.ink : p.onPastel,
                    ),
                  ),
                  if (prayer.body.isNotEmpty) ...[
                    const SizedBox(height: Space.x3),
                    Text(
                      prayer.body,
                      style: AppType.body.copyWith(
                        color: answered ? p.inkSoft : p.onPastel,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (scripture != null) ...[
              const SizedBox(height: Space.x4),
              PillButton(
                label: scripture.label,
                icon: PhosphorIconsRegular.bookOpen,
                variant: PillVariant.tonal,
                onPressed: () => context.push(
                  ReaderArgs.location(scripture!.start, flash: scripture),
                ),
              ),
            ],
            const SizedBox(height: Space.x6),
            Text('HISTORY', style: AppType.overline.copyWith(color: p.inkMute)),
            const SizedBox(height: Space.x2),
            _HistoryRow(
              icon: PhosphorIconsRegular.plusCircle,
              text:
                  'Started ${fmt.format(DateTime.fromMillisecondsSinceEpoch(prayer.createdAt))}',
            ),
            if (prayer.updatedAt != prayer.createdAt && !answered)
              _HistoryRow(
                icon: PhosphorIconsRegular.pencilSimple,
                text:
                    'Updated ${fmt.format(DateTime.fromMillisecondsSinceEpoch(prayer.updatedAt))}',
              ),
            if (answered && prayer.answeredAt != null)
              _HistoryRow(
                icon: PhosphorIconsFill.sparkle,
                text:
                    'Answered ${fmt.format(DateTime.fromMillisecondsSinceEpoch(prayer.answeredAt!))}',
                accent: true,
              ),
            if (answered && prayer.answerNote != null)
              Padding(
                padding: const EdgeInsets.only(left: 36, top: 4),
                child: Text(
                  prayer.answerNote!,
                  style: AppType.body.copyWith(color: p.ink),
                ),
              ),
            if (prayer.reminderKind != 'none' &&
                !answered &&
                prayer.reminderValue != null)
              _HistoryRow(
                icon: PhosphorIconsRegular.bell,
                text: prayer.reminderKind == 'daily'
                    ? 'Reminder every day at ${TimeOfDay(hour: prayer.reminderValue! ~/ 60, minute: prayer.reminderValue! % 60).format(context)}'
                    : 'Reminder on ${DateFormat('d MMM, HH:mm').format(DateTime.fromMillisecondsSinceEpoch(prayer.reminderValue!))}',
              ),
            const SizedBox(height: Space.x8),
            if (!answered)
              PillButton(
                label: 'Mark as answered',
                icon: PhosphorIconsBold.sparkle,
                variant: PillVariant.accent,
                expand: true,
                onPressed: () async {
                  final note = await showAppSheet<String>(
                    context,
                    builder: (_) => const _AnsweredSheet(),
                  );
                  if (note == null) return;
                  Haptics.success();
                  await repo.markAnswered(prayerId, note: note);
                  final reminders = ref.read(reminderServiceProvider);
                  await reminders.syncPrayerReminders(
                    await repo.withReminders(),
                  );
                },
              )
            else
              PillButton(
                label: 'Pray for this again',
                icon: PhosphorIconsRegular.arrowCounterClockwise,
                variant: PillVariant.secondary,
                expand: true,
                onPressed: () => repo.reopen(prayerId),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.icon,
    required this.text,
    this.accent = false,
  });

  final IconData icon;
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accent ? p.tangerine : p.inkSoft),
          const SizedBox(width: Space.x4),
          Expanded(
            child: Text(text, style: AppType.body.copyWith(color: p.ink)),
          ),
        ],
      ),
    );
  }
}

class _AnsweredSheet extends StatefulWidget {
  const _AnsweredSheet();

  @override
  State<_AnsweredSheet> createState() => _AnsweredSheetState();
}

class _AnsweredSheetState extends State<_AnsweredSheet> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.x6, 0, Space.x6, Space.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(title: 'How was it answered?'),
            TextField(
              controller: _c,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'A few words to remember (optional)',
              ),
            ),
            const SizedBox(height: Space.x4),
            PillButton(
              label: 'Mark answered',
              onPressed: () => Navigator.pop(context, _c.text),
            ),
          ],
        ),
      ),
    );
  }
}
