import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';

import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../bible/references.dart';
import '../../bible/translation.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/layout.dart';
import 'card_templates.dart';

/// Scripture card editor with a live preview.
class ShareCardScreen extends ConsumerStatefulWidget {
  const ShareCardScreen({super.key, required this.range, this.translationId});

  final VerseRange range;
  final String? translationId;

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> {
  final _boundary = GlobalKey();
  CardTemplate _template = CardTemplate.paper;
  CardFormat _format = CardFormat.square;
  CardFont _font = CardFont.fraunces;
  TextAlign _align = TextAlign.left;
  Color _accent = cardPastels.first;
  bool _exporting = false;

  Future<void> _share(String text, String label) async {
    setState(() => _exporting = true);
    try {
      final box =
          _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ratio = _format.width / box.size.width;
      final image = await box.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final bytes = data!.buffer.asUint8List();
      final name = '${label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}.png';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: name)],
          fileNameOverrides: [name],
          text: label,
        ),
      );
    } on Object catch (e) {
      if (mounted) toast(context, 'Couldn’t share the image: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = Motion.of(context);
    final catalog = ref.watch(catalogProvider).value;
    final id =
        widget.translationId ?? ref.watch(currentTranslationProvider).value?.id;
    final bible = id == null
        ? null
        : ref.watch(bibleTextProvider(catalog?.resolve(id).id ?? id)).value;

    final verses = bible?.versesIn(widget.range) ?? const [];
    // Cards read as one passage, without verse numbers.
    final text = [
      for (final (_, t) in verses)
        VerseText.plain(t, suppliedWords: bible!.info.suppliedWords),
    ].join(' ');
    final label =
        '${widget.range.label}${bible == null ? '' : ' ${bible.info.abbreviation}'}';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x3,
                Space.x3,
                Space.gutter,
                Space.x2,
              ),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: PhosphorIconsBold.x,
                    tooltip: 'Close',
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Text(
                      'Share card',
                      style: AppType.titleM.copyWith(color: p.ink),
                    ),
                  ),
                  PillButton(
                    label: 'Share',
                    icon: PhosphorIconsBold.shareNetwork,
                    compact: true,
                    busy: _exporting,
                    onPressed: text.isEmpty ? null : () => _share(text, label),
                  ),
                ],
              ),
            ),
            // Live preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.x8,
                  vertical: Space.x3,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: m.base,
                    switchInCurve: m.standard,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.97, end: 1.0).animate(a),
                        child: child,
                      ),
                    ),
                    child: AspectRatio(
                      key: ValueKey(_format),
                      aspectRatio: _format.aspect,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: Radii.smAll,
                          boxShadow: floatingShadow(p),
                        ),
                        child: ClipRRect(
                          borderRadius: Radii.smAll,
                          child: RepaintBoundary(
                            key: _boundary,
                            child: text.isEmpty
                                ? ColoredBox(color: p.paperDeep)
                                : AnimatedSwitcher(
                                    duration: m.base,
                                    child: ScriptureCard(
                                      key: ValueKey(
                                        '$_template$_font$_align$_accent',
                                      ),
                                      template: _template,
                                      text: text,
                                      reference: label,
                                      font: _font,
                                      alignment: _align,
                                      accent: _accent,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Controls
            Container(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(Radii.xl),
                ),
              ),
              padding: const EdgeInsets.only(top: Space.x4, bottom: Space.x4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.gutter,
                      ),
                      itemCount: CardTemplate.values.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: Space.x3),
                      itemBuilder: (context, i) {
                        final t = CardTemplate.values[i];
                        final on = t == _template;
                        return Semantics(
                          button: true,
                          selected: on,
                          label: '${t.label} template',
                          child: Pressable(
                            onTap: () => setState(() => _template = t),
                            child: Column(
                              children: [
                                AnimatedContainer(
                                  duration: m.fast,
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: Radii.smAll,
                                    border: Border.all(
                                      color: on ? p.tangerine : p.line,
                                      width: on ? 3 : 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: ScriptureCard(
                                    template: t,
                                    text: 'Aa',
                                    reference: '',
                                    font: _font,
                                    alignment: TextAlign.center,
                                    accent: _accent,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  t.label,
                                  style: AppType.caption.copyWith(
                                    color: on ? p.ink : p.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: Space.x3),
                  ChipRow<CardFormat>(
                    options: CardFormat.values,
                    selected: _format,
                    labelOf: (f) => f.label,
                    onSelected: (f) => setState(() => _format = f),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      6,
                      Space.gutter,
                      0,
                    ),
                    child: Text(
                      '${_format.useFor} · ${_format.width}×${_format.height}',
                      style: AppType.caption.copyWith(color: p.inkMute),
                    ),
                  ),
                  const SizedBox(height: Space.x3),
                  ChipRow<CardFont>(
                    options: CardFont.values,
                    selected: _font,
                    labelOf: (f) => f.label,
                    onSelected: (f) => setState(() => _font = f),
                  ),
                  const SizedBox(height: Space.x3),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.gutter,
                    ),
                    child: Row(
                      children: [
                        CircleIconButton(
                          icon: PhosphorIconsRegular.textAlignLeft,
                          tooltip: 'Align left',
                          background: _align == TextAlign.left ? p.ink : null,
                          foreground: _align == TextAlign.left ? p.paper : null,
                          onPressed: () =>
                              setState(() => _align = TextAlign.left),
                        ),
                        const SizedBox(width: Space.x2),
                        CircleIconButton(
                          icon: PhosphorIconsRegular.textAlignCenter,
                          tooltip: 'Centre',
                          background: _align == TextAlign.center ? p.ink : null,
                          foreground: _align == TextAlign.center
                              ? p.paper
                              : null,
                          onPressed: () =>
                              setState(() => _align = TextAlign.center),
                        ),
                        const Spacer(),
                        AnimatedOpacity(
                          opacity: _template.hasColors ? 1 : 0.3,
                          duration: m.fast,
                          child: Row(
                            children: [
                              for (final c in cardPastels)
                                Semantics(
                                  button: true,
                                  label: 'Card colour',
                                  selected: c == _accent,
                                  child: GestureDetector(
                                    onTap: _template.hasColors
                                        ? () => setState(() => _accent = c)
                                        : null,
                                    child: AnimatedContainer(
                                      duration: m.fast,
                                      width: 28,
                                      height: 28,
                                      margin: const EdgeInsets.only(left: 6),
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: c == _accent ? p.ink : p.line,
                                          width: c == _accent ? 2.5 : 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
