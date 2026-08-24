<script lang="ts">
	import '../app.css';

	let { children } = $props();
</script>

<div class="page">
	{@render children()}
</div>

<style>
	.page {
		max-width: var(--measure);
		margin: 0 auto;
		padding: 48px 20px 96px;
	}

	@media (max-width: 520px) {
		.page {
			padding: 28px 16px 64px;
		}
	}
</style>
