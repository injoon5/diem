CREATE TABLE `device` (
	`id` text PRIMARY KEY NOT NULL,
	`token` text NOT NULL,
	`timezone` text DEFAULT 'UTC' NOT NULL,
	`goal_minutes` integer DEFAULT 120 NOT NULL,
	`created_at` integer DEFAULT (unixepoch() * 1000) NOT NULL,
	`seen_at` integer DEFAULT (unixepoch() * 1000) NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `device_token_idx` ON `device` (`token`);--> statement-breakpoint
CREATE TABLE `interval` (
	`id` text PRIMARY KEY NOT NULL,
	`device_id` text NOT NULL,
	`session_id` text NOT NULL,
	`subject_id` text,
	`started_at` integer NOT NULL,
	`ended_at` integer,
	`planned_sec` integer,
	FOREIGN KEY (`device_id`) REFERENCES `device`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `interval_started_at_idx` ON `interval` (`started_at`);--> statement-breakpoint
CREATE INDEX `interval_session_idx` ON `interval` (`session_id`);--> statement-breakpoint
CREATE INDEX `interval_device_started_idx` ON `interval` (`device_id`,`started_at`);--> statement-breakpoint
CREATE TABLE `pair_code` (
	`code` text PRIMARY KEY NOT NULL,
	`device_id` text NOT NULL,
	`expires_at` integer NOT NULL,
	`claimed_at` integer,
	FOREIGN KEY (`device_id`) REFERENCES `device`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `subject` (
	`id` text PRIMARY KEY NOT NULL,
	`device_id` text NOT NULL,
	`name` text NOT NULL,
	`color_index` integer NOT NULL,
	`archived` integer DEFAULT false NOT NULL,
	`updated_at` integer NOT NULL,
	`deleted_at` integer,
	FOREIGN KEY (`device_id`) REFERENCES `device`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `subject_device_idx` ON `subject` (`device_id`);