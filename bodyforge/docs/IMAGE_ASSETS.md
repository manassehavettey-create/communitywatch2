# BODYFORGE — Image asset batch (Google Flow)

Style decided: **photographic cutouts** (athletes, objects and food) in the look of the UI
references — isolated subject, soft studio light, no background, placed on lime / lavender /
graphite cards by the app. The app already runs without these files (it draws a themed
fallback), so you can add them in any order.

## How to generate consistently

1. **Create the two recurring athletes first** (A1, A2 below) and save the best result of each.
   In Flow, add that image as an *ingredient / reference* for every later athlete prompt so the
   same two people appear throughout the app.
2. Google Flow outputs images **with a background**. Every prompt asks for a flat, plain
   `#E9E9E4` studio backdrop so the cutout is clean. Then either:
   - remove the background yourself (Canva *BG Remover*, remove.bg, Photoshop) and export PNG
     with transparency, **or**
   - just drop the raw images into the folders and tell me — I can batch-cut them out with a
     script (`rembg`) and resize/compress them for you.
3. Export at the listed size (or larger with the same aspect ratio). Keep each PNG under ~400 KB
   after compression (I can compress for you too).
4. Use the exact filename and folder listed. Folders are relative to `bodyforge/`.

### Shared style block (already included in every prompt below)

> Photorealistic commercial fitness photography, soft diffused key light from upper left with a
> subtle cool rim light, crisp focus, natural skin texture, realistic athletic (not bodybuilder)
> physique, clothing in matte charcoal black with small lime-green (#D4F55A) and soft lavender
> (#A99BF7) accents, no logos, no text, no watermark, no gym equipment, no dumbbells, isolated
> subject on a flat plain light-grey #E9E9E4 studio backdrop, full subject in frame with margin,
> consistent with the BODYFORGE asset set.

---

## A. Recurring athletes (make these first — they are the "cast")

| # | File | Size / format | Used on |
|---|------|---------------|---------|
| A1 | `assets/images/cast/kofi_reference.png` | 1024×1280 (4:5), PNG transparent | Reference only + auth screen |
| A2 | `assets/images/cast/ama_reference.png` | 1024×1280 (4:5), PNG transparent | Reference only + auth screen |

**A1 prompt — Kofi**
> Full-body portrait of Kofi, a fit Ghanaian man in his late 20s, dark skin, short fade haircut,
> friendly confident expression, standing relaxed with arms loosely crossed, wearing a fitted
> matte charcoal black training t-shirt with a thin lime-green (#D4F55A) seam detail, black
> training shorts, black sneakers with lavender (#A99BF7) soles. Photorealistic commercial
> fitness photography, soft diffused key light from upper left with a subtle cool rim light,
> crisp focus, natural skin texture, realistic athletic (not bodybuilder) physique, no logos, no
> text, no watermark, no gym equipment, isolated subject on a flat plain light-grey #E9E9E4
> studio backdrop, full body in frame with margin, consistent with the BODYFORGE asset set.

**A2 prompt — Ama**
> Full-body portrait of Ama, a fit Ghanaian woman in her late 20s, dark skin, natural hair in
> neat braids tied back, focused warm expression, standing with hands on hips, wearing a matte
> charcoal black sports top with a thin lavender (#A99BF7) trim, black high-waisted leggings
> with a small lime-green (#D4F55A) stripe at the ankle, black sneakers. Photorealistic
> commercial fitness photography, soft diffused key light from upper left with a subtle cool rim
> light, crisp focus, natural skin texture, realistic athletic (not bodybuilder) physique, no
> logos, no text, no watermark, no gym equipment, isolated subject on a flat plain light-grey
> #E9E9E4 studio backdrop, full body in frame with margin, consistent with the BODYFORGE asset
> set.

---

## B. Brand

| # | File | Size / format | Used on |
|---|------|---------------|---------|
| B1 | `assets/images/brand/app_icon.png` | 1024×1024, PNG **no transparency** | App icon (iOS + Android legacy) |
| B2 | `assets/images/brand/app_icon_foreground.png` | 1024×1024, PNG transparent (mark inside the central 66%) | Android adaptive icon foreground + splash mark |

**B1 prompt**
> Minimal premium app icon for a bodyweight fitness app called BODYFORGE. A bold geometric
> monogram letter "B" built from two stacked rounded horizontal bars, like a forged metal
> ingot, matte near-black (#141416) with a subtle soft inner highlight, centred on a flat solid
> lime-green (#D4F55A) square background, generous padding, flat modern design with very subtle
> depth, no text other than the B shape, no gradients except a faint top highlight, crisp
> vector-like edges, consistent with the BODYFORGE asset set.

**B2 prompt**
> The same bold geometric monogram letter "B" built from two stacked rounded horizontal bars,
> like a forged metal ingot, lime-green (#D4F55A) with a subtle soft highlight, centred, occupying
> the middle 60% of the canvas, on a flat plain light-grey #E9E9E4 backdrop, no other elements,
> crisp vector-like edges, consistent with the BODYFORGE asset set.

(If the generated "B" isn't clean enough, tell me — I can draw the icon as a vector in code and
export it instead.)

---

## C. Onboarding heroes (4)

All: **1080×1350 (4:5), PNG transparent**, folder `assets/images/onboarding/`.

| # | File | Used on |
|---|------|---------|
| C1 | `onboarding_welcome.png` | Welcome / sign-up screen |
| C2 | `onboarding_goals.png` | Goals step |
| C3 | `onboarding_space.png` | Training space step |
| C4 | `onboarding_plan.png` | "Forging your plan" reveal |

**C1** — Kofi (use A1 as reference) mid push-up, body in a perfect straight line, shot from a
low three-quarter side angle, arms locked at the top position, determined expression.
*+ shared style block.*

**C2** — Ama (use A2 as reference) holding a strong forearm plank, shot from a low side angle,
body perfectly straight, calm focused face looking forward. *+ shared style block.*

**C3** — Kofi (use A1 as reference) performing a controlled bodyweight split squat, back knee
just above the floor, torso upright, hands at chest, three-quarter front angle.
*+ shared style block.*

**C4** — Ama (use A2 as reference) standing tall, rolling her shoulders back with a slight
confident smile, one hand adjusting her sleeve, mid-motion, three-quarter angle, cropped from
mid-thigh up. *+ shared style block.*

---

## D. Workout types (7) — mission card, plan cards, category tiles, skill-path headers

All: **900×1100 (≈4:5), PNG transparent**, folder `assets/images/workouts/`.
Frame the athlete so they can overflow the top edge of a card (head near the top, some margin).

| # | File | Used on |
|---|------|---------|
| D1 | `type_upper.png` | Upper body / push path |
| D2 | `type_lower.png` | Lower body / leg path |
| D3 | `type_core.png` | Core / core path |
| D4 | `type_back.png` | Back & posterior chain path |
| D5 | `type_full.png` | Full body |
| D6 | `type_conditioning.png` | Conditioning |
| D7 | `type_recovery.png` | Recovery & mobility |

**D1** — Kofi (ref A1) at the bottom of a diamond push-up, elbows tucked, three-quarter front
angle from slightly above. *+ shared style block.*

**D2** — Ama (ref A2) in a deep bodyweight squat, arms extended forward for balance, heels down,
three-quarter front angle. *+ shared style block.*

**D3** — Kofi (ref A1) holding a hollow body hold on the floor, lower back pressed down, arms
overhead, legs straight and raised, side angle from low. *+ shared style block.*

**D4** — Ama (ref A2) lying face down performing a "superman" back extension, arms and legs
lifted off the floor, side angle from low. *+ shared style block.*

**D5** — Kofi (ref A1) in the middle of a controlled reverse lunge with a knee drive, arms in a
natural running position, dynamic but balanced, three-quarter angle. *+ shared style block.*

**D6** — Ama (ref A2) mid "fast feet" high-knee march in place, low-impact, one knee high, arms
pumping, slight motion energy but sharp, three-quarter angle. *+ shared style block.*

**D7** — Kofi (ref A1) seated on the floor in a relaxed deep hip-flexor / world's greatest
stretch position, calm breathing expression, side angle. *+ shared style block.*

---

## E. Training environments (6) — Environment mode picker & onboarding space step

All: **800×800 (1:1), PNG transparent**, folder `assets/images/environments/`.
Style: **object still-life cutouts** (no people), same lighting as the athletes.

Shared object style block:
> Photorealistic product-style still life, soft diffused key light from upper left with a
> subtle cool rim light, crisp focus, slightly elevated three-quarter angle, muted realistic
> colours with a small lime-green (#D4F55A) or lavender (#A99BF7) accent object, no people, no
> text, no logos, isolated on a flat plain light-grey #E9E9E4 studio backdrop, consistent with
> the BODYFORGE asset set.

| # | File | Prompt subject (+ object style block) |
|---|------|---------------------------------------|
| E1 | `env_bedroom.png` | The corner of a neatly made single bed with a charcoal duvet and a folded lavender towel on it, a small patch of wooden floor in front. |
| E2 | `env_living_room.png` | A compact modern charcoal two-seater sofa with one lime-green cushion, a small woven rug in front of it. |
| E3 | `env_small_space.png` | A narrow strip of wooden floor, just wider than a folded towel, with a rolled lavender towel lying on it, cropped tightly to feel compact. |
| E4 | `env_large_space.png` | A wide, empty, clean wooden floor area seen at a low angle, with a single folded lime-green towel far in the corner to show scale. |
| E5 | `env_outside.png` | A small square of green grass with a low concrete step at the edge and a black water bottle with a lime cap, bright daylight. |
| E6 | `env_hotel_room.png` | A hotel room key card and a neatly folded white hotel towel on the edge of a bed with crisp white sheets. |

---

## F. Achievement medallions (3) — the app draws each achievement's icon and title on top

All: **768×768 (1:1), PNG transparent**, folder `assets/images/badges/`.

Shared medallion block:
> Premium 3D rendered hexagonal medallion with softly rounded corners, a raised bevelled rim
> and a smooth empty centre face (leave the centre blank for an icon to be overlaid), soft studio
> reflections, subtle glow, no text, no symbols, no numbers, centred, isolated on a flat plain
> light-grey #E9E9E4 backdrop, consistent with the BODYFORGE asset set.

| # | File | Subject (+ medallion block) | Used for |
|---|------|------------------------------|----------|
| F1 | `medal_lavender.png` | Matte graphite medallion with a satin lavender (#A99BF7) metal rim. | Habit & consistency achievements |
| F2 | `medal_lime.png` | Matte graphite medallion with a satin lime-green (#D4F55A) metal rim. | Strength, PR & skill achievements |
| F3 | `medal_ember.png` | Matte black medallion with a warm brushed ember-orange (#FF9A3C) and gold metal rim, slightly more ornate bevel. | Milestones (30 workouts, 12-week BODYFORGE) |

---

## G. Empty states (5)

All: **800×800 (1:1), PNG transparent**, folder `assets/images/empty/`. Use the object style
block from section E unless it's an athlete.

| # | File | Subject | Used on |
|---|------|---------|---------|
| G1 | `empty_workouts.png` | Kofi (ref A1) sitting on the floor tying his sneaker, getting ready, relaxed. *+ shared athlete style block.* | No workout history yet |
| G2 | `empty_measurements.png` | A soft fabric measuring tape loosely coiled with a lime-green end tab. *+ object style block.* | No measurements yet |
| G3 | `empty_records.png` | A matte black digital stopwatch lying at an angle with a lavender strap. *+ object style block.* | No personal records yet |
| G4 | `empty_achievements.png` | Ama (ref A2) sitting on the floor, towel around her neck, drinking water, calm smile. *+ shared athlete style block.* | No achievements unlocked yet |
| G5 | `empty_search.png` | A single black sneaker with a lavender sole lying on its side. *+ object style block.* | No search results |

---

## H. 12-week journey artwork (4)

All: **1080×1350 (4:5), PNG transparent**, folder `assets/images/journey/`.

| # | File | Subject (+ shared athlete style block) |
|---|------|------------------------------------------|
| H1 | `phase_1_habit.png` | Ama (ref A2) carefully learning a bodyweight squat, controlled, hands together at her chest, attentive expression — "learning the movement". |
| H2 | `phase_2_body.png` | Kofi (ref A1) holding the lowered position of a decline push-up with feet on a bed edge (only the bed edge visible), strong and focused. |
| H3 | `phase_3_forge.png` | Ama (ref A2) mid assisted pistol squat, one leg extended forward, lightly touching a chair back for balance (only the chair visible), intense focus. |
| H4 | `journey_complete.png` | Kofi and Ama (refs A1 + A2) standing side by side, tired but proud, towels over shoulders, fist bump, slight smiles — "12 weeks done". |

---

## I. Nutrition challenges (4)

All: **800×800 (1:1), PNG transparent**, folder `assets/images/challenges/`. Use the food
style block (section J).

| # | File | Subject |
|---|------|---------|
| I1 | `challenge_protein_20.png` | A simple affordable plate: two boiled eggs halved, a portion of red-red (black-eyed bean stew with palm oil) and fried ripe plantain, on a plain dark plate. |
| I2 | `challenge_water_7.png` | A tall clear glass of water with ice and a lime slice next to a black reusable water bottle. |
| I3 | `challenge_breakfast_7.png` | A bowl of oats porridge (Hausa koko-style bowl acceptable) topped with sliced banana and groundnuts, with a boiled egg beside it. |
| I4 | `challenge_no_soda_7.png` | A glass bottle of plain water with a lime slice beside an empty, crushed generic soft-drink can with no branding. |

---

## J. Food database (32)

All: **600×600 (1:1), PNG transparent**, folder `assets/images/foods/`.

Shared food style block:
> Photorealistic food photography, one realistic single serving, slightly elevated 45-degree
> angle, soft diffused key light from upper left with a subtle cool rim light, crisp focus,
> natural appetising colours, simple plain matte dark-grey plate or bowl only where a vessel
> makes sense, no cutlery clutter, no people, no text, no logos or branded packaging, isolated
> on a flat plain light-grey #E9E9E4 studio backdrop, consistent with the BODYFORGE asset set.

Prompt = `<subject>` + food style block.

| File | Subject |
|------|---------|
| `food_eggs.png` | Two whole eggs and one boiled egg cut in half showing the yolk |
| `food_beans_red_red.png` | A bowl of red-red: black-eyed bean stew in red palm-oil sauce |
| `food_sardines.png` | An open unbranded tin of sardines in tomato sauce |
| `food_tuna.png` | An open unbranded tin of flaked tuna |
| `food_chicken.png` | A grilled chicken thigh and drumstick, skin lightly charred |
| `food_tilapia.png` | A whole grilled tilapia with pepper sauce on the side |
| `food_mackerel.png` | A fried or smoked mackerel (Ghanaian "salmon") fillet |
| `food_milk.png` | A glass of milk next to an unbranded small tin of evaporated milk |
| `food_groundnuts.png` | A small bowl of roasted groundnuts (peanuts) in their red skins |
| `food_wagashi.png` | Slices of wagashi (West African soft cheese), lightly fried |
| `food_soya_chunks.png` | A bowl of cooked soya chunks in light stew |
| `food_rice.png` | A bowl of plain white rice |
| `food_waakye.png` | A portion of waakye (rice and beans) with a boiled egg and shito on the side |
| `food_oats.png` | A bowl of cooked oats porridge |
| `food_plantain.png` | One ripe yellow plantain and one green unripe plantain, one sliced |
| `food_kelewele.png` | A small bowl of kelewele (spiced fried ripe plantain cubes) |
| `food_yam.png` | Boiled white yam slices on a plate with a piece of whole yam behind |
| `food_sweet_potato.png` | Two orange-fleshed sweet potatoes, one cut open |
| `food_gari.png` | A bowl of dry gari (cassava granules) |
| `food_kenkey.png` | A ball of Ga kenkey partly unwrapped from its dried corn husk |
| `food_banku.png` | A ball of banku with okro soup beside it |
| `food_kontomire.png` | A bowl of kontomire (cocoyam leaf) stew with egg |
| `food_garden_eggs.png` | A few whole garden eggs (African white eggplant), one sliced |
| `food_okro.png` | Fresh okro (okra) pods, a few sliced |
| `food_tomato_onion.png` | Fresh tomatoes, a red onion and a scotch bonnet pepper |
| `food_cabbage_carrot.png` | Half a green cabbage and two carrots |
| `food_banana.png` | A small bunch of ripe bananas |
| `food_orange.png` | Two local green-yellow oranges, one halved |
| `food_pawpaw.png` | A pawpaw (papaya) cut in half showing the seeds |
| `food_pineapple.png` | A pineapple with a few cut wedges |
| `food_watermelon.png` | Two triangular slices of watermelon |
| `food_avocado.png` | An avocado cut in half with the seed |

---

## Exercise demonstrations

No images needed — every exercise has an **animated figure drawn in code** (a looping
movement demo) plus step-by-step form cues, so you don't need to generate exercise clips.

---

## Status (what ships in the app)

All images were processed the same way:
- background removed with `rembg` (isnet-general-use)
- trimmed and resized
- saved as WebP q86

The whole set is about 2.3 MB. `lib/core/assets.dart` is the single registry.

| Group | Status | Alternative used where missing |
|---|---|---|
| A cast | Ama ✓ (Kofi appears through the workout-type set) | — |
| B brand | Logo mark ✓; launcher icons generated from `branding/` | — |
| C onboarding | Goals ✓, plan ✓ | Welcome uses Kofi's push-up (`type_upper`); the other steps have no hero |
| D workout types | 7/7 ✓ | — |
| E environments | 6/6 ✓ | — (large-space image is the weakest; replace if you make a better one) |
| F medallions | 3/3 ✓ | — |
| G empty states | 4/5 ✓ | "No achievements" uses the locked lavender medallion |
| H journey | 0/4 | Phases use athlete shots: Habit → lower body, Body → full body, Forge → core; report header uses the ember medallion |
| I challenges | 4/4 ✓ | — |
| J foods | 24/32 ✓ | Banana reuses the plantain photo (it shows bananas). Mackerel, milk, wagashi, orange, pawpaw, pineapple and groundnuts get a typographic tile drawn in code, coloured by food group. Meal ideas show each ingredient's photo or tile. |

To add a missing image later:
1. Drop it into the listed folder with the listed filename.
2. Add the id to `Img._foods` for foods, or point the `Img` constant at the new file.

## Checklist

- [ ] A1–A2 cast
- [ ] B1–B2 brand
- [ ] C1–C4 onboarding
- [ ] D1–D7 workout types
- [ ] E1–E6 environments
- [ ] F1–F3 medallions
- [ ] G1–G5 empty states
- [ ] H1–H4 journey
- [ ] I1–I4 challenges
- [ ] J (32 foods)

**Total: 69 images.** When you've added some or all, tell me which folders are done and I'll wire
them up, cut out / compress anything that needs it, and check each one in the app.
