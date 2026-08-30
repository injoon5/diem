<script lang="ts">
	let { ondone }: { ondone: () => void } = $props();

	let open = $state(false);
	let confirming = $state(false);
	let code = $state('');
	let busy = $state(false);
	let message = $state('');
	/** Set when a request failed after the server may already have acted. */
	let uncertain = $state(false);

	const entered = $derived(code.trim().toUpperCase());

	/** The step that exists so the irreversible bit has to be read. */
	function ask(event: SubmitEvent) {
		event.preventDefault();
		message = '';
		confirming = true;
	}

	function back() {
		confirming = false;
		message = '';
	}

	async function migrate() {
		busy = true;
		message = '';
		uncertain = false;
		try {
			const response = await fetch('/api/migrate', {
				method: 'POST',
				headers: { 'content-type': 'application/json' },
				body: JSON.stringify({ code: entered })
			});
			if (!response.ok) {
				message =
					response.status === 404
						? 'That code has expired or was already used.'
						: 'That did not work.';
				confirming = false;
				return;
			}
			code = '';
			open = false;
			confirming = false;
			ondone();
		} catch {
			// The request left, and nothing came back. The move is atomic on
			// the server, so it either happened or it did not — but this side
			// cannot tell which, and guessing either way is worse than saying so.
			message = 'Could not reach the server. Reload the page to see whether the move went through.';
			uncertain = true;
			confirming = false;
		} finally {
			busy = false;
		}
	}
</script>

<div class="card">
	{#if !open}
		<div class="head">
			<div>
				<h3>Got a new watch?</h3>
				<p>Move your history, your streak and your profile across.</p>
			</div>
			<button type="button" class="quiet" onclick={() => (open = true)}>Replace watch</button>
		</div>
	{:else if confirming}
		<h3>Move everything to {entered}?</h3>
		<p>
			Your whole history, your streak and your profile move to the new watch. This watch stops
			syncing from that moment, and anything it has not already sent stays on it. There is no way
			to undo this.
		</p>
		<div class="actions">
			<button type="button" class="danger" disabled={busy} onclick={migrate}>
				{busy ? 'Moving…' : 'Yes, move it'}
			</button>
			<button type="button" class="quiet" disabled={busy} onclick={back}>Back</button>
		</div>
	{:else}
		<h3>Replace your watch</h3>
		<p>
			Install Diem on the new watch, open <em>Pair with Web</em> in its settings, and type the code
			it shows. Everything moves across, and the old watch stops syncing.
		</p>
		<form onsubmit={ask}>
			<input
				bind:value={code}
				maxlength="6"
				autocapitalize="characters"
				autocomplete="off"
				spellcheck="false"
				placeholder="XXXXXX"
				aria-label="Pairing code from the new watch"
			/>
			<button type="submit" disabled={busy || entered.length !== 6}>Continue</button>
			<button type="button" class="quiet" onclick={() => ((open = false), (message = ''))}>
				Cancel
			</button>
		</form>
	{/if}
	{#if message}<p class="error" class:uncertain>{message}</p>{/if}
</div>

<style>
	.card {
		border: 1px solid var(--line);
		border-radius: var(--radius);
		padding: 20px;
	}

	.head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 16px;
	}

	h3 {
		font-size: 15px;
	}

	p {
		color: var(--muted);
		font-size: 13px;
		margin: 6px 0 0;
		max-width: 52ch;
	}

	form {
		display: flex;
		gap: 8px;
		margin-top: 16px;
		flex-wrap: wrap;
	}

	form input {
		flex: 1;
		min-width: 160px;
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

	.quiet {
		background: none;
		border: 1px solid var(--line);
		border-radius: 8px;
		padding: 8px 14px;
		font-size: 13px;
		color: var(--muted);
		white-space: nowrap;
	}

	.quiet:hover {
		color: var(--text);
		border-color: var(--faint);
	}

	em {
		font-style: normal;
		color: var(--text);
	}

	.actions {
		display: flex;
		gap: 8px;
		margin-top: 16px;
		flex-wrap: wrap;
	}

	.danger {
		background: var(--accent);
		color: #fff;
		border: none;
		border-radius: 8px;
		padding: 10px 18px;
		font-weight: 500;
	}

	.danger:disabled {
		opacity: 0.4;
		cursor: default;
	}

	.error {
		color: var(--accent);
		font-size: 13px;
		margin: 12px 0 0;
	}

	/* Not a failure so much as an unknown, and it should not read as one. */
	.error.uncertain {
		color: var(--muted);
	}

	@media (max-width: 520px) {
		.head {
			flex-direction: column;
			align-items: flex-start;
		}
	}
</style>
