# Checklist — the app's screens

Covers [`app/`](../app/). One table per document, one row per observable claim.
`—` in Result means not yet run. Nothing here has been run.

Read [`README.md`](README.md) first, especially the note that the project does
not currently build.

## Start screen — `START`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| START-01 | P2 | device | The ring at rest is today against the goal ([doc](../app/start-screen.md#what-you-see)) | Goal 2h, 1h studied | Open the app | The arc is half a turn | — |
| START-02 | P2 | device | Past the goal the ring laps | Goal 1h, 90m studied | Open the app | A dimmed full turn with a bright half over it | — |
| START-03 | P1 | device | The crown scrubs continuously while the reading steps ([doc](../app/start-screen.md#what-you-can-do)) | Fresh launch | Turn the crown slowly | The arc moves smoothly; the number steps a minute at a time; one click per step | — |
| START-04 | P1 | device | Committing suppresses exactly one click, and no more ([B-12](../bug-triage.md#b-12)) | Fresh launch | Turn the crown a third of a step so the reading stays 0. Tap Start. End the session. Turn the crown one step. | A click on that step. Regression: this used to be silent. | — |
| START-05 | P1 | device | The crown still works after a sheet ([B-12b](../bug-triage.md#b-12)) | Fresh launch | Open the subject picker, dismiss it, turn the crown | The duration changes. Focus is reclaimed when the last sheet closes. | — |
| START-06 | P2 | device | An archived subject is not offered | One subject, used last session, then archived | Open the app | The button reads "Subject" | — |
| START-07 | P2 | device | Choosing Free is not overwritten | A subject used last session | Open the picker, choose Free, dismiss, reopen the app's Start screen without leaving | The button still reads "Subject" | — |
| START-08 | P3 | device | The ring does not clip at the bezel | 41mm watch | Open the app | The arc is fully visible at top and bottom | — |
| START-09 | P3 | device | The 12pt optical lift still reads centred when dimmed | 41mm watch | Lower the wrist | The ring looks centred with the controls faded out | — |
| START-12 | P1 | device | Always-On does not resize the ring ([doc](../app/start-screen.md#cross-cutting)) | Any state | Lower the wrist, raise it again | The four controls fade out and back; the ring is the same diameter, in the same place, throughout | — |
| START-10 | P2 | device | Three sheets on one view all present ([open question](../app/start-screen.md#open-questions-and-verification)) | Fresh launch | Open Settings, dismiss; Metrics, dismiss; the picker, dismiss | All three present and dismiss | — |
| START-11 | P2 | device, VoiceOver | The ring's progress is announced ([B-15](../bug-triage.md#b-15)) | 1h of 2h studied | Swipe to the ring | "Today", then "1 hour of 2 hours, 50 percent" | — |
| START-13 | P1 | device with double tap | The double tap starts the composed session ([doc](../app/start-screen.md#what-you-can-do)) | Series 9 or later, a subject chosen, crown at 25m | Double tap | A 25m session under that subject, and the start haptic — the same thing tapping Start does | — |
| START-14 | P2 | device with double tap | The gesture is withdrawn under a sheet | Following START-13, but with the subject picker open | Double tap | Nothing starts. The system's own gesture behaviour applies to the sheet instead. | — |

## Running screen — `RUN`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| RUN-01 | P1 | device | The countdown measures studied time, not wall clock ([doc](../foundations/session-model.md#two-clocks-and-they-disagree)) | 25m session | Study 5m, hold 10m, look | The clock still reads 20:00 | — |
| RUN-02 | P1 | device | A held session says so and steps back | Any session | Tap Hold | "Paused" appears; the numeral drops to 45% | — |
| RUN-03 | P1 | device | The deadline fires a haptic and shows "Complete" | 1m session | Wait | Success haptic; "Complete" for two minutes; the clock rolls to +0:00 and up | — |
| RUN-04 | P1 | device | Paused outranks Complete | 1m session | Let it pass zero, then hold | "Paused", not "Complete" | — |
| RUN-05 | P1 | device | The End question withdraws itself after six seconds | Any session | Tap End once, wait | The controls revert; no session ends | — |
| RUN-06 | P1 | device | Always-On strikes the seconds out rather than dropping them ([doc](../app/running-screen.md#cross-cutting)) | Any session | Lower the wrist | The last two digits cross over into figure dashes — `24:‒‒`, same field, same colon, a step quieter — and the minutes in front of them do not move | — |
| RUN-15 | P1 | device | Always-On centres the picture without resizing it ([doc](../app/running-screen.md#cross-cutting)) | Any session | Lower the wrist, raise it again | The controls fade; the ring and the clock inside it slide down together to the middle of the screen and back up, on one short spring. The ring is the same diameter throughout | — |
| RUN-07 | P1 | device | The app is still frontmost after a wrist drop | Any session | Lower the wrist, wait 10s, raise it | The running screen, not the watch face | — |
| RUN-08 | P1 | device | Crowning out gives up the hold and does not reclaim it | Any session | Press the crown, wait, raise the wrist | The watch face | — |
| RUN-09 | P1 | device, largest text size | The bottom bar fits at the largest text size ([B-14](../bug-triage.md#b-14)) | Any session, text size at max | Tap End once | Both 44pt controls stay on screen; "END?" shrinks, and gives up its space entirely before they move | — |
| RUN-10 | P2 | device | The session ring draws one band per run, in subject colours | Two subjects, switched once | Look behind the clock | Two bands, two colours, in the order they happened | — |
| RUN-11 | P1 | device, VoiceOver | The session ring is announced ([B-15](../bug-triage.md#b-15)) | Two subjects, switched once | VoiceOver onto the ring | "Session so far", then each run in order: "Maths, 25m, then Physics, 10m" | — |
| RUN-12 | P2 | device | Overtime takes the same size as the countdown it replaced ([B-16](../bug-triage.md#b-16)) | 1m session on a 41mm watch | Let it run past zero | `+00:07` sits inside the arc at the same face size `00:07` had | — |
| RUN-13 | P1 | device | The deadline notification is delivered while the app holds the foreground ([B-18](../bug-triage.md#b-18)) | 1m session, notifications allowed, wrist down | Wait past the deadline | A wrist tap within a few seconds of the deadline. A delegate now presents it; it used to be suppressed. | — |
| RUN-14 | P2 | device | Hold and resume are indistinguishable by feel ([doc](../foundations/input-model.md#cross-cutting)) | Any session, wrist down | Tap Hold, then Resume | Both feel identical — a stated observation, not a defect | — |
| RUN-15 | P1 | device with double tap | The double tap holds and resumes ([doc](../app/running-screen.md#what-you-can-do)) | Series 9 or later, a session running | Double tap, then double tap again | Held, then resumed — the clock stops and starts, with the same click a tap gives | — |
| RUN-16 | P1 | device with double tap | The double tap never ends a session | Session running | Tap End once to arm the question, then double tap | The question is withdrawn and the session is still running. The gesture follows the left control, which now means "keep going". | — |

## Summary — `DONE`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DONE-01 | P1 | device | A held session is not called Complete ([B-02](../bug-triage.md#b-02)) | 25m session | Study 5m, hold 30m, resume, study 1m, end | "Ended", and the softer stop haptic. Six minutes of a planned twenty-five is not complete however long the hold was. | — |
| DONE-02 | P1 | device | A session under a minute is dropped silently | Any session | Start and end within 30s | No summary; one retry haptic; the day's total unchanged | — |
| DONE-03 | P2 | device | The breakdown appears on more than one subject, not more than one interval | A session held once, same subject | End it | No breakdown | — |
| DONE-04 | P2 | device | Again repeats the last subject, not the biggest | Two subjects: 20m on A, 5m on B, ending on B | End, tap Again | The new session is on B | — |
| DONE-05 | P1 | device | Discard asks twice and withdraws itself | Any kept session | Tap Discard once, wait 6s | The label reverts; nothing is deleted | — |
| DONE-06 | P2 | device, VoiceOver | An armed Discard announces its state ([B-15](../bug-triage.md#b-15)) | Any kept session | VoiceOver onto Discard, activate | The label stays "Discard"; the hint becomes "Discards this session. Double tap to confirm." | — |
| DONE-07 | P2 | device | Done leads, Again is secondary ([doc](../app/done-screen.md#what-you-see)) | Any kept session | End a session and look | Done first, in the accent; Again under it in near-transparent white; Discard quiet below both | — |
| DONE-08 | P1 | device with double tap | The double tap is Done ([doc](../app/done-screen.md#what-you-can-do)) | Series 9 or later, any kept session | Double tap | The Start screen, with the session banked — the same thing tapping Done does. Not a repeat. | — |
| DONE-09 | P1 | device with double tap | The double tap never discards | Any kept session | Tap Discard once to arm it, then double tap | The screen closes and the session is kept. Reopen Metrics and it is still in the day's total. | — |

## Subject picker — `PICK`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PICK-01 | P2 | device | Archived subjects are hidden here and kept in Settings | One archived subject | Open the picker, then Settings | Absent from one, dimmed in the other | — |
| PICK-02 | P1 | device | Switching mid-session opens a new run | Session running on A | Pick B | The ring gains a band; the clock does not jump | — |
| PICK-03 | P1 | device | Switching while held waits for the next interval | Session held on A | Pick B, resume | The new interval is B; the closed one is still A | — |
| PICK-04 | P2 | device | Rows meet the 44pt floor ([B-13](../bug-triage.md#b-13)) | Any | Measure a row | 44pt, with the hit shape filling it | — |
| PICK-05 | P2 | device | The sheet does not flicker on dismissal ([B-19](../bug-triage.md#b-19)) | Any | Pick a row | One clean dismissal, no double animation | — |

## Settings — `SET`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SET-01 | P1 | device | The goal crown does not fire a detent on appearance | Goal 2h | Open the goal screen | No click until the crown moves | — |
| SET-02 | P2 | device | The goal row and the goal screen spell the number identically | Goal 2h | Compare | Both `2h 00m` | — |
| SET-03 | P2 | device | The widgets are told once the crown settles, not per detent | A complication on the face | Scrub the goal across its range, stop | The complication rescales once, shortly after | — |
| SET-04 | P2 | device | Subjects here are sorted by name, not recency | Subjects named Set 2, Set 10, alpha | Open Settings | Alphabetical, with Set 2 before Set 10 | — |
| SET-05 | P2 | device | Swatch cells meet the 44pt floor ([B-13](../bug-triage.md#b-13)) | Any subject | Measure a cell | 44pt. Check the grid still fits ten across without wrapping oddly on the 41mm watch. | — |
| SET-06 | P1 | device | Delete asks for confirmation ([B-21](../bug-triage.md#b-21)) | Any subject | Tap Delete once, wait 6s | The label arms to "Delete?" and then takes itself back. Nothing is deleted. | — |
| SET-07 | P2 | device | Deleting keeps history | A subject with a past session | Delete it, open Metrics | Past sessions still show the name | — |
| SET-08 | P2 | device | Duplicate names are refused ([B-20](../bug-triage.md#b-20)) | Any | Add "Maths", then try to add "maths" | "Already used." under the field and Save disabled | — |
| SET-08b | P2 | device | Saving a name does not flash its own duplicate warning | Any | Add "Physics" and watch the sheet as it closes | The sheet dismisses with nothing under the field. Saving makes the name taken, and the sheet is still on screen while it goes. | — |
| SET-09 | P2 | device | The eleventh subject gets the least-used colour ([B-22](../bug-triage.md#b-22)) | Ten subjects, all colours used once | Add an eleventh | Any colour. Add a twelfth and check it is not the eleventh's. | — |

## Metrics — `MET`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MET-01 | P1 | device | "Today" advances while a session runs ([B-09](../bug-triage.md#b-09)) | Session started from the Action Button | Open Metrics from Start, wait two minutes | The number advances on each minute | — |
| MET-02 | P2 | device | A streak of 1 is not shown | One study-day | Open Metrics | No streak text | — |
| MET-03 | P2 | device | A streak survives today being empty | Three past days, nothing today | Open Metrics | "3 day streak" | — |
| MET-04 | P2 | device | The heatmap is weekday-down, week-across | Two weeks of varied data | Open Metrics | Rows are weekdays; columns advance left to right | — |
| MET-05 | P2 | device, VoiceOver | Weekday bars announce the day ([B-15](../bug-triage.md#b-15)) | Any week | VoiceOver onto a bar | "Monday", then the duration — or "Nothing" for an empty day | — |
| MET-06 | P2 | device, VoiceOver | The heatmap announces its data ([B-15](../bug-triage.md#b-15)) | Any history | VoiceOver onto the heatmap | "Last twelve weeks", then days studied, total, and best day | — |
| MET-07 | P2 | device | Both charts use the ring's copper, not the accent | Any history | Compare against the Start ring | The same copper | — |

## Pairing — `PAIR`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PAIR-01 | P2 | device, network | A code appears | Online | Open Pair | Four characters at 32pt, uppercase | — |
| PAIR-02 | P2 | device, airplane mode | Failure is stated and retryable | Offline | Open Pair | "Couldn't reach the server." and a Try Again button | — |
| PAIR-03 | P2 | device, network | Claiming the code still changes nothing on the watch ([B-24](../bug-triage.md#b-24)) | Online | Show a code, claim it on the web | The watch says nothing. Known and unfixed — it would need polling or a push. | — |
| PAIR-04 | P2 | device, VoiceOver | The code is spelled in the case shown ([B-23](../bug-triage.md#b-23)) | Online, a lowercase code from the server | VoiceOver onto the code | The same uppercase characters the screen draws | — |
