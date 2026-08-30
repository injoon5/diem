# Glossary

The source of truth for every term of art used in these documents. A word used
in a document that is not defined here is a consistency bug.

## The record

**Interval** — one unbroken stretch of study on one subject. The only durable
record; everything else is derived. Immutable once its `endedAt` is set.

**Open interval** — an interval with no `endedAt`. At most one exists at a time,
and only inside the live session.

**Session** — the intervals that share a session id. Not stored; assembled on
demand. Pausing or switching subject closes one interval and opens the next, so
a session can be many intervals.

**Live session** — the session currently being counted, running or held. There
is at most one.

**Free session** — a session with no subject. Nothing else marks it.

**Timed session** — a session with a planned length, carried on its first
interval only. An **open-ended session** has none.

**Studied time** — the sum of a session's intervals. Held time is not in it.

**Span** — wall clock from a session's first start to its last end. Held time
*is* in it. Studied time and span are the same number only for a session that
was never held. See [Terms this description avoids](#terms-this-description-avoids).

**Banked** — study already closed into an interval, as opposed to the seconds
accruing in the open one.

## What a session does

**Compose, Commit, Run, Close, Account** — the five phases every session passes
through. Defined in [`README.md`](README.md#the-products-shape).

**Held** — what this description calls a paused session, because the app's own
word on screen is "Paused" but the behaviour is a hold: the countdown stops
where it is rather than continuing against the wall clock.

**Overtime** — a timed session past its deadline that has not been ended. The
count carries a `+` and the numeral steps back. Overtime is a real state, not an
error.

**Deadline** — the instant a timed session's countdown reaches zero, measured in
studied time.

**Discard** — throwing a session away on purpose. Deletes its intervals.

**Dropped** — a session under a minute of studied time, deleted without being
offered a summary. The app does not use this word; there is no word on screen,
because nothing is shown.

**Again** — repeating the last session's length and its *last* subject.

## The day

**Study-day** — 04:00 to 03:59 local. A session counts toward the day it
started in.

**Day boundary** — 4am. The instant a study-day's total resets to zero.

**Goal** — the daily target, in minutes. 15 minutes to 12 hours, default 2h.

**Streak** — consecutive study-days with anything in them, counting back. Today
having nothing in it yet does not break one.

**Lap** — a reading past its goal. One turn is the goal met; past that the
completed pass dims and the overflow draws over it. The ring on the watch and
the bar on the complication are the same lap in two shapes.

## On screen

**Hero numeral** — the largest reading on a screen: the running count, the day's
total inside the Start ring, the summary total. Never resized by its own value.

**Field** — the width a numeral reserves, taken from the widest string it could
ever hold. A numeral shorter than its field is centred inside it.

**Roll** — a digit changing by counting. **Replace** — a numeral being swapped
for a different quantity, drawn as a blur rather than a roll.

**Goal ring** — the Start screen's ring. One turn is the goal.

**Scrub ring** — the same ring while the crown is turning. One turn is an hour.

**Session ring** — the ring behind the running clock: the session so far as
bands of colour, one per run, an hour to the turn.

**Run** — one unbroken stretch on one subject *within* a session, in the order
it happened. A hold splits an interval but not a run. Not the same as a total:
switching away and back is two runs on one subject.

**Detent** — one whole step of the crown. The reading and the haptic land on
detents; the ring tracks between them.

**Question** — an armed confirmation. The first tap arms it, the second commits,
and it withdraws itself after six seconds.

**Double tap** — the watch's own gesture, index finger and thumb pinched twice.
It runs the **primary action** of the screen in front of you: Start on the Start
screen, Hold on the Running one, Done on the summary. A screen declares at most
one, and it is never the action that deletes something.

**Always-On** — the dimmed state, `isLuminanceReduced`. Not a separate screen:
the same clock with its seconds struck out to dashes, inside bars that keep
their height and lose their controls. Nothing resizes across the crossing; on
the Running screen the whole picture slides down to the middle of what is lit.

## Outside the app

**Snapshot** — the small JSON file in the shared App Group container that the
widget extension reads instead of the database. Written by the app on every
state change.

**Complication** — the app's one widget, in four families. It shows the day
against the goal, and — in `accessoryRectangular`, the family the Smart Stack
shows — the running session and an End button while one is live.

**Session card** — the `accessoryRectangular` complication while a session is
running. Not a second widget: the same card, showing the other of its two
readings. It was a widget of its own until the two were merged.

**Relevance** — the window a widget claims so the Smart Stack surfaces it
unasked. A window, not an event.

**Control** — the Action Button widget that starts a session.

**Intent** — Start, Pause or End as Siri, Shortcuts, the Control and the card's
buttons all run them.

**Extension process** — the widget extension. A separate process from the app,
with its own copy of the model layer and its own caches. See
[`foundations/surfaces.md`](foundations/surfaces.md).

**Frontmost hold** — the extended runtime session the app claims so a wrist
raise mid-session returns to the app rather than the watch face.

## Sync

**Pairing** — claiming a watch from the web by typing the six-character code the
watch shows. It gives the browser a session; it tells the watch nothing.

**Push** — sending completed intervals and the subject list to the server.

**Pull** — reading subjects back. Intervals are never pulled; see
[`bug-triage.md`](bug-triage.md#b-25).

**Device** — the server's row for one watch: its token, its timezone, its goal,
and its profile. Every interval and subject on the server hangs off one. A watch
that has never paired has no device row and does not need one.

**Device token** — the random string the watch generates on first launch and
sends with every request. The only credential in the product. There is no
account, no password and no email; whoever holds the token is the watch.

**Session cookie** — what the browser gets by pairing. It holds the device
token, so a browser and the watch it paired with are the same caller as far as
the server is concerned.

## The profile

**Profile** — the public page a device may claim. Optional, and off until a
handle is taken.

**Handle** — the path segment the profile lives at: three to twenty characters,
lowercase letters, digits and hyphens. Unique across the product, claimed first
come, and claimable **once, ever**: a handle given up is retired rather than
returned to circulation, so an old link can never resolve to somebody else.
Claiming one requires a logged session.

**Retired handle** — one that has been given up in a rename. Permanently
unclaimable, by anyone, including whoever released it.

**Change budget** — the three renames a profile gets. The first claim is free
and does not spend one; a rename refused as taken or reserved does not spend one
either. Spent, the handle is fixed for good.

**Display name** — an optional name shown instead of the handle. Free text, up
to forty characters.

**Stats only** — the default a profile is published under: hours, streak, goal
rate and the shape of the year, with no subject named. **Showing subjects** is
the opt-in that adds the names and their colours.

**Replacing a watch** — moving a profile and its whole history onto a new watch.
The only thing the web is in charge of; see
[`web/replacing-a-watch.md`](web/replacing-a-watch.md).

**Retired** — what the old watch becomes after a replacement. Its token matches
nothing, so it is refused and stops syncing.

## Terms this description avoids

**Paused** — the app's word; this description says *held* when describing
behaviour and quotes "Paused" when describing what is on screen.

**Complete** — reserved for the app's own derived flag, which is *not* the same
as "the countdown reached zero". Where these documents mean the latter they say
*ran to term*. The gap between the two is [B-02](bug-triage.md#b-02).
