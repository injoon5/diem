import assert from 'node:assert/strict';
import test from 'node:test';
import { calendar, dominant, hitRate, streak } from '../src/lib/summary.ts';
import type { DaySummary } from '../src/lib/types.ts';

const day = (day: string, seconds: number): DaySummary => ({
	day,
	seconds,
	dominantSubjectId: null
});

test('the calendar ends on today and walks back one day at a time', () => {
	const now = Date.parse('2026-03-04T12:00:00Z');
	assert.deepEqual(calendar('UTC', 3, now), ['2026-03-02', '2026-03-03', '2026-03-04']);
});

test('before 4am still counts as the previous day', () => {
	const now = Date.parse('2026-03-04T03:30:00Z');
	assert.deepEqual(calendar('UTC', 1, now), ['2026-03-03']);
});

test('4am starts the new day', () => {
	const now = Date.parse('2026-03-04T04:00:00Z');
	assert.deepEqual(calendar('UTC', 1, now), ['2026-03-04']);
});

test('the streak counts back from today', () => {
	assert.equal(
		streak([day('2026-03-01', 600), day('2026-03-02', 600), day('2026-03-03', 900)]),
		3
	);
});

test('a zero day breaks the streak — no grace days', () => {
	assert.equal(streak([day('2026-03-01', 600), day('2026-03-02', 0), day('2026-03-03', 900)]), 1);
});

test('today not having started yet does not break the streak', () => {
	assert.equal(streak([day('2026-03-01', 600), day('2026-03-02', 900), day('2026-03-03', 0)]), 2);
});

test('an empty log has no streak', () => {
	assert.equal(streak([day('2026-03-01', 0), day('2026-03-02', 0)]), 0);
});

test('the goal-hit rate is a share of the window, not of the streak', () => {
	const days = [day('2026-03-01', 7200), day('2026-03-02', 600), day('2026-03-03', 7200)];
	assert.equal(hitRate(days, 7200, 3), 2 / 3);
});

test('no goal means no rate', () => {
	assert.equal(hitRate([day('2026-03-01', 7200)], 0), 0);
});

test('the dominant subject is the one with the most seconds', () => {
	const totals = new Map<string | null, number>([
		[null, 300],
		['a', 900],
		['b', 1200]
	]);
	assert.equal(dominant(totals), 'b');
});

test('a day of free study has no dominant subject', () => {
	assert.equal(dominant(new Map<string | null, number>([[null, 900]])), null);
});
