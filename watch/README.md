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
| `Diem/Sync` | DTOs and the client. Only completed intervals go over the wire |
| `DiemWidget` | Four complication families, the Smart Stack card, the Control |

`Model`, `Design` and `Intents` are compiled into the widget extension too; the
app and the extension share a snapshot file in the `group.app.diem` container
rather than the database.

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

**Always-On is a second layout, not a dimmed copy.** Minutes only, one weight
lighter, tracking loosened, no controls — and no animation at all, because the
display refreshes about once a minute and queued animations land as stutter on
the next wake.

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

**The accent is never on text.** International Orange in Display P3, on the ring
and the pill fill only. There is deliberately no app-wide tint.
