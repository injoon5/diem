import { json, error } from '@sveltejs/kit';
import { eq, sql } from 'drizzle-orm';
import { db } from '$lib/server/db';
import { subject } from '$lib/server/db/schema';
import { currentDevice } from '$lib/server/auth';
import { parseSubject } from '$lib/server/validate';
import type { SubjectDTO } from '$lib/types';
import type { RequestHandler } from './$types';

function toDTO(row: typeof subject.$inferSelect): SubjectDTO {
	return {
		id: row.id,
		name: row.name,
		colorIndex: row.colorIndex,
		archived: row.archived,
		updatedAt: row.updatedAt.toISOString(),
		deletedAt: row.deletedAt?.toISOString() ?? null
	};
}

export const GET: RequestHandler = async (event) => {
	const device = await currentDevice(event);
	if (!device) error(401, 'Unknown device');

	const rows = await db.select().from(subject).where(eq(subject.deviceId, device.id));
	return json({ subjects: rows.map(toDTO) });
};

/** Last-write-wins on `updated_at`. An older write is simply ignored. */
export const POST: RequestHandler = async (event) => {
	const device = await currentDevice(event);
	if (!device) error(401, 'Unknown device');

	const body = (await event.request.json().catch(() => null)) as { subjects?: unknown[] } | null;
	const rows = (Array.isArray(body?.subjects) ? body.subjects.slice(0, 500) : [])
		.map(parseSubject)
		.filter((row) => row !== null);

	if (rows.length > 0) {
		await db
			.insert(subject)
			.values(rows.map((row) => ({ ...row, deviceId: device.id })))
			.onConflictDoUpdate({
				target: subject.id,
				set: {
					name: sql`excluded.name`,
					colorIndex: sql`excluded.color_index`,
					archived: sql`excluded.archived`,
					deletedAt: sql`excluded.deleted_at`,
					updatedAt: sql`excluded.updated_at`
				},
				setWhere: sql`${subject.updatedAt} < excluded.updated_at`
			});
	}

	const current = await db.select().from(subject).where(eq(subject.deviceId, device.id));
	return json({ subjects: current.map(toDTO) });
};
