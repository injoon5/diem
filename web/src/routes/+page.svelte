<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import Heatmap from '$lib/components/Heatmap.svelte';
	import Stat from '$lib/components/Stat.svelte';
	import NewWatch from '$lib/components/NewWatch.svelte';
	import Profile from '$lib/components/Profile.svelte';
	import Subjects from '$lib/components/Subjects.svelte';
	import WeekBars from '$lib/components/WeekBars.svelte';
	import { hours, longDate } from '$lib/format';
	import { studyDays } from '$lib/summary';
	import type { ProfileDTO, Summary, SubjectDTO } from '$lib/types';

	let phase = $state<'loading' | 'ready' | 'unpaired' | 'error'>('loading');
	let summary = $state<Summary | null>(null);
	let code = $state('');
	let claiming = $state(false);
	let claimError = $state('');
	let subjectError = $state('');
	let signingOut = $state(false);

	const goalSeconds = $derived((summary?.goalMinutes ?? 120) * 60);

	const tagline = $derived.by(() => {
		const first = summary?.days.find((day) => day.seconds > 0);
		return first ? `A day at a time, since ${longDate(first.day)}.` : 'Nothing logged yet.';
	});

	onMount(() => {
		load();
		// The summary is worked out when the request is served, so a page left
		// open goes quietly wrong: a session ending on the wrist never appears,
		// and past 4am the streak and the last cell of the grid are a day
		// stale with nothing saying so. Two cheap triggers cover both.
		document.addEventListener('visibilitychange', refreshIfStale);
		window.addEventListener('focus', refreshIfStale);
		armBoundary();
	});

	onDestroy(() => {
		if (typeof document === 'undefined') return;
		document.removeEventListener('visibilitychange', refreshIfStale);
		window.removeEventListener('focus', refreshIfStale);
		clearTimeout(boundary);
	});

	let boundary: ReturnType<typeof setTimeout> | undefined;

	/** Fires once, just after the next 4am in the watch's timezone. */
	function armBoundary() {
		clearTimeout(boundary);
		if (!summary) return;
		const day = studyDays(summary.timezone);
		const now = Date.now();
		// Walk forward rather than doing timezone arithmetic by hand: the day
		// name is the thing that matters, and it changes exactly once. In
		// quarter hours, because some offsets are :30 and :45 and an hourly
		// step would land the refresh up to an hour late in those.
		const step = 900_000;
		let ahead = step;
		while (ahead <= 30 * 3_600_000 && day(new Date(now + ahead)) === day(new Date(now))) {
			ahead += step;
		}
		boundary = setTimeout(() => load(), ahead + 5_000);
	}

	function refreshIfStale() {
		if (document.visibilityState !== 'visible' || phase !== 'ready' || !summary) return;
		load();
	}

	async function load() {
		try {
			const response = await fetch('/api/summary');
			if (response.status === 401) {
				phase = 'unpaired';
				summary = null;
				return;
			}
			if (!response.ok) throw new Error(String(response.status));
			summary = (await response.json()) as Summary;
			phase = 'ready';
			armBoundary();
		} catch {
			// A refresh that fails leaves what is already drawn alone; only a
			// first load has nothing to fall back to.
			if (!summary) phase = 'error';
		}
	}

	async function signOut() {
		signingOut = true;
		try {
			await fetch('/api/claim', { method: 'DELETE' });
			summary = null;
			phase = 'unpaired';
		} finally {
			signingOut = false;
		}
	}

	async function claim(event: SubmitEvent) {
		event.preventDefault();
		claiming = true;
		claimError = '';
		try {
			const response = await fetch('/api/claim', {
				method: 'POST',
				headers: { 'content-type': 'application/json' },
				body: JSON.stringify({ code: code.trim().toUpperCase() })
			});
			if (!response.ok) {
				claimError = 'That code has expired or was already used.';
				return;
			}
			phase = 'loading';
			await load();
		} catch {
			claimError = 'Could not reach the server.';
		} finally {
			claiming = false;
		}
	}

	function saveProfile(profile: ProfileDTO) {
		if (summary) summary = { ...summary, profile };
	}

	/** A migration swaps the device underneath us, so nothing on-screen holds. */
	async function reload() {
		phase = 'loading';
		summary = null;
		await load();
	}

	/** The one write path on the web that the watch also owns. */
	async function saveSubject(next: SubjectDTO) {
		subjectError = '';
		let subjects: SubjectDTO[];
		try {
			const response = await fetch('/api/subjects', {
				method: 'POST',
				headers: { 'content-type': 'application/json' },
				body: JSON.stringify({ subjects: [next] })
			});
			if (!response.ok) throw new Error(String(response.status));
			({ subjects } = (await response.json()) as { subjects: SubjectDTO[] });
		} catch {
			subjectError = 'That rename did not reach the server. Nothing changed.';
			return;
		}
		if (!summary) return;
		summary = { ...summary, subjects };
		// A write older than what the server holds is dropped by design, and
		// the list comes back unchanged — which looks exactly like the rename
		// having silently failed. Say which it was.
		const stored = subjects.find((subject) => subject.id === next.id);
		if (stored && stored.name !== next.name) {
			subjectError = `Kept "${stored.name}" — the watch renamed it more recently.`;
		}
	}
</script>

<svelte:head>
	<title>Diem</title>
</svelte:head>

<header>
	<h1>Diem</h1>
	{#if phase === 'ready' && summary}
		<p class="tagline">{tagline}</p>
	{:else}
		<p class="tagline">A study timer for Apple Watch.</p>
	{/if}
</header>

{#if phase === 'loading'}
	<div class="skeleton">
		<div class="block stats"></div>
		<div class="block bars"></div>
		<div class="block map"></div>
	</div>
{:else if phase === 'unpaired'}
	<section class="pair">
		<h2>Pair your watch</h2>
		<p>Open Settings on the watch, tap <em>Pair with Web</em>, and type the six characters here.</p>
		<form onsubmit={claim}>
			<input
				bind:value={code}
				maxlength="6"
				autocapitalize="characters"
				autocomplete="off"
				spellcheck="false"
				placeholder="XXXXXX"
				aria-label="Pairing code"
			/>
			<button type="submit" disabled={claiming || code.trim().length !== 6}>
				{claiming ? 'Pairing…' : 'Pair'}
			</button>
		</form>
		{#if claimError}<p class="error">{claimError}</p>{/if}
	</section>
{:else if phase === 'error'}
	<section class="pair">
		<h2>Something went wrong</h2>
		<button onclick={load}>Try again</button>
	</section>
{:else if summary}
	<section class="stats">
		<Stat label="Streak" value={String(summary.streak)} unit={summary.streak === 1 ? 'day' : 'days'} accent />
		<Stat label="Goal hit" value={String(Math.round(summary.goalHitRate * 100))} unit="%" />
		<Stat label="Total" value={hours(summary.totalSeconds)} unit="h" />
	</section>

	<section>
		<h2 class="label">This week</h2>
		<WeekBars days={summary.days} {goalSeconds} />
	</section>

	<section>
		<h2 class="label">The year</h2>
		<Heatmap days={summary.days} subjects={summary.subjects} {goalSeconds} />
	</section>

	<section>
		<h2 class="label">Subjects</h2>
		<Subjects subjects={summary.subjects} onchange={saveSubject} />
		{#if subjectError}<p class="notice">{subjectError}</p>{/if}
	</section>

	<section>
		<h2 class="label">Profile</h2>
		<Profile profile={summary.profile} onchange={saveProfile} />
	</section>

	<section>
		<h2 class="label">Watch</h2>
		<NewWatch ondone={reload} />
	</section>

	<footer>
		<span>Paired to this browser.</span>
		<button type="button" onclick={signOut} disabled={signingOut}>
			{signingOut ? 'Signing out…' : 'Sign out'}
		</button>
	</footer>
{/if}

<style>
	header {
		margin-bottom: 40px;
	}

	h1 {
		font-size: 22px;
		letter-spacing: -0.02em;
	}

	.tagline {
		margin: 2px 0 0;
		color: var(--muted);
		font-size: 14px;
	}

	section {
		margin-bottom: 40px;
	}

	section h2.label {
		margin-bottom: 14px;
	}

	.stats {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 16px;
	}

	.pair {
		border: 1px solid var(--line);
		border-radius: var(--radius);
		padding: 24px;
	}

	.pair h2 {
		font-size: 17px;
	}

	.pair p {
		color: var(--muted);
		font-size: 14px;
		margin: 6px 0 18px;
	}

	form {
		display: flex;
		gap: 8px;
	}

	form input {
		flex: 1;
		background: var(--surface);
		border: 1px solid var(--line);
		border-radius: 8px;
		padding: 10px 12px;
		font-variant-numeric: tabular-nums;
		letter-spacing: 0.28em;
		text-transform: uppercase;
		outline: none;
	}

	form input:focus-visible {
		border-color: var(--accent);
	}

	button[type='submit'] {
		background: var(--accent);
		color: #fff;
		border: none;
		border-radius: 8px;
		padding: 10px 18px;
		font-weight: 500;
	}

	button[type='submit']:disabled {
		opacity: 0.4;
		cursor: default;
	}

	.error {
		color: var(--accent);
		font-size: 13px;
		margin: 12px 0 0;
	}

	.notice {
		color: var(--muted);
		font-size: 13px;
		margin: 12px 0 0;
	}

	footer {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 16px;
		border-top: 1px solid var(--line);
		padding-top: 16px;
		color: var(--faint);
		font-size: 13px;
	}

	footer button {
		background: none;
		border: 1px solid var(--line);
		border-radius: 8px;
		padding: 7px 14px;
		font-size: 13px;
		color: var(--muted);
	}

	footer button:hover:not(:disabled) {
		color: var(--text);
		border-color: var(--faint);
	}

	footer button:disabled {
		opacity: 0.5;
		cursor: default;
	}

	.skeleton {
		display: flex;
		flex-direction: column;
		gap: 40px;
	}

	.block {
		border-radius: var(--radius);
		background: linear-gradient(90deg, var(--surface) 25%, var(--empty) 50%, var(--surface) 75%);
		background-size: 200% 100%;
		animation: shimmer 1.4s linear infinite;
	}

	.block.stats {
		height: 56px;
	}

	.block.bars {
		height: 148px;
	}

	.block.map {
		height: 104px;
	}

	@keyframes shimmer {
		to {
			background-position: -200% 0;
		}
	}

	@media (max-width: 520px) {
		.stats {
			gap: 10px;
		}
	}
</style>
