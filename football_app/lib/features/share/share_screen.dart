import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import 'share_cards.dart';

enum ShareKind { result, moment, player, playerInMatch, table }

class ShareRequest {
  const ShareRequest._(this.kind, {this.matchId, this.playerId, this.season, this.leagueId});
  factory ShareRequest.match(int matchId, {bool moment = false}) => ShareRequest._(moment ? ShareKind.moment : ShareKind.result, matchId: matchId);
  factory ShareRequest.player(int playerId, int season) => ShareRequest._(ShareKind.player, playerId: playerId, season: season);
  factory ShareRequest.playerInMatch(int matchId, int playerId) => ShareRequest._(ShareKind.playerInMatch, matchId: matchId, playerId: playerId);
  factory ShareRequest.table(int leagueId) => ShareRequest._(ShareKind.table, leagueId: leagueId);
  final ShareKind kind;
  final int? matchId;
  final int? playerId;
  final int? season;
  final int? leagueId;
}

enum CardFormat {
  post('Post 4:5', 4 / 5),
  story('Story 9:16', 9 / 16),
  square('Square 1:1', 1);

  const CardFormat(this.label, this.ratio);
  final String label;
  final double ratio;
}

/// Share graphics (spec §33): generated from live data, previewed with a
/// build-in animation, exported as a PNG through the system share sheet
/// (WhatsApp, Instagram, Facebook, X, …).
class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({super.key, this.request});
  final ShareRequest? request;
  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final _boundary = GlobalKey();
  late ShareKind _kind = widget.request?.kind ?? ShareKind.result;
  CardFormat _format = CardFormat.post;
  bool _busy = false;
  int _shine = 0;

  Future<void> _share(String caption) async {
    setState(() {
      _busy = true;
      _shine++;
    });
    HapticFeedback.mediumImpact();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      final ro = _boundary.currentContext?.findRenderObject();
      if (ro is! RenderRepaintBoundary) return;
      // Export at 1080px wide regardless of screen size.
      final ratio = 1080 / ro.size.width;
      final image = await ro.toImage(pixelRatio: ratio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes.buffer.asUint8List(), mimeType: 'image/png', name: 'touchline-${DateTime.now().millisecondsSinceEpoch}.png')],
        text: caption,
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = widget.request;
    if (r == null) return Scaffold(appBar: AppBar(), body: const Center(child: NotProvided('Nothing to share')));
    final kinds = switch (r.kind) {
      ShareKind.result || ShareKind.moment => [ShareKind.result, ShareKind.moment],
      _ => [r.kind],
    };

    final (AsyncValue<Widget> card, String caption) = _buildCard(r);

    return Scaffold(
      appBar: AppBar(title: const Text('Share')),
      body: Column(children: [
        if (kinds.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Row(children: [
              for (final k in kinds) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChipPill(label: k == ShareKind.result ? 'Result' : 'Match moment', selected: _kind == k, onTap: () => setState(() => _kind = k))),
            ]),
          ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.gutter),
              child: AspectRatio(
                aspectRatio: _format.ratio,
                child: switch (card) {
                  AsyncValue(:final value?) => RepaintBoundary(
                      key: _boundary,
                      child: ClipRRect(borderRadius: BorderRadius.circular(_busy ? 0 : Radii.xl), child: value),
                    )
                        .animate(key: ValueKey('$_kind-$_format'))
                        .fadeIn(duration: Motion.slow)
                        .scale(begin: const Offset(0.9, 0.9), curve: Motion.spring, duration: Motion.slow)
                        .animate(key: ValueKey('shine$_shine'), autoPlay: _shine > 0)
                        .shimmer(duration: 700.ms, color: Colors.white.withValues(alpha: 0.35))
                        .scaleXY(end: 1.02, duration: 220.ms, curve: Curves.easeOut)
                        .then()
                        .scaleXY(end: 1 / 1.02, duration: 260.ms, curve: Motion.spring),
                  AsyncValue(:final error?) => ErrorState(error: error, compact: true),
                  _ => const Skeleton(radius: Radii.xl, height: double.infinity),
                },
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final f in CardFormat.values) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChipPill(label: f.label, selected: _format == f, onTap: () => setState(() => _format = f))),
              ]),
              const SizedBox(height: Space.md),
              PillButton(label: 'Share image', icon: Icons.ios_share_rounded, expand: true, busy: _busy, onTap: card.hasValue ? () => _share(caption) : null),
              const SizedBox(height: 8),
              Text('Opens your share sheet — WhatsApp, Instagram, Facebook, X and more.', style: AppType.body(12, color: c.textFaint), textAlign: TextAlign.center),
            ]),
          ),
        ),
      ]),
    );
  }

  (AsyncValue<Widget>, String) _buildCard(ShareRequest r) {
    final demo = ref.watch(repositoryProvider).isDemo;
    switch (_kind) {
      case ShareKind.result:
      case ShareKind.moment:
        final m = ref.watch(matchProvider(r.matchId!));
        final match = m.value?.data;
        final caption = match == null ? '' : '${match.home.name} ${match.homeGoals ?? 0}–${match.awayGoals ?? 0} ${match.away.name} · ${match.league.name}';
        return (m.whenData((f) => _kind == ShareKind.moment && f.data.goals.isNotEmpty ? MomentCard(match: f.data, format: _format, demo: demo) : ResultCard(match: f.data, format: _format, demo: demo)), caption);
      case ShareKind.playerInMatch:
        final m = ref.watch(matchProvider(r.matchId!));
        return (
          m.whenData((f) {
            final line = f.data.players?.where((p) => p.player.id == r.playerId).firstOrNull;
            if (line == null) throw const DataException(DataErrorKind.notFound, 'No stats for this player in the match.');
            final team = f.data.teamById(line.teamId) ?? f.data.home;
            return PlayerCard(name: line.player.name, photo: line.player.photo, team: team, stats: line.stats, context: '${f.data.home.short} ${f.data.homeGoals}–${f.data.awayGoals} ${f.data.away.short} · ${shortDate(f.data.kickoff)}', format: _format, demo: demo);
          }),
          'Player card · Touchline',
        );
      case ShareKind.player:
        final p = ref.watch(playerProvider((r.playerId!, r.season!)));
        return (
          p.whenData((f) => PlayerCard(name: f.data.profile.name, photo: f.data.profile.photo, team: f.data.mainTeam ?? const TeamRef(id: 0, name: ''), stats: f.data.total, context: 'Season ${seasonLabel(r.season!)}', format: _format, demo: demo)),
          '${p.value?.data.profile.name ?? 'Player'} · Season ${seasonLabel(r.season!)}',
        );
      case ShareKind.table:
        final t = ref.watch(standingsProvider(r.leagueId!));
        return (
          t.whenData((f) {
            if (f.data == null || f.data!.groups.isEmpty) throw const DataException(DataErrorKind.notFound, 'No table for this competition.');
            return TableCard(table: f.data!, format: _format, demo: demo);
          }),
          '${t.value?.data?.league.name ?? 'League'} table · Touchline',
        );
    }
  }
}
