# BODYFORGE design system

Extracted from the five UI references supplied for the project. Code lives in
`lib/core/theme/` (tokens, colours, type) and `lib/core/motion/motion.dart` (motion).
Every screen uses these — no default Material styling.

## Direction

- **Dark theme (default, the hero look)** — refs 1–3: near-black canvas, colour-blocked lime and
  lavender cards, oversized numerals, very rounded shapes, floating pill navigation.
- **Light theme** — ref 5 (+ the pastel card tints of ref 4): off-white canvas, white cards with
  one soft shadow, pastels for categories. Ref 4's starbursts and full-bleed candy backgrounds
  were deliberately left out — too playful for "premium, bold, athletic".
- Lime + lavender are the brand accents in both themes. Text on lime/lavender is always ink.

## Colour

| Role | Dark | Light |
|------|------|-------|
| Canvas | `#141416` | `#F3F3F0` |
| Surface | `#1F1F23` | `#FFFFFF` |
| Surface raised | `#2A2A30` | `#EDEDE8` |
| Outline | `#3A3A42` | `#DCDCD5` |
| Text / muted / faint | `#F5F5F2` / `#A9A9B2` / `#6E6E78` | `#111113` / `#5E5E66` / `#9A9AA2` |
| **Primary — Forge Lime** | `#D4F55A` | `#C6EA3E` |
| **Secondary — Lavender** | `#A99BF7` | `#9C8CF2` |
| Tertiary — Lilac | `#E3B8F5` | `#F0D4FA` |
| Ember (streaks, PRs, calories) | `#FF9A3C` | `#F5892A` |
| Sheet (player bottom sheet, light cards on dark) | `#F7F7F2` | `#FFFFFF` |
| Pastels | sky `#BFE3F0` · mint `#CFE8B8` · peach `#F7CBA9` · coral `#F4A39A` · butter `#F6DE82` | |
| Success / warning / danger | `#7FE3A0` / `#FFC857` / `#FF6B6B` | `#2FB86A` / `#E0A21B` / `#E5484D` |

Usage rules
- One accent-filled card per viewport region; neighbours use surface or the other accent.
- Colour blocks carry meaning: **lime = today / action / strength**, **lavender = plan / habit**,
  **ember = records & streaks**, pastels = nutrition & recovery categories.

## Typography

- **Sora** (display, numerals): 700 for headlines, 600 for big numbers. Tight negative tracking.
- **Manrope** (body, labels): 500 body, 700 labels/buttons.
- Numerals use tabular figures everywhere they tick (timers, counters).
- Overlines (`TODAY'S MISSION`) are Manrope 800, 11 px, +1.6 tracking.

Scale: display 56/44/34 · headline 28/24/20 · title 18/16/14 · body 16/14/12 · label 15/13/11.

## Shape & spacing

- Spacing: 4-pt scale — 4, 8, 12, 16, 20, 24, 32, 40. Page gutter 20.
- Radii: cards 28, large cards 32, tiles 20, small 12, chips/buttons fully rounded.
- Icon buttons: 48 / 56 circles (white on dark, ink on light).
- Shadows: none on dark (separation by colour); one soft `0 8 24` shadow on light.

## Signature components (`lib/core/widgets/`)

| Component | Reference | Notes |
|-----------|-----------|-------|
| `ForgeNavBar` | refs 1–2 | Floating pill, circular items, active item fills lavender, icon morphs outline→filled. |
| `NotchedCard` | ref 1 | Card with a circular cut-out (top-right) housing a round action button. |
| `StackedCards` handle notch | ref 1 | Small pill "handle" joining stacked exercise cards. |
| `ConcentricRings` | refs 1–2 | Painted ring texture inside accent cards. |
| `DateStrip` | refs 1, 3 | Week strip, selected day = lime circle, status dot below. |
| `PillChip` | refs 1–2 | Selected = sheet fill + ink text; unselected = outline. |
| `RingProgress` | ref 3 | Gapped arc, optional lime→ember gradient. |
| `SwipeToStart` | ref 1 | "Start workout >>>" slider. |
| Player sheet | refs 1–2 | Elapsed · giant timer · Set x/y, "Next" pill with thumbnail. |
| Tilted list cards | ref 3 | Slight rotation on history cards. |

## Imagery

Photographic cutouts (Ghanaian / West African athletes "Kofi" and "Ama", objects, food) on
transparent backgrounds, placed on accent cards and allowed to overflow the card top edge.
Prompts: `docs/IMAGE_ASSETS.md`. Missing images fall back to a painted, on-brand graphic.

## Motion (`Motion`)

- Durations: instant 90 · fast 160 · medium 280 · slow 460 · slower 720 · hero 520 ·
  count-up 1100 · chart draw 900 · celebration 1800 ms.
- Curves: standard `easeOutCubic`, emphasized `(0.2,0,0,1)`, spring `easeOutBack`.
- Stagger: 55 ms per item, capped at 8 items.
- Press: scale to 0.96 + haptic selection click.
- Reduced motion (OS setting): durations go to zero, choreography becomes simple fades,
  particles are skipped, rings/charts appear at their final value.
