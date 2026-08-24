/** Same rules as the watch: minutes under an hour, tenths of an hour above. */
export function total(seconds: number): { value: string; unit: string } {
	if (seconds < 3600) return { value: String(Math.floor(seconds / 60)), unit: 'm' };
	const hours = Math.floor(seconds / 360) / 10;
	return { value: hours.toFixed(1), unit: 'h' };
}

export function hours(seconds: number): string {
	return (Math.floor(seconds / 360) / 10).toFixed(1);
}

export function duration(seconds: number): string {
	const minutes = Math.floor(seconds / 60);
	if (minutes < 60) return `${minutes}m`;
	const rest = minutes % 60;
	return rest === 0 ? `${Math.floor(minutes / 60)}h` : `${Math.floor(minutes / 60)}h ${rest}m`;
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** `2026-03-04` → `4 Mar`, without dragging in a date library. */
export function shortDate(day: string): string {
	const [, month, date] = day.split('-').map(Number);
	return `${date} ${MONTHS[(month ?? 1) - 1]}`;
}

/** `2025-10-28` → `28 Oct 2025`. */
export function longDate(day: string): string {
	const [year] = day.split('-');
	return `${shortDate(day)} ${year}`;
}

export function weekday(day: string): number {
	return new Date(`${day}T12:00:00Z`).getUTCDay();
}
