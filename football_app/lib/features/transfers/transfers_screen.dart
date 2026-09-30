import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/favorites.dart';
import '../../app/providers.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../player/player_screen.dart';

/// Transfers (spec §29). Confirmed transfers only from the provider; a
/// REPORTED section appears only if the active provider supplies rumours —
/// the two are never mixed.
class TransfersScreen extends ConsumerStatefulWidget {
  const TransfersScreen({super.key});
  @override
  ConsumerState<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends ConsumerState<TransfersScreen> {
  TeamRef? _team;

  Future<void> _pickTeam() async {
    final hit = await showModalBottomSheet<SearchHit>(context: context, isScrollControlled: true, builder: (_) => const _TeamPicker());
    if (hit != null) setState(() => _team = TeamRef(id: hit.id, name: hit.title, logo: hit.image));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final caps = ref.watch(capabilitiesProvider);
    final teams = ref.watch(activeFavoritesProvider).where((f) => f.kind == FavKind.team).map((f) => TeamRef(id: f.id, name: f.name, logo: f.image)).toList();
    final selected = _team ?? teams.firstOrNull;
    final chips = {for (final t in [...teams, ?_team]) t.id: t}.values.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Transfers')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 60),
        children: [
          Text('Latest confirmed transfers', style: context.text.headlineSmall),
          const SizedBox(height: 4),
          Row(children: [
            ProvenanceTag(ref.watch(repositoryProvider).isDemo ? Provenance.demo : Provenance.confirmed, compact: true, source: 'completed moves'),
          ]),
          const SizedBox(height: Space.md),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final t in chips) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChipPill(label: t.name, selected: selected?.id == t.id, onTap: () => setState(() => _team = t), leading: TeamCrest(team: t, size: 20))),
              ChoiceChipPill(label: 'Choose team', selected: false, onTap: _pickTeam, leading: Icon(Icons.add_rounded, size: 16, color: c.textMuted)),
            ]),
          ),
          const SizedBox(height: Space.md),
          if (selected == null)
            EmptyState(art: EmptyArt.favorites, title: 'Pick a team', message: 'Follow teams or choose one to see their confirmed arrivals and departures.', actionLabel: 'Choose team', onAction: _pickTeam, compact: true)
          else
            _TeamTransferList(team: selected),
          if (caps.reportedTransfers) ...[
            const SizedBox(height: Space.xl),
            Row(children: [Expanded(child: Text('Reported & rumoured', style: context.text.headlineSmall)), const ProvenanceTag(Provenance.reported, compact: true)]),
            const SizedBox(height: 6),
            Text('Not confirmed. Shown separately and never as completed transfers.', style: AppType.body(12.5, color: c.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _TeamTransferList extends ConsumerWidget {
  const _TeamTransferList({required this.team});
  final TeamRef team;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teamTransfersProvider(team.id));
    return switch (async) {
      AsyncValue(:final value?) when value.data.isEmpty => EmptyState(art: EmptyArt.search, title: 'No transfers on record', message: '${team.name} have no confirmed transfers with the provider.', compact: true),
      AsyncValue(:final value?) => Column(children: [
          for (final (i, t) in value.data.take(25).indexed) TransferTile(transfer: t).animate(delay: Motion.staggerFor(i)).fadeIn(duration: Motion.base).slideY(begin: 0.1),
        ]),
      AsyncValue(:final error?) => ErrorState(error: error, compact: true, onRetry: () => ref.invalidate(teamTransfersProvider(team.id))),
      _ => const SkeletonList(count: 4, height: 64, padding: EdgeInsets.zero),
    };
  }
}

class _TeamPicker extends ConsumerStatefulWidget {
  const _TeamPicker();
  @override
  ConsumerState<_TeamPicker> createState() => _TeamPickerState();
}

class _TeamPickerState extends ConsumerState<_TeamPicker> {
  List<SearchHit> _hits = const [];
  bool _loading = false;
  Object? _error;

  Future<void> _search(String q) async {
    if (q.trim().length < 3) return;
    setState(() => _loading = true);
    try {
      final r = await ref.read(repositoryProvider).searchTeams(q.trim());
      if (mounted) setState(() => (_hits = r.data, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: TextField(autofocus: true, textInputAction: TextInputAction.search, onSubmitted: _search, onChanged: (v) => v.trim().length >= 3 ? _search(v) : null, decoration: const InputDecoration(hintText: 'Search teams', prefixIcon: Icon(Icons.search_rounded))),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null) ErrorState(error: _error!, compact: true),
        Expanded(
          child: ListView(children: [
            for (final h in _hits)
              ListTile(
                leading: TeamCrest(team: TeamRef(id: h.id, name: h.title, logo: h.image), size: 32),
                title: Text(h.title, style: AppType.body(15, weight: 600, color: c.text)),
                subtitle: h.subtitle == null ? null : Text(h.subtitle!, style: AppType.body(12.5, color: c.textMuted)),
                onTap: () => Navigator.pop(context, h),
              ),
          ]),
        ),
      ]),
    );
  }
}
