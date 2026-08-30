/** The wire format, matching the Swift DTOs. Dates are ISO8601 strings. */
export type IntervalDTO = {
	id: string;
	sessionId: string;
	subjectId: string | null;
	startedAt: string;
	endedAt: string | null;
	plannedSec: number | null;
};

export type SubjectDTO = {
	id: string;
	name: string;
	colorIndex: number;
	archived: boolean;
	updatedAt: string;
	deletedAt: string | null;
};

export type DaySummary = {
	/** The study-day, as YYYY-MM-DD — the date its 4am start falls on. */
	day: string;
	seconds: number;
	/** Whichever subject took the most of the day. */
	dominantSubjectId: string | null;
};

/** The profile, as its owner sees it. Null handle means nothing is published. */
export type ProfileDTO = {
	handle: string | null;
	displayName: string | null;
	publicSubjects: boolean;
	/** Renames remaining. The first claim is free; after that there are three. */
	changesLeft: number;
};

export type Summary = {
	timezone: string;
	goalMinutes: number;
	totalSeconds: number;
	streak: number;
	goalHitRate: number;
	days: DaySummary[];
	subjects: SubjectDTO[];
	profile: ProfileDTO;
};

/**
 * What `/{handle}` serves to anyone. Stats only unless the owner opted in:
 * without `showsSubjects`, `subjects` is empty and no day names the subject it
 * went to, so the heatmap draws intensity and nothing else.
 */
export type PublicProfile = {
	handle: string;
	displayName: string | null;
	streak: number;
	totalSeconds: number;
	goalHitRate: number;
	goalMinutes: number;
	days: DaySummary[];
	subjects: SubjectDTO[];
	showsSubjects: boolean;
};
