#!/bin/sh
# A scripted pass over the API, against a real local D1.
#
# It checks what a script can check: status codes, returned JSON, the HTML the
# public profile serves, and the database underneath. It cannot see anything on
# screen — see watch/description/verification/web.md, whose row IDs these names
# match.
#
#   npm run dev                 # in another shell, on port 5177
#   sh scripts/api-pass.sh
#
# Expects an empty database:
#   rm -rf .wrangler && npx wrangler d1 migrations apply diem --local

B=${DIEM_BASE:-http://localhost:5177}
ok=0; bad=0
chk() { # name expected actual
  if [ "$2" = "$3" ]; then ok=$((ok+1)); printf '  pass  %s\n' "$1"
  else bad=$((bad+1)); printf '  FAIL  %s  (expected %s, got %s)\n' "$1" "$2" "$3"; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
# A device must have studied before it can claim a handle, so give it a session.
studied() {
  curl -s -o /dev/null -X POST $B/api/intervals -H 'content-type: application/json' \
    -H "X-Diem-Device: $1" -d "{\"intervals\":[{\"id\":\"$2\",\"sessionId\":\"$2\",\"subjectId\":null,\"startedAt\":\"2026-08-20T02:00:00.000Z\",\"endedAt\":\"2026-08-20T02:30:00.000Z\",\"plannedSec\":null}]}"
}
json() { curl -s "$@"; }

A=watch-A-token-1111; C=watch-C-token-3333
PAIR=$(json -X POST $B/api/pair -H 'content-type: application/json' -H 'X-Diem-TZ: Asia/Seoul' -d "{\"deviceToken\":\"$A\"}")
CODE=$(printf '%s' "$PAIR" | python3 -c 'import sys,json;print(json.load(sys.stdin)["code"])')
chk "SYNC-01 pair returns a 6-char code" 6 "${#CODE}"
chk "DASH-02 claim sets a session" 200 "$(code -X POST $B/api/claim -H 'content-type: application/json' -c /tmp/pass-cj.txt -d "{\"code\":\"$CODE\"}")"
chk "DASH-03 a code is single use" 404 "$(code -X POST $B/api/claim -H 'content-type: application/json' -d "{\"code\":\"$CODE\"}")"
chk "DASH-04 a wrong code looks the same" 404 "$(code -X POST $B/api/claim -H 'content-type: application/json' -d '{"code":"ZZZZZZ"}')"
chk "SYNC-07 no token is refused" 401 "$(code $B/api/summary)"

IV='{"id":"11111111-1111-4111-8111-111111111111","sessionId":"22222222-2222-4222-8222-222222222222","subjectId":null,"startedAt":"2026-08-30T01:00:00.000Z","endedAt":"2026-08-30T02:00:00.000Z","plannedSec":3600}'
json -X POST $B/api/intervals -H 'content-type: application/json' -H "X-Diem-Device: $A" -H 'X-Diem-TZ: Asia/Seoul' -H 'X-Diem-Goal: 90' -d "{\"intervals\":[$IV]}" > /dev/null
json -X POST $B/api/intervals -H 'content-type: application/json' -H "X-Diem-Device: $A" -d "{\"intervals\":[$IV]}" > /dev/null
chk "SYNC-02 a resend stores one row" 1 "$(sqlite3 "$(ls .wrangler/state/v3/d1/miniflare-D1DatabaseObject/*.sqlite | grep -v metadata)" 'select count(*) from interval')"

json -X POST $B/api/intervals -H 'content-type: application/json' -H "X-Diem-Device: $A" -H 'X-Diem-TZ: Asia/Seoul' -d '{"intervals":[{"id":"44444444-4444-4444-8444-444444444444","sessionId":"55555555-5555-4555-8555-555555555555","subjectId":"33333333-3333-4333-8333-333333333333","startedAt":"2026-08-29T18:00:00.000Z","endedAt":"2026-08-29T18:30:00.000Z","plannedSec":null}]}' > /dev/null

SUB='{"id":"33333333-3333-4333-8333-333333333333","name":"Korean","colorIndex":2,"archived":false,"updatedAt":"2026-08-30T10:00:00.000Z","deletedAt":null}'
json -X POST $B/api/subjects -H 'content-type: application/json' -H "X-Diem-Device: $A" -d "{\"subjects\":[$SUB]}" > /dev/null
STALE=$(json -X POST $B/api/subjects -H 'content-type: application/json' -H "X-Diem-Device: $A" -d '{"subjects":[{"id":"33333333-3333-4333-8333-333333333333","name":"STALE","colorIndex":9,"archived":true,"updatedAt":"2026-08-29T10:00:00.000Z","deletedAt":null}]}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["subjects"][0]["name"])')
chk "SYNC-03 an older write is dropped" "Korean" "$STALE"
NEW=$(json -X POST $B/api/subjects -H 'content-type: application/json' -H "X-Diem-Device: $A" -d '{"subjects":[{"id":"33333333-3333-4333-8333-333333333333","name":"Korean II","colorIndex":5,"archived":false,"updatedAt":"2026-08-31T10:00:00.000Z","deletedAt":null}]}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["subjects"][0]["name"])')
chk "SYNC-04 a newer write wins" "Korean II" "$NEW"

SUM=$(json $B/api/summary -H "X-Diem-Device: $A" -H 'X-Diem-TZ: Asia/Seoul' -H 'X-Diem-Goal: 90')
chk "SYNC-05 03:00 Seoul counts as the previous day" "2026-08-29" "$(printf '%s' "$SUM" | python3 -c 'import sys,json;print([d["day"] for d in json.load(sys.stdin)["days"] if d["seconds"]==1800][0])')"
chk "SYNC-06 10:00 Seoul counts as its own day" "2026-08-30" "$(printf '%s' "$SUM" | python3 -c 'import sys,json;print([d["day"] for d in json.load(sys.stdin)["days"] if d["seconds"]==3600][0])')"
chk "DASH-05 streak counts both days" 2 "$(printf '%s' "$SUM" | python3 -c 'import sys,json;print(json.load(sys.stdin)["streak"])')"
chk "DASH-05 goal rate is 0 at 90m" 0 "$(printf '%s' "$SUM" | python3 -c 'import sys,json;print(int(json.load(sys.stdin)["goalHitRate"]))')"
chk "SYNC-08 the pull is not full, so no cursor" "None" "$(json "$B/api/intervals?since=2026-01-01T00:00:00Z" -H "X-Diem-Device: $A" | python3 -c 'import sys,json;print(json.load(sys.stdin)["cursor"])')"

chk "PROF-01 a handle is lowercased" "injoon" "$(json -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $A" -d '{"handle":"Injoon","displayName":"  Injoon   Oh "}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["handle"])')"
chk "PROF-06 a display name is collapsed" "Injoon Oh" "$(json $B/api/summary -H "X-Diem-Device: $A" | python3 -c 'import sys,json;print(json.load(sys.stdin)["profile"]["displayName"])')"
chk "PROF-13 the first claim is free" 3 "$(json $B/api/summary -H "X-Diem-Device: $A" | python3 -c 'import sys,json;print(json.load(sys.stdin)["profile"]["changesLeft"])')"
chk "PROF-02 a reserved word is refused" 422 "$(code -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $A" -d '{"handle":"api"}')"
chk "PROF-03 a malformed handle is refused" 422 "$(code -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $A" -d '{"handle":"-nope-"}')"
chk "PROF-20 the floor is three characters (B-49)" 422 "$(code -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $A" -d '{"handle":"ab"}')"
chk "PROF-21 the ceiling is twenty" 422 "$(code -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $A" -d '{"handle":"aaaaaaaaaaaaaaaaaaaaa"}')"
chk "PROF-15 a refused change spends nothing" 3 "$(json $B/api/summary -H "X-Diem-Device: $A" | python3 -c 'import sys,json;print(json.load(sys.stdin)["profile"]["changesLeft"])')"

chk "PUB-01 the profile is public" 200 "$(code $B/injoon)"
chk "PUB-08 handles resolve case-insensitively" 200 "$(code $B/INJOON)"
chk "PUB-06 an unknown handle 404s" 404 "$(code $B/nobody)"
chk "PUB-07 a reserved word 404s" 404 "$(code $B/api)"
chk "PUB-09 /api/* still reaches the API" 401 "$(code $B/api/summary)"
P=$(json $B/injoon)
chk "PUB-02 stats only names no subject" 0 "$(printf '%s' "$P" | grep -c 'Korean II')"
chk "PUB-03 stats only leaks no subject id" 0 "$(printf '%s' "$P" | grep -c '33333333-3333')"
chk "PUB-04 the stats still render" 3 "$(printf '%s' "$P" | grep -oE 'Streak|Goal hit|Total' | sort -u | wc -l | tr -d ' ')"
json -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $A" -d '{"publicSubjects":true}' > /dev/null
chk "PUB-05 opting in adds the names" "yes" "$(json $B/injoon | grep -q 'Korean II' && echo yes || echo no)"
json -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $A" -d '{"publicSubjects":false}' > /dev/null

json -X POST $B/api/pair -H 'content-type: application/json' -d "{\"deviceToken\":\"$C\"}" > /dev/null
studied "$C" 90000000-0000-4000-8000-000000000002
json -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $C" -d '{"handle":"other"}' > /dev/null
chk "PROF-04 a taken handle is refused" 409 "$(code -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $C" -d '{"handle":"injoon"}')"

CAP=cap-token-9999
json -X POST $B/api/pair -H 'content-type: application/json' -d "{\"deviceToken\":\"$CAP\"}" > /dev/null
chk "PROF-23 a handle needs a logged session first (B-50)" 409 "$(code -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $CAP" -d '{"handle":"capzero"}')"
studied "$CAP" 90000000-0000-4000-8000-000000000001
json -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $CAP" -d '{"handle":"capzero"}' > /dev/null
for n in one two three; do json -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $CAP" -d "{\"handle\":\"cap$n\"}" > /dev/null; done
chk "PROF-14 the budget reaches zero" 0 "$(json $B/api/summary -H "X-Diem-Device: $CAP" | python3 -c 'import sys,json;print(json.load(sys.stdin)["profile"]["changesLeft"])')"
chk "PROF-14 a fourth change is refused" 409 "$(code -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $CAP" -d '{"handle":"capfour"}')"
chk "PROF-17 the rest of the card still works" 200 "$(code -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $CAP" -d '{"displayName":"Fine"}')"

NEWW=watch-B-token-2222
PAIR2=$(json -X POST $B/api/pair -H 'content-type: application/json' -H 'X-Diem-TZ: Asia/Seoul' -d "{\"deviceToken\":\"$NEWW\"}")
CODE2=$(printf '%s' "$PAIR2" | python3 -c 'import sys,json;print(json.load(sys.stdin)["code"])')
json -X POST $B/api/intervals -H 'content-type: application/json' -H "X-Diem-Device: $NEWW" -d '{"intervals":[{"id":"66666666-6666-4666-8666-666666666666","sessionId":"77777777-7777-4777-8777-777777777777","subjectId":null,"startedAt":"2026-08-30T05:00:00.000Z","endedAt":"2026-08-30T05:20:00.000Z","plannedSec":null}]}' > /dev/null
chk "MOVE-01 the move is accepted" 200 "$(code -X POST $B/api/migrate -H 'content-type: application/json' -b /tmp/pass-cj.txt -c /tmp/pass-cj.txt -d "{\"code\":\"$CODE2\"}")"
chk "MOVE-01 the whole history moved" 6600 "$(json $B/api/summary -H "X-Diem-Device: $NEWW" | python3 -c 'import sys,json;print(int(json.load(sys.stdin)["totalSeconds"]))')"
chk "MOVE-01 all three intervals are on the one device" 3 "$(sqlite3 "$(ls .wrangler/state/v3/d1/miniflare-D1DatabaseObject/*.sqlite | grep -v metadata)" "select count(*) from interval where device_id = (select id from device where token = '$NEWW')")"
chk "MOVE-01 the subject came too" "Korean II" "$(json $B/api/summary -H "X-Diem-Device: $NEWW" | python3 -c 'import sys,json;print(json.load(sys.stdin)["subjects"][0]["name"])')"
chk "MOVE-02 the old watch is refused" 401 "$(code $B/api/summary -H "X-Diem-Device: $A")"
chk "MOVE-03 nothing is orphaned" 0 "$(sqlite3 "$(ls .wrangler/state/v3/d1/miniflare-D1DatabaseObject/*.sqlite | grep -v metadata)" 'select count(*) from interval where device_id not in (select id from device)')"
chk "MOVE-04 the browser session survives" 200 "$(code $B/api/summary -b /tmp/pass-cj.txt)"
chk "MOVE-05 the profile survives" 200 "$(code $B/injoon)"
chk "PROF-05 a released handle is retired, not recycled (B-46)" 409 "$(json -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $NEWW" -d '{"handle":"renamed"}' > /dev/null; code -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $C" -d '{"handle":"injoon"}')"
chk "PROF-05 the old address stays gone" 404 "$(code $B/injoon)"
chk "PROF-05 nor can its own owner take it back" 409 "$(code -X POST $B/api/profile -H 'content-type: application/json' -H "X-Diem-Device: $NEWW" -d '{"handle":"injoon"}')"
chk "DASH-13 the sign-out endpoint works" 200 "$(code -X DELETE $B/api/claim -b /tmp/pass-cj.txt)"

printf '\n%s passed, %s failed\n' "$ok" "$bad"
[ "$bad" -eq 0 ]
