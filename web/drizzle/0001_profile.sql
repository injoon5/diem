ALTER TABLE `device` ADD `handle` text;--> statement-breakpoint
ALTER TABLE `device` ADD `display_name` text;--> statement-breakpoint
ALTER TABLE `device` ADD `public_subjects` integer DEFAULT false NOT NULL;--> statement-breakpoint
CREATE UNIQUE INDEX `device_handle_idx` ON `device` (`handle`);