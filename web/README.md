# Diem — web

SvelteKit on Cloudflare Workers, Drizzle against D1. The dashboard, the sync API,
and the public profiles at `diem.ij5.dev/{handle}`.

## Running it

```sh
npm install
npm run db:migrate    # applies the migrations to a local D1
npm run dev
```

There is no `.env` and no connection string. D1 arrives as a binding, and the
adapter reads `wrangler.jsonc` to emulate it during `npm run dev`, so
`platform.env.DB` is the same shape locally as it is deployed.

`npm run check` typechecks, `npm test` runs the day-bucketing, streak and
goal-rate tests. With a dev server up on port 5177 and an empty database,
`sh scripts/api-pass.sh` runs 42 checks over the whole API — pairing, idempotent
push, last-write-wins, the 4am bucketing, handles, both positions of the public
switch, and a full watch replacement.

## API

| Route | |
| --- | --- |
| `POST /api/pair` | `{ deviceToken }` → a 6-character code, valid ten minutes |
| `POST /api/claim` | `{ code }` → sets the browser's session cookie |
| `DELETE /api/claim` | Clears it. The dashboard's Sign out |
| `POST /api/intervals` | Idempotent on interval id. Only completed intervals are stored |
| `DELETE /api/intervals` | Un-tells the server about discarded ones, scoped to the caller |
| `GET /api/intervals?since=` | Paged, cursored on `started_at` |
| `GET /api/subjects` | |
| `POST /api/subjects` | Last-write-wins on `updated_at` |
| `GET /api/summary` | The dashboard's one read: a year of days, streak, hit rate, profile |
| `POST /api/profile` | Claim or change a handle, set a display name, opt into showing subjects. Three changes per profile |
| `POST /api/migrate` | Move the profile and its history onto a new watch |
| `GET /{handle}` | The public profile, server-rendered, no session required |

The watch authenticates with `X-Diem-Device`; the browser with the cookie it
got by entering a pairing code. Both resolve to the same device row.

Two headers travel with every watch request: `X-Diem-TZ`, because sessions are
stored in UTC and bucketed by the local day they started in, and `X-Diem-Goal`,
because the goal-hit rate needs a copy of the one setting that lives on the
watch.

## Handles

Three to twenty characters, lowercase, claimed first come, and held back from a
list of about thirty reserved words — `api` above all, since handles sit at the
root of the site. A profile gets **three** changes after its first claim; the
first claim is free, and a rename refused as taken or reserved is not counted.

Two rules that are less obvious and both deliberate:

**A handle is claimable once, ever.** Giving one up in a rename retires it into
`retired_handle` in the same batch, so it is never free for an instant. Old links
404 rather than redirecting, which is the honest outcome — the alternative was a
released handle that could later resolve to a stranger under the name its first
owner was known by.

**Claiming one needs a logged session.** A device costs nothing to create, so
without this a script could hold every short handle on the site in minutes. It is
invisible to anyone using a watch and expensive for a squatter.

## The day boundary, and why it is not in SQL

A study-day runs 4am to 4am in the watch's timezone. Postgres could do that in
the query — `date_trunc('day', started_at AT TIME ZONE $zone) - interval '4
hours'` — but SQLite has no timezone database, and `datetime(x, 'localtime')`
means the *server's* zone, which in a Worker is always UTC.

So the bucketing moved into the application, in `summarize()`. A year of one
wrist's sessions is a few thousand narrow rows; summing them is cheaper than the
round trip that fetched them, and it puts the 4am rule next to the streak and
goal-rate rules it belongs with, where it can be unit-tested.

## What the web owns

The watch is the author and the web is the reader, with two exceptions. The
profile — handle, display name, and whether subjects are public — exists only
here; the watch has never heard of it. And replacing a watch is here because a
new watch cannot know it is a replacement: only the browser holding the old
session can say so. That endpoint moves the *token* onto the existing device
row rather than moving the history, so nothing is copied and nothing collides.

Everything else the web writes is a subject rename, which settles last-write-wins
against the watch on `updated_at`.

## Deploying

See the root [`README.md`](../README.md).
