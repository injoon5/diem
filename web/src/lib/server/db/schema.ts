import { sql } from 'drizzle-orm';
import { index, integer, sqliteTable, text, uniqueIndex } from 'drizzle-orm/sqlite-core';

/**
 * SQLite has no uuid, boolean or timestamp type. Ids stay `text` and are
 * generated in the app rather than by a `gen_random_uuid()` default; instants
 * are stored as epoch milliseconds, which `timestamp_ms` reads back as a
 * `Date`, so nothing above this file has to know.
 */
const now = sql`(unixepoch() * 1000)`;

/**
 * A paired watch. The watch generates its own token on first launch and works
 * fully without ever reaching this table.
 */
export const device = sqliteTable(
	'device',
	{
		id: text('id')
			.primaryKey()
			.$defaultFn(() => crypto.randomUUID()),
		token: text('token').notNull(),
		/**
		 * Sessions are stored in UTC and bucketed by the local day they started
		 * in, so the server needs to know which local day that is.
		 */
		timezone: text('timezone').notNull().default('UTC'),
		/** The one setting the web needs a copy of, for the goal-hit rate. */
		goalMinutes: integer('goal_minutes').notNull().default(120),
		/**
		 * The public profile, and the only thing the web owns outright. Null
		 * until claimed, and claiming it is what publishes `/{handle}` — there
		 * is no separate visibility switch, because a page nobody can find is
		 * the same as no page.
		 */
		handle: text('handle'),
		displayName: text('display_name'),
		/**
		 * Renames spent. The first claim is free; after that a handle may move
		 * three times and no more. A released handle goes straight back into
		 * circulation, so an unbounded rename is an unbounded supply of other
		 * people's old links.
		 */
		handleChanges: integer('handle_changes').notNull().default(0),
		/**
		 * Stats only by default. What a public page shows without this is the
		 * shape of a year, a streak and a total; with it, the subject names and
		 * the colours the heatmap draws them in.
		 */
		publicSubjects: integer('public_subjects', { mode: 'boolean' }).notNull().default(false),
		createdAt: integer('created_at', { mode: 'timestamp_ms' })
			.notNull()
			.default(now),
		seenAt: integer('seen_at', { mode: 'timestamp_ms' }).notNull().default(now)
	},
	(table) => [
		uniqueIndex('device_token_idx').on(table.token),
		uniqueIndex('device_handle_idx').on(table.handle)
	]
);

/**
 * Handles that have been given up.
 *
 * A released handle used to go straight back into circulation, which meant a
 * link somebody had already shared could later resolve to a different person's
 * study record under the name its first owner was known by. Retiring them
 * closes that: a handle is claimable once, ever.
 */
export const retiredHandle = sqliteTable('retired_handle', {
	handle: text('handle').primaryKey(),
	/** Whoever gave it up, kept so a rename can be walked back by hand. */
	deviceId: text('device_id'),
	releasedAt: integer('released_at', { mode: 'timestamp_ms' }).notNull().default(now)
});

/** Six characters, shown on the watch, entered once on the web. */
export const pairCode = sqliteTable('pair_code', {
	code: text('code').primaryKey(),
	deviceId: text('device_id')
		.notNull()
		.references(() => device.id, { onDelete: 'cascade' }),
	expiresAt: integer('expires_at', { mode: 'timestamp_ms' }).notNull(),
	claimedAt: integer('claimed_at', { mode: 'timestamp_ms' })
});

/**
 * The one mutable entity: last-write-wins on `updated_at`, soft delete via
 * `deleted_at`.
 */
export const subject = sqliteTable(
	'subject',
	{
		id: text('id').primaryKey(),
		deviceId: text('device_id')
			.notNull()
			.references(() => device.id, { onDelete: 'cascade' }),
		name: text('name').notNull(),
		colorIndex: integer('color_index').notNull(),
		archived: integer('archived', { mode: 'boolean' }).notNull().default(false),
		updatedAt: integer('updated_at', { mode: 'timestamp_ms' }).notNull(),
		deletedAt: integer('deleted_at', { mode: 'timestamp_ms' })
	},
	(table) => [index('subject_device_idx').on(table.deviceId)]
);

/**
 * Immutable once `ended_at` is set — no conflicts, no tombstones, no merge
 * logic. A row with no `subject_id` is a free session; nothing else marks one.
 */
export const interval = sqliteTable(
	'interval',
	{
		id: text('id').primaryKey(),
		deviceId: text('device_id')
			.notNull()
			.references(() => device.id, { onDelete: 'cascade' }),
		sessionId: text('session_id').notNull(),
		subjectId: text('subject_id'),
		startedAt: integer('started_at', { mode: 'timestamp_ms' }).notNull(),
		endedAt: integer('ended_at', { mode: 'timestamp_ms' }),
		/** First interval of a timed session only. */
		plannedSec: integer('planned_sec')
	},
	(table) => [
		index('interval_started_at_idx').on(table.startedAt),
		index('interval_session_idx').on(table.sessionId),
		index('interval_device_started_idx').on(table.deviceId, table.startedAt)
	]
);

export type Device = typeof device.$inferSelect;
export type Subject = typeof subject.$inferSelect;
export type Interval = typeof interval.$inferSelect;
