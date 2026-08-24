import type { IntervalDTO, SubjectDTO } from '$lib/types';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isUuid(value: unknown): value is string {
	return typeof value === 'string' && UUID.test(value);
}

function date(value: unknown): Date | null {
	if (typeof value !== 'string') return null;
	const parsed = new Date(value);
	return Number.isNaN(parsed.getTime()) ? null : parsed;
}

export type ParsedInterval = {
	id: string;
	sessionId: string;
	subjectId: string | null;
	startedAt: Date;
	endedAt: Date;
	plannedSec: number | null;
};

/** Only completed intervals sync, so an open one is dropped rather than stored. */
export function parseInterval(raw: unknown): ParsedInterval | null {
	if (typeof raw !== 'object' || raw === null) return null;
	const value = raw as Partial<IntervalDTO>;
	if (!isUuid(value.id) || !isUuid(value.sessionId)) return null;
	if (value.subjectId != null && !isUuid(value.subjectId)) return null;

	const startedAt = date(value.startedAt);
	const endedAt = date(value.endedAt);
	if (!startedAt || !endedAt || endedAt < startedAt) return null;

	const plannedSec =
		typeof value.plannedSec === 'number' && Number.isFinite(value.plannedSec) && value.plannedSec > 0
			? Math.round(value.plannedSec)
			: null;

	return {
		id: value.id,
		sessionId: value.sessionId,
		subjectId: value.subjectId ?? null,
		startedAt,
		endedAt,
		plannedSec
	};
}

export type ParsedSubject = {
	id: string;
	name: string;
	colorIndex: number;
	archived: boolean;
	updatedAt: Date;
	deletedAt: Date | null;
};

export function parseSubject(raw: unknown): ParsedSubject | null {
	if (typeof raw !== 'object' || raw === null) return null;
	const value = raw as Partial<SubjectDTO>;
	if (!isUuid(value.id)) return null;

	const name = typeof value.name === 'string' ? value.name.trim().slice(0, 60) : '';
	if (!name) return null;

	const updatedAt = date(value.updatedAt);
	if (!updatedAt) return null;

	return {
		id: value.id,
		name,
		colorIndex:
			typeof value.colorIndex === 'number' && Number.isFinite(value.colorIndex)
				? Math.max(0, Math.round(value.colorIndex))
				: 0,
		archived: value.archived === true,
		updatedAt,
		deletedAt: date(value.deletedAt)
	};
}
