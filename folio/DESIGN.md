# Folio — design language

Folio adapts the visual language of the reference shots (flat colour-block
cards, ink-black pill controls, oversized grotesk numerals, warm paper
backgrounds, soft pastel accents) into a calm reading product. No branding,
logos or layouts are copied; only the palette logic, type contrast, shapes
and motion feel.

All tokens live in `lib/core/theme/`. Never hard-code a colour, radius,
duration or text style in a widget — pull it from the tokens.

## Colour

| Role | Light | Dark (night) | Notes |
|---|---|---|---|
| `paper` (scaffold) | `#F6F1E7` | `#121110` | Warm, never pure white / pure black |
| `surface` (cards) | `#FFFDF8` | `#1C1A18` | |
| `surfaceMuted` | `#EDE6D8` | `#262320` | Chips, inputs, skeletons |
| `hairline` | `#E2DACB` | `#34302B` | 1 px dividers and outlines |
| `ink` (text, primary CTA) | `#161514` | `#EDE6D8` | Primary buttons are ink pills |
| `inkMuted` | `#6B665E` | `#9D968A` | Secondary text |
| `onInk` | `#F6F1E7` | `#121110` | Text on ink pills |
| `lavender` (brand) | `#A58BF7` | `#B6A2F5` | Focus, selection, links |
| `lime` (progress) | `#D6F26B` | `#C9E26A` | Progress bars, streak, goals |

Shelf pastels — collections, stat tiles, highlight colours. In dark mode they
are shown at reduced saturation on dark surfaces, with ink text kept dark on
top of them for contrast.

| Name | Hex | Tint (card bg) |
|---|---|---|
| butter | `#F8D96A` | `#FCF0C4` |
| peach | `#F9A77E` | `#FDE3D5` |
| mint | `#B5EBCB` | `#DDF5E6` |
| sky | `#A9CBF2` | `#DCE9FA` |
| lilac | `#CDB8FA` | `#E7DEFD` |
| rose | `#F7C3D6` | `#FBE3EC` |

Highlights use butter, mint, sky, rose and lilac at 42 % opacity over the page
(multiply blend), so text stays legible in every page theme.

### Page themes (reader)

The PDF page itself is re-coloured with a colour matrix, never a naive
inversion:

* **Paper** – untouched.
* **Sepia** – white → `#F3E7CF`, black → `#3B2E20`.
* **Night** – *luminance* is inverted while hue is kept
  (`c' = c − 2·L + 255`), then mapped into a warm dim range: white →
  `#1E1C19`, black → `#D9D0BF`. Photos keep their hues instead of turning
  into negatives, and white pages never glare.

## Typography

Bundled OFL fonts (no runtime font fetching):

| Style | Family | Size / weight | Use |
|---|---|---|---|
| `display` | Bricolage Grotesque | 40 / 800, −2 % tracking | Screen titles ("Library") |
| `headline` | Bricolage Grotesque | 28 / 750 | Section heroes |
| `title` | Bricolage Grotesque | 20 / 700 | Card titles |
| `numeral` | Bricolage Grotesque | 44 / 800, tabular | Big stats, timers |
| `body` | Manrope | 15 / 500, 1.45 line height | Paragraphs |
| `label` | Manrope | 13 / 700 | Buttons, chips |
| `caption` | Manrope | 12 / 600 | Meta ("p. 42 · 3 days ago") |
| Reading (Text view) | Literata | user size 14–28, line height 1.3–2.0 | Reflowed book text |

## Shape & spacing

* Radii: `xs 8`, `sm 12`, `md 20`, `lg 28` (cards), `xl 36` (sheets, hero
  cards), `pill 999`.
* Spacing scale (4 pt): 4, 8, 12, 16, 20, 24, 32, 40, 56. Screen gutter 20.
* Icon buttons: 44 px circles. Primary buttons: 56 px ink pills.
* Book covers: 2:3 with `sm` radius, a 6 px darker spine gradient on the
  left edge and a soft ambient shadow.

## Elevation

Mostly flat colour blocks. Only floating things get a shadow:
`0 8 24 ink @ 8 %` (floating nav bar, covers, toolbars). Dark mode replaces
shadows with a 1 px `hairline` outline.

## Components

* **Floating pill nav bar** – ink capsule floating 12 px above the safe area.
  Active tab = paper-coloured pill with icon + label; inactive = icon only.
* **Filter chips** – pills; selected = filled ink, others = hairline outline.
* **Colour-block cards** – pastel tint backgrounds, ink text, no borders.
  Continue Reading is an ink card in light mode (the one dark block on Home).
* **Stat tiles** – oversized numeral + caption on a pastel tile; stacked tiles
  join with a notched edge.
* **Streak badge** – circular running text ("READING STREAK · 12 DAYS ·")
  that slowly rotates; static when reduce-motion is on.
* **Grid paper** – faint 24 px grid behind empty-state illustrations.
* **Icons** – Phosphor, regular weight; filled weight for active states.

## Motion

Calm and quick. Everything checks `MediaQuery.disableAnimations` (system
"reduce motion") through `Motion.of(context)` and collapses to instant
changes when set.

| Token | Duration | Curve | Used for |
|---|---|---|---|
| `fast` | 160 ms | easeOutCubic | Chips, toggles, icon swaps |
| `base` | 240 ms | easeOutCubic | Cards, sheets, list/grid swap |
| `slow` | 360 ms | easeInOutCubic | Page transitions, progress fills |
| `stagger` | 30 ms / item | — | List and grid entrances (max 8 items) |

* Book open: the cover is a `Hero` from the card into the reader's loading
  frame, then fades into the first rendered page.
* Highlight: colour sweeps left→right over 220 ms. Bookmark: ribbon drops
  with a small overshoot.
* Session complete: lime ring fills, numbers count up, sparkles fade out.
* Skeletons: soft shimmer (1.2 s loop) on `surfaceMuted`.
