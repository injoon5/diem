<script lang="ts">
	import type { DaySummary } from '$lib/types';
	import { duration, shortDate, weekday } from '$lib/format';
	import { ACCENT } from '$lib/palette';

	let { days, goalSeconds }: { days: DaySummary[]; goalSeconds: number } = $props();

	const INITIALS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

	// The current week, starting on Sunday. Days after today stay empty.
	const week = $derived.by(() => {
		const today = days[days.length - 1];
		if (!today) return [];
		const offset = weekday(today.day);
		const start = days.length - 1 - offset;
		return Array.from({ length: 7 }, (_, index) => days[start + index] ?? null);
	});

	const peak = $derived(
		Math.max(goalSeconds, ...week.map((day) => day?.seconds ?? 0))
	);
</script>

<div class="week">
	{#each week as day, index (index)}
		<div class="column">
			<div class="track" title={day ? `${shortDate(day.day)} · ${duration(day.seconds)}` : ''}>
				{#if day && day.seconds > 0}
					<div
						class="bar"
						style:height="{peak > 0 ? Math.min(100, (day.seconds / peak) * 100) : 0}%"
						style:background={day.seconds >= goalSeconds
							? ACCENT
							: `color-mix(in srgb, ${ACCENT} 55%, transparent)`}
					></div>
				{/if}
			</div>
			<div class="day">{INITIALS[index]}</div>
			<div class="amount numeral">{day && day.seconds > 0 ? duration(day.seconds) : '—'}</div>
		</div>
	{/each}
</div>

<style>
	.week {
		display: grid;
		grid-template-columns: repeat(7, 1fr);
		gap: 8px;
		align-items: end;
	}

	.column {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 6px;
	}

	.track {
		width: 100%;
		max-width: 52px;
		margin: 0 auto;
		height: 104px;
		display: flex;
		align-items: flex-end;
		background: var(--empty);
		border-radius: 6px;
		overflow: hidden;
	}

	.bar {
		width: 100%;
		border-radius: 6px;
		min-height: 2px;
		transition: height 0.35s cubic-bezier(0.32, 0.72, 0, 1);
	}

	.day {
		font-size: 12px;
		color: var(--muted);
	}

	.amount {
		font-size: 11px;
		color: var(--faint);
	}

	@media (max-width: 520px) {
		.amount {
			display: none;
		}
	}
</style>
