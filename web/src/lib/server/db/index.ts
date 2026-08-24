import { attachDatabasePool } from '@vercel/functions';
import { drizzle } from 'drizzle-orm/node-postgres';
import pg from 'pg';
import { env } from '$env/dynamic/private';
import * as schema from './schema';

/**
 * One pool per instance, against PSBouncer on 6432.
 *
 * `max` stays at its default — capping it at 1 only hurts throughput — and
 * `min: 1` keeps a warm connection for the next invocation. Transaction-mode
 * pooling breaks prepared statements, which is fine: `pg` doesn't use them
 * unless asked.
 */
const pool = new pg.Pool({
	connectionString: env.DATABASE_URL,
	min: 1,
	idleTimeoutMillis: 30_000,
	connectionTimeoutMillis: 10_000
});

// Closes the pool when the instance suspends. Without this, redeploys strand
// connections until the pooler times them out.
attachDatabasePool(pool);

export const db = drizzle(pool, { schema });
export { schema };
