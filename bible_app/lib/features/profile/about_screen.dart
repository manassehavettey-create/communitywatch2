import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/layout.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final catalog = ref.watch(catalogProvider).value;
    TextStyle body = AppType.bodySmall.copyWith(color: p.inkSoft);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.x14,
          ),
          children: [
            ScreenHeader(
              title: 'About',
              leading: CircleIconButton(
                icon: PhosphorIconsBold.caretLeft,
                tooltip: 'Back',
                onPressed: () => context.pop(),
              ),
            ),
            const SectionHeader(title: 'Scripture'),
            for (final t in catalog?.available ?? const [])
              Padding(
                padding: const EdgeInsets.only(bottom: Space.x3),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t.name} (${t.abbreviation})',
                        style: AppType.titleS.copyWith(color: p.ink),
                      ),
                      if (t.edition.isNotEmpty) Text(t.edition, style: body),
                      const SizedBox(height: 4),
                      Text(
                        t.licenseNote.isEmpty ? t.license : t.licenseNote,
                        style: body,
                      ),
                    ],
                  ),
                ),
              ),
            Text(
              'Bible texts are bundled in the app so reading works without a connection. '
              'Other translations will be added only with a licence that allows it.',
              style: body,
            ),
            const SectionHeader(title: 'Typefaces'),
            Text(
              'Fraunces, Urbanist, Literata, Source Serif 4, Atkinson Hyperlegible and Caveat, '
              'all under the SIL Open Font License 1.1.',
              style: body,
            ),
            const SectionHeader(title: 'Icons & illustration'),
            Text(
              'Icons by Phosphor (MIT licence). Illustrations made for this app.',
              style: body,
            ),
            const SizedBox(height: Space.x6),
            TextButton(
              onPressed: () =>
                  showLicensePage(context: context, applicationName: 'Bible'),
              child: const Text('Open-source licences'),
            ),
          ],
        ),
      ),
    );
  }
}
