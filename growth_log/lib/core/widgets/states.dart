import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../theme/phosphor_icons.dart';
import '../theme/tokens.dart';
import 'app_image.dart';
import 'buttons.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.image,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String image;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppImage(
            image,
            width: compact ? 160 : 240,
            height: compact ? 120 : 180,
          ),
          const SizedBox(height: Space.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleLarge,
          ),
          const SizedBox(height: Space.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: context.gl.muted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Space.lg),
            PillButton(
              label: actionLabel!,
              onPressed: onAction,
              trailingArrow: true,
            ),
          ],
        ],
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.height = 200});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: context.gl.text,
            semanticsLabel: 'Loading',
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsRegular.warning, size: 40, color: context.gl.muted),
          const SizedBox(height: Space.sm),
          Text('Something went wrong', style: context.text.titleMedium),
          const SizedBox(height: Space.xxs),
          Text(
            friendlyError(error),
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: Space.md),
            PillButton(
              label: 'Try again',
              style: PillStyle.outline,
              height: 46,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

String friendlyError(Object error) {
  final text = error.toString();
  if (text.startsWith('Exception: ')) return text.substring(11);
  if (text.length > 160) return 'An unexpected error occurred.';
  return text;
}

/// Renders an [AsyncValue] with the shared loading/error states.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loadingHeight = 200,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final double loadingHeight;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => LoadingState(height: loadingHeight),
      error: (e, _) => ErrorState(error: e, onRetry: onRetry),
    );
  }
}
