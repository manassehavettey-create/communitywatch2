import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/favorites.dart';
import '../../app/providers.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import 'recent.dart';

/// Bottom sheet to choose a player (used by comparison).
Future<SearchHit?> pickPlayer(BuildContext context, {required String title}) =>
    showModalBottomSheet<SearchHit>(context: context, isScrollControlled: true, builder: (_) => _PlayerPicker(title: title));

class _PlayerPicker extends ConsumerStatefulWidget {
  const _PlayerPicker({required this.title});
  final String title;
  @override
  ConsumerState<_PlayerPicker> createState() => _PlayerPickerState();
}

class _PlayerPickerState extends ConsumerState<_PlayerPicker> {
  String _q = '';
  Timer? _debounce;
  List<SearchHit> _results = const [];
  bool _loading = false;
  Object? _error;

  void _onChanged(String v) {
    setState(() => _q = v.trim());
    _debounce?.cancel();
    if (_q.length < 3) return;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _loading = true);
      try {
        final r = await ref.read(repositoryProvider).searchPlayers(_q);
        if (mounted) setState(() => (_results = r.data, _error = null));
      } catch (e) {
        if (mounted) setState(() => _error = e);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final followed = ref.watch(activeFavoritesProvider).where((f) => f.kind == FavKind.player).map((f) => SearchHit(kind: SearchKind.player, id: f.id, title: f.name, subtitle: f.subtitle, image: f.image));
    final recent = ref.watch(recentProvider).where((h) => h.kind == SearchKind.player);
    final suggestions = {for (final h in [...followed, ...recent]) h.id: h}.values.toList();
    final list = _q.length >= 3 ? _results : suggestions;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: Space.gutter), child: Align(alignment: Alignment.centerLeft, child: Text(widget.title, style: context.text.headlineSmall))),
        Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: TextField(autofocus: true, onChanged: _onChanged, decoration: const InputDecoration(hintText: 'Search players (3+ letters)', prefixIcon: Icon(Icons.search_rounded))),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null) Padding(padding: const EdgeInsets.all(Space.md), child: ErrorState(error: _error!, compact: true)),
        if (_q.length < 3 && suggestions.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: Space.gutter), child: Align(alignment: Alignment.centerLeft, child: Overline('Following & recent'))),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) => ListTile(
              leading: PlayerAvatar(name: list[i].title, photo: list[i].image, size: 40),
              title: Text(list[i].title, style: AppType.body(15, weight: 600, color: c.text)),
              subtitle: list[i].subtitle == null ? null : Text(list[i].subtitle!, style: AppType.body(12.5, color: c.textMuted)),
              onTap: () => Navigator.pop(context, list[i]),
            ),
          ),
        ),
      ]),
    );
  }
}
