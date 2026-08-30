CREATE TABLE `retired_handle` (
	`handle` text PRIMARY KEY NOT NULL,
	`device_id` text,
	`released_at` integer DEFAULT (unixepoch() * 1000) NOT NULL
);
