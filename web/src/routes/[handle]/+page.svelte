<script lang="ts">
	import Heatmap from '$lib/components/Heatmap.svelte';
	import Stat from '$lib/components/Stat.svelte';
	import WeekBars from '$lib/components/WeekBars.svelte';
	import { duration, hours, longDate } from '$lib/format';
	import { subjectColor } from '$lib/palette';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	const profile = $derived(data.profile);
	const goalSeconds = $derived(profile.goalMinutes * 60);
	const name = $derived(profile.displayName ?? profile.handle);

	const since = $derived.by(() => {
		const first = profile.days.find((day) => day.seconds > 0);
		return first ? `Studying since ${longDate(first.day)}.` : 'Nothing logged yet.';
	});

	const visible = $derived(profile.subjects.filter((subject) => !subject.archived));
</script>

<svelte:head>
	<title>{name} · Diem</title>
	<meta
		name="description"
		content="{name} has studied {hours(profile.totalSeconds)} hours on Diem."
	/>
	<meta property="og:title" content="{name} · Diem" />
	<meta
		property="og:description"
		content="A {profile.streak}-day streak and {hours(profile.totalSeconds)} hours studied."
	/>
</svelte:head>

<header>
	<div class="who">
		<h1>{name}</h1>
		{#if profile.displayName}<span class="handle">@{profile.handle}</span>{/if}
	</div>
	<p class="tagline">{since}</p>
</header>

<section class="stats">
	<Stat
		label="Streak"
		value={String(profile.streak)}
		unit={profile.streak === 1 ? 'day' : 'days'}
		accent
	/>
	<!--
		The goal the rate is measured against, said out loud. Without it two
		profiles both reading 80% look comparable when one of them set fifteen
		minutes a day and the other set four hours.
	-->
	<Stat
		label="Goal hit"
		value={String(Math.round(profile.goalHitRate * 100))}
		unit="%"
		note="of {duration(profile.goalMinutes * 60)} a day"
	/>
	<Stat label="Total" value={hours(profile.totalSeconds)} unit="h" />
</section>

<section>
	<h2 class="label">This week</h2>
	<WeekBars days={profile.days} {goalSeconds} />
</section>

<section>
	<h2 class="label">The year</h2>
	<Heatmap
		days={profile.days}
		subjects={profile.subjects}
		{goalSeconds}
		fallback="var(--accent)"
	/>
</section>

{#if profile.showsSubjects && visible.length > 0}
	<section>
		<h2 class="label">Subjects</h2>
		<ul class="subjects">
			{#each visible as subject (subject.id)}
				<li>
					<span class="dot" style:background={subjectColor(subject.colorIndex)}></span>
					{subject.name}
				</li>
			{/each}
		</ul>
	</section>
{/if}

<footer>
	<a href="/">Diem</a> — a study timer for Apple Watch.
</footer>

<style>
	header {
		margin-bottom: 40px;
	}

	.who {
		display: flex;
		align-items: baseline;
		gap: 8px;
		flex-wrap: wrap;
	}

	h1 {
		font-size: 22px;
		letter-spacing: -0.02em;
	}

	.handle {
		color: var(--faint);
		font-size: 14px;
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

	.subjects {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-wrap: wrap;
		gap: 8px;
	}

	.subjects li {
		display: flex;
		align-items: center;
		gap: 8px;
		border: 1px solid var(--line);
		border-radius: 999px;
		padding: 5px 12px 5px 10px;
		font-size: 13px;
	}

	.dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
	}

	footer {
		border-top: 1px solid var(--line);
		padding-top: 16px;
		color: var(--faint);
		font-size: 13px;
	}

	footer a {
		color: var(--muted);
		text-decoration: none;
		font-weight: 500;
	}

	footer a:hover {
		color: var(--text);
	}

	@media (max-width: 520px) {
		.stats {
			gap: 10px;
		}
	}
</style>
