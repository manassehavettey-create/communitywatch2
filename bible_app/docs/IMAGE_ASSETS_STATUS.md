# Image assets: status

Received on 28 September 2026. The generator returned every image as a
768×1376 JPEG and painted a checkerboard where transparency was requested.
`tools/images/process_assets.py` fixes both, reading from the originals in
`design/raw/`:

- It crops each image to its subject and resizes it to the target size.
- It removes the painted checkerboard by flood-filling neutral grey from the
  image edges. Where a dark checkerboard also removed the outline, it redraws
  the ink line.
- It clears leftover specks.

Every result was checked on both the paper and night backgrounds.

| Asset | Status |
|---|---|
| brand/app_icon.png | ✅ square crop, 1024 |
| brand/app_icon_foreground.png | ✅ transparent, 1024 |
| brand/splash_mark.png | ✅ transparent, 1152 |
| onboarding/onboarding_read, _keep, _pray, _rhythm | ✅ 960×1200 |
| onboarding/welcome_reader | ✅ extra image, used on the sign-in screen |
| empty/empty_journal, _prayer, _search, _notes, _saved, offline_state | ✅ transparent, 800 |
| empty/empty_plans | Drawn in code (shape illustration) |
| cards/card_botanical_corner, card_dusk | ✅ 1080×1920 |
| cards/card_paper_grain, _blocks, _forest_night, _night_ink, _linen, _wildflowers | Drawn in code as templates |
| textures/grain_tile | Drawn in code: the upload was a painted checkerboard, so there was nothing to extract |

No more generated images are needed. Anything new is drawn in code.
