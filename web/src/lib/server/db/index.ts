import { error } from '@sveltejs/kit';
import { drizzle } from 'drizzle-orm/d1';
import * as schema from './schema';

/**
 * D1 arrives as a per-request binding, so there is no pool to hold open, no
 * connection to warm and nothing to close when the instance suspends — the
 * database is whatever the platform handed this invocation.
 */
export function database(platform: App.Platform | undefined) {
	const d1 = platform?.env.DB;
	// Only reachable if the Worker is running without its binding, which is a
	// deployment fault rather than anything the caller did.
	if (!d1) error(503, 'No database binding');
	return drizzle(d1, { schema });
}

export type Database = ReturnType<typeof database>;
export { schema };
