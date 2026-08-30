import { error } from '@sveltejs/kit';
import { eq } from 'drizzle-orm';
import { database } from '$lib/server/db';
import { device } from '$lib/server/db/schema';
import { summarize } from '$lib/server/summarize';
import { parseHandle } from '$lib/server/handles';
import type { PublicProfile } from '$lib/types';
import type { PageServerLoad } from './$types';

/**
 * Rendered on the server rather than fetched: a profile is a link people send
 * each other, and a link that unfurls as a blank page with a spinner behind it
 * is a worse link.
 */
export const load: PageServerLoad = async ({ params, platform, setHeaders }) => {
	const parsed = parseHandle(params.handle);
	if ('error' in parsed) error(404, 'No such profile');

	const db = database(platform);
	const [owner] = await db.select().from(device).where(eq(device.handle, parsed.handle)).limit(1);
	if (!owner) error(404, 'No such profile');

	const aggregate = await summarize(db, owner);
	const shows = owner.publicSubjects;

	const profile: PublicProfile = {
		handle: parsed.handle,
		displayName: owner.displayName,
		streak: aggregate.streak,
		totalSeconds: aggregate.totalSeconds,
		goalHitRate: aggregate.goalHitRate,
		goalMinutes: owner.goalMinutes,
		// Stats only until the owner opts in — and that means the days stop
		// naming their subject too, not just the list going away. A heatmap
		// coloured by subject is a list of subjects with extra steps.
		days: shows
			? aggregate.days
			: aggregate.days.map((day) => ({ ...day, dominantSubjectId: null })),
		subjects: shows ? aggregate.subjects.filter((s) => !s.deletedAt) : [],
		showsSubjects: shows
	};

	setHeaders({ 'cache-control': 'public, max-age=60' });
	return { profile };
};
