<script lang="ts">
	import type { DaySummary, SubjectDTO } from '$lib/types';
	import { duration, shortDate, weekday } from '$lib/format';
	import { subjectColor } from '$lib/palette';

	let {
		days,
		subjects,
		goalSeconds,
		/**
		 * The hue for a day with no subject to borrow one from. Neutral on the
		 * dashboard, where a free session sitting quiet among named ones is the
		 * point; the accent on a public page, where every day is subject-less
		 * and a whole grey year says nothing.
		 */
		fallback = 'var(--muted)'
	}: {
		days: DaySummary[];
		subjects: SubjectDTO[];
		goalSeconds: number;
		fallback?: string;
	} = $props();

	const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

	const colorFor = $derived.by(() => {
		const byId = new Map(subjects.map((subject) => [subject.id, subject.colorIndex]));
		return (day: DaySummary) => {
			if (day.seconds <= 0) return 'var(--empty)';
			// Dominant subject picks the hue; minutes pick the intensity.
			// A day of free study has no subject colour to borrow, so it stays
			// neutral rather than becoming the brightest cell in the grid.
			const hue = day.dominantSubjectId
				? subjectColor(byId.get(day.dominantSubjectId) ?? 0)
				: fallback;
			const share = goalSeconds > 0 ? Math.min(day.seconds / goalSeconds, 1) : 1;
			const strength = Math.round((0.28 + 0.72 * share) * 100);
			return `color-mix(in srgb, ${hue} ${strength}%, transparent)`;
		};
	});

	/** Blank leading cells so every column is one calendar week. */
	const lead = $derived(days.length > 0 ? weekday(days[0].day) : 0);

	const months = $derived.by(() => {
		const labels: { column: number; name: string }[] = [];
		let previous = '';
		days.forEach((day, index) => {
			const month = day.day.slice(0, 7);
			const column = Math.floor((index + lead) / 7) + 1;
			if (month !== previous && column > (labels.at(-1)?.column ?? -2) + 2) {
				labels.push({ column, name: MONTHS[Number(day.day.slice(5, 7)) - 1] });
				previous = month;
			}
		});
		return labels;
	});

	const columns = $derived(Math.ceil((days.length + lead) / 7));
</script>

<div class="wrap">
	<div class="months" style:--cols={columns}>
		{#each months as month (month.column)}
			<span style:grid-column={month.column}>{month.name}</span>
		{/each}
	</div>
	<div class="grid" style:--cols={columns} role="img" aria-label="Study time over the last year">
		{#each Array(lead) as _, index (`lead-${index}`)}
			<div class="cell blank"></div>
		{/each}
		{#each days as day (day.day)}
			<div
				class="cell"
				style:background={colorFor(day)}
				title="{shortDate(day.day)} · {day.seconds > 0 ? duration(day.seconds) : 'nothing'}"
			></div>
		{/each}
	</div>
</div>

<style>
	.wrap {
		overflow-x: auto;
		padding-bottom: 4px;
	}

	.grid,
	.months {
		display: grid;
		grid-template-columns: repeat(var(--cols), 11px);
		gap: 3px;
		min-width: max-content;
	}

	.grid {
		grid-template-rows: repeat(7, 11px);
		grid-auto-flow: column;
	}

	.months {
		font-size: 10px;
		color: var(--faint);
		margin-bottom: 5px;
	}

	.cell {
		width: 11px;
		height: 11px;
		border-radius: 2px;
	}

	.blank {
		background: transparent;
	}
</style>
