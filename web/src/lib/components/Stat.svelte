<script lang="ts">
	let {
		label,
		value,
		unit = '',
		accent = false,
		/** A qualifier the number is meaningless without. Reserved for that. */
		note = ''
	}: { label: string; value: string; unit?: string; accent?: boolean; note?: string } = $props();
</script>

<div class="stat">
	<div class="label">{label}</div>
	<div class="value numeral" class:accent>
		{value}{#if unit}<span class="unit" class:word={unit.length > 1}>{unit}</span>{/if}
	</div>
	{#if note}<div class="note">{note}</div>{/if}
</div>

<style>
	.stat {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.value {
		font-size: 30px;
		line-height: 1.1;
	}

	.accent {
		color: var(--accent);
	}

	.unit {
		font-size: 0.45em;
		font-weight: 400;
		color: var(--muted);
		margin-left: 2px;
	}

	.unit.word {
		margin-left: 5px;
	}

	.note {
		font-size: 11px;
		color: var(--faint);
		margin-top: 1px;
	}
</style>
