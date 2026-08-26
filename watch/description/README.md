# Diem — product description

What the watch app does, told from the outside in: what is on screen, what you
can do to it, and exactly what happens when you do. Written from the source and
its tests, checked against the running app where that was possible, and
everything that looked wrong collected in [`bug-triage.md`](bug-triage.md).

This is not API documentation. It describes the app as a state chart a person
moves through with a finger, a crown and a wrist.

## Scope decisions

| | |
| --- | --- |
| **Product** | `watch/` — the standalone watchOS 27 app, its widget extension, and the App Intents behind both. The web dashboard in `web/` is out of scope. |
| **Surface** | A single Apple Watch, defaults only: 2h daily goal, no subjects, unpaired, notifications not yet asked for. |
| **Source of truth** | This repository, `watch/`. Drafted against `5ac0e35`; every entry in [`bug-triage.md`](bug-triage.md) has since been fixed, and the documents describe the app after those fixes. |
| **Where to run it** | `cd watch && xcodegen generate && open Diem.xcodeproj`, then the `Diem` scheme on a watchOS 27 simulator or a paired device. |
| **Out of scope** | The web app and sync server; the pairing flow past the point where the code is shown; watch faces and complication *placement*; anything on iPhone (there is no companion app). |
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
| **The app** | | |
| [`app/start-screen.md`](app/start-screen.md) | The pilot. Composing and committing a session. | drafted |
| [`app/running-screen.md`](app/running-screen.md) | The session while it runs. | drafted |
| [`app/done-screen.md`](app/done-screen.md) | The summary, Again, Done, Discard. | drafted |
| [`app/subject-picker.md`](app/subject-picker.md) | Choosing what is being studied. | drafted |
| [`app/settings.md`](app/settings.md) | The goal, the subject list, the subject editor, pairing. | drafted |
| [`app/metrics.md`](app/metrics.md) | Today, this week, twelve weeks. | drafted |
| [`app/pairing.md`](app/pairing.md) | The code, and what it does not tell you. | drafted |
| **Outside the app** | | |
| [`outside/smart-stack.md`](outside/smart-stack.md) | The card while a session runs, and how it is surfaced. | drafted |
| [`outside/complications.md`](outside/complications.md) | One widget, four families of Today. | drafted |
| [`outside/intents.md`](outside/intents.md) | Siri, the Action Button, and the widget buttons. | drafted |
| **Checking** | | |
| [`verification/README.md`](verification/README.md) | How to run a pass. | drafted |
| [`verification/app.md`](verification/app.md) | Checklist for the app documents. | drafted |
| [`verification/outside.md`](verification/outside.md) | Checklist for the widget and intent documents. | drafted |
| [`bug-triage.md`](bug-triage.md) | Every suspected defect, deduplicated. | drafted |

No document is marked `verified`. Nothing here has been observed on a running
watch — see [`verification/README.md`](verification/README.md) for exactly what
that means and what was checked instead.

All 31 triage entries are **fixed**. The checklists under `verification/` are
now regression checks for those fixes as much as they are descriptions of the
product.

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
