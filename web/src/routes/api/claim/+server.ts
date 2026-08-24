import { json, error } from '@sveltejs/kit';
import { and, eq, gt, isNull } from 'drizzle-orm';
import { db } from '$lib/server/db';
import { device, pairCode } from '$lib/server/db/schema';
import { setSession, clearSession } from '$lib/server/auth';
import type { RequestHandler } from './$types';

/** Enter the code once on the web to claim the device. */
export const POST: RequestHandler = async ({ request, cookies }) => {
	const body = (await request.json().catch(() => null)) as { code?: string } | null;
	const code = body?.code?.trim().toUpperCase();
	if (!code || code.length !== 6) error(400, 'A six-character code is required');

	const [match] = await db
		.select({ deviceId: pairCode.deviceId, token: device.token })
		.from(pairCode)
		.innerJoin(device, eq(device.id, pairCode.deviceId))
		.where(and(eq(pairCode.code, code), isNull(pairCode.claimedAt), gt(pairCode.expiresAt, new Date())))
		.limit(1);

	if (!match) error(404, 'That code has expired or was already used');

	await db.update(pairCode).set({ claimedAt: new Date() }).where(eq(pairCode.code, code));
	setSession(cookies, match.token);
	return json({ ok: true });
};

export const DELETE: RequestHandler = async ({ cookies }) => {
	clearSession(cookies);
	return json({ ok: true });
};
