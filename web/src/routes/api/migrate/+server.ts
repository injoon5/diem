import { json, error } from '@sveltejs/kit';
import { and, eq, gt, isNull } from 'drizzle-orm';
import { database } from '$lib/server/db';
import { device, interval, pairCode, subject } from '$lib/server/db/schema';
import { currentDevice, setSession } from '$lib/server/auth';
import type { RequestHandler } from './$types';

/**
 * Move a profile onto a new watch.
 *
 * The one thing the web is genuinely in charge of. Everything a watch records
 * is scoped to the device row it synced from, so a new watch starts empty and
 * has no way of knowing it is a replacement — only the browser holding the old
 * session can say so.
 *
 * The profile does not move: the *token* does. The old device row keeps its id
 * and therefore its whole history, adopts the new watch's token, and the row
 * the new watch made when it paired is folded in and dropped. Anything the new
 * watch had already synced comes along, because ids are watch-generated and
 * globally unique, so nothing collides on the way over.
 *
 * The old watch's token now matches nothing. It gets a 401 on its next sync and
 * quietly stops — which is what retiring a watch should look like.
 */
export const POST: RequestHandler = async (event) => {
	const db = database(event.platform);
	const owner = await currentDevice(event, db);
	if (!owner) error(401, 'Not paired');

	const body = (await event.request.json().catch(() => null)) as { code?: string } | null;
	const code = body?.code?.trim().toUpperCase();
	if (!code || code.length !== 6) error(400, 'A six-character code is required');

	const [match] = await db
		.select({ id: device.id, token: device.token, timezone: device.timezone })
		.from(pairCode)
		.innerJoin(device, eq(device.id, pairCode.deviceId))
		.where(
			and(eq(pairCode.code, code), isNull(pairCode.claimedAt), gt(pairCode.expiresAt, new Date()))
		)
		.limit(1);

	if (!match) error(404, 'That code has expired or was already used');

	// Re-pairing the watch you are already on. Nothing to move, and saying so
	// beats reporting a migration that did nothing.
	if (match.id === owner.id) return json({ ok: true, moved: false });

	// D1 has no interactive transactions, so this goes as one batch: the
	// statements run in order and the whole thing lands or none of it does.
	// Order matters — the children move off the old row before it is deleted,
	// and it is deleted before its token is taken, because tokens are unique.
	await db.batch([
		db.update(interval).set({ deviceId: owner.id }).where(eq(interval.deviceId, match.id)),
		db.update(subject).set({ deviceId: owner.id }).where(eq(subject.deviceId, match.id)),
		db.delete(pairCode).where(eq(pairCode.deviceId, match.id)),
		db.delete(device).where(eq(device.id, match.id)),
		db
			.update(device)
			.set({ token: match.token, timezone: match.timezone, seenAt: new Date() })
			.where(eq(device.id, owner.id))
	]);

	// The cookie holds the token, and the token just changed.
	setSession(event.cookies, match.token);
	return json({ ok: true, moved: true });
};
