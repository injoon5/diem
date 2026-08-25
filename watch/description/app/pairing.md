# Pairing

One screen, one code, and no way to tell whether it worked.

## What you see

Pushed from Settings, titled **Pair**. Three states:

| State | What is on screen |
| --- | --- |
| Loading | A spinner |
| Loaded | The code at 32pt with 2pt tracking, uppercased, "Enter this on diem.app" under it, and a countdown inside the last five minutes |
| Expired | "That code has expired." and a New Code button |
| Failed | "Couldn't reach the server." and a "Try Again" button |

## What you can do

Read the code and type it on the web. Retry if it failed. Leave.

## The five phases

Pairing is outside the session model entirely. The app works fully without ever
pairing — every call in the sync layer is allowed to fail quietly, and nothing
in the product is gated on it.

## Variants

| At the start | What differs |
| --- | --- |
| Online | A code appears. |
| Offline | The failure message, and a retry. |
| Already paired | Identical. A fresh code is claimed every time the screen opens, and nothing indicates the watch is already paired. |

| During | What differs |
| --- | --- |
| The code is claimed on the web | **Nothing.** The screen does not change, and the watch is never told. |
| The code approaches its expiry | Inside five minutes, a countdown appears under the code. |
| The code expires | The code is replaced by "That code has expired." and a button that fetches a new one. [B-24](../bug-triage.md#b-24) |

## Interrupts

| Interrupt | Effect |
| --- | --- |
| Wrist down | The code stays on screen. |
| Crown press | Leaves the app; the code is claimed but unentered. |
| Session started or ended elsewhere | No effect. |
| 4am boundary | No effect. |
| Network loss | If it happens before the request, the failure state. If after, the code is already on screen and stays there whether or not it is still valid. |
| Killed and relaunched | The screen is gone and the code is lost. Reopening claims a new one. |

## Cross-cutting

**Always-On** — the code stays legible at 32pt.

**Typography** — the code is set in the numeral face with wide tracking, which
is right for something being transcribed. It is uppercased on screen.

**Motion** — none.

**Haptics** — none, including on failure.

**Accessibility** — the code is spelled out character by character rather than
read as a word, which is the right call for a code. It is uppercased once on
arrival, so the spoken spelling and the drawn one cannot disagree in case —
they used to: [B-23](../bug-triage.md#b-23).

**What the widgets are told** — nothing.

## State diagram

```mermaid
stateDiagram-v2
    [*] --> Loading
    Loading --> Showing: a code came back
    Loading --> Failed: it did not
    Failed --> Loading: Try Again
    Showing --> [*]: back
    Failed --> [*]: back
```

## Open questions and verification

- The screen still never confirms success, so the only way to know pairing worked is to look at the web. Doing better needs the watch to poll or the server to push, and neither is worth it for a one-time setup step — but it remains the weakest moment in the product. [B-24](../bug-triage.md#b-24)
- The expiry is now shown and acted on, so a lapsed code no longer looks like a fresh one.
- Requests time out after ten seconds rather than the URL session's default minute, so a flaky connection fails visibly.
- Whether five minutes is the right point to start warning wants watching someone type a code.

Drafted against `watch/` commit `5ac0e35`, and revised after the fixes in [`bug-triage.md`](../bug-triage.md)
