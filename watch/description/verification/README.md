# Verification

Drafting reads the code. Verification watches the product. This file covers the
watch, where nothing has reached the second stage, and says exactly what that
means.

The web is further along: its API has been driven against a real database and
about half the rows in [`web.md`](web.md) carry a result. That file has its own
account of what the pass did and did not cover. Nothing about either surface has
been observed on screen.

## What has and has not been checked

**Checked by running code.** The app's Foundation-only core — the day boundary,
the number formats, the crown curves, session assembly, the live-session summary,
the widget snapshot and its day staleness, and the Smart Stack relevance window —
compiles as a Swift package and passes 66 tests:

```sh
cd watch && sh Scripts/core-check.sh
```

That script is part of the fix for [B-01](../bug-triage.md#b-01). The only check
this repo had was `swiftc -parse`, and parsing is not type-checking — which is
how a file that could not compile sat on the default branch through two
releases.

**Checked by reading only.** Everything touching SwiftUI, SwiftData, WatchKit or
WidgetKit. That is most of the app, including every screen. These entries are
marked **suspected** and stay that way until somebody runs a pass below.

**Not checked at all.** Anything about how something *looks*: whether a numeral
overruns a ring, whether a bar overflows at the largest text size, whether an
animation reads as intentional, whether a colour holds up under a watch face
tint. A scripted pass cannot see any of it.

No document is marked `verified`, and none should be until a pass is run on
hardware. Entries up to [B-41](../bug-triage.md#b-41) are fixed, but "fixed" and
"verified" are different words: most of those fixes were made against a reading
of the code, and the rows below are what would turn them into observations.
[B-42](../bug-triage.md#b-42) onwards are the web's, are open, and are checked
against [`web.md`](web.md) rather than here.

## Bringing the surface up

```sh
cd watch
brew install xcodegen
xcodegen generate && open Diem.xcodeproj
```

Then the `Diem` scheme, on a watchOS 27 simulator or a paired watch.

**Build it before anything else.** [B-01](../bug-triage.md#b-01) was a type error
in `Views/Ring.swift` that no check in this repo could see, so the first thing a
pass proves is that the app compiles at all. `Scripts/core-check.sh` covers the
arithmetic and nothing else; only Xcode can tell you about the views.

The generated `Info.plist` files are no longer tracked
([B-26](../bug-triage.md#b-26)), so `xcodegen generate` produces no spurious
diff. `project.yml` is the source of truth for them.

## Confirming the commit

Every document footer cites `5ac0e35`. Before a pass:

```sh
git -C . rev-parse --short HEAD
```

If it differs, either re-read the documents against the newer commit or pin the
checkout. Do not mix.

## Running a pass

1. Work down one checklist file in order. The IDs are stable; never renumber them.
2. Set up exactly what the **Setup** column says. Most rows depend on a specific session state, and getting there is most of the work.
3. Follow the numbered steps literally.
4. Put the result in the **Result** column: `pass`, `fail`, or `blocked`, with a one-line note.
5. A failure is not automatically a product bug. Sometimes the document is wrong. Say which in the note.

## Priorities

| | |
| --- | --- |
| **P1** | An established fact from `goal.md`, or a row that would confirm a suspected triage entry. Run these first. |
| **P2** | An ordinary claim about what a screen does. |
| **P3** | A number, a colour, or a timing. Run when there is time. |

## What a pass is for now

Every triage entry is fixed, so the checklists have changed job. A row that names
a triage entry is a **regression check**: it describes the behaviour the fix was
supposed to produce, and failing it means the fix did not land, not that a new
defect was found. Rows with no entry beside them are ordinary claims, unchanged.

## Filing what a pass finds

A row that fails and is a product bug becomes a triage entry: next free `B-NN`,
with a **Status: confirmed** line and a link back to the checklist row. A row
that fails because the document was wrong becomes a document revision, and the
row's note says so.

Once every P1 and P2 row for a document has passed, that document moves from
`drafted` to `verified` in the README's coverage table. A document with any
`blocked` P1 row does not move.

## Not checkable by hand

- Whether the widget extension's process lifetime is long enough for [B-03](../bug-triage.md#b-03) to bite in normal use. This wants instrumentation, not observation.
- Whether the 12-hour interval recovery works, without waiting half a day or manipulating the clock.
- Whether a race between two notification schedules ([B-31b](../bug-triage.md#b-31)) ever picks the wrong one.
- Long-run battery cost of holding the foreground for hours at a time.
