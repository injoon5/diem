# Verification

Drafting reads the code. Verification watches the product. Nothing in this repo
has reached the second stage, and this file exists to say exactly what that
means.

## What has and has not been checked

**Checked by running code.** The app's Foundation-only core — the day boundary,
the number formats, the crown curves, session assembly, the live-session summary
and the Smart Stack relevance window — compiles as a Swift package under Swift
6.3 on Linux, and 54 project tests plus a 7-test repro suite pass against it.
Every triage entry marked **confirmed** rests on that, or on a direct reading of
two files that disagree.

**Checked by reading only.** Everything touching SwiftUI, SwiftData, WatchKit or
WidgetKit. That is most of the app, including every screen. These entries are
marked **suspected** and stay that way until somebody runs a pass below.

**Not checked at all.** Anything about how something *looks*: whether a numeral
overruns a ring, whether a bar overflows at the largest text size, whether an
animation reads as intentional, whether a colour holds up under a watch face
tint. A scripted pass cannot see any of it.

No document is marked `verified`, and none should be until a pass is run on
hardware.

## Bringing the surface up

```sh
cd watch
brew install xcodegen
xcodegen generate && open Diem.xcodeproj
```

Then the `Diem` scheme, on a watchOS 27 simulator or a paired watch.

**Expect this not to build.** [B-01](../bug-triage.md#b-01) is a type error in
`Views/Ring.swift`. A pass cannot begin until it is fixed, and the fix will
change what the session ring draws, so any checklist row touching the session
ring should be run *after* that fix and noted as such.

Note also [B-26](../bug-triage.md#b-26): `xcodegen generate` rewrites the tracked
`Diem/Info.plist`. Check `git status` before assuming you changed something.

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
