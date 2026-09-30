# Touchline design language

Extracted from the reference shots (dark sports UIs, the playful toy app, the art-trading app) — no branding copied.

- **Palette (dark):** bg `#0A0C0B`, surfaces `#131715 / #1B201D / #252B27`, hairline `#262D29`, text `#F2F5F1`, muted `#8E978F`. Accent lime `#C6F432` (fills, CTA, home series), mint `#3DDC84` (sheen, wins), violet `#9D95FF` (away series, predictions), live red `#FF4545`. Light theme is designed separately (`AppColors.light`), not inverted.
- **Type:** Archivo variable (wght 700–900, wdth 104–125) for display and tabular numerals; Inter for body. Italic accent word in headlines ("Good *evening*").
- **Shape & space:** radii 12 / 16 / 22 / 28 / pill; 4-pt scale, 20 px gutter. Depth via lighter surfaces, not shadows.
- **Navigation:** floating blurred pill bar; active tab expands with its label.
- **Signature pieces:** lime "featured" live card (one per screen), two-sided stat bars (home lime / away violet), rotating circular stamp badge, pitch line art.
- **Motion:** 160/260/420 ms, emphasized curve `(0.2,0,0,1)`, spring for pops; staggered list entrances (capped at 8); score roll + lime glow on change; full-screen goal burst (2.6 s, tap to dismiss); momentum and stat bars draw in; league rows glide to new positions; share card shine on export. All reduce to fades with "Reduce motion".
