# Diem — web

SvelteKit on `adapter-vercel`, Drizzle against PlanetScale Postgres.

## Running it

```sh
npm install
cp .env.example .env        # point DATABASE_URL at PSBouncer, port 6432
npm run db:migrate
npm run dev
```

`npm run check` typechecks, `npm test` runs the day-bucketing, streak and
goal-rate tests.

## API

| Route | |
| --- | --- |
| `POST /api/pair` | `{ deviceToken }` → a 6-character code, valid ten minutes |
| `POST /api/claim` | `{ code }` → sets the browser's session cookie |
| `POST /api/intervals` | Idempotent on interval id. Only completed intervals are stored |
| `GET /api/intervals?since=` | Paged, cursored on `started_at` |
| `GET /api/subjects` | |
| `POST /api/subjects` | Last-write-wins on `updated_at` |
| `GET /api/summary` | The dashboard's one read: a year of days, streak, hit rate |

The watch authenticates with `X-Diem-Device`; the browser with the cookie it
got by entering a pairing code. Both resolve to the same device row.

Two headers travel with every watch request: `X-Diem-TZ`, because sessions are
stored in UTC and bucketed by the local day they started in, and `X-Diem-Goal`,
because the goal-hit rate needs a copy of the one setting that lives on the
watch.

## Connection pooling

One `pg` pool per instance, wrapped in `attachDatabasePool` so it closes when
the instance suspends — without it, redeploys strand connections until the
pooler times them out. `max` stays at its default and `min` is 1. Transaction
-mode pooling breaks prepared statements, which `pg` doesn't use by default.
