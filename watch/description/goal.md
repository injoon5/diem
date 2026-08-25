# Standing instructions

You are describing the Diem watch app from the outside in. Read
[`README.md`](README.md) first for the shape, then
[`glossary.md`](glossary.md) for the words, then
[`app/start-screen.md`](app/start-screen.md) — the pilot — to calibrate depth.

## Stance

Describe the experience, not the code. "The countdown holds where it stopped",
not "`pause()` sets `endedAt`". Technical detail goes in `> Technical note:`
block quotes, and only where the mechanism changes what a person would expect.

Sentence case headings. Direct, concrete, no hedging, no marketing. Surprising
behaviour is stated plainly, with the reason if the code gives one. If it looks
like a bug, say so in "Open questions" and add it to
[`bug-triage.md`](bug-triage.md) — do not smooth it over, and do not fix it: the
source is read-only reference here.

Cross-reference with relative links rather than restating. The foundation
documents own the numbers; a feature document links to them.

## Things already established

Facts other documents must not re-derive or contradict.

**Numbers**

- The study-day runs 04:00 → 03:59 local. A session counts toward the day it started in.
- Default goal 2h. Goal range 15 minutes → 12 hours, in 15-minute steps (48 steps).
- Session length scrubs 0 → 8h: 1-minute steps to 60m, 5-minute to 4h, 15-minute beyond (113 steps).
- One turn of the Start ring at rest is the goal. One turn under the crown, and one turn of the session ring, is 60 minutes.
- A session under **60 seconds** of studied time is dropped on close, silently.
- An interval left open longer than **12 hours** is treated as one the app never closed: it is shut at its own start, and its hours are not credited.
- A question withdraws itself after **6 seconds**.
- The overtime nudge lands **30 minutes** past the deadline.
- The session card claims relevance to its deadline, or a rolling **20 minutes**, whichever is later.
- The widget refreshes every **15 minutes** with a session running, **30** without.

**Rules**

- The countdown measures *studied* time. A hold stops it; it does not run against the wall clock.
- Completion is derived from the **span**, not from studied time. These disagree whenever a session was held. That is [B-02](bug-triage.md#b-02), and documents must describe what the app does, not what the countdown implied.
- Subject and duration are independent. All four combinations are valid.
- Intervals are append-only and immutable once closed. A subject chosen while held applies to the next interval, never the last.
- Colour never carries meaning alone anywhere a watch face may render monochrome.
- Nothing on a redraw path touches the database; every store read is served from a cache dropped on commit.
- Nothing animates while the display is dimmed, except the seconds leaving and returning.

**Vocabulary traps**

- *Held*, not paused, when describing behaviour. Quote "Paused" when describing the screen.
- *Ran to term* when the countdown reached zero. *Complete* only for the app's derived flag.
- *Run* is a stretch within a session, not a total.

## Ownership

| Fact | Owned by |
| --- | --- |
| What an interval and a session are; completion; the 60s floor; the 12h recovery | [`foundations/session-model.md`](foundations/session-model.md) |
| The crown curves, detents, taps, targets, questions, haptics | [`foundations/input-model.md`](foundations/input-model.md) |
| The 4am day, the goal, laps, the streak | [`foundations/day-model.md`](foundations/day-model.md) |
| Which process sees what; the snapshot; relevance | [`foundations/surfaces.md`](foundations/surfaces.md) |

A feature document links to these rather than restating them.

## Adding a document

1. Add it to the structure and coverage table in `README.md` first.
2. Write it on the eight-section template.
3. Add its checklist table to the right file under `verification/`, with a new ID prefix numbered from 01.
4. Add any new triage entries with the next free `B-NN`.
5. Never renumber a checklist or triage ID once it has been used.

## Commits

This repo writes commit subjects as sentences, not as `docs:` prefixes, and
carries `Co-Authored-By` attribution. Follow the repo, not the template.
