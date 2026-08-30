import { json, error } from '@sveltejs/kit';
import { eq } from 'drizzle-orm';
import { database } from '$lib/server/db';
import { device, interval, retiredHandle } from '$lib/server/db/schema';
import { currentDevice } from '$lib/server/auth';
import { changesLeft, HANDLE_CHANGES, parseDisplayName, parseHandle } from '$lib/server/handles';
import type { ProfileDTO } from '$lib/types';
import type { RequestHandler } from './$types';

const MESSAGES = {
	shape: 'Three to twenty characters: letters, numbers and hyphens.',
	reserved: 'That one is spoken for.'
} as const;

/**
 * The profile is the only thing the web owns. Everything else on this API is
 * the watch telling the server what happened; this is the server being told
 * something the watch has no idea about.
 */
export const POST: RequestHandler = async (event) => {
	const db = database(event.platform);
	const owner = await currentDevice(event, db);
	if (!owner) error(401, 'Not paired');

	const body = (await event.request.json().catch(() => null)) as {
		handle?: unknown;
		displayName?: unknown;
		publicSubjects?: unknown;
	} | null;
	if (!body) error(400, 'Expected a body');

	const patch: Partial<typeof device.$inferInsert> = {};

	if ('handle' in body) {
		const parsed = parseHandle(body.handle);
		if ('error' in parsed) error(422, MESSAGES[parsed.error]);
		if (parsed.handle !== owner.handle) {
			// A device costs nothing to create, so without this a script could
			// hold every short handle on the site in minutes. Requiring a real
			// session first is nearly free for anyone using a watch and makes a
			// squatter fabricate study history per handle.
			const [studied] = await db
				.select({ id: interval.id })
				.from(interval)
				.where(eq(interval.deviceId, owner.id))
				.limit(1);
			if (!studied) error(409, 'Log a session on your watch before claiming a handle.');

			// Only a *move* is counted. Taking a handle for the first time is
			// not a change, and it does not spend one.
			if (owner.handle !== null) {
				if (owner.handleChanges >= HANDLE_CHANGES) {
					error(409, 'You have used all three handle changes.');
				}
				patch.handleChanges = owner.handleChanges + 1;
			}

			const [taken] = await db
				.select({ id: device.id })
				.from(device)
				.where(eq(device.handle, parsed.handle))
				.limit(1);
			// Handles are given away, never lent: a claimed one stays claimed
			// even after its owner renames.
			if (taken) error(409, 'That handle is taken.');

			// And a released one is not handed on either. Checked second
			// because a live holder is the commoner case.
			const [retired] = await db
				.select({ handle: retiredHandle.handle })
				.from(retiredHandle)
				.where(eq(retiredHandle.handle, parsed.handle))
				.limit(1);
			if (retired) error(409, 'That handle has been used before and cannot be reclaimed.');
		}
		patch.handle = parsed.handle;
	}

	if ('displayName' in body) patch.displayName = parseDisplayName(body.displayName);
	if ('publicSubjects' in body) patch.publicSubjects = body.publicSubjects === true;

	if (Object.keys(patch).length > 0) {
		const write = db.update(device).set(patch).where(eq(device.id, owner.id));
		// A handle being given up is retired in the same batch that gives it
		// up, so there is no instant in which it is free for somebody else.
		const releasing = patch.handle !== undefined && owner.handle !== null;
		try {
			if (releasing) {
				await db.batch([
					db.insert(retiredHandle).values({ handle: owner.handle!, deviceId: owner.id }),
					write
				]);
			} else {
				await write;
			}
		} catch (cause) {
			// Two people claiming the same handle in the same instant: the
			// check above lost the race and the unique index caught it.
			if (String(cause).includes('UNIQUE')) error(409, 'That handle is taken.');
			throw cause;
		}
	}

	const changes = patch.handleChanges ?? owner.handleChanges;
	const profile: ProfileDTO = {
		handle: patch.handle ?? owner.handle,
		displayName: 'displayName' in patch ? (patch.displayName ?? null) : owner.displayName,
		publicSubjects: patch.publicSubjects ?? owner.publicSubjects,
		changesLeft: changesLeft(changes)
	};
	return json(profile);
};
