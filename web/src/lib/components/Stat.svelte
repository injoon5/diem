<script lang="ts">
	let {
		label,
		value,
		unit = '',
		accent = false
	}: { label: string; value: string; unit?: string; accent?: boolean } = $props();
</script>

<div class="stat">
	<div class="label">{label}</div>
	<div class="value numeral" class:accent>
		{value}{#if unit}<span class="unit" class:word={unit.length > 1}>{unit}</span>{/if}
	</div>
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
</style>
