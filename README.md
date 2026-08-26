# Diem

A standalone Apple Watch study timer, with a web dashboard and minimal sync.

From *diēs* — day. The product is daily: a goal per day, a streak of days, a 4am
boundary.

```
watch/   watchOS 27 app + widget extension (SwiftUI, SwiftData)
web/     SvelteKit dashboard and sync API (Drizzle, PlanetScale Postgres)
```

## The idea

Intervals are the only durable record. A **session** is nothing more than the
intervals sharing a `sessionID`: switching subject or pausing closes the current
interval and opens the next, so the log stays append-only and an interval is
immutable once `endedAt` is set. There is no merge logic because there is
nothing to merge — `subject` is the only mutable entity, last-write-wins on
`updatedAt`.

Subject and duration are independent, and all four combinations are valid. A
session with no subject is a free session; nothing else marks it. Completion is
derived (`endedAt - startedAt >= plannedSec`), never flagged. Sessions under a
minute are discarded silently.

A day runs 4am to 4am, and a session counts toward the day it started.
Everything is stored in UTC and bucketed by the local day in effect at the time.

## Building the watch app

There is no `.xcodeproj` in the repo — the project is described by
`watch/project.yml` and generated:

```sh
brew install xcodegen
cd watch && xcodegen generate && open Diem.xcodeproj
```

Add an asset catalog with `AppIcon` before archiving; the spec doesn't ship one.

Targets: `Diem` (the app), `DiemWidget` (one complication in four families —
which is the Smart Stack card as well — and the Action Button Control) and
`DiemTests`. Model, design and intents are shared
with the extension; views are not, and neither is `Diem/Runtime` — claiming the
foreground is something only the app can do.

The app declares the `mindfulness` background mode, which is what lets it claim
an extended runtime session. Nothing about meditation: it is the one
extended-runtime type that runs *frontmost* for longer than ten minutes, and
holding the foreground is the whole use. Only one such mode may be declared, so
this is the choice.

## Running the web app

See `web/README.md`. `npm run check && npm test && npm run build`.

## What's verified, and what isn't

The Foundation-only core of the watch app — the day boundary, the number
formats, the crown stepping curve, session assembly, the live-session summary
behind the running clock, the goal lap the ring and the complication's bar both
draw, and the window the session card claims in the Smart Stack — compiles and
its 66 tests pass under Swift 6.3 on Linux. One command, anywhere with a Swift
toolchain:

```sh
cd watch && sh Scripts/core-check.sh
```

Every Swift file also parses clean under `-swift-version 6` — and **parsing is
not type-checking**, which is worth saying plainly, because that was the only
check this repo had and `Views/Ring.swift` handed a subject id to a function
taking a colour index and parsed clean for two releases while the app target
could not be built at all. `core-check.sh` type-checks what it can reach.
Everything else needs `xcodegen generate` and a real build before you believe
it compiles.
Everything that touches SwiftUI, SwiftData, WatchKit or AppIntents has **not**
been compiled, because that needs an Apple SDK.

Anything that decides a number should be pulled into that core, not only what is
on a redraw path — it is the only code any machine can check. The completion
rule, the snapshot's day staleness and the relevance window all live there for
that reason. Anything on a redraw path especially: the
store's derived reads are held in a cache, and `liveSummary()` is where the
arithmetic behind them lives precisely so it can be tested here rather than
taken on faith. It is checked against `sessions()` — the assembly it stands in
for — so the fast path can't drift from the slow one unnoticed.

The web side is verified end to end: typecheck, build, unit tests, and a live
run against a real Postgres covering pairing, idempotent interval push,
last-write-wins subjects, cursored pull, the 4am bucketing and the 401 paths.

**The app holds the foreground while a session runs.** A watchOS app is put away
the moment the wrist drops, and the raise that follows lands on the watch face;
the system Timer is the exception everyone has felt, and `Diem/Runtime` asks for
the same thing the same way — a `mindfulness` extended runtime session, the type
that runs frontmost. The system's terms are the app's: it can only be claimed
while the app is active, so a session started from Siri or a widget claims it
when the app is next opened; an hour is the limit, so an expiry that arrives
with the session still running claims the next hour; and crowning out ends it,
which is the user leaving on purpose and not a thing to fight. Stay in the app
and it holds, leave it deliberately and it lets go — the same bargain the Timer
makes.

**Session relevance is wired, and now asked for at the moment it changes.**
`SnapshotProvider.relevance()` claims a window for as long as a session is
running, so the Smart Stack surfaces the card on session start instead of
waiting to be added by hand. There is one card to surface: the complication and
the session card were two widgets reading the same snapshot, and are now one
that shows the day's total until a session starts and the session itself while
one runs. The window is `.scheduled` rather than a plain date
range — the documented reading of that kind is content that wants acting on, and
a running session with an End button on it is exactly that. A timeline reload is
not a relevance reload, so `commit()` also invalidates the card's relevance, but
only when the two things it depends on move: whether a session is live, and
where it ends.

Both are written against the documented watchOS APIs and neither has been
compiled — that needs an Apple SDK, like everything else below. The relevance
window itself is the exception, because it was pulled out into the tested core.

**The app has been audited from the outside in, and everything found is fixed.**
`watch/description/` describes the product feature by feature and collects every
suspected defect in one place; all 31 entries carry a resolution. Four were
critical: the session ring could not compile, a held session was reported
Complete on wall-clock time while the countdown measured studied time, the app
and the widget extension never learned about each other's writes, and a store
that failed to open fell back to memory in silence. The rest run from sync gaps
that lost deletes, through complications showing yesterday's total after 4am, to
touch targets and text scaling under the floors the app sets itself.

Nothing in that audit has been observed on a device. `watch/description/verification/`
is the pass that would change that.

Two things from the plan are still not wired, both flagged there as needing
confirmation against the watchOS 27 SDK first:

- Points-of-interest relevance, for surfacing the start card at known study
  locations.
- `AccessoryWidgetGroup` for the rectangular complication. It stays laid out by
  hand, and the goal bar with it: a stock `accessoryLinearCapacity` gauge draws
  the same thing at 100% and at 200%, where the ring laps. Worth revisiting only
  if the group buys back something the hand layout can't do.

And two to check on hardware, as the plan says: the overflow ring's drop shadow
depends on real OLED contrast, and the crown detent haptics want prototyping
before the stepping curve is final.

## Decisions the plan left open

**A pause holds the countdown.** The data model derives completion from the
wall-clock span, which would mean a pause eats into a timed session. For a study
timer that's the wrong behaviour, so the countdown measures studied time. The
derived formula still agrees: studied time is never longer than the wall-clock
span, so a session that runs to term satisfies it either way.

**The server schema carries three columns the plan's tables don't.** Every row
needs a `device_id` to be scoped to a watch. The device also carries a
`timezone`, because bucketing a UTC instant into a local day needs one, and a
`goal_minutes`, because the goal-hit rate on the web needs a copy of the one
setting that lives on the watch. Both travel as headers on every sync.
