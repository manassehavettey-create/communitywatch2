# Growth Log — Design System

Extracted from the five UI references (Paytin finance app, "Discover / Activities / Event details",
Strut, ronasit "Daily challenge", and the newlife/CoinCraft onboarding set). The shared DNA:
**flat colour-block cards on a light neutral canvas, near-black ink for contrast, pills everywhere,
a floating dark navigation dock, and heavy editorial type mixed with a light italic.**

All tokens live in `lib/core/theme/` — `tokens.dart` (raw values) and `app_theme.dart`
(`ThemeData`, the `GLColors` light/dark extension and the `AppText` type scale).
Nothing in the UI uses default Material colours or type.

![All screens](docs/screens.png)

## Colour

| Token | Hex | Source | Role |
|---|---|---|---|
| `lime` | `#C8EC64` | Paytin | Primary accent: hero cards, CTAs, active pills, chart highlight |
| `limeSoft` | `#EBFBD2` | Paytin | Quiet fills (goal card) |
| `limeDeep` | `#9CC23A` | derived | Chart highlight on light surfaces |
| `ink` | `#0E101C` | ronasit dock | Text, dark cards, dock, primary buttons |
| `inkCard` | `#1B2121` | Paytin balance card | Dark stat cards, chart card |
| `canvas` | `#F5F5F2` | all | Light background |
| `cream` | `#FAF3E6` | Activities | Illustration neutrals |
| `lavender` | `#B6A3FF` | ronasit | Skill colour, practice streak |
| `butter` | `#F4DD7D` | Discover | Skill colour, **Gratitude** entries |
| `apricot` | `#F7CC7E` | ronasit | Skill colour, journal streak |
| `sky` | `#BCC9EC` | Activities | Skill colour |
| `blush` | `#F2B1DC` | Event details | Skill colour, **Win** entries |
| `sage` | `#AEBE91` | Events with friends | Skill colour |
| `electric` | `#012AFE` | Strut | Level-up, recap and onboarding step 3 only |
| `danger` | `#D9404A` | derived | Destructive actions |

**Dark mode** (derived): canvas `#0B0C10`, surface `#16181D`, card `#1F2127`, hairline `#2A2D35`,
muted text `#9A9CA6`. Lime and the pastels are unchanged; text on any pastel card is always ink,
so contrast holds in both modes. The dock stays dark in both themes.

## Typography

Both fonts are bundled (OFL) — no network needed.

| Style | Font | Size / weight | Use |
|---|---|---|---|
| `display` | Archivo Black | 44 / 900, line 1.0, −1.2 tracking | Screen titles, big numbers |
| `displayItalic` | Archivo Light Italic | 44 / 300 | Second half of titles: "Skills *in the making*" |
| `headline` | Urbanist | 28 / 700 | Sheet titles |
| `title` | Urbanist | 20 / 600 | Section headers, card titles |
| `subtitle` | Urbanist | 16 / 600 | Entry text, list titles |
| `body` | Urbanist | 15 / 500 | Body copy |
| `caption` | Urbanist | 12 / 500, +0.2 tracking | Labels, metadata |
| `numeral` | Urbanist | 32 / 700, tabular figures | Stats |

Pattern: **bold word + light italic word**, e.g. "Every hour *counts.*", "The good *stuff*".
Uppercase Archivo Black with tight leading ("LOOK HOW FAR YOU'VE COME.") is reserved for
the electric-blue celebration screens, echoing Strut.

## Shape, spacing, depth

- **Radii:** pills `999` · small cards `20` · cards `28` · hero cards `32` · dock `36`.
- **Spacing scale:** 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48. Screen gutter **20**.
- **Shadows:** essentially none — the look is flat blocks. The only shadow is under the
  floating dock (`0 12 24 rgba(0,0,0,.18)`). Circle buttons use a 1px hairline instead.

## Components (`lib/core/widgets/`)

| Component | Reference | Notes |
|---|---|---|
| `PillButton` | "Start →", "Get Started" | Ink / lime / outline / surface styles, optional arrow bubble, loading state |
| `CircleIconButton` | toolbar circles | 44px, hairline border |
| `ArrowCircleButton` | Paytin "Let's start ↗" | Onboarding next |
| `GLCard` | every colour card | Flat fill, `Pressable` scale on tap |
| `SegmentedPills` | "Today / Weekly / Monthly / Yearly" | Separate pills, filled selection |
| `DayStrip` | ronasit date capsules | Activity dot, selected day in ink |
| `ProgressRing`, `ProgressBar` | — | Spring in on first build |
| `HoursBarChart` | Paytin statistics | Rounded bars on faint full-height tracks, tap for tooltip |
| `FloatingDock` | ronasit / Event details | Dark pill, white active circle, raised lime **＋** |
| Stacked entry cards | "Events with Friends" | Today's log on Home fans out like a deck |
| `DisplayTitle` | "Activities *just for your taste*" | Bold + light-italic headline |

## Icons

Phosphor, regular weight for UI and fill weight for active/emphasis, vendored as fonts in
`assets/fonts/phosphor` (MIT). Skill icons are 45 Phosphor glyphs recoloured per skill.

## Illustration

Two styles, one palette (see `ASSETS.md`):

- **Soft 3D clay** — level badges, trophy, flame, hero shapes, recap mountain, empty states.
- **Flat bold characters** — onboarding and level-up only.

Artwork is processed by `tool/process_assets.py` (background removal that keeps contact shadows
as translucent ink, then exact sizing).

## Motion & haptics

- Press: scale to 0.97 (`Pressable`), 160 ms.
- Lists: fade + 6% slide-up, staggered 40 ms per item (`FadeSlideIn`).
- Rings/bars: animate from zero on first appearance (1 s / 520 ms, ease-out-cubic).
- Level-up: fade + scale-in route, staggered elastic entrances, confetti in palette colours.
- Timer: slow pulsing rings and an orbiting dot while recording.
- All motion respects "reduce motion" (`MediaQuery.disableAnimations`).
- Haptics: selection click on taps, medium on saves/starts, double pulse on level-up.
  Can be turned off in Settings.

## Accessibility

- Every tappable card/button has a semantic label; decorative images are excluded.
- Text scaling honoured up to 1.4× (layouts with display type are clamped beyond that).
- Colour is never the only signal: entry types have icons + labels, milestones have lock/check icons.
