import { json, error } from '@sveltejs/kit';
import { database } from '$lib/server/db';
import { currentDevice } from '$lib/server/auth';
import { summarize } from '$lib/server/summarize';
import { changesLeft } from '$lib/server/handles';
import type { Summary } from '$lib/types';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async (event) => {
	const db = database(event.platform);
	const device = await currentDevice(event, db);
	if (!device) error(401, 'Not paired');

	const summary: Summary = {
		timezone: device.timezone,
		goalMinutes: device.goalMinutes,
		...(await summarize(db, device)),
		profile: {
			handle: device.handle,
			displayName: device.displayName,
			publicSubjects: device.publicSubjects,
			changesLeft: changesLeft(device.handleChanges)
		}
	};

	return json(summary, { headers: { 'cache-control': 'private, max-age=30' } });
};
