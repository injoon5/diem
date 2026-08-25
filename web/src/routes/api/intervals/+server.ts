import { json, error } from '@sveltejs/kit';
import { and, asc, eq, gt, inArray } from 'drizzle-orm';
import { db } from '$lib/server/db';
import { interval } from '$lib/server/db/schema';
import { currentDevice } from '$lib/server/auth';
import { parseInterval } from '$lib/server/validate';
import type { IntervalDTO } from '$lib/types';
import type { RequestHandler } from './$types';

const PAGE = 500;

/**
 * Idempotent on interval id. Intervals are immutable once ended, so a resend of
 * something already stored is a no-op rather than a merge.
 */
export const POST: RequestHandler = async (event) => {
	const device = await currentDevice(event);
	if (!device) error(401, 'Unknown device');

	const body = (await event.request.json().catch(() => null)) as { intervals?: unknown[] } | null;
	const incoming = Array.isArray(body?.intervals) ? body.intervals.slice(0, 1000) : [];
	const rows = incoming.map(parseInterval).filter((row) => row !== null);
	if (rows.length === 0) return json({ accepted: [] });

	await db
		.insert(interval)
		.values(rows.map((row) => ({ ...row, deviceId: device.id })))
		.onConflictDoNothing({ target: interval.id });

	// Everything valid is accepted: a duplicate is already stored, which is the
	// same outcome from the watch's side.
	return json({ accepted: rows.map((row) => row.id) });
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Un-tells the server about intervals the watch discarded.
 *
 * Intervals are immutable once ended, so there is no update path — but a
 * discarded session has to be able to leave, or throwing one away on the watch
 * leaves it on the web for good. Scoped to the calling device, so an id is
 * never enough on its own to delete somebody else's row, and idempotent: an id
 * that is already gone reports as deleted because that is the outcome asked
 * for.
 */
export const DELETE: RequestHandler = async (event) => {
	const device = await currentDevice(event);
	if (!device) error(401, 'Unknown device');

	const body = (await event.request.json().catch(() => null)) as { ids?: unknown[] } | null;
	const ids = (Array.isArray(body?.ids) ? body.ids.slice(0, 1000) : []).filter(
		(id): id is string => typeof id === 'string' && UUID.test(id)
	);
	if (ids.length === 0) return json({ deleted: 0 });

	const removed = await db
		.delete(interval)
		.where(and(eq(interval.deviceId, device.id), inArray(interval.id, ids)))
		.returning({ id: interval.id });

	return json({ deleted: removed.length });
};

export const GET: RequestHandler = async (event) => {
	const device = await currentDevice(event);
	if (!device) error(401, 'Unknown device');

	const since = event.url.searchParams.get('since');
	const cursor = since ? new Date(since) : null;
	const bounded = cursor && !Number.isNaN(cursor.getTime()) ? cursor : new Date(0);

	const rows = await db
		.select()
		.from(interval)
		.where(and(eq(interval.deviceId, device.id), gt(interval.startedAt, bounded)))
		.orderBy(asc(interval.startedAt))
		.limit(PAGE);

	const intervals: IntervalDTO[] = rows.map((row) => ({
		id: row.id,
		sessionId: row.sessionId,
		subjectId: row.subjectId,
		startedAt: row.startedAt.toISOString(),
		endedAt: row.endedAt?.toISOString() ?? null,
		plannedSec: row.plannedSec
	}));

	return json({
		intervals,
		cursor: rows.length === PAGE ? intervals[intervals.length - 1].startedAt : null
	});
};
