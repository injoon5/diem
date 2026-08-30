import { eq } from 'drizzle-orm';
import type { Cookies, RequestEvent } from '@sveltejs/kit';
import type { Database } from './db';
import { device, type Device } from './db/schema';

export const SESSION_COOKIE = 'diem_device';

/**
 * The watch identifies itself with the token it generated on first launch; a
 * browser identifies itself with the cookie it got by entering a pairing code.
 * Either way it resolves to one device row.
 */
export async function currentDevice(event: RequestEvent, db: Database): Promise<Device | null> {
	const token =
		event.request.headers.get('x-diem-device') ?? event.cookies.get(SESSION_COOKIE) ?? null;
	if (!token) return null;

	const [found] = await db.select().from(device).where(eq(device.token, token)).limit(1);
	if (!found) return null;

	// The watch carries its timezone and goal along with every sync: the server
	// needs the timezone to bucket a session into a local day, and the goal to
	// work out a hit rate.
	const timezone = event.request.headers.get('x-diem-tz');
	const goal = Number(event.request.headers.get('x-diem-goal'));
	const patch: Partial<Device> = { seenAt: new Date() };
	if (timezone && timezone !== found.timezone) patch.timezone = timezone;
	if (Number.isFinite(goal) && goal > 0 && goal !== found.goalMinutes) patch.goalMinutes = goal;
	await db.update(device).set(patch).where(eq(device.id, found.id));

	return { ...found, ...patch };
}

export function setSession(cookies: Cookies, token: string) {
	cookies.set(SESSION_COOKIE, token, {
		path: '/',
		httpOnly: true,
		sameSite: 'lax',
		secure: true,
		maxAge: 60 * 60 * 24 * 400
	});
}

export function clearSession(cookies: Cookies) {
	cookies.delete(SESSION_COOKIE, { path: '/' });
}
