---
name: vox-explainer
description: Write explainer-video scripts and storyboards in the style of Vox's YouTube explainers and Netflix's "Explained" series — a cold open hook, a clear narrative arc, plain-language narration, and paired visual/graphic cues with pacing notes. Use this whenever the user asks for a video script, a script for an explainer/documentary-style video, a storyboard, a voiceover script paired with on-screen graphics, or wants to turn a topic into a short explainer video — even if they just say "make this a video" or "script this out" or "explain X like a Vox video." Works on any topic (history, science, current events, how something works, a company, a policy) — not limited to any one subject domain. Not for blog posts, articles, or written-only explainers; use this specifically when visuals/on-screen cues and narration need to be paired for video production.
---

# Vox-Style Explainer Script

## What this produces

A narration + visuals script for a short explainer video, in the reported-documentary
style popularized by Vox's YouTube channel, Vox Borders, and Netflix's "Explained":
a strong opening hook, a topic broken into digestible beats, data and graphics that
carry as much of the explanation as the voiceover does, and a clear takeaway at the end.

This is a **content and structure** skill, not a rendering pipeline — the output is a
script document, not a video file, and it isn't tied to any particular editing tool.

## Before writing: get the essentials

If the user's request doesn't already make these clear, ask (briefly — don't
interrogate over things you can reasonably infer from the topic):

1. **Target runtime.** Drives how many beats you can fit and how deep each one goes.
   Default to ~4 minutes if the user doesn't say — that's the sweet spot for this
   format: long enough for a real argument, short enough to hold attention.
2. **The topic and the angle.** "Explain inflation" is a subject, not an angle. Vox
   videos work because they pick a specific, narrow question inside a big topic
   ("why is a Big Mac in Switzerland twice the price of one in the US?" rather than
   "how prices work"). If the user gives you a broad subject, propose a sharper
   angle rather than trying to cover everything.
3. **Audience assumption.** Default to "smart, curious, but no prior background" —
   the hallmark of this style is making complex things legible to a general
   audience without dumbing them down.

Don't block on these if the user's ask is already specific enough — use judgment.

## The narrative arc

Every script follows this shape, in order. Skipping or reordering these breaks the
format — the hook exists to earn attention *before* any context is given, and the
complication exists so the piece doesn't feel like a one-sided pitch.

1. **Cold open hook** (first 10-20 seconds). Lead with the most surprising, concrete,
   or tension-producing fact or question about the topic — not a definition, not
   "today we're going to talk about X." The viewer should feel a question form in
   their head that the rest of the video answers. Good hooks are specific numbers,
   vivid scenes, or a contradiction ("X should be true, but here's why it isn't").
2. **Context and stakes.** Why does this matter, and to whom? Establish just enough
   background for the hook to make sense — not the full history, just what's needed.
3. **Core explanation, broken into beats.** The main body. Break the explanation into
   3-6 discrete beats, each one advancing the argument by one step. Each beat should
   be able to stand as its own mini-scene with its own visual. Resist the urge to
   front-load all the information — reveal it in the order that builds understanding,
   not the order it appears in a textbook.
4. **Complication or nuance.** A real explainer doesn't pretend the topic is simple.
   Introduce a counterpoint, an exception, an unresolved tension, or "but it's more
   complicated than that" moment. This is what separates an explainer from a pitch.
5. **Resolution / takeaway.** Land the plane — answer the question the hook raised,
   and give the viewer one clear idea to walk away with. Avoid a generic "and that's
   why X matters" — tie it back to the specific hook.

## Voice and narration rules

- Write for the ear, not the eye: short sentences, one idea per sentence, active voice.
- Contractions are fine and usually better ("it's" not "it is") — this is spoken, not written, prose.
- Define jargon the instant you introduce it, in the same breath — don't assume the
  viewer will infer it from context.
- Avoid hedging and academic throat-clearing ("it could be argued that," "in many
  ways"). State things plainly; save the nuance for the complication beat.
- Read every line out loud (mentally or literally) before finalizing — if it's
  awkward to say, it's wrong, even if it's grammatically fine on the page.

## Visual and graphic cues

Every beat needs a visual idea, not just narration. Note cues inline in brackets, e.g.:

```
[GRAPHIC: line chart, 1990-2024, showing the price gap widening after 2008]
[ON-SCREEN TEXT: "$4.20 → $7.80"]
[B-ROLL: archival footage of the factory floor]
[MAP: zoom from country to the specific region being discussed]
```

Favor graphics that carry information the narration doesn't have to say out loud —
a chart showing a trend line is often stronger than narrating the trend. When the
topic involves data, comparisons, or change over time, default to proposing a
specific chart type (line, bar, map, before/after) rather than a vague "graphic here."

## Pacing

Spoken narration runs at roughly **140-150 words per minute**. Use this to size beats
against the target runtime:

- Cold open: 5-8% of runtime
- Context/stakes: 10-15%
- Core explanation beats: 50-60% (split across however many beats you chose)
- Complication: 10-15%
- Resolution: 5-10%

For a 4-minute (≈600-word) script, that's roughly: hook ~40s/~90 words, context ~35s,
core beats ~2 min split across 3-5 beats, complication ~30s, resolution ~25s. Recalculate
proportionally for whatever runtime the user asks for, and state the total word count
and estimated runtime at the top of the script so it's easy to sanity-check.

## Output format

Use a two-column table (or clearly labeled VISUALS / NARRATION pairs if a table
renders poorly in context) for every beat, so production can read visuals and audio
side by side. Structure the full output like this:

```markdown
# [Video Title]

**Target runtime:** ~X min (~Y words)
**Thumbnail text option:** "[short, punchy on-screen text — 3-6 words]"

## Cold Open (~Xs)
| VISUALS | NARRATION |
|---|---|
| [cue] | "..." |

## Context & Stakes (~Xs)
| VISUALS | NARRATION |
|---|---|

## Beat 1: [short label] (~Xs)
| VISUALS | NARRATION |
|---|---|

## Beat 2: [short label] (~Xs)
...

## Complication (~Xs)
| VISUALS | NARRATION |
|---|---|

## Resolution / Takeaway (~Xs)
| VISUALS | NARRATION |
|---|---|
```

Give each core-explanation beat a short descriptive label (not just "Beat 1") so the
structure is scannable at a glance.

## After drafting

Do a final pass and check:
- Does the hook actually create a question, or does it just state a fact?
- Does every beat have a visual that adds information, not just decoration?
- Does the complication beat genuinely complicate things, or is it just a footnote?
- Does the total word count match the target runtime at ~140-150 wpm?
- Would a smart 15-year-old follow every sentence without rereading?

If the user gives feedback on tone, depth, or pacing, revise the whole script rather
than patching isolated lines — a script's rhythm is easy to break by editing in
isolation.

See `references/example.md` for a full worked example on a sample topic.
