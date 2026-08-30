import { and, eq, gte, isNotNull } from 'drizzle-orm';
import type { Database } from './db';
import { interval, subject, type Device } from './db/schema';
import { calendar, dominant, hitRate, streak, studyDays } from '$lib/summary';
import type { DaySummary, SubjectDTO } from '$lib/types';

/** A year, plus enough slack for the grid to start on a week boundary. */
export const WINDOW_DAYS = 371;

export function subjectDTO(row: typeof subject.$inferSelect): SubjectDTO {
	return {
		id: row.id,
		name: row.name,
		colorIndex: row.colorIndex,
		archived: row.archived,
		updatedAt: row.updatedAt.toISOString(),
		deletedAt: row.deletedAt?.toISOString() ?? null
	};
}

export type Aggregate = {
	days: DaySummary[];
	subjects: SubjectDTO[];
	totalSeconds: number;
	streak: number;
	goalHitRate: number;
};

/**
 * The dashboard's one read, and the public page's.
 *
 * SQLite has no timezone database — `localtime` means the server's zone, not an
 * arbitrary IANA one — so the day bucketing that a Postgres `date_trunc(... AT
 * TIME ZONE ...)` did in the query happens here instead. A year of one wrist's
 * sessions is a few thousand narrow rows; summing them is cheaper than the
 * round trip that fetched them.
 */
export async function summarize(db: Database, device: Device): Promise<Aggregate> {
	const cutoff = new Date(Date.now() - (WINDOW_DAYS + 2) * 86_400_000);

	const [rows, subjects] = await Promise.all([
		db
			.select({
				subjectId: interval.subjectId,
				startedAt: interval.startedAt,
				endedAt: interval.endedAt
			})
			.from(interval)
			.where(
				and(
					eq(interval.deviceId, device.id),
					isNotNull(interval.endedAt),
					gte(interval.startedAt, cutoff)
				)
			),
		db.select().from(subject).where(eq(subject.deviceId, device.id))
	]);

	const dayOf = studyDays(device.timezone);
	const totals = new Map<string, { seconds: number; bySubject: Map<string | null, number> }>();
	for (const row of rows) {
		if (!row.endedAt) continue;
		const day = dayOf(row.startedAt);
		const entry = totals.get(day) ?? { seconds: 0, bySubject: new Map() };
		const seconds = (row.endedAt.getTime() - row.startedAt.getTime()) / 1000;
		entry.seconds += seconds;
		entry.bySubject.set(row.subjectId, (entry.bySubject.get(row.subjectId) ?? 0) + seconds);
		totals.set(day, entry);
	}

	const days: DaySummary[] = calendar(device.timezone, WINDOW_DAYS).map((day) => {
		const entry = totals.get(day);
		if (!entry) return { day, seconds: 0, dominantSubjectId: null };
		return { day, seconds: entry.seconds, dominantSubjectId: dominant(entry.bySubject) };
	});

	return {
		days,
		subjects: subjects.map(subjectDTO),
		totalSeconds: days.reduce((sum, day) => sum + day.seconds, 0),
		streak: streak(days),
		goalHitRate: hitRate(days, device.goalMinutes * 60)
	};
}
