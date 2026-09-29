import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';

import '../../app/providers.dart';
import '../../bible/canon.dart';
import '../../bible/references.dart';
import '../../core/haptics.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/reader_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/layout.dart';
import '../../data/db/database.dart';
import '../../data/repos/preferences_repository.dart';

// ---------------------------------------------------------------------------
// Reading settings
// ---------------------------------------------------------------------------

class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final prefs = ref.watch(prefsValueProvider);
    final translation = ref.watch(currentTranslationProvider).value;
    final repo = ref.read(preferencesRepositoryProvider);
    final brightness = Theme.of(context).brightness;
    final activeTheme = ReaderTheme.resolve(prefs.readerTheme, brightness);

    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: Space.x5, bottom: Space.x2),
      child: Text(t, style: AppType.overline.copyWith(color: p.inkMute)),
    );

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.x6, 0, Space.x6, Space.x6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              title: 'Reading',
              trailing: CircleIconButton(
                icon: PhosphorIconsBold.x,
                tooltip: 'Close',
                size: 40,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Live sample of the current settings.
            AnimatedContainer(
              duration: Motion.of(context).base,
              padding: const EdgeInsets.all(Space.x4),
              decoration: BoxDecoration(
                color: activeTheme.background,
                borderRadius: Radii.mdAll,
                border: Border.all(color: p.line),
              ),
              child: Text(
                'In the beginning was the Word, and the Word was with God.',
                style: fontStyle(
                  prefs.font.family,
                  size: prefs.fontSize,
                  height: prefs.lineHeight,
                  color: activeTheme.text,
                  variable: prefs.font.variable,
                ),
              ),
            ),
            label('TEXT SIZE'),
            Row(
              children: [
                Text('A', style: AppType.label.copyWith(color: p.inkSoft)),
                Expanded(
                  child: Slider(
                    value: prefs.fontSize,
                    min: ReaderPrefs.minFontSize,
                    max: ReaderPrefs.maxFontSize,
                    divisions: 15,
                    label: prefs.fontSize.round().toString(),
                    onChanged: (v) =>
                        repo.update(PreferencesCompanion(fontSize: Value(v))),
                  ),
                ),
                Text('A', style: AppType.titleL.copyWith(color: p.inkSoft)),
              ],
            ),
            label('LINE SPACING'),
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.textAlignJustify,
                  color: p.inkSoft,
                  size: 18,
                ),
                Expanded(
                  child: Slider(
                    value: prefs.lineHeight,
                    min: ReaderPrefs.minLineHeight,
                    max: ReaderPrefs.maxLineHeight,
                    divisions: 6,
                    label: prefs.lineHeight.toStringAsFixed(1),
                    onChanged: (v) =>
                        repo.update(PreferencesCompanion(lineHeight: Value(v))),
                  ),
                ),
                Icon(
                  PhosphorIconsRegular.textAlignLeft,
                  color: p.inkSoft,
                  size: 22,
                ),
              ],
            ),
            label('TYPEFACE'),
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              children: [
                for (final f in ScriptureFont.values)
                  _Choice(
                    selected: prefs.font == f,
                    onTap: () => repo.update(
                      PreferencesCompanion(scriptureFont: Value(f.name)),
                    ),
                    child: Text(
                      f.label,
                      style: fontStyle(
                        f.family,
                        size: 15,
                        weight: FontWeight.w500,
                        color: prefs.font == f ? p.paper : p.ink,
                        variable: f.variable,
                      ),
                    ),
                  ),
              ],
            ),
            label('PAGE'),
            Row(
              children: [
                _ThemeSwatch(
                  label: 'Auto',
                  background: brightness == Brightness.dark
                      ? ReaderTheme.night.background
                      : ReaderTheme.paper.background,
                  text: brightness == Brightness.dark
                      ? ReaderTheme.night.text
                      : ReaderTheme.paper.text,
                  selected: prefs.readerTheme == 'auto',
                  onTap: () => repo.update(
                    const PreferencesCompanion(readerTheme: Value('auto')),
                  ),
                ),
                for (final t in ReaderTheme.values)
                  _ThemeSwatch(
                    label: t.label,
                    background: t.background,
                    text: t.text,
                    selected: prefs.readerTheme == t.name,
                    onTap: () => repo.update(
                      PreferencesCompanion(readerTheme: Value(t.name)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.x4),
            _Toggle(
              title: 'Verse numbers',
              value: prefs.showVerseNumbers,
              onChanged: (v) =>
                  repo.update(PreferencesCompanion(showVerseNumbers: Value(v))),
            ),
            _Toggle(
              title: 'Paragraphs',
              subtitle: 'Off shows one verse per line',
              value: prefs.paragraphMode,
              onChanged: (v) =>
                  repo.update(PreferencesCompanion(paragraphMode: Value(v))),
            ),
            if (translation?.suppliedWords ?? false)
              _Toggle(
                title: 'Italic supplied words',
                subtitle: 'Words the KJV translators added for sense',
                value: prefs.suppliedItalics,
                onChanged: (v) => repo.update(
                  PreferencesCompanion(suppliedItalics: Value(v)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context).fast,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? p.ink : p.paperDeep,
            borderRadius: Radii.pillAll,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.label,
    required this.background,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Semantics(
        label: '$label page',
        selected: selected,
        button: true,
        child: Pressable(
          onTap: onTap,
          child: Column(
            children: [
              AnimatedContainer(
                duration: Motion.of(context).fast,
                height: 52,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: Radii.smAll,
                  border: Border.all(
                    color: selected ? p.tangerine : p.line,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Aa',
                  style: fontStyle('Literata', size: 18, color: text),
                ),
              ),
              const SizedBox(height: 6),
              Text(label, style: AppType.caption.copyWith(color: p.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppType.body.copyWith(color: p.ink)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: AppType.caption.copyWith(color: p.inkMute)),
      value: value,
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Translation picker
// ---------------------------------------------------------------------------

class TranslationSheet extends ConsumerWidget {
  const TranslationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final catalog = ref.watch(catalogProvider).value;
    final current = ref.watch(currentTranslationProvider).value;
    if (catalog == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(Space.x4, 0, Space.x4, Space.x6),
        children: [
          SheetHeader(
            title: 'Translation',
            trailing: CircleIconButton(
              icon: PhosphorIconsBold.x,
              tooltip: 'Close',
              size: 40,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          for (final t in catalog.available)
            _TranslationTile(
              abbreviation: t.abbreviation,
              name: t.name,
              detail: t.license,
              selected: t.id == current?.id,
              onTap: () async {
                Haptics.select();
                await ref
                    .read(preferencesRepositoryProvider)
                    .setTranslation(t.id);
                if (context.mounted) Navigator.pop(context, t.id);
              },
            ),
          if (catalog.unavailable.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x2,
                Space.x6,
                Space.x2,
                Space.x2,
              ),
              child: Text(
                'NOT AVAILABLE YET',
                style: AppType.overline.copyWith(color: p.inkMute),
              ),
            ),
            for (final t in catalog.unavailable)
              _TranslationTile(
                abbreviation: t.abbreviation,
                name: t.name,
                detail: t.reason,
                selected: false,
                onTap: null,
              ),
          ],
        ],
      ),
    );
  }
}

class _TranslationTile extends StatelessWidget {
  const _TranslationTile({
    required this.abbreviation,
    required this.name,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String abbreviation;
  final String name;
  final String detail;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onTap != null;
    return Semantics(
      selected: selected,
      button: enabled,
      label: '$name. $detail',
      child: Pressable(
        onTap: onTap,
        scale: 0.98,
        child: AnimatedContainer(
          duration: Motion.of(context).fast,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(Space.x4),
          decoration: BoxDecoration(
            color: selected ? p.butter : p.paperDeep,
            borderRadius: Radii.mdAll,
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    abbreviation,
                    style: AppType.titleM.copyWith(
                      color: selected ? p.onPastel : p.ink,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppType.body.copyWith(
                          color: selected ? p.onPastel : p.ink,
                        ),
                      ),
                      Text(
                        detail,
                        style: AppType.caption.copyWith(
                          color: selected ? p.onPastel : p.inkMute,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(PhosphorIconsBold.check, color: p.onPastel),
                if (!enabled)
                  Icon(
                    PhosphorIconsRegular.lockSimple,
                    color: p.inkMute,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Book and chapter picker
// ---------------------------------------------------------------------------

/// Book list (by testament) that expands into a chapter grid. Returns the
/// chosen chapter.
class ChapterPicker extends ConsumerStatefulWidget {
  const ChapterPicker({
    super.key,
    this.current,
    this.onPicked,
    this.scrollable = true,
  });

  final ChapterRef? current;
  final ValueChanged<ChapterRef>? onPicked;
  final bool scrollable;

  @override
  ConsumerState<ChapterPicker> createState() => _ChapterPickerState();
}

class _ChapterPickerState extends ConsumerState<ChapterPicker> {
  late Testament _testament = widget.current?.book.testament ?? Testament.old;
  String? _open;

  @override
  void initState() {
    super.initState();
    _open = widget.current?.bookId;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = Motion.of(context);
    final read = ref.watch(readChaptersProvider).value ?? const <String>{};
    final books = Canon.testament(_testament).toList();
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: _Segmented(
            value: _testament,
            onChanged: (t) => setState(() {
              _testament = t;
              _open = null;
            }),
          ),
        ),
        const SizedBox(height: Space.x3),
        for (final b in books)
          Column(
            children: [
              InkWell(
                onTap: () =>
                    setState(() => _open = _open == b.id ? null : b.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.gutter,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.name,
                          style: AppType.titleS.copyWith(
                            color: widget.current?.bookId == b.id
                                ? p.tangerineText
                                : p.ink,
                          ),
                        ),
                      ),
                      Text(
                        '${b.chapterCount}',
                        style: AppType.caption.copyWith(color: p.inkMute),
                      ),
                      const SizedBox(width: Space.x2),
                      AnimatedRotation(
                        turns: _open == b.id ? 0.5 : 0,
                        duration: m.fast,
                        child: Icon(
                          PhosphorIconsRegular.caretDown,
                          size: 16,
                          color: p.inkMute,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: m.base,
                curve: m.standard,
                alignment: Alignment.topCenter,
                child: _open == b.id
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.gutter,
                          0,
                          Space.gutter,
                          Space.x4,
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var c = 1; c <= b.chapterCount; c++)
                              _ChapterCell(
                                number: c,
                                read: read.contains('${b.id}.$c'),
                                current: widget.current == ChapterRef(b.id, c),
                                onTap: () =>
                                    widget.onPicked?.call(ChapterRef(b.id, c)),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              Divider(
                indent: Space.gutter,
                endIndent: Space.gutter,
                color: p.line,
              ),
            ],
          ),
      ],
    );
    return widget.scrollable ? SingleChildScrollView(child: list) : list;
  }
}

class _ChapterCell extends StatelessWidget {
  const _ChapterCell({
    required this.number,
    required this.read,
    required this.current,
    required this.onTap,
  });

  final int number;
  final bool read;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bg = current ? p.ink : (read ? p.sage : p.paperDeep);
    final fg = current ? p.paper : (read ? p.onPastel : p.ink);
    return Semantics(
      label: 'Chapter $number${read ? ', read' : ''}',
      button: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: Radii.smAll),
          child: Text(
            '$number',
            style: AppType.label.copyWith(
              color: fg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.onChanged});

  final Testament value;
  final ValueChanged<Testament> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = Motion.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.paperDeep,
        borderRadius: Radii.pillAll,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: m.base,
                curve: m.standard,
                left: value == Testament.old ? 0 : w,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: p.ink,
                    borderRadius: Radii.pillAll,
                  ),
                ),
              ),
              Row(
                children: [
                  for (final t in Testament.values)
                    Expanded(
                      child: Semantics(
                        selected: t == value,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(t),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: m.fast,
                              style: AppType.label.copyWith(
                                color: t == value ? p.paper : p.inkSoft,
                              ),
                              child: Text(t.label),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
