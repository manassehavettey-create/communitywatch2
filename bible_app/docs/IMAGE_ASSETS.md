# Image assets: batch 1

These are all the images the design needs. Everything else is drawn in code:
Scripture cards, stickers, progress rings, avatars and chips.

Until you confirm an image, the screen that uses it shows a finished
code-drawn state (a sticker shape and an icon on a pastel field). It never
shows a grey placeholder box.

**How to deliver:** generate the images in Google Flow, then drop the files
into the folder listed for each one using the exact filename. Tell me when
they're in and I'll wire them up. PNG where transparency matters, JPG for
full-bleed backgrounds.

## Shared style

Paste this block at the start of every prompt so all the assets match.

> **STYLE:** Flat editorial illustration with a warm, calm, modern feel. Use
> confident black ink linework with slightly uneven hand-drawn edges, and flat
> fills in a limited palette: warm paper #F6F0E6, ink #141414, tangerine
> #F5620F used sparingly, sage #AAC385, butter #F4D352, blush #E9B4C8, sky
> #A1BDDD, cream #F3E9CC. Add subtle risograph grain. No gradients, no gold, no
> glow, no lens flare. No church buildings, no crosses, no stained glass, no
> halos, no doves, no praying-hands clip-art. No text, letters or numbers
> anywhere in the image. Consistent with the other assets in this set.

Every illustration with people uses diverse, contemporary characters drawn
simply: minimal faces, no photorealism.

---

## 1. App identity

### 1.1 App icon
- **Used:** home-screen and App Store / Play Store icon.
- **Size:** 1024×1024 PNG, square, opaque. No rounded corners; the operating
  system masks them.
- **File:** `assets/images/brand/app_icon.png`
- **Prompt:**
  > STYLE block. A single app icon mark, centred, filling about 60% of the
  > canvas. An open book seen from above, drawn as two soft rounded page
  > shapes in warm paper #F6F0E6 with a thin ink outline. A small tangerine
  > #F5620F bookmark ribbon falls from the spine. The whole background is solid
  > ink #141414. Geometric, bold, readable at 29 px. No text, no shadow, no
  > gradient, no border.

### 1.2 Android adaptive icon (foreground)
- **Used:** Android launcher, where the system provides the background layer.
- **Size:** 1024×1024 PNG with a transparent background. Keep the mark inside
  the centre 66% (the safe zone).
- **File:** `assets/images/brand/app_icon_foreground.png`
- **Prompt:**
  > STYLE block. The same open-book mark with the tangerine bookmark ribbon as
  > the app icon, alone on a fully transparent background. Warm paper pages
  > with an ink outline, occupying the centre 60% of the canvas. No background
  > colour, no shadow, no text.

  The background layer is solid ink `#141414`, set in code.

### 1.3 Splash mark
- **Used:** launch screen, centred on paper `#F6F0E6` (light) or `#121110`
  (dark).
- **Size:** 1152×1152 PNG with a transparent background. Keep the mark inside
  the centre 768×768 circle, as Android 12+ requires.
- **File:** `assets/images/brand/splash_mark.png`
- **Prompt:**
  > STYLE block. The open-book mark with tangerine bookmark ribbon, pages
  > filled butter #F4D352 with ink outlines, on a fully transparent background.
  > The mark sits inside a centred circle occupying 66% of the canvas. No text,
  > no shadow.

---

## 2. Onboarding

There are four screens. The illustration fills the top 60% of the screen, and
the headline and button sit below it.

- **Size (all four):** 1200×1500 PNG (4:5), background exactly paper `#F6F0E6`
  so it blends into the screen. Leave the bottom 10% empty paper.
- **Folder:** `assets/images/onboarding/`

### 2.1 `onboarding_read.png`: "Scripture, always with you" (works offline)
> STYLE block. A young woman sits cross-legged on a floor cushion by a window
> at dusk, reading a small open book held close. Her hair is in a loose bun,
> with a butter-yellow sweater and ink trousers. A tangerine mug sits beside
> her, and a trailing plant in a cream pot. Loose sage leaves float around her
> like the pages are breathing. Calm and focused. Composition centred, with
> generous empty paper-coloured space around the figure. Background solid
> #F6F0E6. No text.

### 2.2 `onboarding_keep.png`: "Keep what speaks to you" (highlights and notes)
> STYLE block. Hands holding an open book seen from above. A few lines of the
> page are marked with soft rounded highlight strokes in butter, sage and blush
> (abstract lines, no readable letters). A tangerine pencil rests across the
> page and a small folded note sticks out. A few small sticker shapes (a
> scalloped circle, a soft blob) float around the book. Background solid
> #F6F0E6. No text.

### 2.3 `onboarding_pray.png`: "Pray and reflect" (prayer and journal)
> STYLE block. A person with short curly hair sits at a small wooden table
> writing in a journal by warm lamp light. Their eyes are softly closed in a
> moment of reflection, one hand resting on the page. A sky-blue ceramic
> lamp, a cream cup, and a small stack of books in sage and blush. Quiet
> evening mood, drawn with the same flat palette. Background solid #F6F0E6.
> No text.

### 2.4 `onboarding_rhythm.png`: "Build a gentle rhythm" (plans and reminders)
> STYLE block. A tidy stack of four closed books in sage, blush, butter and
> sky, spines facing out. The spines are blank with no letters. On top sits a
> small potted plant with three new leaves. A tangerine alarm clock with a
> simple face and no numbers leans against the stack. A soft blob shape sits
> behind the stack in cream. Still-life composition. Background solid
> #F6F0E6. No text.

---

## 3. Empty states

These are small spot illustrations shown above one line of text.

- **Size (all):** 800×800 PNG with a transparent background. The subject fills
  about 70% of the canvas.
- **Folder:** `assets/images/empty/`

| File | Screen | Prompt (prefix with STYLE block) |
|---|---|---|
| `empty_journal.png` | Journal, no entries | An open blank notebook lying at a slight angle, with a tangerine pen beside it and a small sage sprig. Transparent background. No text. |
| `empty_prayer.png` | Prayer, no requests | Two cupped hands gently holding a small glowing paper lantern in butter yellow; the "glow" is a flat cream shape, not a gradient. Transparent background. No text. |
| `empty_saved.png` | Saved, nothing saved yet | A single bookmark ribbon in tangerine tucked into a closed cream book, with a small scalloped sticker shape floating beside it. Transparent background. No text. |
| `empty_notes.png` | Notes, no notes | A small stack of three note cards in blush, sky and cream, slightly fanned, the top one with abstract squiggle lines only. Transparent background. No text. |
| `empty_search.png` | Search, no results | A magnifying glass with an ink outline resting on an open book whose pages are blank, with a curious small leaf peeking out. Transparent background. No text. |
| `empty_plans.png` | Plans, no active plan | A winding path drawn as a single sage ribbon, leading to a small flag in tangerine planted in a cream mound. Transparent background. No text. |
| `offline_state.png` | Sync paused / offline notice | A small paper boat in cream floating on two flat sky-blue wave shapes, with a tiny tangerine sail. Transparent background. No text. |

---

## 4. Scripture card backgrounds

The share-card templates are built in code: background, then verse text, then
reference, then a small mark. Any verse renders into any template. These
images are the optional background art behind the text.

- **Composition:** calm, low detail, with a large empty area for text. The
  text will sit on top, so nothing busy goes in the middle.
- **Size (all):** 1440×2560 JPG (9:16, the largest share format). Square and
  landscape cards crop from the centre, so keep important shapes near the
  edges and corners, not the centre.
- **Folder:** `assets/images/cards/`

| File | Prompt (prefix with STYLE block, then add: "Background art only, the centre 70% must stay calm and nearly empty for overlaid text, no text.") |
|---|---|
| `card_paper_grain.jpg` | Warm paper #F6F0E6 with fine natural paper fibres and subtle risograph grain, very even. A single tiny sage sprig in the bottom-right corner. |
| `card_botanical_corner.jpg` | Cream #F3E9CC background with ink line-drawn olive branches entering from the top-left and bottom-right corners, a few leaves filled sage. |
| `card_blocks.jpg` | Paper #F6F0E6 background with two large soft organic blob shapes, one butter in the top-left corner bleeding off the edge and one sky in the bottom-right, both flat with grain. |
| `card_forest_night.jpg` | Deep forest green #1F312B field with faint grain, a few thin cream line-drawn fern fronds rising from the bottom edge, and small cream star dots near the top. |
| `card_dusk.jpg` | Flat colour bands suggesting a dusk horizon: blush at the top, then cream, then a low sage hill silhouette across the bottom 20%. Flat, grainy, no gradient blending. |
| `card_night_ink.jpg` | Near-black #121110 field with fine grain and a thin tangerine crescent-moon line drawing in the top-right corner. |
| `card_linen.jpg` | Close-up warm cream linen fabric texture, soft and even, very subtle weave, evenly lit. |
| `card_wildflowers.jpg` | Paper #F6F0E6 background with small hand-drawn wildflowers (ink outlines, tangerine, butter and blush fills) growing along the bottom edge only. |

---

## 5. Seamless texture (optional)

| File | Size | Use | Prompt |
|---|---|---|---|
| `assets/images/textures/grain_tile.png` | 512×512 PNG, seamless tile | A very faint grain overlay on large pastel cards (used at 6% opacity) | Seamless tileable risograph-style paper grain noise, neutral grey on transparent background, fine and even, no pattern repeats visible, no text. |

---

**Total: 23 images** (3 identity, 4 onboarding, 7 empty states, 8 card
backgrounds, 1 texture).
