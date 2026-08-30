import { json, error } from '@sveltejs/kit';
import { eq } from 'drizzle-orm';
import { database } from '$lib/server/db';
import { device, pairCode } from '$lib/server/db/schema';
import { CODE_TTL_MS, pairingCode } from '$lib/server/codes';
import type { RequestHandler } from './$types';

/** The watch asks for a code; the code is what gets typed on the web. */
export const POST: RequestHandler = async ({ request, platform }) => {
	const body = (await request.json().catch(() => null)) as { deviceToken?: string } | null;
	const token = body?.deviceToken?.trim();
	if (!token || token.length < 8 || token.length > 128) error(400, 'deviceToken required');

	const db = database(platform);

	const timezone = request.headers.get('x-diem-tz') ?? 'UTC';
	const [row] = await db
		.insert(device)
		.values({ token, timezone })
		.onConflictDoUpdate({
			target: device.token,
			set: { seenAt: new Date(), timezone }
		})
		.returning();

	// One live code per device: a new request replaces the old one.
	await db.delete(pairCode).where(eq(pairCode.deviceId, row.id));

	const expiresAt = new Date(Date.now() + CODE_TTL_MS);
	const code = pairingCode();
	await db.insert(pairCode).values({ code, deviceId: row.id, expiresAt });

	return json({ code, expiresAt: expiresAt.toISOString() });
};
