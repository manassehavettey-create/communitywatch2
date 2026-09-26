# "Was It Real?" — Paper-Cut Diorama Short
**Topic:** The Moon Landing "hoax" conspiracy theory
**Format:** 9 shots × 5s (Google Flow) = 45s total runtime, budget: 45 credits
**Style:** Paper-cut / stop-motion diorama, shoebox-theatre aesthetic

---

## Can one prompt generate all 9 shots at once in Flow?

No. Flow generates one clip per generation call — there's no single mega-prompt that outputs 9 distinct finished shots in one shot. What you *can* do to make the process fast and consistent:

1. **Lock a style anchor.** Use the "MASTER STYLE" block below at the start of every one of the 9 prompts, word-for-word. That's what keeps the paper texture, palette, and diorama "shoebox" look identical across all 9 separate generations.
2. **Reuse reference images ("Ingredients").** After your first shot generates, save the still frame(s) and feed them back in as reference/ingredient images for later shots featuring the same characters (the astronaut, the whistleblower, the investigator) so faces/props don't drift.
3. **Generate in story order.** Go 1→9 in sequence — each finished shot becomes your visual reference for the next, which is the closest Flow gets to "continuity" across separate generations.
4. **Batch your typing, not your generating.** Everything below is pre-written so you just paste-and-go nine times without having to think mid-session about wording.

---

## MASTER STYLE (paste at the start of every shot prompt)

> Paper-cut stop-motion diorama, miniature shoebox theatre aesthetic, layered cardboard and construction-paper cutouts with visible torn edges and soft drop-shadows between layers, warm tungsten key light with long dramatic shadows, muted retro 1960s palette (mustard, olive, rust, cream, faded NASA-blue), subtle handmade paper-grain texture, shallow depth of field with soft-focus background layers, cinematic documentary framing, slight film-grain and warm vignette, highly detailed, award-winning craft/stop-motion animation style.

---

## THE 9 SHOTS

### Shot 1 — The Broadcast
**Image prompt:** [MASTER STYLE] + A cramped 1960s living room diorama, paper-cutout family silhouettes gathered around a boxy paper television, static crackling on its screen, a paper hand reaching to turn a large round knob on the TV, warm lamp glow, night-time blue light through a paper window.
**Animation (must move, not just camera):** The hand visibly turns the knob; the TV screen flickers from static to a clear glowing image; the family's paper heads tilt forward in unison toward the screen.
**Voiceover:** *"July, 1969. The whole world was watching — or so we were told."*

### Shot 2 — Mission Control
**Image prompt:** [MASTER STYLE] + Layered paper diorama of a 1960s mission control room, rows of paper engineers at control panels with tiny blinking paper lights, confetti and paper scraps thrown in celebration, one still figure in the back row not celebrating, quietly sliding a paper folder into a drawer.
**Animation:** Confetti falls and scatters across the desks; engineers throw their arms up and high-five; the background figure's hand slides the folder shut — a small, deliberate motion contrasted against the celebration.
**Voiceover:** *"Mission control celebrated a triumph three years in the making."*

### Shot 3 — The Reveal
**Image prompt:** [MASTER STYLE] + Wide reveal shot pulling back from a paper astronaut figure planting a small flag on a grey paper crater surface, to show the crater set is actually built on a soundstage floor with visible paper light-rigs, cables, and a stagehand cutout crossing in the background carrying a large reflector panel.
**Animation:** Camera pulls back (a push-out reveal); the stagehand physically walks across the background carrying the reflector; the astronaut figure's arm slowly lowers after planting the flag.
**Voiceover:** *"But look closer at the footage — something doesn't add up."*

### Shot 4 — The Flag
**Image prompt:** [MASTER STYLE] + Close-up on the small paper flag planted in the crater set, rippling fabric-paper folds catching studio light, a paper crew member's hands entering frame from the side holding an open clapperboard.
**Animation:** The flag visibly flutters and waves on its pole (an "impossible" motion for an airless surface); the clapperboard hands clap shut in one sharp motion, sticks snapping together.
**Voiceover:** *"A flag that waves... in a place with no wind."*

### Shot 5 — The Lighting Rig
**Image prompt:** [MASTER STYLE] + A backstage diorama view of a black paper backdrop painted with stars, a director-type paper figure standing at a large round reflector on a rolling stand, adjusting its angle, hot studio spotlights aimed from multiple directions, cables coiled on the floor.
**Animation:** The director figure's hands rotate the reflector on its stand; the beam of light visibly sweeps across the black backdrop as it turns; a couple of painted stars flicker like loose bulbs.
**Voiceover:** *"Lighting that argues with itself. Shadows that don't belong."*

### Shot 6 — The Whistleblower
**Image prompt:** [MASTER STYLE] + A dim paper hallway at night, a lone technician cutout figure tiptoeing past a sleeping paper security guard slumped in a chair, clutching a film reel canister tightly against his chest, a sliver of moonlight-blue light coming from a cracked door ahead.
**Animation:** The technician's legs move in an exaggerated tiptoe walk-cycle; he glances back over his shoulder; the door creaks open wider under his push, light spilling further across the floor.
**Voiceover:** *"One insider said he saw more than he was supposed to."*

### Shot 7 — The Cover-Up
**Image prompt:** [MASTER STYLE] + A paper government office diorama, several suited bureaucrat cutouts around a long table, one hand-cranking a paper document shredder with strips falling into a bin, another figure stamping a folder marked "CLASSIFIED" in bold red ink, a small wastebasket with an orange paper flame licking up crumpled papers.
**Animation:** The shredder crank turns and paper strips fall continuously; the stamp hand slams down twice, ink mark appearing; the paper flame flickers and consumes a crumpled sheet in the bin.
**Voiceover:** *"Files vanished. Reels disappeared. Questions were buried with them."*

### Shot 8 — The Investigator
**Image prompt:** [MASTER STYLE] + A cluttered paper study diorama decades later, a corkboard covered in photos and newspaper clippings connected by taut red string, an investigator cutout figure pinning a new photo to the board and pulling a fresh string tight, an old desk fan cutout in the corner, coffee mug and scattered notes on the desk.
**Animation:** The investigator's hand pins the photo and stretches red string across to another pin, tying it off; the desk fan blades spin, ruffling the loose papers on the desk.
**Voiceover:** *"Decades later, believers are still connecting the dots."*

### Shot 9 — The Question (meta reveal)
**Image prompt:** [MASTER STYLE] + Wide final shot: a small crowd of tiny paper people in a paper town square at night, looking up at a glowing paper moon in the sky, one figure shrugging with open paper hands, then camera pulls back further to reveal the entire town square is a miniature diorama sitting inside an open cardboard shoebox on a wooden table, room lights visible around the edges of frame.
**Animation:** The shrugging figure's arms lift in a shrug motion; the paper moon gently pulses/glows brighter and dimmer like a heartbeat; the final pull-back is a slow, continuous zoom-out revealing the shoebox frame.
**Voiceover:** *"Did we really walk on the moon? Or just build a beautiful story?"*

---

## Full Voiceover Script (read straight through, ~45s at a measured pace)

> July, 1969. The whole world was watching — or so we were told.
> Mission control celebrated a triumph three years in the making.
> But look closer at the footage — something doesn't add up.
> A flag that waves... in a place with no wind.
> Lighting that argues with itself. Shadows that don't belong.
> One insider said he saw more than he was supposed to.
> Files vanished. Reels disappeared. Questions were buried with them.
> Decades later, believers are still connecting the dots.
> Did we really walk on the moon? Or just build a beautiful story?

---

## Notes on pacing
- Each VO line is timed to sit inside its 5-second shot without rushing — if a line runs long when you record it, trim adjectives rather than cutting story beats.
- Shot 9 doubles as a framing device: the "it's all a diorama" pull-back is a visual wink that keeps the piece framed as *exploring a theory*, not asserting it as fact — worth keeping even if you tweak the rest.
- Recommended order of operations in Flow: generate Shot 1 image → animate → generate Shot 2 (using Shot 1 stills as style/character reference where a character repeats) → repeat through Shot 9.
