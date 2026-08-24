import { json, error } from '@sveltejs/kit';
import { and, eq, gte, isNotNull, sql } from 'drizzle-orm';
import { db } from '$lib/server/db';
import { interval, subject } from '$lib/server/db/schema';
import { currentDevice } from '$lib/server/auth';
import { calendar, dominant, hitRate, streak } from '$lib/summary';
import type { DaySummary, Summary, SubjectDTO } from '$lib/types';
import type { RequestHandler } from './$types';

/** A year, plus enough slack for the grid to start on a week boundary. */
const WINDOW_DAYS = 371;

export const GET: RequestHandler = async (event) => {
	const device = await currentDevice(event);
	if (!device) error(401, 'Not paired');

	const zone = device.timezone;
	// A session counts toward the day it started; a day runs 4am to 4am local.
	const dayExpr = sql<string>`to_char(
		date_trunc('day', (${interval.startedAt} AT TIME ZONE ${zone}) - interval '4 hours'),
		'YYYY-MM-DD'
	)`;
	const secondsExpr = sql<number>`sum(
		extract(epoch from (${interval.endedAt} - ${interval.startedAt}))
	)::float8`;

	const cutoff = new Date(Date.now() - (WINDOW_DAYS + 2) * 86_400_000);
	const [buckets, subjects] = await Promise.all([
		db
			.select({ day: dayExpr, subjectId: interval.subjectId, seconds: secondsExpr })
			.from(interval)
			.where(
				and(
					eq(interval.deviceId, device.id),
					isNotNull(interval.endedAt),
					gte(interval.startedAt, cutoff)
				)
			)
			// By ordinal: repeating the expression would repeat its bind
			// parameter, and Postgres won't match `$1` against `$4`.
			.groupBy(sql`1`, sql`2`),
		db.select().from(subject).where(eq(subject.deviceId, device.id))
	]);

	const totals = new Map<string, { seconds: number; bySubject: Map<string | null, number> }>();
	for (const bucket of buckets) {
		const entry = totals.get(bucket.day) ?? { seconds: 0, bySubject: new Map() };
		const seconds = Number(bucket.seconds) || 0;
		entry.seconds += seconds;
		entry.bySubject.set(bucket.subjectId, (entry.bySubject.get(bucket.subjectId) ?? 0) + seconds);
		totals.set(bucket.day, entry);
	}

	const days: DaySummary[] = calendar(zone, WINDOW_DAYS).map((day) => {
		const entry = totals.get(day);
		if (!entry) return { day, seconds: 0, dominantSubjectId: null };
		return { day, seconds: entry.seconds, dominantSubjectId: dominant(entry.bySubject) };
	});

	const goalSeconds = device.goalMinutes * 60;
	const summary: Summary = {
		timezone: zone,
		goalMinutes: device.goalMinutes,
		totalSeconds: days.reduce((sum, day) => sum + day.seconds, 0),
		streak: streak(days),
		goalHitRate: hitRate(days, goalSeconds),
		days,
		subjects: subjects.map(
			(row): SubjectDTO => ({
				id: row.id,
				name: row.name,
				colorIndex: row.colorIndex,
				archived: row.archived,
				updatedAt: row.updatedAt.toISOString(),
				deletedAt: row.deletedAt?.toISOString() ?? null
			})
		)
	};

	return json(summary, { headers: { 'cache-control': 'private, max-age=30' } });
};
