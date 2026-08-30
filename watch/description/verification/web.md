# Checklist — the web

Covers [`web/`](../web/) and [`foundations/sync-model.md`](../foundations/sync-model.md).
One table per document, one row per observable claim. `—` in Result means not
yet run.

Read [`README.md`](README.md) first. Unlike the watch checklists, **a first pass
has been run here** — see [What the scripted pass covered](#what-the-scripted-pass-covered)
for exactly what "pass" means and what it could not see.

## Bringing the surface up

```sh
cd web
npm install
npm run db:migrate          # applies the migrations to a local D1
npm run dev
```

`http://localhost:5173`. A watch is not required to exercise the API: a device
identifies itself with a token of its own choosing in `X-Diem-Device`, so `curl`
can stand in for one. A browser is required for anything about what is on screen.

The scripted half of this checklist is kept as a script. Against an empty
database, with a dev server on port 5177:

```sh
cd web
rm -rf .wrangler && npx wrangler d1 migrations apply diem --local
npm run dev                     # in another shell, on port 5177
sh scripts/api-pass.sh
```

42 checks, named for the rows below. All 42 pass.

## The sync model — `SYNC`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SYNC-01 | P1 | curl | A device row is created on first contact ([doc](../foundations/sync-model.md#the-five-phases)) | Empty database | `POST /api/pair` with a new token | A six-character code and an expiry ten minutes out | **pass** |
| SYNC-02 | P1 | curl | Re-sending an interval stores it once ([doc](../foundations/sync-model.md#why-nothing-needs-merging)) | Paired device | Push the same interval twice | Both calls report it accepted; one row exists | **pass** |
| SYNC-03 | P1 | curl | An older subject write is dropped ([doc](../foundations/sync-model.md#why-nothing-needs-merging)) | A subject at `updatedAt` T | Push the same id at T−1 day | 200, and the returned list is unchanged | **pass** |
| SYNC-04 | P1 | curl | A newer subject write wins | Following SYNC-03 | Push the same id at T+1 day | The returned list carries the new name and colour | **pass** |
| SYNC-05 | P1 | curl | A session is bucketed in the watch's zone, not the server's ([doc](../foundations/sync-model.md)) | `X-Diem-TZ: Asia/Seoul` | Push an interval at `2026-08-29T18:00Z` — 03:00 Seoul — and read the summary | It lands on `2026-08-29`, the day before the one it starts in, because the study-day begins at 4am | **pass** |
| SYNC-06 | P1 | curl | The 4am boundary is a boundary, not a rounding | As above | Push an interval at `2026-08-30T01:00Z` — 10:00 Seoul | It lands on `2026-08-30` | **pass** |
| SYNC-07 | P1 | curl | An unknown token is refused | Any | `GET /api/summary` with no headers | 401 | **pass** |
| SYNC-08 | P2 | curl | The pull is cursored on start time | 1 interval | `GET /api/intervals?since=` a year ago | The interval, and `cursor: null` because the page is not full | **pass** |
| SYNC-09 | P2 | curl | A discard deletes only the caller's rows | Two devices, one interval each | `DELETE /api/intervals` from device A with device B's interval id | `deleted: 0`; B's row survives | — |
| SYNC-10 | P2 | curl | The timezone header is adopted on every request | Paired device | Send a request with a different `X-Diem-TZ` | The summary comes back in the new zone, and the whole year re-buckets | **pass** |
| SYNC-11 | P3 | browser | A failed push leaves nothing behind | Paired device, server stopped | Push, then restart and push again | The interval arrives once | — |
| SYNC-12 | P2 | curl | The summary read holds up at a year of heavy use | 6,000 intervals on one device | `GET /api/summary` | 200, a 21KB body, in tens of milliseconds. The unbounded read is not a problem at this scale. | **pass** |

## The dashboard — `DASH`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DASH-01 | P1 | browser | Signed out, the page is the pairing card ([doc](../web/dashboard.md#what-you-see)) | No cookie | Open `/` | One card, "Pair your watch", a six-character field | — |
| DASH-02 | P1 | curl | A code claims a session | A code from `POST /api/pair` | `POST /api/claim` with it | 200, and a `diem_device` cookie | **pass** |
| DASH-03 | P1 | curl | A code is single use | Following DASH-02 | Claim the same code again | 404, "expired or was already used" | — |
| DASH-04 | P1 | curl | A wrong code and a lapsed code are indistinguishable ([doc](../web/dashboard.md#pairing-from-this-side)) | Any | Claim `ZZZZZZ` | The same 404 and the same message as DASH-03 | — |
| DASH-05 | P1 | browser | The three numbers are the streak, the 30-day goal rate and the window total ([doc](../web/dashboard.md#the-three-numbers)) | Two consecutive days logged, goal 90m, neither day reaching it | Open `/` | Streak 2, Goal hit 0%, Total the sum in hours | **pass** (checked in the payload, not on screen) |
| DASH-06 | P2 | browser | Today being empty does not break the streak | Yesterday logged, today not | Open `/` | The streak still counts yesterday | — |
| DASH-07 | P2 | browser | A zero day does break it | A gap in the middle | Open `/` | The streak counts back only to the gap | — |
| DASH-08 | P2 | browser | A free day stays neutral in the grid ([doc](../web/dashboard.md#the-year)) | One day of free study, one under a subject | Open `/` | The free day is grey; the other takes its subject's colour | — |
| DASH-09 | P2 | browser | A rename is replaced by the server's answer ([doc](../web/dashboard.md#renaming-a-subject)) | One subject | Rename it | The list redraws from the response | **pass** (checked in the payload) |
| DASH-10 | P1 | curl | A stale write is still dropped by the server | A subject at T | Push the same id at T−1 day | 200, and the list comes back unchanged | **pass** |
| DASH-11 | P1 | browser | 4am refetches on its own ([B-44](../bug-triage.md#b-44)) | Loaded before 04:00 local | Leave it open past 04:00 | The streak and the last cell roll over without a reload. Regression: this used to stay a day stale. | — |
| DASH-12 | P1 | browser | Looking at the tab again refetches ([B-44](../bug-triage.md#b-44)) | Dashboard open | Push an interval, switch away, switch back | The new session is there | — |
| DASH-13 | P1 | browser | Sign out clears the session ([B-43](../bug-triage.md#b-43)) | Signed in | Press Sign out in the footer | The pairing card returns and the cookie is gone | **pass** — driven in a browser; `document.cookie` empty afterwards |
| DASH-17 | P2 | browser | A failed refresh leaves the drawn page alone | Loaded, then server stopped | Switch away and back | The page stays as it was; no error card | — |
| DASH-18 | P1 | browser | A stale rename says which it was ([B-45](../bug-triage.md#b-45)) | A subject renamed more recently on the watch | Rename it on the web | `Kept "…" — the watch renamed it more recently.` | — |
| DASH-14 | P3 | browser | The loading blocks match what replaces them | Slow network | Open `/` | The shimmer blocks are the height of the stats, bars and grid; nothing jumps | — |
| DASH-15 | P3 | browser, reduced motion | The shimmer and the bars hold still | Reduce Motion on | Open `/` | No shimmer, no bar growth | — |
| DASH-16 | P2 | browser, screen reader | The grid is one labelled image, not 371 cells | Any | Swipe to the grid | "Study time over the last year" | — |

## Claiming a profile — `PROF`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PROF-01 | P1 | curl | A handle is lowercased on claim ([doc](../web/profile.md#what-a-handle-may-be)) | Paired device | Claim `Injoon` | The profile comes back as `injoon` | **pass** |
| PROF-02 | P1 | curl | A reserved word is refused | Paired device | Claim `api` | 422, "That one is spoken for." | **pass** |
| PROF-03 | P1 | curl | A malformed handle is refused | Paired device | Claim `-nope-` | 422 | **pass** |
| PROF-04 | P1 | curl | A taken handle is refused | Two devices | Claim the same handle from the second | 409, "That handle is taken." | **pass** |
| PROF-05 | P1 | curl | A released handle is retired, not recycled ([B-46](../bug-triage.md#b-46)) | Device A holding `alpha` | Rename A to `beta`, then claim `alpha` from device B | 409. Regression: B used to get it. | **pass** |
| PROF-05b | P1 | curl | The old address stays gone | Following PROF-05 | `GET /alpha` | 404 | **pass** |
| PROF-05c | P1 | curl | Not even its own owner can take it back | Following PROF-05 | Claim `alpha` from device A again | 409 | **pass** |
| PROF-06 | P2 | curl | A display name is trimmed and its whitespace collapsed ([doc](../web/profile.md#the-display-name)) | Paired device | Set `"  Injoon   Oh "` | `Injoon Oh` | **pass** |
| PROF-13 | P1 | curl | The first claim does not spend a change ([doc](../web/profile.md#the-three-changes)) | Fresh device | Claim a handle | `changesLeft: 3` | **pass** |
| PROF-14 | P1 | curl | Three changes are allowed and a fourth is not | Following PROF-13 | Rename four times | 3 succeed, counting down to 0; the fourth is 409, "You have used all three handle changes." | **pass** |
| PROF-15 | P1 | curl | A refused change does not spend one | Fresh device with a handle | Try to claim a handle another device holds | 409, and `changesLeft` is still 3 | **pass** |
| PROF-16 | P2 | curl | Re-submitting the handle already held is not a change | A device with a handle | Send the same handle again | 200, `changesLeft` unchanged | **pass** |
| PROF-17 | P2 | curl | An exhausted budget does not lock the rest of the card | A device with 0 changes left | Set a display name and toggle the switch | Both succeed | **pass** |
| PROF-18 | P2 | browser | The budget is shown before it is spent ([doc](../web/profile.md#the-three-changes)) | A device with 2 left | Open the Change form | "You get three changes in all — two changes left." | — |
| PROF-19 | P2 | browser | The Change button goes when the budget does | A device with 0 left | Look at the live card | "No changes left" in place of the button | — |
| PROF-20 | P1 | curl | The floor is three characters ([B-49](../bug-triage.md#b-49)) | Paired device | Claim `ab` | 422. Regression: this used to be accepted and served. | **pass** |
| PROF-21 | P2 | curl | The ceiling is twenty | Paired device | Claim 21 characters, then 20 | 422, then 200 | **pass** |
| PROF-22 | P2 | curl | A device still costs nothing to create | None | `POST /api/pair` three times with invented tokens | Three devices, three codes — but none of them can claim a handle | **pass** |
| PROF-23 | P1 | curl | A handle needs a logged session first ([B-50](../bug-triage.md#b-50)) | A paired device with no intervals | Claim a handle | 409, "Log a session on your watch before claiming a handle." | **pass** |
| PROF-07 | P2 | curl | Clearing the display name falls back to the handle | Following PROF-06 | Set it to `""` | Null, and the public page leads with the handle | — |
| PROF-08 | P2 | browser | Claim stays disabled under three characters | No handle | Type two characters | The button is disabled | — |
| PROF-09 | P2 | browser | Illegal characters never enter the field | No handle | Type `In joon!` | The field holds `injoon` | — |
| PROF-10 | P2 | browser | "Saved." appears and fades | A claimed handle | Toggle the switch | The word appears under the card and goes after about 1.6s | — |
| PROF-11 | P2 | browser, keyboard | The switch is reachable and operable from the keyboard ([doc](../web/profile.md#cross-cutting)) | A claimed handle | Tab to it, press Space | It toggles, with a visible focus ring | — |
| PROF-12 | P3 | browser, reduced motion | The switch knob does not travel | Reduce Motion on | Toggle it | It changes state without the 180ms slide | — |

## The public profile — `PUB`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PUB-01 | P1 | curl | The page is public ([doc](../web/public-profile.md#what-you-see)) | A claimed handle | `GET /{handle}` with no cookie | 200 | **pass** |
| PUB-02 | P1 | curl | Stats only names no subject ([doc](../web/public-profile.md#what-stats-only-actually-withholds)) | Handle claimed, switch off, one named subject with days against it | `GET /{handle}` and search the HTML | The subject's name does not appear | **pass** |
| PUB-03 | P1 | curl | Stats only leaks no subject id either | As PUB-02 | Search the HTML for the subject's id | It does not appear | **pass** |
| PUB-04 | P1 | curl | The stats themselves still render | As PUB-02 | Search the HTML | Streak, Goal hit and Total are present, and the grid has 372 cells | **pass** |
| PUB-05 | P1 | curl | Opting in adds the names | Switch on | `GET /{handle}` | The subject's name and a Subjects heading appear | **pass** |
| PUB-06 | P1 | curl | An unknown handle 404s | Any | `GET /nobody` | 404 | **pass** |
| PUB-07 | P1 | curl | A reserved word 404s rather than hinting | Any | `GET /api` | 404 | **pass** |
| PUB-08 | P2 | curl | A handle resolves case-insensitively | `injoon` claimed | `GET /INJOON` | 200, the same page | **pass** |
| PUB-09 | P2 | curl | `/api/*` still reaches the API, not the profile route | Any | `GET /api/summary` unauthenticated | 401 from the endpoint, not 404 from the profile page | **pass** |
| PUB-10 | P2 | curl | Link previews carry the two numbers and no subject | Switch off | Read the `og:description` | "A N-day streak and N hours studied." | **pass** |
| PUB-11 | P2 | browser | The display name leads, the handle follows | A name set | Open the page | The name at 22pt, the handle faint beside it | **pass** — driven in a browser |
| PUB-15 | P1 | browser | The goal is drawn under the rate ([B-47](../bug-triage.md#b-47)) | Goal 90m | Open the page | "of 1h 30m a day" under the percentage | **pass** — driven in a browser |
| PUB-12 | P2 | browser | With no name the handle leads alone | Name cleared | Open the page | No second line | — |
| PUB-13 | P3 | browser | The page follows the reader's colour scheme | Any | Switch the system between light and dark | The page follows, and contrast holds in both | — |
| PUB-14 | P3 | browser | The subject pills carry a colour dot, not colour alone | Switch on | Open the page | Each pill has a dot and a name | — |

## Replacing a watch — `MOVE`

| ID | P | Needs | Claim | Setup | Steps | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MOVE-01 | P1 | curl | The whole history moves ([doc](../web/replacing-a-watch.md#what-actually-moves)) | Device A with 2 intervals and a subject; device B paired, holding 1 interval of its own | Migrate with B's code, then read the summary as B | All 3 intervals and the subject, under one device | **pass** |
| MOVE-02 | P1 | curl | The old watch is refused afterwards | Following MOVE-01 | `GET /api/summary` as A | 401 | **pass** |
| MOVE-03 | P1 | curl | The old device row is gone and nothing is orphaned | Following MOVE-01 | Count rows in the database | One device; no interval or subject pointing at a missing device | **pass** |
| MOVE-04 | P1 | curl | The browser session survives ([doc](../web/replacing-a-watch.md#what-actually-moves)) | Following MOVE-01 | `GET /api/summary` with the same cookie | 200 | **pass** |
| MOVE-05 | P1 | curl | The profile survives | Following MOVE-01, a handle claimed before the move | `GET /{handle}` | 200, with the moved history | **pass** |
| MOVE-06 | P2 | curl | Migrating to the watch already in use is a no-op | One device | Pair it again and migrate with its own code | `moved: false`, nothing changed | — |
| MOVE-07 | P2 | curl | An expired or used code is refused | Any | Migrate with a used code | 404, and nothing moved | — |
| MOVE-08 | P2 | browser | Move stays disabled under six characters | Signed in | Open the card, type five | The button is disabled | — |
| MOVE-09 | P1 | browser | Continue confirms rather than commits ([B-48](../bug-triage.md#b-48)) | Signed in, a valid code | Type it and press Continue | "Move everything to {code}?", the consequences spelled out, "Yes, move it" and "Back". Nothing has been sent. | **pass** — driven in a browser |
| MOVE-10 | P2 | browser | The dashboard reloads from scratch afterwards | Following MOVE-09 | Press "Yes, move it" | The page comes back on the new device with the history intact | **pass** — driven in a browser |
| MOVE-12 | P2 | browser | Back returns to the field | At the confirmation | Press Back | The field returns with the code still in it | — |
| MOVE-13 | P1 | device | The old watch says it was replaced ([B-42](../bug-triage.md#b-42)) | A replaced watch | Open Settings on it | A line under Pair with Web saying it no longer syncs | — (needs a watch, and this is Swift that has only been parsed) |
| MOVE-11 | P2 | browser, screen reader | The two six-character fields are told apart | Signed in, the card open | Swipe between them | "Pairing code" and "Pairing code from the new watch" | — |

## Not checkable by hand

- Whether the old watch has unpushed sessions at the moment of a replacement, and what is lost with them ([B-42](../bug-triage.md#b-42)) — needs two real watches and a controlled offline window.
- Whether a request that fails *after* the server acted leaves the card wrong ([B-48](../bug-triage.md#b-48)) — needs the connection cut between the server's commit and its response.
- Whether a route added later collides with a handle already claimed.

## What the scripted pass covered

Every row marked **pass** above was run against a real database — a local D1 —
driving the API with `curl` and reading the returned JSON, the returned HTML, and
the database itself. It is reproducible: `web/scripts/api-pass.sh`, 42 checks,
all passing on a database created fresh from the migrations. That pass established: pairing, idempotent interval push,
last-write-wins subjects in both directions, the cursored pull, the 4am bucketing
in `Asia/Seoul` on both sides of the boundary, the 401 paths, handle validation
including the reserved list and the taken case, both positions of the subjects
switch with the HTML searched for leaks, and the full watch replacement including
a new watch that had already logged a session.

It did **not** cover anything about what is on screen: no layout, no colour, no
focus ring, no animation, no screen reader, no reduced motion, and no page opened
in an actual browser. Every row needing `browser` is either unrun or, where it is
marked "checked in the payload", verified only at the level of the data the page
was given. No document here should move to `verified` on the strength of this
pass.

Two claims were **falsified** by the first pass and the documents were corrected
rather than the code: handles turned out to be released on rename and reclaimable
by anyone ([B-46](../bug-triage.md#b-46)), which had been written up as the
opposite; and `DELETE /api/claim` turned out to work, which made
[B-43](../bug-triage.md#b-43) a missing control rather than a missing endpoint.
Both have since been fixed, and the rows that reproduced them now assert the
opposite — they are regression checks.

A **second, smaller pass was driven in a browser** for the four things a script
cannot reach: the sign-out footer, the goal under the public rate, the
confirmation step in front of a watch replacement, and the replacement itself
end to end. Those rows say "driven in a browser". Everything else needing a
browser is still unrun.
