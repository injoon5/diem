# The Start screen

The pilot document. Everything else copies its depth.

Where the app rests when nothing is running. One ring, one number, four
controls.

## What you see

A **ring** filling most of the display, with the day's total in the middle of
it. Around the edge, four controls in two bars:

| Position | Control |
| --- | --- |
| Top leading | A gear — Settings |
| Top trailing | A bar chart — Metrics |
| Bottom leading | The **subject button**: a coloured dot, a name, a chevron |
| Bottom trailing | A filled orange circle with a play glyph — **Start** |

The ring at rest is **today against the goal**. One turn is the goal met; past
it, it laps. The track behind it is white at 10%, not a dim orange — a
desaturated accent would read as a second data value rather than as an empty
groove.

The number inside is today's total, spelled `45 m` under an hour and `1h 30m`
over it. It is sized to the ring rather than to the type scale: at a normal
title size it read as a caption in a large empty circle.

The ring is deliberately not centred geometrically. The bottom bar carries a
filled accent circle and the top two small outlined glyphs, so the heavier edge
pulls the eye down; the ring is lifted 12pt to sit at the optical centre of what
is actually on screen. It is also allowed to overrun the bars slightly, the way
an Activity ring does, because it is bounded by the height between them rather
than by the width.

If no subject has been chosen the button reads a dimmed "Subject" with no dot.
If the last-used subject has since been archived or deleted, it reads "Subject"
too — the screen will not offer a subject that Settings has got rid of.

## What you can do

**Turn the crown** to set a session length. Step 0 is no length at all; turning
past it puts the ring into scrub mode, where one turn is an hour rather than the
goal, and the number in the middle becomes the duration being set rather than
the day's total. The two are different quantities, so the swap is a blur, not a
roll — rolling one into the other would read as the number counting itself down.

The arc tracks the crown continuously; the number and the click land on whole
minutes. See [`../foundations/input-model.md`](../foundations/input-model.md).

**Tap the subject button** to open the picker. **Tap Start** to commit. **Tap
the gear or the chart** for Settings and Metrics.

The Start control's spoken label changes with the crown: "Start" at rest,
"Start 25m" once a length is set.

## The five phases

**Compose.** The crown and the subject button. Neither writes anything to the
log — the length lives in the view, and the subject is remembered in defaults
only once a session actually starts. Coming back to this screen re-reads the
last-used subject, unless the picker has already been opened this visit, so an
explicit choice of "Free" is not silently overwritten.

**Commit.** One tap. An interval is inserted carrying the session id, the chosen
subject and the length; the start haptic fires; the crown is reset to zero; the
root crossfades to the Running screen.

The reset is made silently — the app suppresses the click that its own reset
would otherwise cause. It suppresses exactly one, and if the crown was turned
less than half a step there is no reset to suppress, so the suppression is left
armed and swallows the *next* real detent instead. That is
[B-12](../bug-triage.md#b-12).

**Run.** Not this screen. The root switches wholly.

**Close.** Not this screen.

**Account.** Coming back, the ring and the number have grown by whatever the
session banked.

## Variants

| At the start | What differs |
| --- | --- |
| No subjects exist at all | The button reads "Subject"; the picker offers only "Free" and a footer pointing at Settings. |
| A subject was used last time | It is pre-selected, with its dot. |
| That subject has since been archived or deleted | The button falls back to "Subject", and starting produces a free session. |
| Crown at rest | Open-ended session. The ring shows the day. |
| Crown turned | Timed session. The ring shows the duration, in the accent at 72% rather than the ring copper. |
| Goal already met | The ring is closed before anything is added; further study laps it. |

| During | What differs |
| --- | --- |
| Crown turning fast | The arc stays welded to the crown; the numeral rolls per minute. Minutes are zero-padded so the `h` and `m` labels do not skate sideways. |
| Dimmed | Both bars are removed and the ring takes the height back in a single frame, on a short critically damped spring. |
| A sheet is open | The screen behind is unchanged. Whether the crown still works after the sheet closes is [B-12b](../bug-triage.md#b-12). |

## Interrupts

| Interrupt | Effect |
| --- | --- |
| Wrist down | Controls leave; the ring grows; the numeral stops rolling. A length being scrubbed is kept. |
| Crown press | Leaves the app. A length being scrubbed is lost on the next launch. |
| Session started elsewhere | The root should switch to Running. It will, if the app is in the foreground; if the app was alive in the background it may not, per [B-03](../bug-triage.md#b-03). |
| 4am boundary | The total and the ring reset on the next minute tick. The screen re-reads once a minute, so this lands within 60 seconds. |
| Network loss | No effect. |
| Killed and relaunched | Lands here with the crown at zero and the last-used subject restored. |

## Cross-cutting

**Always-On** — the ring is the whole screen. The numeral holds still. This is
the crossing the app cares most about, and it is animated deliberately: both
bars leave at once and the ring takes most of a diameter in a single frame, so
the animation is short and critically damped rather than springy — the display
drops to about one refresh a minute on the way down, and anything with overshoot
risks being caught mid-bounce and held there.

**Typography** — the total is a hero numeral at 40pt with −1.0 tracking, always
monospaced digits, the field reserved at its widest value so nothing shifts.
Over an hour the units are drawn separately at 36% of the numeral so the digits
lead. The reserved field is one hour-digit wider than any day can produce, so
every reading under ten hours sits slightly narrower than its box:
[B-17](../bug-triage.md#b-17).

**Motion** — entering and leaving scrub mode is one event, so the ring and the
numeral leave on the same curve. They used to leave on different ones, which is
close enough to look like a mistake rather than a choice.

**Haptics** — a click per detent, and the start haptic on commit.

**Accessibility** — the ring and numeral are one element, labelled "Today" or
"Session length" depending on mode. The *progress* against the goal is not
spoken: [B-15](../bug-triage.md#b-15). The crown has no adjustable action, so
setting a length without a crown is not possible.

**What the widgets are told** — nothing changes here until a session commits.

## State diagram

```mermaid
stateDiagram-v2
    [*] --> AtRest
    AtRest --> Scrubbing: crown turned past step 0
    Scrubbing --> AtRest: crown returned to 0
    AtRest --> Picking: subject button
    Scrubbing --> Picking: subject button
    Picking --> AtRest: a subject chosen
    Picking --> Scrubbing: a subject chosen, crown still turned
    AtRest --> Running: Start
    Scrubbing --> Running: Start
    AtRest --> Sheet: gear or chart
    Sheet --> AtRest: dismissed
```

## Open questions and verification

- Whether crown focus returns after a sheet is dismissed. Nothing in the code reclaims it. [B-12b](../bug-triage.md#b-12).
- Three sheets are attached to the same view. Modern SwiftUI generally handles this, but stacked `sheet(isPresented:)` modifiers on one view have historically been unreliable; this wants a device before it is called fine.
- Whether the −14pt vertical overrun clips the ring against the bezel on the 41mm watch.
- Whether the optical 12pt lift still reads as centred once the bars are gone in Always-On, where the thing it was correcting for is no longer on screen.

Verified against `watch/` commit `5ac0e35`
