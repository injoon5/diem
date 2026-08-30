/**
 * A handle is a path segment at the root of the site, so it competes with every
 * route the app might ever add. Three to twenty characters, lowercase, digits
 * and hyphens, never starting or ending on a hyphen.
 */
const SHAPE = /^[a-z0-9][a-z0-9-]{1,18}[a-z0-9]$/;

/**
 * Words a handle would shadow or be mistaken for. `api` is the load-bearing
 * one — everything else is cheap to reserve now and impossible to reclaim
 * later.
 */
const RESERVED = new Set([
	'about',
	'account',
	'admin',
	'api',
	'app',
	'assets',
	'claim',
	'diem',
	'favicon',
	'help',
	'home',
	'index',
	'login',
	'logout',
	'me',
	'migrate',
	'new',
	'pair',
	'privacy',
	'profile',
	'robots',
	'settings',
	'signin',
	'signup',
	'sitemap',
	'static',
	'status',
	'support',
	'terms',
	'watch',
	'www'
]);

/**
 * The first claim is free; after that a handle may move three times.
 *
 * A released handle goes straight back into circulation, so every rename hands
 * somebody else an address other people already hold links to. The cap does not
 * close that — see B-46 in the description's triage — but it bounds it.
 */
export const HANDLE_CHANGES = 3;

/** Renames remaining, given how many have been spent. */
export function changesLeft(spent: number): number {
	return Math.max(0, HANDLE_CHANGES - spent);
}

export type HandleError = 'shape' | 'reserved';

/** Normalises to lowercase, or says why it can't be a handle. */
export function parseHandle(raw: unknown): { handle: string } | { error: HandleError } {
	const handle = typeof raw === 'string' ? raw.trim().toLowerCase().replace(/^@/, '') : '';
	if (!SHAPE.test(handle)) return { error: 'shape' };
	if (RESERVED.has(handle)) return { error: 'reserved' };
	return { handle };
}

/** Empty is a deliberate clear, not a rejection. */
export function parseDisplayName(raw: unknown): string | null {
	if (typeof raw !== 'string') return null;
	const name = raw.trim().replace(/\s+/g, ' ').slice(0, 40);
	return name.length > 0 ? name : null;
}
