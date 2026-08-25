# Diem — watch

watchOS 27, SwiftUI and SwiftData, no iPhone companion.

```sh
brew install xcodegen
xcodegen generate && open Diem.xcodeproj
```

## Layout

| | |
| --- | --- |
| `Diem/Model` | Intervals, subjects, the store, the 4am day, the widget snapshot |
| `Diem/Design` | Palette, typography, number formats, motion, haptics |
| `Diem/Views` | Start, Running, Done, Settings, Metrics, and the shared parts |
| `Diem/Intents` | Start / Pause / End, behind every other surface |
| `Diem/Runtime` | The extended runtime session that holds the foreground |
| `Scripts` | `core-check.sh` — builds and tests the Foundation-only core anywhere |
| `Diem/Sync` | DTOs and the client. Only completed intervals go over the wire |
| `DiemWidget` | Four complication families, the Smart Stack card, the Control |

`Model`, `Design` and `Intents` are compiled into the widget extension too; the
app and the extension share a snapshot file in the `group.app.diem` container
rather than the database. `Runtime` is app-only on purpose — an extension has no
foreground to claim, and a `WKExtendedRuntimeSession` started from one is a
session the system refuses.

## Foundations worth knowing before editing

**Numerals are their own thing.** SF Compact Rounded at `.medium`, always
`.monospacedDigit()`, tracking set per size. `.monospacedDigit()` fixes per-digit
width but not total string width, so every hero numeral reserves the frame of
the widest value its field can hold and centres shorter strings inside it —
nothing moves. Where the unit sits inside the numeral rather than after it —
`1h 30m` — the minutes are zero-padded for the same reason: a group that sizes
to its own value drags the label along with it, and under a fast crown that is
the whole reading skating about. Colons are drawn separately at half opacity,
and each digit group rolls on its own.

**Visible durations and spoken ones are different formatters.** Anything drawn
on screen uses `Format.total(_:)` — `.text` where it needs to be one string
rather than a numeral — so a total and the goal beside it are spelled the same
way. `Format.duration(_:)` is what's left: Siri dialogs and accessibility
values, where the padding that holds a numeral still would be heard as "one h
oh five m". `Format.count(_:)` decides what a running session reads, once, for
the app and the widget both.

**Rolls versus replaces.** A total gets `.numericText(value:)`, so the system
knows both the direction and the size of the jump. A count gets
`.numericText(countsDown:)`, because its direction is fixed and its magnitude
means nothing. When the field itself changes — `59 m` to `1.2 h`, `0:00` to
`+0:00`, today's total to the duration being scrubbed — the numeral is replaced
with `.blurReplace` rather than rolled, because those are different quantities
and rolling one into the other reads as a glitch.

**Direct manipulation is never animated.** The ring binds straight to the crown.
Springs are for discrete state changes, and every one is scoped with
`.animation(_:value:)`.

**Always-On is the same clock with its seconds taken off.** Not a second layout
— the last two digits slide out to the trailing edge, what's left recentres in
the space they gave up, and they slide back on the wake. One layout means the
reading never changes units, size or place between lit and dimmed; only the
controls go, and the ring on the Start screen grows into the room they leave.

**Nothing else moves while dimmed.** A roll queued against a display that
refreshes about once a minute lands as stutter on the next wake. Suppress it at
the animation that would run — the numeral and the arc each check
`isLuminanceReduced` themselves — rather than blanketing a transaction over the
screen: a blanket also clears the animation on a view's own frame, which is
exactly the crossing worth seeing.

**Nothing on a redraw path touches SwiftData.** Every read the store exposes —
`elapsed`, `remaining`, `isPaused`, `activeSubjectID`, `todaySeconds`,
`dailySeconds`, `subject(_:)` — is served from a cache held behind
`@ObservationIgnored` and dropped in `commit()`, which is the only place the log
changes. The running clock redraws once a second and the crown fires far faster
than that; a fetch and a session assembly per read put SwiftData on the critical
path of the numeral roll. A view takes its reading once and passes it down
(`RunningView.Tick`) rather than asking again per element, and a `TimelineView`
schedule is anchored to `@State`, never to `.now`, or every redraw hands it a
new schedule.

**Three rings, two meanings for a turn.** The Start screen at rest is today
against the goal — one revolution is the goal met, and past it the ring laps.
Under the crown, and behind the running clock, one revolution is an hour: the
duration being scrubbed, and the session so far drawn as a bar of coloured runs
bent into a circle, going round again over what is already there. The Start ring
is the day; the running ring is this session, which is what the clock in front
of it is measuring. Check which you are reading before changing either.

**A running session keeps the app.** Not by the app's own choice — a watchOS app
is put away the moment the wrist drops. `SessionRuntime` claims a `mindfulness`
extended runtime session for as long as a session is live, which is the public
way to ask for what the system Timer has: the wrist raise comes back to the
clock that is counting. It is driven off the scene phase as much as off the
session, because the system will only hand the foreground over while the app is
active — so a session started from Siri, the Action Button or the Smart Stack
card claims it when the app is next opened, and there is no earlier moment it
could. An hour is the system's limit and a study session can be longer, so an
expiry that arrives with the session still running claims the next hour.
Crowning out ends it, and that is left ended: the user leaving is not a thing to
argue with, and the system would refuse the argument anyway.

**Relevance is a window, and it has to be asked for.** The Smart Stack surfaces
the session card because `SnapshotProvider.relevance()` claims one — through to
the deadline for a timed session, a rolling twenty minutes for an open-ended
one, and the floor applies to overtime too, where the card matters most and the
deadline is already behind. `.scheduled` is the hint that separates a card the
stack could show from one it puts in front of you. The window itself lives on
`DiemSnapshot.Live` rather than in the widget, because it is arithmetic and the
core is where arithmetic gets tested. And a timeline reload does not re-ask the
question: `commit()` invalidates the card's relevance itself, when — and only
when — a session starts, ends, or moves its deadline.

**Parsing is not type-checking.** `swiftc -parse` was the only check this repo
had, and `Views/Ring.swift` passed it for two releases while handing a subject
id to a function that takes a colour index — a file that could not compile, in
the app's headline feature. `Scripts/core-check.sh` builds and tests everything
that decides a number, on any machine with a Swift toolchain and no Apple SDK.
It cannot reach the views. Run a real build before believing the app compiles,
and prefer putting new arithmetic where the script can see it.

**The accent is never on text.** International Orange in Display P3, on the ring
and the pill fill only. There is deliberately no app-wide tint.
