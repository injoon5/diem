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

Targets: `Diem` (the app), `DiemWidget` (complications, the Smart Stack card and
the Action Button Control) and `DiemTests`. Model, design and intents are shared
with the extension; views are not.

## Running the web app

See `web/README.md`. `npm run check && npm test && npm run build`.

## What's verified, and what isn't

The Foundation-only core of the watch app — the day boundary, the number
formats, the crown stepping curve, session assembly, the live-session summary
behind the running clock and the goal lap the ring and the complication's bar
both draw — compiles and its 48 tests pass under Swift 6.3 on Linux
(`watch/DiemTests`, run on a Mac through the `Diem` scheme, or standalone
against `Day`, `Format`, `Scrub`, `SessionAssembly`, `Snapshot` and the
`ISO8601` helper out of `Sync/DTO`). Every Swift file parses clean under `-swift-version 6`.
Everything that touches SwiftUI, SwiftData, WatchKit or AppIntents has **not**
been compiled, because that needs an Apple SDK.

Anything on a redraw path that can be pulled out into that core should be: the
store's derived reads are held in a cache, and `liveSummary()` is where the
arithmetic behind them lives precisely so it can be tested here rather than
taken on faith. It is checked against `sessions()` — the assembly it stands in
for — so the fast path can't drift from the slow one unnoticed.

The web side is verified end to end: typecheck, build, unit tests, and a live
run against a real Postgres covering pairing, idempotent interval push,
last-write-wins subjects, cursored pull, the 4am bucketing and the 401 paths.

Session relevance is now wired: `SnapshotProvider.relevance()` claims a window
for as long as a session is running, so the Smart Stack surfaces the card on
session start instead of waiting to be added by hand. It is written against the
documented watchOS `WidgetRelevance` API but has not been compiled — that needs
an Apple SDK, like everything else below.

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
