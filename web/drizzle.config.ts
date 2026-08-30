import type { Config } from 'drizzle-kit';

/**
 * Generate-only: migrations are applied by `wrangler d1 migrations apply`,
 * which reads the same directory, so drizzle-kit never needs credentials.
 */
export default {
	schema: './src/lib/server/db/schema.ts',
	out: './drizzle',
	dialect: 'sqlite'
} satisfies Config;
