import 'dart:math' as math;

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/theme/reader_themes.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/day.dart';
import '../../core/utils/format.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/notification_service.dart';
import '../../shared/widgets/controls.dart';

enum SettingsPage {
  appearance('appearance', 'Appearance', 'Light, dark and page themes', PhosphorIconsRegular.sun),
  reading('reading', 'Reading preferences', 'View mode, fit and Text view', PhosphorIconsRegular.bookOpen),
  notifications('notifications', 'Notifications', 'Daily reading reminder', PhosphorIconsRegular.bell),
  goals('goals', 'Reading goals', 'Minutes a day', PhosphorIconsRegular.target),
  storage('storage', 'Storage', 'Space used by your library', PhosphorIconsRegular.hardDrives),
  ai('ai', 'AI settings', 'Reading assistant and Ask This Book', PhosphorIconsRegular.sparkle),
  privacy('privacy', 'Privacy', 'What’s stored and what’s sent', PhosphorIconsRegular.shieldCheck),
  about('about', 'About Folio', 'Version and licences', PhosphorIconsRegular.info);

  const SettingsPage(this.path, this.title, this.subtitle, this.icon);
  final String path;
  final String title;
  final String subtitle;
  final IconData icon;
}

class SettingsPageScreen extends StatelessWidget {
  const SettingsPageScreen({super.key, required this.page});
  final SettingsPage page;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x10),
        children: [
          Text(page.title, style: context.text.displaySmall),
          const SizedBox(height: Space.x5),
          switch (page) {
            SettingsPage.appearance => const _Appearance(),
            SettingsPage.reading => const _Reading(),
            SettingsPage.notifications => const _Notifications(),
            SettingsPage.goals => const _Goals(),
            SettingsPage.storage => const _Storage(),
            SettingsPage.ai => const _Ai(),
            SettingsPage.privacy => const _Privacy(),
            SettingsPage.about => const _About(),
          },
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.x5, bottom: Space.x2),
    child: Text(text.toUpperCase(), style: context.text.labelSmall),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: context.colors.surface, borderRadius: Radii.lgAll),
    padding: const EdgeInsets.symmetric(vertical: Space.x2),
    child: Column(children: children),
  );
}

// --------------------------------------------------------------- appearance

class _Appearance extends ConsumerWidget {
  const _Appearance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('App theme'),
        Wrap(
          spacing: Space.x2,
          children: [
            for (final (mode, label) in [
              (ThemeMode.system, 'System'),
              (ThemeMode.light, 'Light'),
              (ThemeMode.dark, 'Dark'),
            ])
              PillChip(
                label: label,
                selected: s.themeMode == mode,
                onTap: () => n.update((x) => x.copyWith(themeMode: mode)),
              ),
          ],
        ),
        const SizedBox(height: Space.x2),
        Text(
          'Dark mode uses warm, low-glare tones designed for reading at night, not inverted colours.',
          style: context.text.bodySmall,
        ),
        const _Label('Reader page theme'),
        Row(
          children: [
            for (final t in ReaderTheme.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: Space.x2),
                  child: GestureDetector(
                    onTap: () => n.update((x) => x.copyWith(readerTheme: t, followSystemForReader: false)),
                    child: Container(
                      height: 88,
                      decoration: BoxDecoration(
                        color: t.page,
                        borderRadius: Radii.mdAll,
                        border: Border.all(
                          color: !s.followSystemForReader && s.readerTheme == t
                              ? context.colors.lavender
                              : context.colors.hairline,
                          width: !s.followSystemForReader && s.readerTheme == t ? 2.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Aa', style: context.text.headlineSmall?.copyWith(color: t.text)),
                          Text(t.label, style: context.text.labelSmall?.copyWith(color: t.mutedText)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Match app theme'),
          subtitle: const Text('Use Night pages automatically when the app is dark'),
          value: s.followSystemForReader,
          onChanged: (v) => n.update((x) => x.copyWith(followSystemForReader: v)),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- reading

class _Reading extends ConsumerWidget {
  const _Reading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final t = ReaderTheme.paper;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Default view'),
        Wrap(
          spacing: Space.x2,
          runSpacing: Space.x2,
          children: [
            for (final m in ReaderViewMode.values)
              PillChip(
                label: m.label,
                selected: s.viewMode == m,
                onTap: () => n.update((x) => x.copyWith(viewMode: m)),
              ),
          ],
        ),
        const SizedBox(height: Space.x2),
        Text(
          'Scroll shows pages top to bottom. Page by page turns one page at a time. Text '
          'reflows the book’s text so size and spacing can change (PDFs with a text layer only).',
          style: context.text.bodySmall,
        ),
        const _Label('Fit PDF pages'),
        Wrap(
          spacing: Space.x2,
          children: [
            for (final f in FitMode.values)
              PillChip(
                label: f.label,
                selected: s.fitMode == f,
                onTap: () => n.update((x) => x.copyWith(fitMode: f)),
              ),
          ],
        ),
        const _Label('Text view'),
        _Card(
          children: [
            _Slider(
              'Text size',
              s.textScale,
              14,
              28,
              14,
              '${s.textScale.round()}',
              (v) => n.update((x) => x.copyWith(textScale: v)),
            ),
            _Slider(
              'Line spacing',
              s.lineHeight,
              1.3,
              2.0,
              7,
              s.lineHeight.toStringAsFixed(1),
              (v) => n.update((x) => x.copyWith(lineHeight: v)),
            ),
            _Slider(
              'Reading width',
              s.textWidth,
              420,
              900,
              8,
              s.textWidth < 560
                  ? 'Narrow'
                  : s.textWidth < 760
                  ? 'Medium'
                  : 'Wide',
              (v) => n.update((x) => x.copyWith(textWidth: v)),
            ),
          ],
        ),
        const SizedBox(height: Space.x4),
        Container(
          padding: const EdgeInsets.all(Space.x5),
          decoration: BoxDecoration(
            color: t.page,
            borderRadius: Radii.lgAll,
            border: Border.all(color: context.colors.hairline),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: s.textWidth * 0.5),
              child: Text(
                'It was a bright cold day in April, and the reading lamp was already on. '
                'She opened the book where the ribbon lay and began again.',
                style: TextStyle(fontFamily: 'Literata', fontSize: s.textScale, height: s.lineHeight, color: t.text),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider(this.label, this.value, this.min, this.max, this.divisions, this.display, this.onChanged);
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.x4),
    child: Row(
      children: [
        SizedBox(width: 104, child: Text(label, style: context.text.labelLarge)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(display, textAlign: TextAlign.end, style: context.text.bodySmall),
        ),
      ],
    ),
  );
}

// --------------------------------------------------------------- notifications

class _Notifications extends ConsumerWidget {
  const _Notifications();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final supported = NotificationService.instance.isSupported;
    final time = TimeOfDay(hour: s.reminderMinutes ~/ 60, minute: s.reminderMinutes % 60);

    Future<void> apply(AppSettings Function(AppSettings) change) async {
      await n.update(change);
      await NotificationService.instance.applySettings(ref.read(settingsProvider));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          children: [
            SwitchListTile(
              title: const Text('Daily reading reminder'),
              subtitle: Text(
                supported ? 'A gentle nudge at the time you choose' : 'Reminders are available on Android and iOS',
              ),
              value: s.reminderEnabled && supported,
              onChanged: !supported
                  ? null
                  : (v) async {
                      if (v) {
                        final granted = await NotificationService.instance.requestPermission();
                        if (!granted) {
                          if (context.mounted) {
                            showFolioSnack(context, 'Notifications are turned off for Folio in your phone’s settings.');
                          }
                          return;
                        }
                      }
                      await apply((x) => x.copyWith(reminderEnabled: v));
                    },
            ),
            ListTile(
              enabled: s.reminderEnabled && supported,
              title: const Text('Reminder time'),
              trailing: Text(time.format(context), style: context.text.titleSmall),
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: time);
                if (picked != null) await apply((x) => x.copyWith(reminderMinutes: picked.hour * 60 + picked.minute));
              },
            ),
          ],
        ),
        const SizedBox(height: Space.x3),
        Text(
          'Reminders are scheduled by your phone. Folio has no server and never sends '
          'notifications from the internet.',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- goals

class _Goals extends ConsumerWidget {
  const _Goals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final stats = ref.watch(statsProvider).value;
    final today = (stats?.secondsToday ?? 0) ~/ 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How long would you like to read each day?', style: context.text.bodyLarge),
        const SizedBox(height: Space.x4),
        Wrap(
          spacing: Space.x2,
          runSpacing: Space.x2,
          children: [
            for (final m in const [10, 15, 20, 30, 45, 60])
              PillChip(
                label: '$m min',
                selected: s.dailyGoalMinutes == m,
                onTap: () => n.update((x) => x.copyWith(dailyGoalMinutes: m)),
              ),
          ],
        ),
        const SizedBox(height: Space.x3),
        _Card(
          children: [
            _Slider(
              'Custom',
              s.dailyGoalMinutes.toDouble(),
              5,
              120,
              23,
              '${s.dailyGoalMinutes} min',
              (v) => n.update((x) => x.copyWith(dailyGoalMinutes: v.round())),
            ),
          ],
        ),
        const SizedBox(height: Space.x4),
        Text(
          today >= s.dailyGoalMinutes
              ? 'You’ve reached today’s goal ($today min). Anything more is a bonus.'
              : 'Today: $today of ${s.dailyGoalMinutes} minutes.',
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: Space.x2),
        Text('Goals are just for you. There are no points, badges or leaderboards.', style: context.text.bodySmall),
      ],
    );
  }
}

// --------------------------------------------------------------- storage

final _storageUsageProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(booksProvider);
  return ref.watch(libraryStorageProvider).usedBytes();
});

class _Storage extends ConsumerWidget {
  const _Storage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = [...ref.watch(booksProvider).value ?? const <Book>[]]
      ..sort((a, b) => b.fileSize.compareTo(a.fileSize));
    final used = ref.watch(_storageUsageProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Space.x5),
          decoration: BoxDecoration(
            color: ShelfColor.sky.cardBackground(context.brightness),
            borderRadius: Radii.lgAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                used == null ? '…' : formatBytes(used),
                style: context.text.displayMedium?.copyWith(color: ShelfColor.sky.cardForeground(context.brightness)),
              ),
              Text(
                'used by ${plural(books.length, 'book')} and their covers',
                style: context.text.bodySmall?.copyWith(color: ShelfColor.sky.cardForeground(context.brightness)),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.x3),
        Text(
          'Folio keeps its own copy of each PDF so books keep working if the original is moved. '
          'Removing a book frees this space and never touches the original file.',
          style: context.text.bodySmall,
        ),
        if (books.isNotEmpty) ...[
          const _Label('Largest books'),
          _Card(
            children: [
              for (final b in books.take(10))
                ListTile(
                  title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(formatBytes(b.fileSize), style: context.text.bodySmall),
                  onTap: () => context.push('/book/${b.id}'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// --------------------------------------------------------------- AI

class _Ai extends StatelessWidget {
  const _Ai();

  @override
  Widget build(BuildContext context) {
    final b = context.brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Space.x5),
          decoration: BoxDecoration(color: ShelfColor.lilac.cardBackground(b), borderRadius: Radii.lgAll),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(PhosphorIconsRegular.sparkle, color: ShelfColor.lilac.cardForeground(b)),
                  const SizedBox(width: Space.x2),
                  Text(
                    'AI is off',
                    style: context.text.titleLarge?.copyWith(color: ShelfColor.lilac.cardForeground(b)),
                  ),
                ],
              ),
              const SizedBox(height: Space.x2),
              Text(
                'No AI provider is connected, so Explain, Summarize, Key points, Simplify, Define, '
                'Ask This Page, Ask This Book and chapter summaries are turned off. Nothing is ever '
                'sent while AI is off.',
                style: context.text.bodyMedium?.copyWith(color: ShelfColor.lilac.cardForeground(b)),
              ),
            ],
          ),
        ),
        const _Label('What will be sent once AI is on'),
        const _PrivacyAiNote(),
      ],
    );
  }
}

class _PrivacyAiNote extends StatelessWidget {
  const _PrivacyAiNote();

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: Space.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: Space.x3),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
    return Column(
      children: [
        row(
          PhosphorIconsRegular.quotes,
          'Explain / Define / Simplify: only the passage you selected, plus the book title.',
        ),
        row(PhosphorIconsRegular.file, 'Ask This Page and page summaries: only that page’s text.'),
        row(
          PhosphorIconsRegular.listNumbers,
          'Chapter summaries: only the pages of that chapter (or the page range you pick).',
        ),
        row(
          PhosphorIconsRegular.chatCircleText,
          'Ask This Book: your question plus the few pages Folio finds most relevant on your phone, '
          'never the whole book.',
        ),
        row(
          PhosphorIconsRegular.shieldCheck,
          'Requests are sent only when you tap an AI action. Answers are saved on this device only.',
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- privacy

class _Privacy extends ConsumerWidget {
  const _Privacy();

  Future<void> _eraseAll(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Erase everything in Folio?',
      message:
          'This removes every book copy, highlight, note, bookmark, collection and your reading '
          'history from this phone. Your original PDF files outside Folio are not touched. '
          'This can’t be undone.',
      confirmLabel: 'Erase everything',
      destructive: true,
    );
    if (!ok) return;
    final db = ref.read(databaseProvider);
    final storage = ref.read(libraryStorageProvider);
    final books = await db.select(db.books).get();
    await db.transaction(() async {
      for (final t in db.allTables) {
        if (t is Settings) continue;
        await db.delete(t).go();
      }
    });
    for (final b in books) {
      await storage.deleteFiles(filePath: b.filePath, coverPath: b.coverPath);
    }
    if (context.mounted) showFolioSnack(context, 'Folio’s data has been erased');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget point(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleMedium),
          const SizedBox(height: 2),
          Text(body, style: context.text.bodyMedium?.copyWith(color: context.colors.inkMuted)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        point(
          'Everything stays on this phone',
          'Your books, highlights, notes, bookmarks, collections and reading history are stored only on '
              'this device. There is no account, no cloud library and no sync.',
        ),
        point('Encrypted at rest', 'Folio’s database is encrypted. Its key is kept in your phone’s secure keystore.'),
        point('No tracking', 'Folio has no analytics, ads or crash reporting that phones home.'),
        point(
          'Importing',
          'Imported PDFs are copied into Folio’s private storage and read on-device. Nothing is uploaded.',
        ),
        point(
          'AI (optional)',
          'AI features are off until you add a provider. When on, only the selected passage, page or '
              'chapter is sent with each request. See Settings → AI for exactly what is sent.',
        ),
        const SizedBox(height: Space.x3),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: context.colors.danger),
          onPressed: () => _eraseAll(context, ref),
          icon: const Icon(PhosphorIconsRegular.trash, size: 18),
          label: const Text('Erase all Folio data'),
        ),
        if (kAllowDemoData) ...[const _Label('Debug build only'), _DemoData()],
      ],
    );
  }
}

/// Sample reading history for previewing Stats. Only compiled into debug
/// builds' UI; release builds never show or seed demo data.
class _DemoData extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () async {
        final db = ref.read(databaseProvider);
        final rnd = math.Random(7);
        final today = dateOnly(DateTime.now());
        await db.batch((b) {
          for (var i = 0; i < 40; i++) {
            if (i > 12 && rnd.nextDouble() < 0.3) continue;
            b.insert(
              db.dailyActivities,
              DailyActivitiesCompanion(
                day: Value(dayKey(addDays(today, -i))),
                pagesRead: Value(5 + rnd.nextInt(40)),
                seconds: Value(600 + rnd.nextInt(3000)),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        });
        if (context.mounted) showFolioSnack(context, 'Added sample reading history');
      },
      icon: const Icon(PhosphorIconsRegular.flask, size: 18),
      label: const Text('Add sample reading history'),
    );
  }
}

// --------------------------------------------------------------- about

class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: Radii.mdAll,
              child: Image.asset(
                'assets/images/app_icon/app_icon.png',
                width: 72,
                height: 72,
                errorBuilder: (_, _, _) => Container(width: 72, height: 72, color: context.colors.lavender),
              ),
            ),
            const SizedBox(width: Space.x4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Folio', style: context.text.headlineMedium),
                Text('Version 1.0.0', style: context.text.bodySmall),
              ],
            ),
          ],
        ),
        const SizedBox(height: Space.x5),
        Text(
          'A calm, private home for your PDFs. Built local-first: no account, no cloud, no tracking.',
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: Space.x5),
        Text(
          'PDF rendering by PDFium via pdfrx. Fonts: Bricolage Grotesque, Manrope and Literata '
          '(SIL Open Font License).',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: Space.x4),
        OutlinedButton(
          onPressed: () => showLicensePage(context: context, applicationName: 'Folio', applicationVersion: '1.0.0'),
          child: const Text('Open-source licences'),
        ),
      ],
    );
  }
}
