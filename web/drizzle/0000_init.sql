CREATE TABLE "device" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"token" text NOT NULL,
	"timezone" text DEFAULT 'UTC' NOT NULL,
	"goal_minutes" integer DEFAULT 120 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"seen_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "interval" (
	"id" uuid PRIMARY KEY NOT NULL,
	"device_id" uuid NOT NULL,
	"session_id" uuid NOT NULL,
	"subject_id" uuid,
	"started_at" timestamp with time zone NOT NULL,
	"ended_at" timestamp with time zone,
	"planned_sec" integer
);
--> statement-breakpoint
CREATE TABLE "pair_code" (
	"code" char(6) PRIMARY KEY NOT NULL,
	"device_id" uuid NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"claimed_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "subject" (
	"id" uuid PRIMARY KEY NOT NULL,
	"device_id" uuid NOT NULL,
	"name" text NOT NULL,
	"color_index" integer NOT NULL,
	"archived" boolean DEFAULT false NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "interval" ADD CONSTRAINT "interval_device_id_device_id_fk" FOREIGN KEY ("device_id") REFERENCES "public"."device"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "pair_code" ADD CONSTRAINT "pair_code_device_id_device_id_fk" FOREIGN KEY ("device_id") REFERENCES "public"."device"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "subject" ADD CONSTRAINT "subject_device_id_device_id_fk" FOREIGN KEY ("device_id") REFERENCES "public"."device"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "device_token_idx" ON "device" USING btree ("token");--> statement-breakpoint
CREATE INDEX "interval_started_at_idx" ON "interval" USING btree ("started_at");--> statement-breakpoint
CREATE INDEX "interval_session_idx" ON "interval" USING btree ("session_id");--> statement-breakpoint
CREATE INDEX "interval_device_started_idx" ON "interval" USING btree ("device_id","started_at");--> statement-breakpoint
CREATE INDEX "subject_device_idx" ON "subject" USING btree ("device_id");