import {
	boolean,
	char,
	index,
	integer,
	pgTable,
	text,
	timestamp,
	uniqueIndex,
	uuid
} from 'drizzle-orm/pg-core';

/**
 * A paired watch. The watch generates its own token on first launch and works
 * fully without ever reaching this table.
 */
export const device = pgTable(
	'device',
	{
		id: uuid('id').primaryKey().defaultRandom(),
		token: text('token').notNull(),
		/**
		 * Sessions are stored in UTC and bucketed by the local day they started
		 * in, so the server needs to know which local day that is.
		 */
		timezone: text('timezone').notNull().default('UTC'),
		/** The one setting the web needs a copy of, for the goal-hit rate. */
		goalMinutes: integer('goal_minutes').notNull().default(120),
		createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
		seenAt: timestamp('seen_at', { withTimezone: true }).notNull().defaultNow()
	},
	(table) => [uniqueIndex('device_token_idx').on(table.token)]
);

/** Six characters, shown on the watch, entered once on the web. */
export const pairCode = pgTable('pair_code', {
	code: char('code', { length: 6 }).primaryKey(),
	deviceId: uuid('device_id')
		.notNull()
		.references(() => device.id, { onDelete: 'cascade' }),
	expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
	claimedAt: timestamp('claimed_at', { withTimezone: true })
});

/**
 * The one mutable entity: last-write-wins on `updated_at`, soft delete via
 * `deleted_at`.
 */
export const subject = pgTable(
	'subject',
	{
		id: uuid('id').primaryKey(),
		deviceId: uuid('device_id')
			.notNull()
			.references(() => device.id, { onDelete: 'cascade' }),
		name: text('name').notNull(),
		colorIndex: integer('color_index').notNull(),
		archived: boolean('archived').notNull().default(false),
		updatedAt: timestamp('updated_at', { withTimezone: true }).notNull(),
		deletedAt: timestamp('deleted_at', { withTimezone: true })
	},
	(table) => [index('subject_device_idx').on(table.deviceId)]
);

/**
 * Immutable once `ended_at` is set — no conflicts, no tombstones, no merge
 * logic. A row with no `subject_id` is a free session; nothing else marks one.
 */
export const interval = pgTable(
	'interval',
	{
		id: uuid('id').primaryKey(),
		deviceId: uuid('device_id')
			.notNull()
			.references(() => device.id, { onDelete: 'cascade' }),
		sessionId: uuid('session_id').notNull(),
		subjectId: uuid('subject_id'),
		startedAt: timestamp('started_at', { withTimezone: true }).notNull(),
		endedAt: timestamp('ended_at', { withTimezone: true }),
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
