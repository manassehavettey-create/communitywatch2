# Growth Log — Image Asset Brief (Google Flow)

All images go under `growth_log/assets/images/<folder>/<filename>`.
The app is already wired to these exact paths; once a file is dropped in, it shows up — no code change needed.

## Two styles, one family

**Style A — Soft 3D clay** (badges, trophies, streak flame, empty states, hero shapes, recap).
**Style B — Flat bold characters** (the 3 onboarding screens and the level-up screen only).

Both share the same palette so they look like one set:

| Name | Hex |
|---|---|
| Lime | `#C8EC64` |
| Lavender | `#B6A3FF` |
| Butter | `#F4DD7D` |
| Apricot | `#F7CC7E` |
| Sky | `#BCC9EC` |
| Blush | `#F2B1DC` |
| Sage | `#AEBE91` |
| Ink (near-black) | `#0E101C` |
| Cream | `#FAF3E6` |
| Electric blue | `#012AFE` |

### Transparency
Google Flow usually exports on a solid background. **Every prompt asks for a plain pure white background** — that's fine:
save them as PNG exactly as generated and I'll cut the white background out with a script when you tell me they're in.
(If you already have a background-removal tool, transparent PNGs are even better.)

### Tips
- Generate each group in one Flow session and reuse the first good result as a **style reference image** for the rest of that group.
- Pick the variant with the cleanest silhouette and the most empty space around the subject.
- No text, logos or watermarks should appear in any image.

---

## Style blocks (already included in every prompt below)

**[STYLE A]**
> soft 3D clay render, matte plasticine material, chunky rounded geometric forms, smooth bevelled edges, soft diffused studio lighting from the top-left, gentle soft contact shadow directly underneath, pastel palette of lime #C8EC64, lavender #B6A3FF, butter yellow #F4DD7D, apricot #F7CC7E, sky blue #BCC9EC, blush pink #F2B1DC and sage #AEBE91 with small near-black #0E101C accents, playful minimal modern app illustration, centered, single isolated object group, plain pure white background, no text, no logo, consistent with the other assets in this set

**[STYLE B]**
> flat 2D editorial vector illustration, bold confident shapes, flat color fills with one or two flat shadow tones, no gradients, no outlines except very thin near-black details, stylish modern character with slightly elongated fashion-illustration proportions and a simple minimal face, confident dynamic pose, limited palette of near-black #0E101C, cream #FAF3E6, butter yellow #F4DD7D, apricot #F7CC7E, lavender #B6A3FF, blush pink #F2B1DC and small touches of lime #C8EC64, full body, isolated on a plain pure white background, generous empty space around the figure, no text, no logo, consistent with the other assets in this set

---

## Batch 1 — Brand (folder `assets/images/brand/`)

### 1. `app_icon.png`
- **Used for:** launcher icon (iOS + Android legacy icon)
- **Size:** 1024×1024, 1:1, PNG, **opaque** (no transparency)
- **Prompt:**
> App icon, a single chunky soft 3D clay sprout with two rounded leaves growing out of a small rounded upward-pointing arrow shape, the sprout in near-black #0E101C and the leaves in lavender #B6A3FF, centered on a flat solid lime #C8EC64 square background filling the whole frame, soft 3D clay render, matte plasticine material, soft diffused studio lighting from the top-left, subtle soft shadow, minimal bold iconic silhouette readable at small sizes, no text, no border, no rounded corners on the canvas, consistent with the other assets in this set

### 2. `app_icon_foreground.png`
- **Used for:** Android adaptive icon foreground (the background is filled with lime by the app config)
- **Size:** 1024×1024, 1:1, PNG, transparent (white background is fine, I'll cut it)
- **Keep the subject inside the central ~60% of the canvas** (Android crops the edges)
- **Prompt:**
> The same chunky soft 3D clay sprout with two rounded lavender #B6A3FF leaves growing out of a small rounded near-black #0E101C upward-pointing arrow, small and centered, occupying only the central 55 percent of the frame with lots of empty space around it, soft 3D clay render, matte plasticine material, soft diffused lighting from the top-left, plain pure white background, no text, consistent with the other assets in this set

### 3. `splash_logo.png`
- **Used for:** splash screen and lock screen mark
- **Size:** 1024×1024, 1:1, PNG, transparent
- **Prompt:**
> The same chunky soft 3D clay sprout with two rounded lavender #B6A3FF leaves growing out of a small rounded near-black #0E101C upward-pointing arrow, a tiny lime #C8EC64 clay sparkle beside it, centered with generous empty space, [STYLE A]

---

## Batch 2 — Onboarding + level-up characters (folder `assets/images/onboarding/`) — STYLE B

The app places these on full-colour screens: screen 1 lime, screen 2 blush pink, screen 3 electric blue, level-up electric blue.
The character colours are chosen so they don't disappear into those backgrounds.

### 4. `onboarding_track.png`
- **Used for:** onboarding screen 1 — "Every hour counts" (lime background)
- **Size:** 1200×1600, 3:4 portrait, PNG, transparent
- **Prompt:**
> A stylish young person mid-stride holding an acoustic guitar over one shoulder and glancing at a large round stopwatch floating beside them, wearing a lavender #B6A3FF oversized jacket, cream #FAF3E6 trousers and near-black #0E101C boots, the stopwatch in butter yellow #F4DD7D with a near-black hand, avoid lime green on the character, [STYLE B]

### 5. `onboarding_gratitude.png`
- **Used for:** onboarding screen 2 — "Notice the good" (blush pink background)
- **Size:** 1200×1600, 3:4 portrait, PNG, transparent
- **Prompt:**
> A stylish person sitting cross-legged writing in an open journal with a pencil, a few small four-point sparkles and a tiny heart floating up from the pages, wearing a butter yellow #F4DD7D knit sweater, near-black #0E101C wide trousers and cream #FAF3E6 sneakers, journal cover in lavender #B6A3FF, avoid pink on the character, [STYLE B]

### 6. `onboarding_grow.png`
- **Used for:** onboarding screen 3 — "Watch yourself grow" (electric blue background)
- **Size:** 1200×1600, 3:4 portrait, PNG, transparent
- **Prompt:**
> A stylish person confidently stepping up onto the top of three rising rounded blocks like a staircase, one arm raised holding a small flag, blocks in butter yellow #F4DD7D, apricot #F7CC7E and lavender #B6A3FF, the person wearing a blush pink #F2B1DC long coat, cream #FAF3E6 top and near-black #0E101C trousers, avoid blue anywhere in the image, [STYLE B]

### 7. `levelup_hero.png`
- **Used for:** full-screen level-up celebration (electric blue background, confetti drawn by the app)
- **Size:** 1200×1600, 3:4 portrait, PNG, transparent
- **Prompt:**
> A joyful stylish person leaping in the air with both arms up holding a chunky trophy above their head, wearing a lime #C8EC64 bomber jacket, cream #FAF3E6 trousers and near-black #0E101C boots, trophy in butter yellow #F4DD7D, a few flat four-point sparkles around them, energetic celebratory pose, avoid blue anywhere in the image, [STYLE B]

---

## Batch 3 — Level badges (folder `assets/images/badges/`) — STYLE A

Shown on the skill-detail level ring, on skill cards and in the level-up screen. They must read clearly at 48 px, so keep each one a single, bold object.

- **Size (all five):** 1024×1024, 1:1, PNG, transparent

### 8. `badge_novice.png` — 0 h
> A small chunky seed sprouting a single tiny rounded leaf from a small round sage #AEBE91 clay pot, the leaf in lime #C8EC64, [STYLE A]

### 9. `badge_apprentice.png` — 20 h
> A small young plant with three rounded leaves in lime #C8EC64 growing from a round butter yellow #F4DD7D clay pot, slightly bigger and fuller than a seedling, [STYLE A]

### 10. `badge_skilled.png` — 100 h
> A chunky puffy five-point star in apricot #F7CC7E resting on a small round lavender #B6A3FF disc pedestal, [STYLE A]

### 11. `badge_expert.png` — 1,000 h
> A chunky round medal in lavender #B6A3FF with a raised rounded lime #C8EC64 star in the center, hanging from a short folded blush pink #F2B1DC ribbon, [STYLE A]

### 12. `badge_master.png` — 10,000 h
> A chunky rounded crown in butter yellow #F4DD7D with three soft rounded points, each tipped with a small glossy lavender #B6A3FF clay ball, a tiny lime #C8EC64 sparkle beside it, the most premium-looking badge of the set, [STYLE A]

---

## Batch 4 — Wins, streaks & hero shapes (folder `assets/images/illustrations/`) — STYLE A

### 13. `trophy.png`
- **Used for:** milestone win cards in the Log and the recap "biggest milestones" section
- **Size:** 1024×1024, 1:1, PNG, transparent
> A chunky rounded trophy cup in butter yellow #F4DD7D with two round handles on a near-black #0E101C rounded base, a small lime #C8EC64 clay star floating above, [STYLE A]

### 14. `streak_flame.png`
- **Used for:** streak counters on Home, Log and Insights
- **Size:** 1024×1024, 1:1, PNG, transparent
> A chunky rounded cartoon flame made of layered soft clay, outer layer apricot #F7CC7E, inner layer butter yellow #F4DD7D, tiny blush pink #F2B1DC core, friendly soft shape, [STYLE A]

### 15. `hero_shapes.png`
- **Used for:** the lime "This week" hero card on Home (sits on the right edge of the card, partly cropped)
- **Size:** 1200×1200, 1:1, PNG, transparent
> A playful balanced stack of chunky geometric clay shapes: a lavender #B6A3FF cylinder, a blush pink #F2B1DC rounded cube, a near-black #0E101C torus ring, a butter yellow #F4DD7D half-sphere and a small sky blue #BCC9EC ball, stacked diagonally, [STYLE A]

### 16. `recap_mountain.png`
- **Used for:** the top of the monthly "Look how far you've come" recap screen and the share card
- **Size:** 1600×1200, 4:3 landscape, PNG, transparent
> A chunky rounded clay mountain with two peaks in lavender #B6A3FF and sky blue #BCC9EC, a small lime #C8EC64 flag planted on the tallest peak, a winding apricot #F7CC7E path up the slope, two small round sage #AEBE91 clay trees at the base, [STYLE A]

---

## Batch 5 — Empty states (folder `assets/images/empty/`) — STYLE A

- **Size (all four):** 1200×900, 4:3 landscape, PNG, transparent

### 17. `empty_skills.png` — Skills tab with no skills
> A small rounded near-black #0E101C clay flag stuck into a round lime #C8EC64 clay mound, with a lavender #B6A3FF ball and a butter yellow #F4DD7D cube resting beside it waiting to be used, [STYLE A]

### 18. `empty_log.png` — Log tab with no entries
> A chunky open clay journal with blank cream pages and a lavender #B6A3FF cover, a butter yellow #F4DD7D pencil resting across it and a tiny blush pink #F2B1DC clay heart floating above, [STYLE A]

### 19. `empty_insights.png` — Insights with no data yet
> A small clay bar chart of four rounded bars of increasing height in sage #AEBE91, sky blue #BCC9EC, lavender #B6A3FF and lime #C8EC64 standing on a rounded near-black #0E101C base plate, [STYLE A]

### 20. `empty_search.png` — search or filters with no results
> A chunky clay magnifying glass with a lavender #B6A3FF handle and a butter yellow #F4DD7D rim, tilted, a tiny blush pink #F2B1DC clay question-mark-shaped squiggle beside it, [STYLE A]

---

## Not needed as images (intentionally)
- **Skill icons** — skills are user-created, so the icon picker uses ~40 Phosphor icons that recolour with each skill's colour. Generated images could not cover arbitrary skills.
- **Background textures** — the reference style is flat colour blocks; textures would fight it.
- **Charts, progress rings, confetti** — drawn in code so they animate and theme correctly.

## When you're done
Drop the files into the folders above (or send them to me), then tell me **"images added"**.
I'll then cut backgrounds, generate the launcher icons and splash from the brand images, and verify each one renders on its screen.
