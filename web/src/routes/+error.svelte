<script lang="ts">
	import { page } from '$app/state';
</script>

<svelte:head><title>Diem</title></svelte:head>

<div class="oops">
	<h1 class="numeral">{page.status}</h1>
	<p>{page.status === 404 ? 'Nothing here.' : page.error?.message}</p>
	<a href="/">Back to Diem</a>
</div>

<style>
	.oops {
		padding: 64px 0;
	}

	h1 {
		font-size: 44px;
		color: var(--faint);
		line-height: 1;
	}

	p {
		margin: 8px 0 20px;
		color: var(--muted);
	}

	a {
		font-size: 14px;
		font-weight: 500;
		color: var(--accent);
		text-decoration: none;
	}
</style>
