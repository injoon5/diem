<script lang="ts">
	import { untrack } from 'svelte';
	import type { ProfileDTO } from '$lib/types';

	let { profile, onchange }: { profile: ProfileDTO; onchange: (next: ProfileDTO) => void } =
		$props();

	// Drafts, seeded once. The parent unmounts this card whenever the device
	// underneath changes, so there is nothing to resync — and resyncing on every
	// prop change would yank the field out from under someone mid-word.
	let handle = $state(untrack(() => profile.handle) ?? '');
	let name = $state(untrack(() => profile.displayName) ?? '');
	let editing = $state(untrack(() => profile.handle) === null);
	let busy = $state(false);
	let message = $state('');
	let saved = $state(false);

	const url = $derived(profile.handle ? `/${profile.handle}` : null);
	const clean = $derived(handle.trim().toLowerCase().replace(/[^a-z0-9-]/g, ''));
	const spent = $derived(profile.handle !== null && profile.changesLeft === 0);

	const remaining = $derived(
		profile.changesLeft === 1 ? 'One change left.' : `${profile.changesLeft} changes left.`
	);

	/** One write path, so a rename and a toggle can't disagree about the rest. */
	async function save(patch: Partial<ProfileDTO>) {
		busy = true;
		message = '';
		try {
			const response = await fetch('/api/profile', {
				method: 'POST',
				headers: { 'content-type': 'application/json' },
				body: JSON.stringify(patch)
			});
			const body = await response.json().catch(() => null);
			if (!response.ok) {
				message = body?.message ?? 'That did not work.';
				return false;
			}
			onchange(body as ProfileDTO);
			saved = true;
			setTimeout(() => (saved = false), 1600);
			return true;
		} catch {
			message = 'Could not reach the server.';
			return false;
		} finally {
			busy = false;
		}
	}

	async function claim(event: SubmitEvent) {
		event.preventDefault();
		if (await save({ handle: clean })) editing = false;
	}

	function renameTo(next: string) {
		const trimmed = next.trim();
		if (trimmed === (profile.displayName ?? '')) return;
		save({ displayName: trimmed });
	}
</script>

<div class="card">
	{#if editing}
		<h3>{profile.handle ? 'Change your handle' : 'Claim your profile'}</h3>
		<p class="hint">
			{#if profile.handle}
				Your old address stops working the moment this changes, and anyone else can take it. You
				get three changes in all — {remaining.toLowerCase()}
			{:else}
				A public page of your streak, your hours and the shape of your year. Subject names stay
				private unless you say otherwise. Pick carefully: you can change it three times.
			{/if}
		</p>
		<form onsubmit={claim}>
			<div class="field">
				<span class="prefix">diem.ij5.dev/</span>
				<input
					bind:value={handle}
					maxlength="20"
					autocapitalize="none"
					autocomplete="off"
					spellcheck="false"
					placeholder="yourname"
					aria-label="Handle"
				/>
			</div>
			<button type="submit" disabled={busy || clean.length < 3 || clean === profile.handle}>
				{busy ? 'Claiming…' : 'Claim'}
			</button>
			{#if profile.handle}
				<button type="button" class="quiet" onclick={() => ((editing = false), (message = ''))}>
					Cancel
				</button>
			{/if}
		</form>
	{:else if url}
		<div class="live">
			<div>
				<h3>Your profile is live</h3>
				<a class="url" href={url}>diem.ij5.dev{url}</a>
			</div>
			{#if spent}
				<span class="spent" title="A handle can be changed three times">No changes left</span>
			{:else}
				<button type="button" class="quiet" onclick={() => (editing = true)}>Change</button>
			{/if}
		</div>

		<label class="row">
			<span>
				Display name
				<em>Shown instead of your handle.</em>
			</span>
			<input
				class="text"
				bind:value={name}
				maxlength="40"
				placeholder={profile.handle}
				onblur={() => renameTo(name)}
				onkeydown={(event) => event.key === 'Enter' && event.currentTarget.blur()}
			/>
		</label>

		<label class="row">
			<span>
				Show subjects
				<em>Off means hours and streaks only — no names, no colours.</em>
			</span>
			<input
				type="checkbox"
				class="switch"
				checked={profile.publicSubjects}
				onchange={(event) => save({ publicSubjects: event.currentTarget.checked })}
			/>
		</label>
	{/if}

	{#if message}<p class="error">{message}</p>{/if}
	{#if saved}<p class="saved">Saved.</p>{/if}
</div>

<style>
	.card {
		border: 1px solid var(--line);
		border-radius: var(--radius);
		padding: 20px;
	}

	h3 {
		font-size: 15px;
	}

	.hint {
		color: var(--muted);
		font-size: 13px;
		margin: 6px 0 16px;
		max-width: 46ch;
	}

	form {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
	}

	.field {
		flex: 1;
		min-width: 220px;
		display: flex;
		align-items: center;
		background: var(--surface);
		border: 1px solid var(--line);
		border-radius: 8px;
		padding: 0 12px;
	}

	.field:focus-within {
		border-color: var(--accent);
	}

	.prefix {
		color: var(--faint);
		font-size: 14px;
		white-space: nowrap;
	}

	.field input {
		flex: 1;
		min-width: 0;
		background: none;
		border: none;
		outline: none;
		padding: 10px 0;
		font-weight: 500;
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
	}

	.quiet:hover {
		color: var(--text);
		border-color: var(--faint);
	}

	.spent {
		font-size: 13px;
		color: var(--faint);
		white-space: nowrap;
	}

	.live {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 16px;
	}

	.url {
		display: inline-block;
		margin-top: 2px;
		color: var(--accent);
		font-size: 14px;
		text-decoration: none;
		font-weight: 500;
	}

	.url:hover {
		text-decoration: underline;
	}

	.row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 16px;
		border-top: 1px solid var(--line);
		margin-top: 18px;
		padding-top: 18px;
		font-size: 14px;
	}

	.row span {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.row em {
		font-style: normal;
		font-size: 12px;
		color: var(--faint);
		max-width: 40ch;
	}

	input.text {
		width: 180px;
		background: var(--surface);
		border: 1px solid var(--line);
		border-radius: 8px;
		padding: 8px 10px;
		outline: none;
		font-size: 14px;
	}

	input.text:focus-visible {
		border-color: var(--accent);
	}

	/* A checkbox that still is one: the box draws the track, ::before the knob. */
	.switch {
		appearance: none;
		flex: none;
		width: 40px;
		height: 24px;
		border-radius: 999px;
		background: var(--empty);
		border: 1px solid var(--line);
		position: relative;
		cursor: pointer;
		transition: background 0.18s ease;
	}

	.switch::before {
		content: '';
		position: absolute;
		top: 2px;
		left: 2px;
		width: 18px;
		height: 18px;
		border-radius: 50%;
		background: var(--bg);
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.28);
		transition: transform 0.18s cubic-bezier(0.32, 0.72, 0, 1);
	}

	.switch:checked {
		background: var(--accent);
		border-color: transparent;
	}

	.switch:checked::before {
		transform: translateX(16px);
	}

	.switch:focus-visible {
		outline: 2px solid var(--accent);
		outline-offset: 2px;
	}

	.error {
		color: var(--accent);
		font-size: 13px;
		margin: 12px 0 0;
	}

	.saved {
		color: var(--faint);
		font-size: 13px;
		margin: 12px 0 0;
	}

	@media (max-width: 520px) {
		.row {
			align-items: flex-start;
			flex-direction: column;
		}

		input.text {
			width: 100%;
		}
	}
</style>
