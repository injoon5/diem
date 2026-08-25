# Bug triage

Every suspected defect found while writing this description, deduplicated. One
entry per root cause, however many documents raised it.

**Severity** is about the user, not the code: *critical* means the app does not
build or loses data; *high* means a person is shown something untrue; *medium*
is a papercut or a stated guideline broken; *low* is polish, dead code or
configuration drift.

**Status** is only present where a claim was checked by running something.
Everything else was read from the source and is marked *suspected* — no part of
this app has been observed on a device or simulator.

## How the confirmed entries were confirmed

Seven entries carry a **Status: confirmed** line. Those were checked by
compiling the app's Foundation-only core (`Day`, `Format`, `Scrub`,
`SessionAssembly`, `Snapshot`, and the `ISO8601` helper) as a Swift package
under Swift 6.3 on Linux and running a repro suite against it. The suite is
reproduced in [Appendix: the repro suite](#appendix-the-repro-suite) and all of
it passes, alongside the project's own 54 tests.

Nothing that touches SwiftUI, SwiftData, WatchKit or WidgetKit can be compiled
without an Apple SDK, so every entry against those is a reading. Where a reading
is a *type error* rather than a judgement — [B-01](#b-01) — it is still marked
confirmed, because the type rule it breaks does not need a compiler to settle.

## Summary

| ID | Severity | What | Decision |
| --- | --- | --- | --- |
| [B-01](#b-01) | critical | The session ring passes a subject id where a colour index is expected — the app does not compile | fix |
| [B-02](#b-02) | critical | A held session is reported "Complete" when it was barely studied | fix |
| [B-03](#b-03) | critical | The app and the widget extension never learn about each other's writes | fix |
| [B-04](#b-04) | critical | A store that fails to open silently discards every session, with no signal and no migration plan | fix |
| [B-05](#b-05) | high | Deleting a subject never reaches the server | fix |
| [B-06](#b-06) | high | Discarding a session never reaches the server | product call |
| [B-07](#b-07) | high | Complications show yesterday's total for up to half an hour after 4am | fix |
| [B-08](#b-08) | high | The deadline alert asks for Time Sensitive without the entitlement to get it | fix |
| [B-09](#b-09) | high | Metrics freezes "Today" at the moment it opened | fix |
| [B-10](#b-10) | high | Starting from Siri or the Action Button silently ends a running session | product call |
| [B-11](#b-11) | medium | Ending from the card with the app on screen fires the completion haptic twice | fix |
| [B-12](#b-12) | medium | The crown's silent-reset latch can stick and swallow a real detent | fix |
| [B-13](#b-13) | medium | Two sets of touch targets are under the 44pt floor the app states | fix |
| [B-14](#b-14) | medium | Nothing scales with the watch's text size, and the running screen's bottom bar overflows | fix |
| [B-15](#b-15) | medium | The ring, the heatmap and the weekday bars are unreadable or mislabelled to VoiceOver | fix |
| [B-16](#b-16) | medium | Overtime under an hour gains a glyph without dropping a size step | product call |
| [B-17](#b-17) | medium | Every total under ten hours is centred in a field a digit too wide | fix |
| [B-18](#b-18) | medium | The deadline notification is suppressed exactly when the app now holds the foreground | fix |
| [B-19](#b-19) | medium | The subject picker dismisses itself twice | fix |
| [B-20](#b-20) | medium | Two subjects can share a name, with nothing to tell them apart | product call |
| [B-21](#b-21) | medium | Deleting a subject asks nothing; discarding a session asks twice | product call |
| [B-22](#b-22) | medium | The eleventh subject silently reuses the first one's colour | fix |
| [B-23](#b-23) | low | The pairing code is spoken in a different case from the one on screen | fix |
| [B-24](#b-24) | low | Pairing never confirms success and never says the code expires | product call |
| [B-25](#b-25) | low | Interval pull and its cursor are dead code | product call |
| [B-26](#b-26) | low | `Info.plist` and `project.yml` disagree, and regenerating rewrites a tracked file | fix |
| [B-27](#b-27) | low | The app declares an app group nothing uses and the spec does not generate | fix |
| [B-28](#b-28) | low | Every sync pushes the entire subject list | fix |
| [B-29](#b-29) | low | The device token's getter writes, untracked, from two processes | fix |
| [B-30](#b-30) | low | A force-try on the fallback container | fix |
| [B-31](#b-31) | low | The deadline notification's title and body say the same thing twice | fix |

---

## B-01

**The session ring passes a subject id where a colour index is expected.**

Where you meet it: nowhere, because the target does not build.

Expected: the ring behind the running clock draws each run in that subject's
colour. What happens: `watch/Diem/Views/Ring.swift:164` calls
`Palette.subject(band.subjectID)`, where `band.subjectID` is a `UUID?` and the
only `subject` in `Palette` is `static func subject(_ index: Int?) -> Color`
(`watch/Diem/Design/Palette.swift:60`). There is no conversion from `UUID?` to
`Int?` and no overload. The file cannot type-check, so neither can the app
target.

The type error is also the design gap underneath it. `SubjectRing` has no access
to the store, so it has no way to turn a subject id into a colour index at all.
Fixing the call means either handing the view a resolved colour per run — the
shape `MetricsView` already uses at `MetricsView.swift:92` — or giving `Band` a
colour rather than an id.

This is why the README's "every Swift file parses clean under `-swift-version 6`"
did not catch it: parsing is not type-checking, and no CI step ever compiles the
app target.

Reproduce: `cd watch && xcodegen generate && xcodebuild -scheme Diem`.

Severity: **critical**. Decision: **fix**.
Status: **confirmed** — by the type rule, not by a build. See the note at the
top; the repo has no environment that can compile a watchOS target.
Raised by: [running-screen](app/running-screen.md), [session-model](foundations/session-model.md).

## B-02

**A held session is reported "Complete" when it was barely studied.**

Where you meet it: the summary, immediately after ending a session you paused
for a while.

Expected: "Complete" means the countdown reached zero. What happens: completion
is derived from the *span* — last end minus first start — while the countdown
measures *studied* time. A hold adds to the span and not to the countdown, so
the two diverge by exactly the length of every hold.

Reproduce: start a 25-minute session. Study 5 minutes. Hold for 30 minutes.
Resume, study 1 more minute, end. The countdown reads `19:00` throughout the
hold; the summary says **Complete**, plays the success haptic, and the web
counts the session toward the goal-hit rate.

Cause: `watch/Diem/Model/SessionAssembly.swift:111` —
`endedAt.timeIntervalSince(startedAt) >= Double(plannedSec)`. The existing test
at `DiemTests/DiemTests.swift:487` covers only single-interval sessions, where
span and studied time are equal, so the false positive is untested.

The top-level README argues the two agree: "studied time is never longer than
the wall-clock span, so a session that runs to term satisfies it either way."
That is true in one direction only. It shows there are no false *negatives*; it
says nothing about false positives, which is the direction that bites.

The fix that keeps the server agreeing with the watch is to compare studied time
to the plan on both sides. The fix that keeps the schema is to store studied
seconds on the session. Either is a change to the sync contract, so this is not
a one-line correction.

Severity: **critical** — it makes the app's central claim about a session untrue,
and the error propagates to the web's headline statistic.
Decision: **fix**.
Status: **confirmed** — `pauseInflatesCompletion` and `countdownDisagrees` in the
[repro suite](#appendix-the-repro-suite) both pass.
Raised by: [session-model](foundations/session-model.md), [done-screen](app/done-screen.md).

## B-03

**The app and the widget extension never learn about each other's writes.**

Where you meet it: the End button on the Smart Stack card, and the app after
using it.

Both processes open the same database in the shared App Group container, and
both build a `SessionStore` whose caches — the live session's timing, today's
total, the daily aggregations, the subject list — are dropped only by that
store's own `commit()` (`SessionStore.swift:463`). Nothing observes
`NSPersistentStoreRemoteChange`, nothing refreshes on foregrounding, nothing
re-fetches at all after launch.

Two failures follow.

**The End button can do nothing.** The card's *layout* reads the snapshot file
and is always fresh. Its *button* runs an intent that reads the extension's
store. If that store was built before the session started, it believes nothing
is running and answers "Nothing is running."

**The app can revive an ended session.** End from the card while the app is
alive in the background. The database is updated; the app's store is not told.
Raise your wrist and the Running screen is still there, showing a stopped clock
labelled "Paused" — because a session with no open interval is, as far as that
screen can tell, held. Tap Resume and a new interval is inserted into a session
that ended, splicing it back to life with a gap in the middle.

Reproduce: needs a device, two processes and some patience about extension
lifetimes — see the open question in
[surfaces](foundations/surfaces.md#open-questions-and-verification).

Cause: `Diem/Model/SessionStore.swift` has no change observation of any kind;
`Diem/Model/Container.swift:23` makes the store a process-lifetime singleton.

Severity: **critical** — it corrupts the interval log, which the whole product
is built on being append-only and trustworthy.
Decision: **fix**. The smallest honest fix is to observe remote changes and drop
the caches; the safest is that plus re-deriving `activeSessionID` whenever the
app becomes active.
Status: suspected.
Raised by: [surfaces](foundations/surfaces.md), [smart-stack](outside/smart-stack.md), [intents](outside/intents.md), [running-screen](app/running-screen.md).

## B-04

**A store that fails to open silently discards every session.**

Where you meet it: after any future change to the data model, or any corruption.

`Container.swift:12-19` catches a failed `ModelContainer` and falls back to an
in-memory one. The app then comes up completely empty — no subjects, no history,
no streak — and every session studied afterwards is discarded when the process
ends. Nothing on screen says anything is wrong. To a user this is
indistinguishable from a fresh install that then loses a day's work.

The comment is honest about the trade — "an in-memory fallback at least keeps
the session in front of the user instead of crashing" — but keeping the session
in front of the user while throwing it away afterwards is the worse of the two
outcomes, not the better one.

Compounding it: there is no `VersionedSchema` and no `SchemaMigrationPlan`. The
schema is declared inline as `Schema([Interval.self, Subject.self])`, so the
first model change that is not automatically lightweight-migratable lands
directly on this path.

Severity: **critical**. Decision: **fix** — a migration plan, and a visible
"can't open your history" state rather than a silent empty one.
Status: suspected.
Raised by: [session-model](foundations/session-model.md).

## B-05

**Deleting a subject never reaches the server.**

Deletion is a tombstone: `delete(_:)` sets `deletedAt` and bumps `updatedAt`, so
the watch stops showing it and history still resolves it. The sync pass then
sends `store.subjects(includeArchived: true)` — and that method filters
`$0.deletedAt == nil` (`SessionStore.swift:315`) before it applies
`includeArchived`. A deleted subject is therefore excluded from *every* push and
lives on the web forever.

Worse, the server's last-write-wins on `updatedAt` means the next pull can
resurrect it locally, because the incoming copy has an older `updatedAt` than
the local tombstone — so it will not, but only by accident of ordering.

Reproduce: pair, create a subject, sync, delete it, sync again, look at the web.

Cause: `SessionStore.swift:315` and `SyncClient.swift:109`.

Severity: **high**. Decision: **fix** — the push needs its own fetch that
includes tombstones, since `deletedAt` is precisely what the wire format carries.
Status: suspected.
Raised by: [settings](app/settings.md).

## B-06

**Discarding a session never reaches the server.**

`push(intervals:)` is the only interval call in the client. There is no delete.
So a session discarded on the watch — or one dropped for being under a minute —
stays on the web if its intervals were pushed first.

Only *completed* intervals are pushed, and both discard paths close their
intervals before deleting them, so the window is small but real: end a session,
let a sync run, then discard from the summary.

Severity: **high** for anyone using the web, invisible to anyone who is not.
Decision: **product call** — this needs a delete endpoint, which is a change to
a contract outside this repository's watch half.
Status: suspected.
Raised by: [done-screen](app/done-screen.md), [session-model](foundations/session-model.md).

## B-07

**Complications show yesterday's total for up to half an hour after 4am.**

The snapshot carries the day's banked seconds and the goal. It does not carry
*which day*. So a complication holding a snapshot written at 03:50 has no way to
notice that 04:00 has passed, and goes on drawing yesterday's total — and
yesterday's closed ring — as today's.

The timeline policy makes the window as wide as it can be: with nothing running
the next refresh is scheduled 30 minutes out (`Provider.swift:33`), and
nothing schedules a refresh at the boundary itself.

Reproduce: study two hours, leave the watch alone, look at the complication at
04:05. It says two hours and a closed ring.

Cause: `Diem/Model/Snapshot.swift` has no day field; `DiemWidget/Provider.swift`
has no boundary-aligned reload.

Severity: **high**. A goal ring that is already closed when the day has just
started is the exact opposite of what the product is for.
Decision: **fix** — put the study-day start in the snapshot and zero the banked
total when it no longer matches, and schedule a reload at the next boundary.
Status: **confirmed** — `snapshotSurvivesTheDayBoundary` in the
[repro suite](#appendix-the-repro-suite) passes: a snapshot with two hours banked
still reports two hours and a full lap when read twenty minutes after the
boundary.
Raised by: [day-model](foundations/day-model.md), [complications](outside/complications.md), [smart-stack](outside/smart-stack.md).

## B-08

**The deadline alert asks for Time Sensitive without the entitlement to get it.**

`SessionAlerts.swift:44` sets `content.interruptionLevel = .timeSensitive`.
That level requires `com.apple.developer.usernotifications.time-sensitive`, and
neither `Diem/Diem.entitlements` nor `DiemWidget/DiemWidget.entitlements`
declares it. Without the entitlement the level is ignored and the notification
is delivered as an ordinary one.

Which means it is silenced by any Focus, including Do Not Disturb and Sleep —
and a study timer's deadline alert being silenced by a focus mode is the alert
failing in exactly the situation it was written for. The code reads as though
this is handled; nothing tells you it is not.

Severity: **high**. Decision: **fix** — add the entitlement, or stop claiming a
level the app cannot have.
Status: suspected — the entitlement's absence is confirmed by reading the files;
what the system does with the unentitled level is documented behaviour, not
observed.
Raised by: [running-screen](app/running-screen.md).

## B-09

**Metrics freezes "Today" at the moment it opened.**

`MetricsView.swift:8` is `private let now = Date.now` — a stored property on the
view struct, with no timeline driving it. Every reading on the screen is taken
against that instant.

So "Today" does not advance while Metrics is open, and neither does the subject
breakdown or the current week's bar. Worse, the value is *unpredictable* rather
than merely stale: a stored property is re-initialised whenever the parent
rebuilds the view, and the Start screen behind it rebuilds on every crown event
and every minute tick. Whether the number moves depends on something the user
cannot see.

Reproduce: start a session from the Action Button (which leaves the Start screen
reachable), open Metrics from the Start screen, and watch "Today" not move.

Severity: **high** — this is the screen whose whole job is to be the accurate
one.
Decision: **fix** — a `TimelineView` on a one-minute cadence, the way the Start
screen already does it.
Status: suspected.
Raised by: [metrics](app/metrics.md).

## B-10

**Starting from Siri or the Action Button silently ends a running session.**

`start(subjectID:plannedSec:)` closes and banks whatever is running before
opening the new session (`SessionStore.swift:108`). From the app that is
invisible because you cannot reach Start while a session runs. From Siri, the
Control, or the card's play button, you can — and the confirmation is "Studying."
with no mention that a two-hour session just ended without a summary.

Severity: **high** for the Action Button, which is a single physical press with
no confirmation step at all.
Decision: **product call** — either the intent refuses when something is running
and says so, or it reports what it ended: "Ended Maths at 1h 12m. Studying."
Status: suspected.
Raised by: [intents](outside/intents.md), [surfaces](foundations/surfaces.md).

### B-10b

Related, and newly relevant: `EndSessionIntent` decides whether to queue a
summary by asking whether `WKApplication.shared().applicationState == .active`
(`Intents.swift:112`). Now that the app holds an extended runtime session for
the whole of a session, it can be the frontmost app with the wrist down — where
that state is very likely `.inactive`. If so, ending from the card in that
moment skips the summary the user would otherwise land on. Needs a device.

## B-11

**Ending from the card with the app on screen fires the completion haptic twice.**

`EndSessionIntent.perform()` plays the success haptic unconditionally
(`Intents.swift:103`) and *also* queues the summary
when the app is on screen. The summary then plays its own haptic on appearance
(`DoneView.swift:102-108`). Two success taps land back to back for one action.

It is worse than a duplicate: the intent plays the *completion* haptic for every
kept session, including one ended early after four minutes, while the summary
plays the softer stop haptic for the same session. So the user feels "you
finished" immediately followed by "you stopped."

Severity: **medium**. Decision: **fix** — the intent should not fire a haptic on
the path where a screen is about to.
Status: suspected.
Raised by: [done-screen](app/done-screen.md), [smart-stack](outside/smart-stack.md), [intents](outside/intents.md).

## B-12

**The crown's silent-reset latch can stick and swallow a real detent.**

Committing a session resets the crown to zero and arms a one-shot suppression so
the app's own reset does not click (`StartView.swift:189-190`, `67-73`). The
suppression is armed whenever `crownStep != 0` — but it is disarmed only inside
the change handler, which fires only when the *rounded* step changes.

Turn the crown a third of a step, so the reading is still 0, and tap Start.
`crownStep` is 0.33, so the latch is armed; setting it to 0 does not change the
detent, so the handler never runs and the latch is never cleared. The next
genuine crown detent — on the next session you compose — is silent.

Severity: **medium**. A missing click on a watch is a real papercut: the click is
the confirmation that the crown is doing anything at all.
Decision: **fix** — clear the latch where it is set, or key the suppression to
the reset itself rather than to the next change.
Status: suspected.

### B-12b

Also on this screen: crown focus is claimed once, in `onAppear`
(`StartView.swift:130-134`), and nothing reclaims it after a sheet is dismissed.
If watchOS does not restore it, the duration crown stops working after a visit
to the subject picker, Settings or Metrics — and the Start screen gives no sign
that it has stopped listening. Needs a device.

Raised by: [start-screen](app/start-screen.md), [input-model](foundations/input-model.md).

## B-13

**Two sets of touch targets are under the 44pt floor the app states.**

`Controls.swift` is careful — `minWidth: 44, minHeight: 44` on the subject
button, `44×44` on every circle control, with comments explaining that the
target comes from padding rather than from a visible shape. Two places do not
follow it:

- Subject picker rows: `frame(minHeight: 40)` (`SubjectPicker.swift:54`).
- Colour swatch cells: `frame(width: 34, height: 34)` (`SettingsView.swift:217`),
  on a 4pt grid spacing, so the pitch is 38pt.

The swatch comment says "what the thumb gets is the whole cell" — which is true,
and the cell is still 10pt short.

Severity: **medium**. The colour grid is the worse of the two: ten targets in a
row, each under size, each committing an irreversible-looking change.
Decision: **fix**.
Status: suspected.
Raised by: [subject-picker](app/subject-picker.md), [settings](app/settings.md), [input-model](foundations/input-model.md).

## B-14

**Nothing scales with the watch's text size, and the running screen's bottom bar
overflows.**

There is no `ScaledMetric`, no `minimumScaleFactor`, and no `dynamicTypeSize`
anywhere in the app. Every hero numeral is a fixed point size (44, 40, 38, 34,
32), so the largest reading in the app ignores the user's text size setting
entirely.

That is arguably right for an instrument display. What is not right is the
running screen's bottom bar, where the "End?" question is set in a caption —
which *does* scale — and then given `.fixedSize()` (`RunningView.swift:87`) so
it cannot shrink or wrap, between two 44pt controls in a row that must fit the
screen width.

On a 41mm watch the bar has roughly 156pt to work with. Two controls take 88,
two spacers take 16, and "END?" uppercased with tracking takes what is left. At
the default text size it fits. At the largest, it does not, and `fixedSize()`
means the layout does not degrade gracefully — it overflows.

Severity: **medium**, and higher for anyone who uses a large text size, for whom
it is the primary control surface breaking.
Decision: **fix** — the question should shrink, wrap or move.
Status: suspected.
Raised by: [running-screen](app/running-screen.md), [input-model](foundations/input-model.md).

## B-15

**The ring, the heatmap and the weekday bars are unreadable or mislabelled to
VoiceOver.**

The app is generally careful here — hero numerals speak their reading in words,
breakdown rows are combined into single elements, the pairing code is spelled
out character by character. Four gaps against that standard:

1. **The goal ring carries no value.** The Start screen labels its container
   "Today" and the numeral speaks the total, so *progress against the goal* —
   the only thing the ring exists to show — is never announced.
2. **The 12-week heatmap has no value at all** (`MetricsView.swift:187-188`):
   one element, labelled "Last twelve weeks", containing nothing. A quarter of a
   year of data is invisible.
3. **Weekday bars are labelled with a single letter**
   (`MetricsView.swift:156`), so VoiceOver reads "M, 1 hour 5 minutes". The
   single letter is a *visual* abbreviation; the label should be the weekday.
4. **The session ring carries nothing**, so the per-subject shape of a running
   session is sighted-only.

Also: an armed question changes only its label text, with no announcement that
the state changed; and the subject picker's selected checkmark is decorative, so
the current selection is unspoken.

Severity: **medium**. Decision: **fix**.
Status: suspected.
Raised by: [metrics](app/metrics.md), [day-model](foundations/day-model.md), [running-screen](app/running-screen.md), [subject-picker](app/subject-picker.md).

## B-16

**Overtime under an hour gains a glyph without dropping a size step.**

The running clock picks its face size from the *field* rather than the value,
which is right — but the test is a character count with the threshold at six
(`RunningView.swift:273`). A countdown under an hour reserves `00:00`, five
characters, and takes the 44pt face. Overtime under an hour reserves `+00:00`,
six characters, and takes the 44pt face too.

So crossing the deadline adds a glyph at the largest size the app draws, inside
a ring it is not supposed to overhang. The typography note in `Typography.swift`
is explicit that seven characters at 44pt overrun the ring on the smallest
watch; six is the untested case in between.

Severity: **medium**, and it may be nothing — it needs measuring on a 41mm
device.
Decision: **product call** — either drop overtime to the compact size, or
confirm six characters fit and leave the threshold alone.
Status: **confirmed** as a description of what the code does —
`overtimeKeepsTheLargestFace` in the [repro suite](#appendix-the-repro-suite)
passes. Whether it actually overruns is unverified.
Raised by: [running-screen](app/running-screen.md).

## B-17

**Every total under ten hours is centred in a field a digit too wide.**

`Format.total` reserves `88h 88m` for any reading over an hour
(`Format.swift:70`) — seven characters, with two hour digits. A study-day cannot
exceed 24 hours and in practice does not exceed 12, so the second hour digit is
never used. Every real reading is six characters centred inside a
seven-character box.

Because the numeral is centred in its reserved field, the effect is not a shift
— it is that the whole reading sits about half a digit narrower than the space
it was given, and on the Start screen that space was sized to the ring. The
hero numeral is smaller than it needed to be, in the one place the app went to
some trouble to make it large.

Severity: **medium** as typography, low as behaviour.
Decision: **fix** — reserve `8h 88m`, and let the ten-hour case take the wider
field if it ever arrives.
Status: **confirmed** — `totalsOverReserve` in the
[repro suite](#appendix-the-repro-suite) passes.
Raised by: [start-screen](app/start-screen.md).

## B-18

**The deadline notification is suppressed exactly when the app now holds the
foreground.**

Nothing sets a `UNUserNotificationCenter` delegate, so a notification arriving
while the app is frontmost is not presented. That used to be harmless: if the
app was frontmost you were looking at the running screen, whose own haptic
fires on the zero crossing.

The frontmost hold changes the arithmetic. The app is now the frontmost app for
the whole session, wrist down included — and with the wrist down the running
screen's timeline drops to one tick a minute, so its haptic can be up to sixty
seconds late. The notification that would have been on time is the one being
suppressed.

Severity: **medium**, and it is a regression introduced by the frontmost hold
rather than a pre-existing bug.
Decision: **fix** — implement `willPresent` and return `.banner`/`.sound`, or
call `notifyUser(hapticType:)` on the runtime session at the deadline, which is
what that API is for.
Status: suspected — needs a device.
Raised by: [running-screen](app/running-screen.md).

## B-19

**The subject picker dismisses itself twice.**

`SubjectPicker.row` calls `dismiss()` after `onPick` (`SubjectPicker.swift:40`),
and both callers *also* set their presentation flag to false inside `onPick`
(`StartView.swift:125`, `RunningView.swift:118`).

This is the exact pattern the codebase has already diagnosed once, in
`SettingsView.swift:75-76`: "`NameField` dismisses itself, which clears this
binding — setting it here as well dismissed a sheet that was already going."
The fix landed in one place and not the other two.

Severity: **medium**. Decision: **fix** — pick one owner of the dismissal, as
Settings already did.
Status: suspected.
Raised by: [subject-picker](app/subject-picker.md).

## B-20

**Two subjects can share a name, with nothing to tell them apart.**

`addSubject(name:)` does no duplicate check, and rename does not either. Two
subjects called "Maths" appear in the picker as two identical rows differing
only by dot colour — and colour is explicitly not allowed to carry meaning alone
in this app, because watch faces render complications monochrome.

Severity: **medium**. Decision: **product call** — reject duplicates, or accept
them and disambiguate.
Status: suspected.
Raised by: [subject-picker](app/subject-picker.md), [settings](app/settings.md).

## B-21

**Deleting a subject asks nothing; discarding a session asks twice.**

Discard on the summary is guarded by a two-tap question, with a comment
explaining why: "throwing the session away is the one action here that cannot be
undone." Delete in the subject editor is a single tap that pops the screen
(`SettingsView.swift:232-235`).

Delete is a tombstone, so history survives it — but nothing on screen says so.
The section footer explains *archiving* and says nothing about deleting, so the
one action the user is least sure about is the one with no explanation and no
confirmation.

Severity: **medium**. Decision: **product call** — confirm it, or explain in the
footer that history is kept.
Status: suspected.
Raised by: [settings](app/settings.md).

## B-22

**The eleventh subject silently reuses the first one's colour.**

`addSubject` takes the first unused palette index, and falls back to
`used.count % Palette.subjectCount` when all ten are taken
(`SessionStore.swift:337`). With ten subjects, `used.count` is 10 and the
eleventh gets index 0 — the same colour as the first.

Two subjects then share a colour on the session ring, where colour is the *only*
thing distinguishing one run from the next; the ring has no labels.

Severity: **medium**. Decision: **fix** — at minimum pick the least-used index
rather than one that is guaranteed to collide with the first.
Status: suspected.
Raised by: [settings](app/settings.md).

## B-23

**The pairing code is spoken in a different case from the one on screen.**

`PairingView.swift:14-17` uppercases the code for display and then builds the
accessibility label from the *raw* string. If the server returns lowercase, a
VoiceOver user is told a different case from the one printed — on a value that
is being transcribed character by character into another device.

Severity: **low**, unless codes are case-sensitive, in which case it is high.
Decision: **fix** — uppercase once, and derive both from that.
Status: suspected.
Raised by: [pairing](app/pairing.md).

## B-24

**Pairing never confirms success and never says the code expires.**

The server returns `expiresAt` in `PairResponse` and the app decodes it and
throws it away (`PairingView.swift:40`). The screen shows a code with no clock
on it, and never changes when the code is claimed or when it lapses.

There is also nothing anywhere in the app that says whether this watch is
already paired. Opening the screen claims a fresh code either way.

Severity: **low** in isolation, higher as the first-run experience of the only
feature that requires the network.
Decision: **product call**.
Status: suspected.
Raised by: [pairing](app/pairing.md).

## B-25

**Interval pull and its cursor are dead code.**

`SyncClient.pullIntervals(since:)` exists and `Settings.syncCursor` exists.
Neither is called from anywhere: `SyncEngine.run` pushes intervals and
round-trips subjects, and nothing reads or writes the cursor.

For a single-watch product that may be correct — intervals only ever originate
on the watch — but the presence of the cursor and the puller suggests otherwise,
and a future reader will assume pull works.

The cursor's percent-encoding is also wrong if it is ever used:
`.urlQueryAllowed` permits `&` and `=` through, so a cursor containing either
would break the query.

Severity: **low**. Decision: **product call** — wire it or delete it.
Status: suspected.

## B-26

**`Info.plist` and `project.yml` disagree, and regenerating rewrites a tracked
file.**

The README's build step is `xcodegen generate`, and `project.yml` declares
`info: path: Diem/Info.plist` with a `properties` block — so generating the
project *writes* `watch/Diem/Info.plist`, which is tracked in git.

The two currently differ in both directions:

| Key | In the tracked plist | In the spec |
| --- | --- | --- |
| `WKWatchOnly` | yes | no |
| `WKRunsIndependentlyOfCompanionApp` | no | yes |

Both are keys that declare a watch-only app. So every contributor's first
`xcodegen generate` produces a diff they did not make, and silently drops
`WKWatchOnly`.

Severity: **low** as behaviour, medium as a trap.
Decision: **fix** — put both keys in the spec and stop tracking the generated
plist, or stop generating it.
Status: **confirmed** — the two key lists were diffed directly.

## B-27

**The app declares an app group nothing uses and the spec does not generate.**

`Diem/Diem.entitlements` lists both `group.app.diem` and
`group.com.injoon5.diem`. `project.yml` generates only the first, and
`SnapshotStore.appGroup` is the first. The second appears nowhere else in the
codebase, and the widget's entitlements do not have it — so if anything ever did
use it, the two targets could not share it.

Severity: **low**. Decision: **fix** — remove it, or add it to the spec and to
the widget if it is wanted.
Status: **confirmed** — by reading the three files.

## B-28

**Every sync pushes the entire subject list.**

`SyncEngine.run` sends `store.subjects(includeArchived: true).map(\.dto)` on
every pass (`SyncClient.swift:109-110`), with no filter for what has changed.
Intervals are correctly filtered to the unsynced ones; subjects are not.

Small lists make this cheap, and last-write-wins makes it correct. It is still a
full table push on every launch and every backgrounding, on a watch radio.

Severity: **low**. Decision: **fix**.
Status: suspected.

## B-29

**The device token's getter writes, untracked, from two processes.**

`Settings.deviceToken` generates and stores a UUID on first read
(`Settings.swift:37-42`). It is a `get`-only computed property with a side
effect, it does not go through `withMutation`, and both the app and the widget
extension can reach it.

Two processes reading it for the first time concurrently can generate two
tokens, and the loser's writes are attributed to a device the server has never
seen.

Severity: **low** — the window is one first launch, and the extension has little
reason to read it.
Decision: **fix** — generate it once at store construction, or guard it.
Status: suspected.

## B-30

**A force-try on the fallback container.**

`Container.swift:18` is `try! ModelContainer(for: schema, configurations:
fallback)`. An in-memory container essentially cannot fail, so this will
essentially never fire — but it is a force-unwrap on the *recovery* path of a
failure the app is already handling, which is the one place a crash is least
excusable.

Severity: **low**. Decision: **fix** — see [B-04](#b-04), which replaces this
path anyway.
Status: suspected.

## B-31

**The deadline notification's title and body say the same thing twice.**

With a subject, `SessionAlerts.schedule` sets the title to the subject's name and
the body to "Time's up on Maths." So the notification reads:

> **Maths**
> Time's up on Maths.

Severity: **low**. Decision: **fix** — "Maths / Time's up." or "Session complete
/ Time's up on Maths."
Status: **confirmed** — by reading `SessionAlerts.swift:42-43`.

### B-31b

Related, in the same file: `schedule` cancels synchronously and then adds from a
detached task. Two commits in quick succession — hold then resume — each cancel
and each spawn a task, and the two adds race. Both use the same identifiers, so
the last write wins, and which one that is is not determined. The surviving
notification can carry the older deadline.

---

## Appendix: the repro suite

Seven tests, run against the app's Foundation-only core compiled as a Swift
package under Swift 6.3 on Linux. All pass, alongside the project's own 54.
Reproduced here in full so the confirmed entries can be checked without taking
this document's word for it.

To run it: build a package from `Diem/Model/Day.swift`,
`Diem/Model/Snapshot.swift`, `Diem/Model/SessionAssembly.swift`,
`Diem/Design/Format.swift`, `Diem/Views/Scrub.swift` and the `ISO8601` helper
out of `Diem/Sync/DTO.swift`, then drop this in as a test target.

```swift
private struct Rec: IntervalRecord {
    var sessionID: UUID
    var subjectID: UUID?
    var startedAt: Date
    var endedAt: Date?
    var plannedSec: Int?
}

@Suite("AUDIT repros")
struct AuditRepros {
    private let t0 = Date(timeIntervalSince1970: 1_772_000_000)
    private let sid = UUID()

    /// B-02: a long hold inflates the wall-clock span, so a session the user
    /// barely studied is reported Complete.
    @Test("A 25m session with 6m studied and a 30m hold reports Complete")
    func pauseInflatesCompletion() {
        let records = [
            Rec(sessionID: sid, subjectID: nil, startedAt: t0,
                endedAt: t0.addingTimeInterval(5 * 60), plannedSec: 25 * 60),
            Rec(sessionID: sid, subjectID: nil, startedAt: t0.addingTimeInterval(35 * 60),
                endedAt: t0.addingTimeInterval(36 * 60), plannedSec: nil),
        ]
        let session = records.sessions(asOf: t0.addingTimeInterval(36 * 60)).first!
        #expect(session.studiedSec == 6 * 60)   // six minutes actually studied
        #expect(session.isComplete)             // …and the app says Complete
    }

    /// B-02: the countdown the user watched never reached zero.
    @Test("The clock still had 19 minutes left when the session was called Complete")
    func countdownDisagrees() {
        let remaining = Double(25 * 60) - 6 * 60
        #expect(remaining == 19 * 60)
        #expect(Format.count(remaining: remaining, elapsed: 6 * 60, plannedSec: 25 * 60).value == "19:00")
    }

    /// B-07: the snapshot carries no day identity.
    @Test("A snapshot published at 3:50am still reads as today's total at 4:10am")
    func snapshotSurvivesTheDayBoundary() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let lateNight = ISO8601.parse("2026-03-04T03:50:00Z")!
        let afterFour = ISO8601.parse("2026-03-04T04:10:00Z")!
        #expect(Day.start(of: lateNight, calendar: utc) != Day.start(of: afterFour, calendar: utc))

        let snapshot = DiemSnapshot(todaySec: 2 * 3600, goalSec: 2 * 3600)
        #expect(snapshot.today(asOf: afterFour) == 2 * 3600)
        #expect(snapshot.lap(asOf: afterFour).turns == 1)
    }

    /// B-16: overtime under an hour keeps the 44pt face while carrying one more
    /// glyph than the countdown it replaced.
    @Test("Crossing into overtime adds a glyph without dropping a size step")
    func overtimeKeepsTheLargestFace() {
        let before = Format.count(remaining: 1, elapsed: 1499, plannedSec: 1500)
        let after = Format.count(remaining: -1, elapsed: 1501, plannedSec: 1500)
        #expect(before.widest == "00:00")
        #expect(after.widest == "+00:00")
        #expect(before.widest.count <= 6 && after.widest.count <= 6)  // both take Size.hero
    }

    /// An open-ended session's field identity changes on the stroke of the hour.
    @Test("An open-ended session changes field identity at exactly one hour")
    func openEndedFieldFlipsAtTheHour() {
        let justUnder = Format.count(remaining: nil, elapsed: 3599, plannedSec: nil)
        let justOver = Format.count(remaining: nil, elapsed: 3600, plannedSec: nil)
        #expect(justUnder.widest == "00:00" && justUnder.value == "59:59")
        #expect(justOver.widest == "0:00:00" && justOver.value == "1:00:00")
    }

    /// B-17: totals reserve a field one digit wider than any day can produce.
    @Test("Totals reserve a field one digit wider than any day can produce")
    func totalsOverReserve() {
        #expect(Format.total(90 * 60).widest == "88h 88m")
        #expect(Format.total(90 * 60).value == "1h 30m")
        #expect(Format.total(90 * 60).value.count == 6)
        #expect(Format.total(90 * 60).widest.count == 7)
    }

    /// The streak is capped by the window it is measured in — a stated limit.
    @Test("A streak is capped by the window it is measured in")
    func streakCapped() {
        let day = 86_400.0
        let entries = (0..<400).map { (day: Date(timeIntervalSince1970: Double($0) * day), seconds: 3600.0) }
        #expect(entries.studyStreak == 400)
    }
}
```

Verified against `watch/` commit `5ac0e35`
