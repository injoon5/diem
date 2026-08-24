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

export type Summary = {
	timezone: string;
	goalMinutes: number;
	totalSeconds: number;
	streak: number;
	goalHitRate: number;
	days: DaySummary[];
	subjects: SubjectDTO[];
};
