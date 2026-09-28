import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/phosphor_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/day_key.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/skill_icons.dart';
import '../../../core/widgets/states.dart';
import '../../skills/domain/levels.dart';
import '../application/insights_providers.dart';

class RecapScreen extends ConsumerStatefulWidget {
  const RecapScreen({super.key, this.initialMonth});

  final DayKey? initialMonth;

  @override
  ConsumerState<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends ConsumerState<RecapScreen> {
  late DayKey _month = Days.monthStart(
    widget.initialMonth ?? ref.read(todayProvider),
  );
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share(RecapData d) async {
    setState(() => _sharing = true);
    await guarded(context, () async {
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw Exception('Could not render the card.');
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(
          dir.path,
          'growth-log-${Fmt.monthYear(d.month).replaceAll(' ', '-').toLowerCase()}.png',
        ),
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: 'My ${Fmt.monthYear(d.month)} in Growth Log 🌱',
        ),
      );
    });
    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final data = ref.watch(recapProvider(_month));
    final isCurrent = _month == Days.monthStart(today);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Palette.electric,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                top + Space.sm,
                Space.gutter,
                0,
              ),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: PhosphorIconsBold.arrowLeft,
                    tooltip: 'Back',
                    background: Palette.white,
                    foreground: Palette.ink,
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(Routes.insights),
                  ),
                  const Spacer(),
                  CircleIconButton(
                    icon: PhosphorIconsBold.caretLeft,
                    tooltip: 'Previous month',
                    size: 40,
                    background: Palette.white.withValues(alpha: 0.15),
                    foreground: Palette.white,
                    onPressed: (data.value?.hasOlder ?? false)
                        ? () => setState(
                            () => _month = Days.addMonths(_month, -1),
                          )
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                    child: Text(
                      Fmt.monthYear(_month),
                      style: AppText.subtitle.copyWith(color: Palette.white),
                    ),
                  ),
                  CircleIconButton(
                    icon: PhosphorIconsBold.caretRight,
                    tooltip: 'Next month',
                    size: 40,
                    background: Palette.white.withValues(alpha: 0.15),
                    foreground: Palette.white,
                    onPressed: isCurrent
                        ? null
                        : () => setState(
                            () => _month = Days.addMonths(_month, 1),
                          ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 260,
              child: Stack(
                children: [
                  const Positioned(
                    right: -20,
                    bottom: 0,
                    child: AppImage(AppAssets.recapMountain, width: 230),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      Space.lg,
                      Space.gutter,
                      0,
                    ),
                    child: Semantics(
                      header: true,
                      label: "Look how far you've come",
                      child: ExcludeSemantics(
                        child: Text(
                          'LOOK\nHOW FAR\nYOU\'VE\nCOME.',
                          style: AppText.display.copyWith(
                            color: Palette.white,
                            fontSize: 50,
                            height: 0.9,
                            letterSpacing: -2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: data.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(Space.xl),
                child: Center(
                  child: CircularProgressIndicator(color: Palette.white),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(Space.gutter),
                child: GLCard(
                  child: ErrorState(
                    error: e,
                    onRetry: () => ref.invalidate(recapProvider(_month)),
                  ),
                ),
              ),
              data: (d) => d.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Space.gutter),
                      child: GLCard(
                        color: Palette.white,
                        child: EmptyState(
                          image: AppAssets.emptyInsights,
                          title: 'A quiet month',
                          message: isCurrent
                              ? 'Your recap fills in as you log practice, wins and gratitude.'
                              : 'Nothing was logged in ${Fmt.monthYear(_month)}.',
                          compact: true,
                        ),
                      ),
                    )
                  : _RecapBody(
                      data: d,
                      cardKey: _cardKey,
                      sharing: _sharing,
                      onShare: () => _share(d),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.paddingOf(context).bottom + Space.xxl,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapBody extends StatelessWidget {
  const _RecapBody({
    required this.data,
    required this.cardKey,
    required this.sharing,
    required this.onShare,
  });

  final RecapData data;
  final GlobalKey cardKey;
  final bool sharing;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final d = data;
    Widget heading(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.xl,
        Space.gutter,
        Space.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(t, style: AppText.title.copyWith(color: Palette.white)),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Hours practised',
                      value: Fmt.hours(d.seconds),
                      caption: Fmt.plural(d.sessions, 'session'),
                      color: Palette.lime,
                      foreground: Palette.ink,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: StatTile(
                      label: 'Entries',
                      value: '${d.entryCount}',
                      caption:
                          '${d.gratitudeCount} gratitude · ${d.winCount} wins',
                      color: Palette.butter,
                      foreground: Palette.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Active days',
                      value: '${d.activeDays}',
                      caption: 'showed up',
                      color: Palette.blush,
                      foreground: Palette.ink,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: StatTile(
                      label: 'Top skill',
                      value: d.topSkill?.name ?? '—',
                      caption: d.topSkill == null
                          ? 'no practice'
                          : Fmt.duration(d.topSkillSeconds),
                      color: Palette.lavender,
                      foreground: Palette.ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (d.topTags.isNotEmpty) ...[
          heading('What filled your month'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in d.topTags)
                  TagChip(
                    '#${t.name} · ${t.count}',
                    color: Palette.white,
                    foreground: Palette.ink,
                  ),
              ],
            ),
          ),
        ],
        if (d.milestones.isNotEmpty) ...[
          heading('Biggest milestones'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Column(
              children: [
                for (final m in d.milestones.take(5)) ...[
                  GLCard(
                    color: Palette.white,
                    padding: const EdgeInsets.all(Space.sm),
                    radius: Radii.cardSmall,
                    child: Row(
                      children: [
                        AppImage(
                          (Levels.levelAtExactly(m.hours) ??
                                  Levels.forSeconds(m.hours * 3600))
                              .badgeAsset,
                          width: 48,
                          height: 48,
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${Fmt.number(m.hours)} hours of ${m.skill.name}',
                                style: AppText.subtitle.copyWith(
                                  color: Palette.ink,
                                ),
                              ),
                              if (Levels.levelAtExactly(m.hours)
                                  case final level?)
                                Text(
                                  'Reached ${level.name}',
                                  style: AppText.caption.copyWith(
                                    color: Palette.ink.withValues(alpha: 0.7),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SkillAvatar(skill: m.skill, size: 32),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                ],
              ],
            ),
          ),
        ],
        if (d.wins.isNotEmpty) ...[
          heading('Highlight reel'),
          SizedBox(
            height: 170,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.82),
              padEnds: false,
              itemCount: d.wins.length,
              itemBuilder: (_, i) {
                final w = d.wins[i];
                return Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? Space.gutter : Space.xs,
                  ),
                  child: GLCard(
                    color: i.isEven ? Palette.blush : Palette.lime,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            TagChip(
                              Fmt.shortDate(w.entry.dayKey),
                              icon: PhosphorIconsFill.trophy,
                            ),
                            const Spacer(),
                            if (w.entry.mood != null)
                              Text(
                                w.entry.mood!,
                                style: const TextStyle(fontSize: 22),
                              ),
                          ],
                        ),
                        const SizedBox(height: Space.sm),
                        Expanded(
                          child: Text(
                            w.entry.body,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.subtitle.copyWith(
                              color: Palette.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        heading('Share your month'),
        Center(
          child: RepaintBoundary(
            key: cardKey,
            child: ShareCard(data: d),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.lg,
            Space.gutter,
            0,
          ),
          child: PillButton(
            label: 'Share card',
            icon: PhosphorIconsBold.shareNetwork,
            expand: true,
            loading: sharing,
            background: Palette.white,
            foreground: Palette.ink,
            onPressed: onShare,
          ),
        ),
      ],
    );
  }
}

/// 4:5 card rendered to a PNG for sharing (1080×1350 at 3×).
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.data});

  final RecapData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    Widget stat(String value, String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: Radii.pillR),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: value,
              style: AppText.subtitle.copyWith(
                color: Palette.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: ' $label',
              style: AppText.caption.copyWith(
                color: Palette.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    return MediaQuery.withNoTextScaling(
      child: Container(
        width: 320,
        height: 400,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: Palette.ink,
          borderRadius: Radii.heroR,
        ),
        child: Stack(
          children: [
            const Positioned(
              right: -24,
              bottom: 64,
              child: AppImage(AppAssets.recapMountain, width: 190),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Palette.lime,
                          shape: BoxShape.circle,
                        ),
                        child: const AppImage(AppAssets.splashLogo),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'GROWTH LOG · ${Fmt.monthYear(d.month).toUpperCase()}',
                        style: AppText.caption.copyWith(
                          color: Palette.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Look how\nfar I\'ve',
                    style: AppText.display.copyWith(
                      color: Palette.white,
                      fontSize: 38,
                      height: 0.95,
                    ),
                  ),
                  Text(
                    'come.',
                    style: AppText.displayItalic.copyWith(
                      color: Palette.lime,
                      fontSize: 38,
                      height: 1,
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      stat(Fmt.hours(d.seconds), 'hours', Palette.lime),
                      stat(
                        '${d.winCount}',
                        d.winCount == 1 ? 'win' : 'wins',
                        Palette.blush,
                      ),
                      stat('${d.gratitudeCount}', 'thank-yous', Palette.butter),
                      stat('${d.activeDays}', 'active days', Palette.lavender),
                    ],
                  ),
                  if (d.topSkill != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Most practised: ${d.topSkill!.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        color: Palette.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
