import 'package:flutter/material.dart';

/// Paths of bundled illustrations (see ASSETS.md).
abstract final class AppAssets {
  static const _i = 'assets/images';
  static const splashLogo = '$_i/brand/splash_logo.png';
  static const onboardingGrow = '$_i/onboarding/onboarding_grow.png';
  static const onboardingGratitude = '$_i/onboarding/onboarding_gratitude.png';
  static const levelUpHero = '$_i/onboarding/levelup_hero.png';
  static const trophy = '$_i/illustrations/trophy.png';
  static const streakFlame = '$_i/illustrations/streak_flame.png';
  static const heroShapes = '$_i/illustrations/hero_shapes.png';
  static const recapMountain = '$_i/illustrations/recap_mountain.png';
  static const emptySkills = '$_i/empty/empty_skills.png';
  static const emptyLog = '$_i/empty/empty_log.png';
  static const emptyInsights = '$_i/empty/empty_insights.png';
  static const emptySearch = '$_i/empty/empty_search.png';

  static const all = [
    splashLogo,
    onboardingGrow,
    onboardingGratitude,
    levelUpHero,
    trophy,
    streakFlame,
    heroShapes,
    recapMountain,
    emptySkills,
    emptyLog,
    emptyInsights,
    emptySearch,
  ];
}

/// Bundled illustration. Decodes at display size to keep memory low; if an
/// asset is ever missing it collapses to empty space rather than crashing.
class AppImage extends StatelessWidget {
  const AppImage(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.semanticLabel,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = width == null ? null : (width! * dpr).round();
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      cacheWidth: cacheW,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => SizedBox(width: width, height: height),
    );
  }
}
