# Bug triage

Every suspected defect found while writing this description, deduplicated. One
entry per root cause, however many documents raised it.

**Severity** is about the user, not the code: *critical* means the app does not
build or loses data; *high* means a person is shown something untrue; *medium*
is a papercut or a stated guideline broken; *low* is polish, dead code or
configuration drift.

**Status** records how the claim was established when it was found. It is not
changed by the fix; a suspected defect that was fixed on the strength of a
reading is still a reading, and the verification checklists are what turn it
into an observation.

**Every entry here is fixed.** Each carries a *Resolution* line saying what
changed. The diagnosis above it describes the code **as it was found**, in the
present tense it was written in — a triage file is a record of what was wrong,
and rewriting the diagnoses into the past would lose the only account of why the
fix looks the way it does. Read the summary table's **State** column for what is
true now.

## How the confirmed entries were confirmed

Seven entries carry a **Status: confirmed** line. Those were checked by
compiling the app's Foundation-only core (`Day`, `Format`, `Scrub`,
`SessionAssembly`, `Snapshot`, and the `ISO8601` helper) as a Swift package
under Swift 6.3 on Linux and running a repro suite against it. The suite is
reproduced in [Appendix: what happened to the repro suite](#appendix-what-happened-to-the-repro-suite) and all of
it passes, alongside the project's own 54 tests.

Nothing that touches SwiftUI, SwiftData, WatchKit or WidgetKit can be compiled
without an Apple SDK, so every entry against those is a reading. Where a reading
is a *type error* rather than a judgement — [B-01](#b-01) — it is still marked
confirmed, because the type rule it breaks does not need a compiler to settle.

## Summary

| ID | Severity | What | Decision | State |
| --- | --- | --- | --- | --- |
| [B-01](#b-01) | critical | The session ring passes a subject id where a colour index is expected — the app does not compile | fix | fixed |
| [B-02](#b-02) | critical | A held session is reported "Complete" when it was barely studied | fix | fixed |
| [B-03](#b-03) | critical | The app and the widget extension never learn about each other's writes | fix | fixed |
| [B-04](#b-04) | critical | A store that fails to open silently discards every session, with no signal and no migration plan | fix | fixed |
| [B-05](#b-05) | high | Deleting a subject never reaches the server | fix | fixed |
| [B-06](#b-06) | high | Discarding a session never reaches the server | product call | fixed |
| [B-07](#b-07) | high | Complications show yesterday's total for up to half an hour after 4am | fix | fixed |
| [B-08](#b-08) | high | The deadline alert asks for Time Sensitive without the entitlement to get it | fix | fixed |
| [B-09](#b-09) | high | Metrics freezes "Today" at the moment it opened | fix | fixed |
| [B-10](#b-10) | high | Starting from Siri or the Action Button silently ends a running session | product call | fixed |
| [B-11](#b-11) | medium | Ending from the card with the app on screen fires the completion haptic twice | fix | fixed |
| [B-12](#b-12) | medium | The crown's silent-reset latch can stick and swallow a real detent | fix | fixed |
| [B-13](#b-13) | medium | Two sets of touch targets are under the 44pt floor the app states | fix | fixed |
| [B-14](#b-14) | medium | Nothing scales with the watch's text size, and the running screen's bottom bar overflows | fix | fixed |
| [B-15](#b-15) | medium | The ring, the heatmap and the weekday bars are unreadable or mislabelled to VoiceOver | fix | fixed |
| [B-16](#b-16) | medium | Overtime under an hour gains a glyph without dropping a size step | product call | fixed |
| [B-17](#b-17) | medium | Every total under ten hours is centred in a field a digit too wide | fix | fixed |
| [B-18](#b-18) | medium | The deadline notification is suppressed exactly when the app now holds the foreground | fix | fixed |
| [B-19](#b-19) | medium | The subject picker dismisses itself twice | fix | fixed |
| [B-20](#b-20) | medium | Two subjects can share a name, with nothing to tell them apart | product call | fixed |
| [B-21](#b-21) | medium | Deleting a subject asks nothing; discarding a session asks twice | product call | fixed |
| [B-22](#b-22) | medium | The eleventh subject silently reuses the first one's colour | fix | fixed |
| [B-23](#b-23) | low | The pairing code is spoken in a different case from the one on screen | fix | fixed |
| [B-24](#b-24) | low | Pairing never confirms success and never says the code expires | product call | fixed |
| [B-25](#b-25) | low | Interval pull and its cursor are dead code | product call | fixed |
| [B-26](#b-26) | low | `Info.plist` and `project.yml` disagree, and regenerating rewrites a tracked file | fix | fixed |
| [B-27](#b-27) | low | The app declares an app group nothing uses and the spec does not generate | fix | fixed |
| [B-28](#b-28) | low | Every sync pushes the entire subject list | fix | fixed |
| [B-29](#b-29) | low | The device token's getter writes, untracked, from two processes | fix | fixed |
| [B-30](#b-30) | low | A force-try on the fallback container | fix | fixed |
| [B-31](#b-31) | low | The deadline notification's title and body say the same thing twice | fix | fixed |

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

**Resolution.** `SubjectRing` now takes runs with the colour already looked up (`SubjectRing.Run`), and `RunningView` resolves each one through the store — the shape `MetricsView` already used. The band walk also skips a run of no length, which could otherwise move the cursor without drawing anything. `Scripts/core-check.sh` was added so the Foundation-only core is *type-checked* rather than only parsed; it cannot cover the views, and the script says so.

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
hold; the summary says **Complete** and plays the success haptic.

> **Correction.** This entry originally added "and the web counts the session
> toward the goal-hit rate." That was wrong, and checking it while fixing is
> what caught it: the web never derives session completion at all. `hitRate`
> compares a *day's* studied seconds to the goal, and a day's seconds are summed
> from intervals — which is the right number, and always was. `planned_sec` is
> stored on the server and read by nothing. The defect is the watch's summary
> and its haptic, and it stops there.

Cause: `watch/Diem/Model/SessionAssembly.swift:111` —
`endedAt.timeIntervalSince(startedAt) >= Double(plannedSec)`. The existing test
at `DiemTests/DiemTests.swift:487` covers only single-interval sessions, where
span and studied time are equal, so the false positive is untested.

The top-level README argues the two agree: "studied time is never longer than
the wall-clock span, so a session that runs to term satisfies it either way."
That is true in one direction only. It shows there are no false *negatives*; it
says nothing about false positives, which is the direction that bites.

Because nothing else reads the flag, the fix is exactly one comparison.

Severity: **critical** — it makes the app's central claim about a session
untrue. Not the web's, per the correction above.
Decision: **fix**.
Status: **confirmed** — `pauseInflatesCompletion` and `countdownDisagrees` in the
[repro suite](#appendix-what-happened-to-the-repro-suite) both pass.
Raised by: [session-model](foundations/session-model.md), [done-screen](app/done-screen.md).

**Resolution.** `Session.isComplete` compares studied time to the plan. The web never derived completion at all — its goal-hit rate is per-day studied seconds, which was always right — so nothing on the wire had to change. The original claim in this entry that the web counted these sessions was **wrong**, and is corrected above. Three tests cover it: a held short session is not Complete, a session held *after* running to term still is, and a session still running never is.

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

**Resolution.** `SessionStore.refresh()` rolls the context back, re-derives the live session from the log, drops every cache and republishes. The app calls it when the scene becomes active; every intent calls it before doing anything. Ending from the card can no longer answer "Nothing is running." for a session that is, and the app can no longer come back to a stopped clock that Resume would splice back into.

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

**Resolution.** The schema is versioned (`DiemSchemaV1`) behind a `SchemaMigrationPlan` with an empty stage list for the next version to go in. The in-memory fallback sets `DiemContainer.isEphemeral`, and `RootView` puts "Not saving — reopen Diem" across the top of every screen while it holds. The `try!` is gone; an in-memory container that cannot be built is a `fatalError` with the underlying error, because at that point SwiftData itself is unusable.

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

**Resolution.** `SessionStore.subjectsForSync()` fetches every subject, tombstones included, and the sync pass uses it. `subjects(includeArchived:)` still filters them, which is right for every screen.

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

**Resolution.** Deleting an interval that the server already holds records its id in `Settings.deletedIntervalIDs`; the sync pass sends them to a new `DELETE /api/intervals`, scoped to the calling device and idempotent, and clears them only once the server agrees. An offline discard is retried on the next pass rather than forgotten. The list is capped at 500 so an unreachable server cannot grow a defaults key without bound.

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
[repro suite](#appendix-what-happened-to-the-repro-suite) passes: a snapshot with two hours banked
still reports two hours and a full lap when read twenty minutes after the
boundary.
Raised by: [day-model](foundations/day-model.md), [complications](outside/complications.md), [smart-stack](outside/smart-stack.md).

**Resolution.** `DiemSnapshot.dayStart` records the study-day the total was banked in, and `today(asOf:)` reads a stale snapshot as zero — keeping only the part of a live session on this side of the boundary, which for a session held before it is nothing. `Day.nextStart(after:)` was added (a calendar day on, not 86,400 seconds, so it survives a daylight-saving change) and the widget's timeline now reloads at the boundary as well as on its ordinary cadence. The field is optional so an older build's snapshot still decodes, and unknown reads as "not stale" rather than as zero. Six tests.

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

**Resolution.** `com.apple.developer.usernotifications.time-sensitive` is in the app's entitlements and in `project.yml`, so it survives a regenerate.

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

**Resolution.** Metrics is wrapped in a `TimelineView` on a one-minute cadence anchored to `@State`, and every section takes `now` as a parameter instead of reading a stored property fixed at init.

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

**Resolution.** `StartSessionIntent` names the session it ended before the one it started: "Ended Maths at 1h 12m. Studying." Only for a session worth keeping — under a minute there was nothing to report.

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

**Resolution.** `EndSessionIntent` fires a haptic only when nothing else is about to. When it does fire one it fires the *right* one — success for a session that ran to term, the softer stop for one ended early — instead of success unconditionally.

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

**Resolution.** The suppression compares the crown's value against the one it was just reset to, instead of latching a flag that only a detent change could clear. A crown turned less than half a step no longer arms something that never fires.

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

**Resolution.** Subject picker rows are 44pt with an explicit hit shape; colour swatch cells are 44pt on a 2pt grid. Both were under the floor the rest of the app is built to.

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

**Resolution.** The "End?" label takes `minimumScaleFactor(0.6)` and a negative layout priority, so it shrinks and then yields rather than pushing two 44pt controls off the screen. The spacers either side came down from 8pt to 4pt to give it more room before it has to.

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

**Resolution.** The Start ring speaks its progress against the goal as a percentage; the session ring speaks the day as runs, in order; weekday bars are labelled with the weekday rather than its initial, and say "Nothing" for an empty day; the heatmap speaks its shape — days studied, total, best day — rather than nothing at all; the subject picker marks the current selection with the selected trait; and both armed questions carry a hint saying a second tap confirms. Ten colour swatches went from unnamed buttons to named ones.

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
`overtimeKeepsTheLargestFace` in the [repro suite](#appendix-what-happened-to-the-repro-suite)
passes. Whether it actually overruns is unverified.
Raised by: [running-screen](app/running-screen.md).

**Resolution.** `heroSize` counts digits rather than characters, with the step down at five digits. Punctuation no longer decides the face size, so overtime under an hour keeps the same size as the countdown it replaced instead of gaining a glyph at 44pt.

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
[repro suite](#appendix-what-happened-to-the-repro-suite) passes.
Raised by: [start-screen](app/start-screen.md).

**Resolution.** `Format.total` reserves `8h 88m` below ten hours and `88h 88m` above, so a real reading is centred in a field it can actually fill. Tested at both sides of the step.

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

**Resolution.** `SessionAlerts.Presenter` is installed as the notification-centre delegate at launch and returns `[.banner, .sound, .list]`, so the deadline alert is presented even while the app holds the foreground.

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

**Resolution.** The picker owns its dismissal; both callers stopped clearing the flag underneath it. The same fix Settings had already made for `NameField`.

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

**Resolution.** `SessionStore.isNameTaken(_:excluding:)` compares case- and space-insensitively, and `NameField` disables Save with "Already used." under the field. Rename is checked too, excluding the subject being renamed.

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

**Resolution.** Delete is a two-tap question on the same `Confirmation` the summary's Discard uses, withdrawing itself after six seconds and on leaving the screen. The section footer now explains deleting as well as archiving — that history is kept either way.

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

**Resolution.** The palette hands out the least-used index once all ten are taken, instead of `used.count % 10`, which with ten subjects was always zero and so always collided with the first.

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

**Resolution.** The code is uppercased once, on arrival, and both the screen and the spoken label read that. They cannot disagree about a value being copied by hand.

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

**Resolution.** `expiresAt` is kept. Inside the last five minutes the screen counts down; past it, the code is replaced with "That code has expired." and a New Code button. A ten-second request timeout replaced the URL session's default minute, so a flaky connection fails visibly instead of spinning.

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

**Resolution.** Deleted. `pullIntervals`, `IntervalPage` and `Settings.syncCursor` are gone. Intervals only ever originate on the watch, and a puller nobody called was an invitation to assume otherwise. The server's `GET /api/intervals` stays — it is a legitimate surface, just not one this client uses.

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

**Resolution.** `WKWatchOnly` and `WKRunsIndependentlyOfCompanionApp` are both in `project.yml`, and the generated `Info.plist` files are no longer tracked — they are in `.gitignore`, because the spec is the source of truth and `xcodegen generate` writes them. The empty `NSHealthShareUsageDescription` went with them: it was left over from the `workout-processing` mode removed in the previous change, and nothing in the app touches HealthKit.

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

**Resolution.** `group.com.injoon5.diem` is gone. One app group, in the app, the widget and the spec.

## B-28

**Every sync pushes the entire subject list.**

`SyncEngine.run` sends `store.subjects(includeArchived: true).map(\.dto)` on
every pass (`SyncClient.swift:109-110`), with no filter for what has changed.
Intervals are correctly filtered to the unsynced ones; subjects are not.

Small lists make this cheap, and last-write-wins makes it correct. It is still a
full table push on every launch and every backgrounding, on a watch radio.

Severity: **low**. Decision: **fix**.
Status: suspected.

**Resolution.** The sync pass sends only subjects whose `updatedAt` is newer than `Settings.subjectsPushedAt`, and advances that watermark on success.

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

**Resolution.** The token is minted once in `Settings.init`, so the getter is a pure read and two processes cannot race it into two tokens.

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

**Resolution.** Gone with [B-04](#b-04).

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

**Resolution.** The title is the subject and the body says "Time's up." once. And scheduling is serialised: each call awaits the one before it, so hold-then-resume can no longer leave the request carrying the older deadline as the survivor.

## Appendix: what happened to the repro suite

The seven tests that confirmed the entries above were written against the app's
Foundation-only core compiled as a Swift package. They are not reproduced here
any more, because they have become part of the project's own suite and now
assert the opposite — the fixed behaviour rather than the broken kind:

| Was | Is now, in `DiemTests/DiemTests.swift` |
| --- | --- |
| A held short session reports Complete | `A long hold does not make a short session Complete`, plus `A session held after running to term is still Complete` and `A session still running is never Complete` |
| A snapshot survives the day boundary | A seven-test suite, `The widget snapshot across the day boundary` |
| Overtime keeps the largest face | Replaced by counting digits; `heroSize` is view code and is not unit-tested |
| Totals over-reserve their field | `A total reserves the field it can reach, not one wider` |
| An open-ended session changes field at the hour | Unchanged behaviour, and correct — no test was needed |
| A streak is capped by its window | A stated limit, not a defect — no test added |

Two more were added for `Day.nextStart(after:)`, which the widget's
boundary reload depends on.

The suite went from 54 tests to 66, and it can now be run on any machine with a
Swift toolchain:

```sh
cd watch && sh Scripts/core-check.sh
```

That script is itself part of the fix for [B-01](#b-01). The only check this
repo had was `swiftc -parse`, and parsing is not type-checking — which is how a
file that could not compile at all sat on the default branch through two
releases. The script assembles the Foundation-only files into a package and
builds and tests them for real. It cannot cover the views; nothing without an
Apple SDK can, and it says so at the top.

Drafted against `watch/` commit `5ac0e35`, and revised after the fixes in [`bug-triage.md`](bug-triage.md)
