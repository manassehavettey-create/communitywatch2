# Design language

An original design for a Bible app, adapted from four non-Bible references:

1. A notes app with colour-blocked pastel cards on black or warm paper.
2. A reading app with warm paper, a serif display face and a handwritten
   accent.
3. A set of bold onboarding screens.
4. An events app with a floating black pill tab bar and scalloped badges.

What we take from them is the feel: calm paper, confident type, flat pastel
cards, black as the anchor colour, and playful but restrained shapes. We don't
copy any layout directly, and nothing here comes from existing Bible apps.

**Avoid:** gradients, gold, stained-glass or cross clip-art, drop-shadow
stacks, crowded dashboards, and more than one bright accent on a screen.

### Second set of references

Three more references were added later:

5. A running app with interlocking colour blocks joined by small tabs, huge
   tabular numerals and outline pill buttons.
6. A chat and saved-items app with folder-shaped collection cards,
   speech-bubble cards, grid paper and a floating white pill tab bar.
7. A mood tracker with pastel geometric shapes as illustration, stat tiles
   and a calendar of coloured day tiles.

They add these patterns, used sparingly:

- **Linked cards.** Two stacked cards can be joined by a small rounded tab,
  so they read as one unit. Home uses this for Verse of the Day above
  Continue Reading, and plans use it for today above tomorrow.
- **Folder cards.** Saved collections (Bookmarks, Highlights, Notes, Verses)
  are pastel folders with a tab on top.
- **Big numerals.** Stats use Urbanist 700 with tabular figures at 40–64 px:
  the streak, plan percentage and chapter counts.
- **Reading calendar.** The streak screen shows a month grid of rounded tiles
  tinted by how much was read that day.
- **Stat tiles.** Profile uses small pastel tiles, each with a label and one
  big number.
- **Shape illustrations.** Where no generated art exists, illustrations are
  drawn in code from pastel geometric shapes: circle, scallop, arch, blob and
  pill. They have no faces and no religious symbols.

## Principles

1. **Paper first.** Screens sit on warm paper, never on pure white. Scripture
   gets the most space and the quietest surface.
2. **Flat colour blocks.** Cards are solid pastel fields with ink text. There
   are no gradients, and depth comes from colour and overlap, not shadow.
3. **Big type, few words.** Headlines are oversized and wrap to two lines.
   Body copy stays short.
4. **Ink is the anchor.** Near-black carries primary actions: the tab bar, the
   main action button and primary buttons.
5. **One accent.** Tangerine appears at most once or twice per screen: the
   streak, the current day, the key call to action.

## Colour tokens

Hex values were sampled from the references and then tuned for contrast.

### Light (Paper)

| Token | Hex | Use |
|---|---|---|
| `paper` | `#F6F0E6` | App background |
| `paperDeep` | `#EDE5D6` | Grouped sections, input fills, inactive chips |
| `surface` | `#FBF8F2` | Sheets and dialogs on paper |
| `ink` | `#141414` | Primary text, tab bar, primary buttons |
| `inkSoft` | `#5E5A53` | Secondary text |
| `inkMute` | `#8F897E` | Tertiary text and captions |
| `line` | `#DCD5C8` | Hairlines and outlines |
| `tangerine` | `#F5620F` | The accent: fills, icons and large text only |
| `tangerineText` | `#B8470A` | Accent colour for small text (meets 4.5:1 on paper) |

### Card pastels

Every pastel carries ink text in both themes.

| Token | Hex | Default role |
|---|---|---|
| `coral` | `#EF845D` | Continue Reading |
| `butter` | `#F4D352` | Verse of the Day, highlights |
| `sage` | `#AAC385` | Plans, progress |
| `sky` | `#A1BDDD` | Prayer |
| `blush` | `#E9B4C8` | Journal |
| `cream` | `#F3E9CC` | Neutral cards and saved items |

### Dark (Night): designed for reading in bed

The Night theme is not an inverted light theme. The background is a warm
near-black, which avoids pure-black smearing on OLED screens and avoids
halation. Text is warm off-white at reduced contrast. Pastels keep their hue
but lose some luminance, so cards don't glare. The reader screen uses no
pastel fills at all.

| Token | Hex |
|---|---|
| `paper` | `#121110` |
| `paperDeep` | `#1B1A18` |
| `surface` | `#211F1C` |
| `ink` | `#ECE5D8` (main reading text, about 13:1) |
| `inkSoft` | `#B3AB9D` |
| `inkMute` | `#7C766C` |
| `line` | `#2E2B27` |
| `tangerine` | `#FF7A33` |
| Card pastels | `coral #D9785A`, `butter #D9BC4E`, `sage #93AC74`, `sky #8DA7C4`, `blush #CE9DB0`, `cream #CFC6AA` |

### Reader themes

The reader has its own background choice, independent of the app theme:

- **Paper:** `#F6F0E6` background, `#1E1C19` text.
- **Cream:** `#F3E9CC` background, `#2A261F` text.
- **Night:** `#121110` background, `#D9D2C5` text. The text is slightly dimmer
  than the app ink to cut glare.
- **Forest:** `#1F312B` background, `#E6E1D3` text. The deep green comes from
  reference 2.

### Highlight colours

Highlights are painted as a rounded background behind the text. In light
themes they use the pastel at 55% alpha. In dark themes they use the pastel at
28% alpha over the background, with a 2 px underline in the full pastel, so the
text stays readable. The five choices are `butter`, `coral`, `sage`, `sky` and
`blush`.

## Typography

All fonts are SIL OFL. They are bundled as files and never fetched at runtime,
so the app works offline.

| Role | Family | Notes |
|---|---|---|
| Display | **Fraunces** (variable, soft) | Screen titles, verse of the day, big chapter numbers. Weight 600, tight tracking (−2%). |
| UI | **Urbanist** | Everything interactive. 400/500/600/700; the light italic is used for display sub-lines ("just for today"). |
| Scripture (default) | **Literata** | Built for long-form reading; the default reader face. |
| Scripture options | Source Serif 4, Urbanist, Atkinson Hyperlegible | Available in the reader settings. |
| Hand accent | **Caveat** | Rarely: empty-state notes and a streak remark. Never for Scripture. |

### Type scale

The scale is in logical pixels and follows the system text scale.

| Style | Size / line height | Weight | Family |
|---|---|---|---|
| displayL | 44 / 46 | 600 | Fraunces |
| displayM | 34 / 38 | 600 | Fraunces |
| titleL | 24 / 30 | 700 | Urbanist |
| titleM | 19 / 24 | 700 | Urbanist |
| body | 16 / 24 | 500 | Urbanist |
| label | 14 / 18 | 600 | Urbanist |
| caption | 12 / 16 | 500 | Urbanist |
| scripture | 19 / 1.65× (adjustable from 15 to 30, line height 1.4 to 2.0) | 400 | Literata |
| verseNumber | 0.62× scripture size, raised | 600 | Urbanist in `inkMute` |

## Shape, spacing and elevation

- **Spacing:** 4-point base. Steps are 4, 8, 12, 16, 20, 24, 32, 40 and 56.
  Screen gutter 20. Gap between cards 12.
- **Radii:**
  - `xs` 8: highlight backgrounds.
  - `sm` 14: inputs and small tiles.
  - `md` 22: list cards.
  - `lg` 30: feature cards.
  - `xl` 36: bottom sheets.
  - `pill` 999: chips, buttons, tab bar and search.
- **Buttons:** primary buttons are ink pills 56 tall with paper text.
  Secondary buttons are 1.5 px ink outline pills. The round icon button is a
  44 px circle in `paperDeep`.
- **Elevation:** flat by default. There is one soft shadow for floating
  elements: the tab bar, the action button and the verse menu
  (`0 12 32 rgba(20,20,20,0.18)`). Dark mode uses no shadow; floating elements
  get a 1 px `line` border instead.
- **Stickers:** a scalloped 12-lobe badge and a soft blob, adapted from
  reference 4's organic shapes. Both are drawn in code (`CustomPainter`), not
  images. They're used for the streak count, the date and plan-complete
  moments, and nowhere else.

## Icons

Phosphor icons in the Regular weight (1.5 px stroke) for UI, and Fill for
active tab states. No emoji, no multi-colour icons, and no religious clip-art.

## Navigation

A floating ink pill tab bar sits 12 px above the bottom inset. It has five
icons: Home, Bible, Plans, Prayer and Profile. The active tab is a paper circle
with an ink icon, and the pill between tabs slides with the spring below.
Journal is reached from Home and Prayer, Saved from Home and Profile, and
Search from Bible and Home.

## Motion

Motion tokens live in `lib/core/motion/`.

| Token | Value | Use |
|---|---|---|
| `instant` | 90 ms | Taps, selection tint |
| `fast` | 160 ms | Chip and toggle changes |
| `base` | 240 ms | Card and sheet content changes |
| `slow` | 360 ms | Page transitions and reveals |
| `celebrate` | 900 ms | Plan complete and streak milestones |
| `standard` curve | `Cubic(0.2, 0, 0, 1)` | Most transitions |
| `exit` curve | `Cubic(0.3, 0, 1, 1)` | Things leaving the screen |
| `spring` | stiffness 420, damping 34 | Tab indicator, bottom sheets, card fan |
| `stagger` | 45 ms per item, capped at 8 items | List and card reveals |

- **Card entry:** fade from 0 to 1 and move up 16 px to 0 with a slight scale
  (0.98 to 1).
- **Progress:** progress rings and bars fill over `slow` with the `standard`
  curve and count their numbers up at the same time.
- **Verse selection:** the tint fades in over `instant`, a light haptic plays,
  and the verse menu rises on the `spring`.
- **Reduce motion:** when the system asks for reduced motion, movement, scale
  and springs are removed. Only opacity changes remain (120 ms), and
  celebrations become a static state.

## Voice

Warm, plain and brief. Examples: "Pick up where you left off." "Nothing saved
yet — tap a verse to keep it." There is no gamified language: no "Level up!",
"Crushing it!" or points.
