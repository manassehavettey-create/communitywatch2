import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/favorites.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// Star toggle with a springy pop. Following immediately affects Home,
/// ordering, search suggestions and notifications.
class FollowButton extends ConsumerWidget {
  const FollowButton({super.key, required this.favorite, this.size = 44});
  final Favorite favorite;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    ref.watch(favoritesProvider);
    final on = ref.read(favoritesProvider.notifier).isFollowing(favorite.kind, favorite.id);
    return Pressable(
      semanticLabel: on ? 'Unfollow ${favorite.name}' : 'Follow ${favorite.name}',
      haptic: false,
      onTap: () {
        HapticFeedback.mediumImpact();
        ref.read(favoritesProvider.notifier).toggle(favorite);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(on ? 'Unfollowed ${favorite.name}' : 'Following ${favorite.name} — alerts on'), duration: const Duration(seconds: 2)));
      },
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.emphasized,
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: on ? c.accent : c.surface2, border: Border.all(color: on ? c.accent : c.hairline)),
        child: AnimatedSwitcher(
          duration: Motion.slow,
          switchInCurve: Motion.spring,
          transitionBuilder: (child, a) => ScaleTransition(scale: a, child: RotationTransition(turns: Tween(begin: -0.15, end: 0.0).animate(a), child: child)),
          child: Icon(on ? Icons.star_rounded : Icons.star_outline_rounded, key: ValueKey(on), size: size * 0.5, color: on ? c.onAccent : c.text),
        ),
      ),
    );
  }
}
