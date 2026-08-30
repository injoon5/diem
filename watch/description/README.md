# Diem — product description

What Diem does, told from the outside in: what is on screen, what you can do to
it, and exactly what happens when you do. The watch app first, and now the web
dashboard beside it. Written from the source and
its tests, checked against the running app where that was possible, and
everything that looked wrong collected in [`bug-triage.md`](bug-triage.md).

This is not API documentation. It describes the app as a state chart a person
moves through with a finger, a crown and a wrist.

## Scope decisions

| | |
| --- | --- |
| **Product** | `watch/` — the standalone watchOS 27 app, its widget extension, and the App Intents behind both — **and** `web/`, the dashboard and sync API at `diem.ij5.dev`. The web was originally out of scope and was brought in when the profile and watch-replacement features were added. |
| **Surface** | A single Apple Watch, defaults only: 2h daily goal, no subjects, unpaired, notifications not yet asked for. For the web: one browser, one paired device, no profile claimed. |
| **Source of truth** | This repository. The watch documents were drafted against `5ac0e35` and revised after the fixes in [`bug-triage.md`](bug-triage.md); the web documents were drafted against `6213636` and each says so in its footer. The two are not mixed: a document's footer names the commit it was read against. |
| **Where to run it** | The watch: `cd watch && xcodegen generate && open Diem.xcodeproj`, then the `Diem` scheme on a watchOS 27 simulator or a paired device. The web: `cd web && npm install && npm run db:migrate && npm run dev`. |
| **Out of scope** | Watch faces and complication *placement*; anything on iPhone (there is no companion app); deployment, hosting and the shape of the database; the marketing site, of which there is none. |
| **Where this lives** | `watch/description/`, inside the source repo rather than beside it, because that is where it was asked to go. It is documentation, not a second project: no nested `git init`, and it is committed with the repo. |

## The product's shape

Diem is a **timer with a log behind it**. The unit of interaction is a
**session**, and every session passes through the same five phases:

| Phase | What it is |
| --- | --- |
| **Compose** | On the Start screen, choosing a subject and a length before anything is running. |
| **Commit** | The tap, phrase, or button press that opens the first interval. |
| **Run** | The session is live: counting, pausing, switching subject, going into overtime. |
| **Close** | Ending it — banked, discarded under a minute, or thrown away by hand. |
| **Account** | What the session leaves behind: the day's total, the streak, the ring, the log the server eventually gets. |

**Variant axis:** where the action came from — the app's own screens, the Smart
Stack card, Siri, or the Action Button Control. The same intents sit behind all
four, and they do not all behave the same.

The web is a fifth place the product is met, but not a fifth place a session can
come from: it never starts, holds or ends one. Its documents narrate the same
five phases and say plainly which of them do not apply, because *which phases a
surface cannot reach* is the most useful thing to know about it. The one arc the
web has of its own is the profile, and it fits the five phases without
straining.

**Fixed interrupt list.** Every feature document answers these, in this order,
even when the answer is "no effect":

1. Wrist down (the app dims, then is put away)
2. Crown press (leaving the app)
3. A session ending or starting from another surface
4. The 4am day boundary passing
5. Loss of network
6. The app being killed and relaunched

**Cross-cutting concerns**, in this order: Always-On, typography and numerals,
motion, haptics, accessibility, and what the widgets are told.

## Document template

Every feature document follows the same eight sections:

1. **What you see** — the screen at rest, named parts.
2. **What you can do** — the controls, and their targets.
3. **The five phases** — narrated, one at a time.
4. **Variants** — a table, split into "at the start" and "during".
5. **Interrupts** — the fixed list above, as a table, every cell filled.
6. **Cross-cutting** — the list above, walked in full.
7. **State diagram** — one `stateDiagram-v2`, only the states a person passes through.
8. **Open questions and verification** — what could not be settled from the code, and the footer.

## Structure and coverage

| Document | What it covers | Status |
| --- | --- | --- |
| [`glossary.md`](glossary.md) | The vocabulary. Owns every term of art. | drafted |
| [`goal.md`](goal.md) | Standing instructions for whoever drafts next. | drafted |
| **Foundations** | | |
| [`foundations/session-model.md`](foundations/session-model.md) | Intervals, sessions, the live session, completion. Owns the numbers. | drafted |
| [`foundations/input-model.md`](foundations/input-model.md) | Crown, taps, confirmations, haptics. | drafted |
| [`foundations/day-model.md`](foundations/day-model.md) | The 4am day, the goal, the streak. | drafted |
| [`foundations/surfaces.md`](foundations/surfaces.md) | App, complications, Smart Stack, intents, and what each process can see. | drafted |
| [`foundations/sync-model.md`](foundations/sync-model.md) | The device, the token, what crosses the wire, and who wins a disagreement. Owns the ownership rules. | drafted |
| **The app** | | |
| [`app/start-screen.md`](app/start-screen.md) | The pilot. Composing and committing a session. | drafted |
| [`app/running-screen.md`](app/running-screen.md) | The session while it runs. | drafted |
| [`app/done-screen.md`](app/done-screen.md) | The summary, Again, Done, Discard. | drafted |
| [`app/subject-picker.md`](app/subject-picker.md) | Choosing what is being studied. | drafted |
| [`app/settings.md`](app/settings.md) | The goal, the subject list, the subject editor, pairing. | drafted |
| [`app/metrics.md`](app/metrics.md) | Today, this week, twelve weeks. | drafted |
| [`app/pairing.md`](app/pairing.md) | The code, and what it does not tell you. | drafted |
| **The web** | | |
| [`web/dashboard.md`](web/dashboard.md) | The pilot for this area. Pairing from the browser's side, the three numbers, the week, the year, renaming a subject. | drafted |
| [`web/profile.md`](web/profile.md) | Claiming a handle, the display name, the subjects switch. | drafted |
| [`web/public-profile.md`](web/public-profile.md) | What a stranger sees at `/{handle}`, and what is withheld. | drafted |
| [`web/replacing-a-watch.md`](web/replacing-a-watch.md) | Moving a profile and its history onto a new watch. | drafted |
| **Outside the app** | | |
| [`outside/smart-stack.md`](outside/smart-stack.md) | The card while a session runs, and how it is surfaced. | drafted |
| [`outside/complications.md`](outside/complications.md) | One widget, four families of Today. | drafted |
| [`outside/intents.md`](outside/intents.md) | Siri, the Action Button, and the widget buttons. | drafted |
| **Checking** | | |
| [`verification/README.md`](verification/README.md) | How to run a pass. | drafted |
| [`verification/app.md`](verification/app.md) | Checklist for the app documents. | drafted |
| [`verification/outside.md`](verification/outside.md) | Checklist for the widget and intent documents. | drafted |
| [`verification/web.md`](verification/web.md) | Checklist for the web documents. A first scripted pass has been run. | drafted |
| [`bug-triage.md`](bug-triage.md) | Every suspected defect, deduplicated. | drafted |

No document is marked `verified`. Nothing about the watch has been observed on a
running watch. Most of the web has not been observed in a browser either, though
four claims now have been — see
[`verification/README.md`](verification/README.md) and
[`verification/web.md`](verification/web.md) for exactly what that means and what
was checked instead. The web did get a first pass: its API was driven against a
real database and roughly half its rows now carry a result, which is more than
any watch document can say.

All 50 triage entries are **fixed**, and the checklists under `verification/` are
regression checks for those fixes as much as they are descriptions of the
product. [B-42](bug-triage.md#b-42) onwards came from describing the web: they
were open for one sitting and closed in the next, and several rows in
[`verification/web.md`](verification/web.md) that once reproduced a defect now
assert its opposite.

## Method

Drafted from the source and from `watch/DiemTests`. Where a claim could be
settled by running code rather than reading it, it was — and the tests that
confirmed the defects have become regression tests for the fixes. The suite runs
anywhere:

```sh
cd watch && sh Scripts/core-check.sh
```

The rest was read. Everything that touches SwiftUI, SwiftData, WatchKit or
WidgetKit cannot be compiled without an Apple SDK, so anything asserted about
those is a reading of the code, and says so. That gap is exactly how
[B-01](bug-triage.md#b-01) — a file that could not compile — survived on the
default branch: `swiftc -parse` was the only check, and parsing is not
type-checking.

## Reference

Where the behaviour lives, for whoever reads next:

| | |
| --- | --- |
| Interaction state | `Diem/Model/SessionStore.swift` — the one live session, and every derived read behind a cache |
| Pure arithmetic | `Diem/Model/SessionAssembly.swift`, `Day.swift`, `Snapshot.swift`, `Design/Format.swift`, `Views/Scrub.swift` |
| Behaviour tests | `DiemTests/DiemTests.swift` — 66 tests, all Foundation-only, runnable via `Scripts/core-check.sh` |
| Screens | `Diem/Views/` |
| Defaults and thresholds | `Settings.swift` (goal), `Scrub.swift` (crown curves), `SessionStore.swift` (the 60s floor, the 12h recovery limit), `SessionAlerts.swift` (the 30m overtime grace), `Confirmation.swift` (the 6s question window) |
| Outside the app | `DiemWidget/`, `Diem/Intents/Intents.swift` |
| The wire | `Diem/Sync/SyncClient.swift` and `Diem/Sync/DTO.swift` on the watch; `web/src/routes/api/` on the server |
| The web's reads | `web/src/lib/server/summarize.ts` — the one aggregation both the dashboard and the public page go through |
| The web's rules | `web/src/lib/summary.ts` (the day, the streak, the goal rate), `web/src/lib/server/handles.ts` (what a handle may be, and the reserved list) |
| The web's screens | `web/src/routes/+page.svelte`, `web/src/routes/[handle]/`, `web/src/lib/components/` |
