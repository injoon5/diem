# Standing instructions

You are describing Diem from the outside in — the watch app, and the web
dashboard beside it. Read [`README.md`](README.md) first for the shape, then
[`glossary.md`](glossary.md) for the words, then the pilot for the area you are
writing in: [`app/start-screen.md`](app/start-screen.md) for the watch,
[`web/dashboard.md`](web/dashboard.md) for the web.

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
- A pairing code is **six** characters, valid **ten minutes**, single use.
- A browser session lasts **400 days**, and nothing in the interface ends it.
- The web's window is **371 days** — a year plus enough slack for the grid to start on a week boundary.
- The goal-hit rate is measured over the last **30** days of that window.
- A handle is **3 to 20** characters, lowercase letters, digits and hyphens, never starting or ending on one.
- A handle may be changed **three** times. The first claim is free; a refused change is not counted.
- A handle is claimable once, ever. Releasing one retires it rather than freeing it.
- Claiming a handle requires the device to have logged at least one session.
- A subject rename may be up to **40** characters for a display name, **60** for a subject.

**Rules**

- The countdown measures *studied* time. A hold stops it; it does not run against the wall clock.
- Completion is derived from the **span**, not from studied time. These disagree whenever a session was held. That is [B-02](bug-triage.md#b-02), and documents must describe what the app does, not what the countdown implied.
- Subject and duration are independent. All four combinations are valid.
- Intervals are append-only and immutable once closed. A subject chosen while held applies to the next interval, never the last.
- Colour never carries meaning alone anywhere a watch face may render monochrome.
- Nothing on a redraw path touches the database; every store read is served from a cache dropped on commit.
- Nothing animates while the display is dimmed, except the seconds leaving and returning.
- **The watch is the author, the web is the reader.** Two exceptions, both owned by [`foundations/sync-model.md`](foundations/sync-model.md): the profile, and which watch a profile belongs to. Subjects are the one thing both sides write, and they settle last-write-wins.
- The web never starts, holds or ends a session, and has no control that would. A web document says which of the five phases do not apply rather than omitting them.
- Only closed intervals reach the server, so nothing on the web ever shows a session that is still running.
- The dashboard refetches when the tab is looked at again, and once at the next day boundary. Nothing else updates it.
- Claiming a handle *is* publishing. There is no separate visibility switch, and no way to unpublish.
- A profile is stats only until its owner opts in, and "stats only" strips the subject from every day as well as omitting the list.

**Vocabulary traps**

- *Held*, not paused, when describing behaviour. Quote "Paused" when describing the screen.
- *Ran to term* when the countdown reached zero. *Complete* only for the app's derived flag.
- *Run* is a stretch within a session, not a total.
- *Device* is the server's row, not the watch in someone's hand. Say *watch* for the object.
- *Pairing* gives a browser a session. *Replacing* moves a profile to a new watch. They are different words for different things and share only a code format.
- *Profile* is the public page; *handle* is its address; *display name* is what is drawn on it. Never "username" or "account" — there is no account.

## Ownership

| Fact | Owned by |
| --- | --- |
| What an interval and a session are; completion; the 60s floor; the 12h recovery | [`foundations/session-model.md`](foundations/session-model.md) |
| The crown curves, detents, taps, targets, questions, haptics | [`foundations/input-model.md`](foundations/input-model.md) |
| The 4am day, the goal, laps, the streak | [`foundations/day-model.md`](foundations/day-model.md) |
| Which process sees what; the snapshot; relevance | [`foundations/surfaces.md`](foundations/surfaces.md) |
| The device and its token; what crosses the wire; who wins a disagreement; what a failure looks like | [`foundations/sync-model.md`](foundations/sync-model.md) |
| The three numbers, the year grid, pairing from the browser's side | [`web/dashboard.md`](web/dashboard.md) |
| What a handle may be; the reserved list; the subjects switch | [`web/profile.md`](web/profile.md) |

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
