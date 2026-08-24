import type { DaySummary } from './types';

/**
 * Every study-day in a window, oldest first, as YYYY-MM-DD.
 *
 * A study-day runs 4am to 4am, so shifting an instant back four hours turns it
 * into the day it belongs to.
 */
export function calendar(zone: string, days: number, now = Date.now()): string[] {
	const formatter = new Intl.DateTimeFormat('en-CA', {
		timeZone: zone,
		year: 'numeric',
		month: '2-digit',
		day: '2-digit'
	});
	const today = now - 4 * 3_600_000;
	return Array.from({ length: days }, (_, index) =>
		formatter.format(new Date(today - (days - 1 - index) * 86_400_000))
	);
}

/**
 * Consecutive days with any study at all. Breaks only on a day with zero
 * study — no grace days — and today not having started yet doesn't break it.
 */
export function streak(days: DaySummary[]): number {
	let count = 0;
	for (let index = days.length - 1; index >= 0; index -= 1) {
		if (days[index].seconds > 0) {
			count += 1;
		} else if (index === days.length - 1) {
			continue;
		} else {
			break;
		}
	}
	return count;
}

/** The separate signal that sits beside the streak. */
export function hitRate(days: DaySummary[], goalSeconds: number, window = 30): number {
	const recent = days.slice(-window);
	if (recent.length === 0 || goalSeconds <= 0) return 0;
	return recent.filter((day) => day.seconds >= goalSeconds).length / recent.length;
}

/** Whichever subject took the most of a day. */
export function dominant(bySubject: Map<string | null, number>): string | null {
	let best = 0;
	let winner: string | null = null;
	for (const [subjectId, seconds] of bySubject) {
		if (seconds > best) {
			best = seconds;
			winner = subjectId;
		}
	}
	return winner;
}
