# Checklist — outside the app

Covers [`outside/`](../outside/) and the cross-process claims in
[`foundations/surfaces.md`](../foundations/surfaces.md). Read
[`README.md`](README.md) first.

Most of these need two processes and a stopwatch. Several need the watch left
alone for long enough that the extension is torn down and rebuilt, which is the
part no scripted pass can do.

## The session card — `CARD`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CARD-01 | P1 | device, unpinned Smart Stack | The card surfaces itself when a session starts ([doc](../outside/smart-stack.md#how-it-gets-there)) | The card NOT added to the stack by hand | Start a session in the app, crown out, scroll the Smart Stack | The card is present without having been added | — |
| CARD-02 | P1 | device | It stops claiming the stack once the session ends | Following CARD-01 | End the session, scroll the stack | The card is gone within a refresh | — |
| CARD-03 | P2 | device | Overtime still claims the stack | 1m session, left running past zero for 25m | Scroll the stack | Still present — the floor applies past the deadline | — |
| CARD-04 | P1 | device | The count reads the same thing running and held ([doc](../outside/smart-stack.md#what-the-count-reads)) | 25m session, 10m in | Hold it, look at the card | `15:00`, frozen — not a studied-time figure | — |
| CARD-05 | P1 | device, patience | The End button works after the extension has been rebuilt ([B-03](../bug-triage.md#b-03)) | Start a session in the app. Leave the watch untouched long enough for the extension to be torn down (unknown; try an hour). | Tap End on the card | The session ends. The intent re-reads the log first, so a store built before the session started no longer decides the answer. | — |
| CARD-06 | P1 | device | The app notices a session ended from the card ([B-03](../bug-triage.md#b-03)) | Session running, app backgrounded but recently used | End from the card, then reopen the app | The Start screen, with the day's total including the session that just ended. The app refreshes when the scene becomes active. | — |
| CARD-07 | P1 | device | There is nothing left to resume after CARD-06 ([B-03](../bug-triage.md#b-03)) | Following CARD-06 | Look for a Resume control | There is none — the app is on the Start screen. The failure mode was a live interval spliced into an ended session. | — |
| CARD-08 | P2 | device | Ending from the card with the app on screen fires one haptic ([B-11](../bug-triage.md#b-11)) | Session running for 4m of a planned 25m, app on screen, card pulled over it | End from the card | One haptic, and the softer stop rather than success — the session did not run to term | — |
| CARD-09 | P2 | device | Starting from the card gives a free, open-ended session | Nothing running | Tap the play button | A session with no subject and no countdown | — |
| CARD-10 | P3 | device | The stop button is a comfortable target | Session running | Tap the stop button repeatedly at the edge of the glyph | It responds across the full 30pt, not only on the symbol | — |

## The Today complication — `COMP`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| COMP-01 | P2 | device | Four families all render | A face with each family | Add each | All four legible in under a second | — |
| COMP-02 | P2 | device | Circular and rectangular deliberately spell differently ([doc](../outside/complications.md#two-spellings-on-purpose)) | 90m studied | Compare | `1.5h` and `1h 30m` | — |
| COMP-03 | P1 | device | The rectangular bar laps; the stock gauges cap | Goal 1h, 90m studied | Compare rectangular and circular | The bar shows a dimmed full pass with half a bright one over it; the gauge is simply full | — |
| COMP-04 | P1 | device, overnight | The total resets at the 4am boundary ([B-07](../bug-triage.md#b-07)) | 2h studied, watch left alone from 03:45 | Look at the complication at 04:05 | Zero and an empty ring, without the app having run. The snapshot carries the day it was banked in. | — |
| COMP-05 | P2 | device | The count advances without a refresh | Session running | Watch the rectangular card for a minute | The total climbs | — |
| COMP-06 | P3 | device, tinted face | Accentable elements take the face tint; the track does not | Any | Tint the face | Numerals and fill tint; the ghost track stays neutral | — |
| COMP-07 | P3 | device, monochrome face | Everything stays legible without colour | Any | Switch to a monochrome face | The lap is still readable as a lap | — |
| COMP-08 | P3 | device, VoiceOver | The circular family speaks a usable value ([doc](../outside/complications.md#cross-cutting)) | 90m studied | VoiceOver onto it | "1.5h" — a product call, still open, not a failure | — |

## Intents, Siri and the Action Button — `INT`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INT-01 | P2 | device | All four session shapes are reachable by voice | Any | "Study Maths for 25 minutes", then each of the other three combinations | Each confirms what it did, naming only what was given | — |
| INT-02 | P1 | device | Starting names the session it ended ([B-10](../bug-triage.md#b-10)) | A session running for 20m | Ask Siri to start studying | "Ended Maths at 20m. Studying." From the Action Button there is still no dialog — the haptic is all there is. | — |
| INT-03 | P1 | device | Ending with no screen queues no summary | Session running, app not on screen | "Stop studying in Diem", then open the app | The Start screen, not a summary | — |
| INT-04 | P1 | device | Ending with the app on screen lands on the summary | Session running, app on screen | End via the card | The summary — unless [B-10b](../bug-triage.md#b-10) holds with the wrist down | — |
| INT-05 | P2 | device | Pause toggles, and says which way | Session running | "Pause studying in Diem" twice | "Paused." then "Resumed." | — |
| INT-06 | P2 | device | Under-a-minute sessions are reported as such | Any | Start and end within 30s by voice | "Too short to keep." | — |
| INT-07 | P1 | device | The frontmost hold is claimed when the app is next opened ([doc](../foundations/surfaces.md#the-frontmost-hold)) | Session started from the Action Button | Open the app, lower the wrist, raise it | The running screen, not the watch face | — |
| INT-08 | P3 | device, VoiceOver | The Control confirms what it did | Any | Press the Action Button with VoiceOver on | Expected: a haptic and nothing spoken | — |

## Cross-process and lifecycle — `PROC`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PROC-01 | P1 | device | A session survives the app being killed | Session running 5m | Force quit, reopen | The running screen with the count intact | — |
| PROC-02 | P1 | device, clock control | An interval open longer than 12h is disowned, not credited ([doc](../foundations/session-model.md#two-thresholds-that-delete-data)) | Session running, app killed, 13h passed | Reopen | The Start screen; the day's total does not include 13 hours | — |
| PROC-03 | P1 | device | Two open intervals never coexist | Contrive one via PROC-02 twice | Reopen | Only the newest survives; the rest are closed at their own start | — |
| PROC-04 | P2 | device, airplane mode | Everything works offline | Offline | Run a full session, check Metrics | No difference except Pairing | — |
| PROC-05 | P3 | device | Holding the foreground for an hour does not visibly cost battery | Charged watch | Run a 60m session with the wrist down | A note, not a pass/fail — record the drop | — |
| PROC-06 | P1 | device | The hold survives its own one-hour expiry ([doc](../foundations/surfaces.md#the-frontmost-hold)) | 90m session, app on screen, wrist raised near the hour mark | At ~61 minutes, lower and raise the wrist | The running screen, not the watch face | — |
