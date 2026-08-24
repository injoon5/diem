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
formats, the crown stepping curve and session assembly — compiles and its 23
tests pass under Swift 6.3 on Linux (`watch/DiemTests`, run on a Mac through the
`Diem` scheme, or standalone against those four files). Every Swift file parses
clean. Everything that touches SwiftUI, SwiftData, WatchKit or AppIntents has
**not** been compiled, because that needs an Apple SDK.

The web side is verified end to end: typecheck, build, unit tests, and a live
run against a real Postgres covering pairing, idempotent interval push,
last-write-wins subjects, cursored pull, the 4am bucketing and the 401 paths.

Two things from the plan are deliberately not wired yet, both flagged there as
needing confirmation against the watchOS 27 SDK first:

- The Smart Stack `RelevanceConfiguration` — the relevance signal on session
  start, and points-of-interest relevance for the start card.
- `AccessoryWidgetGroup` for the rectangular complication, which is laid out by
  hand instead.

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
