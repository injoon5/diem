<script lang="ts">
	import type { SubjectDTO } from '$lib/types';
	import { SUBJECT_COLORS, subjectColor } from '$lib/palette';

	let {
		subjects,
		onchange
	}: { subjects: SubjectDTO[]; onchange: (subject: SubjectDTO) => Promise<void> } = $props();

	let editing = $state<string | null>(null);
	let draft = $state('');

	/**
	 * What has been asked for and not yet come back, per subject.
	 *
	 * Every write sends the whole subject, so two of them in quick succession
	 * used to undo each other: a colour picked while a rename was still in
	 * flight sent the old name with a newer timestamp, and last-write-wins put
	 * the old name back. The patches are kept here until the server has the
	 * lot, and the rows on screen are drawn through them.
	 */
	let pending = $state<Record<string, Partial<SubjectDTO>>>({});

	/** The write in flight for a subject, so the next one queues behind it. */
	const queues = new Map<string, Promise<void>>();

	const visible = $derived(
		subjects
			.filter((subject) => subject.deletedAt === null)
			.map((subject) => ({ ...subject, ...pending[subject.id] }))
	);

	function save(subject: SubjectDTO, patch: Partial<SubjectDTO>) {
		const id = subject.id;
		pending = { ...pending, [id]: { ...pending[id], ...patch } };
		const queued = (queues.get(id) ?? Promise.resolve())
			.then(async () => {
				// Looked up again rather than closed over: an earlier write in
				// this queue has been answered since it was made, and its
				// answer is what this one has to build on.
				const current = subjects.find((row) => row.id === id) ?? subject;
				await onchange({
					...current,
					...pending[id],
					updatedAt: new Date().toISOString()
				});
			})
			// Never left rejected: a failed write must not strand the ones
			// queued behind it. The page says what went wrong.
			.catch(() => {})
			.finally(() => {
				// Only the last write in the queue clears the overlay — until
				// then the newer patches are still waiting to be sent.
				if (queues.get(id) !== queued) return;
				queues.delete(id);
				const rest = { ...pending };
				delete rest[id];
				pending = rest;
			});
		queues.set(id, queued);
	}

	function commit(subject: SubjectDTO) {
		const name = draft.trim();
		editing = null;
		if (name && name !== subject.name) save(subject, { name });
	}
</script>

<ul>
	{#each visible as subject (subject.id)}
		<li class:archived={subject.archived}>

			{#if editing === subject.id}
				<!-- svelte-ignore a11y_autofocus -->
				<input
					autofocus
					bind:value={draft}
					onblur={() => commit(subject)}
					onkeydown={(event) => {
						if (event.key === 'Enter') commit(subject);
						if (event.key === 'Escape') editing = null;
					}}
				/>
			{:else}
				<button
					class="name"
					onclick={() => {
						editing = subject.id;
						draft = subject.name;
					}}
				>
					{subject.name}
				</button>
			{/if}

			<div class="swatches">
				{#each SUBJECT_COLORS as _, index (index)}
					<button
						class="swatch"
						class:selected={subject.colorIndex === index}
						style:background={subjectColor(index)}
						aria-label="Colour {index + 1}"
						onclick={() => save(subject, { colorIndex: index })}
					></button>
				{/each}
			</div>

			<button class="archive" onclick={() => save(subject, { archived: !subject.archived })}>
				{subject.archived ? 'Unarchive' : 'Archive'}
			</button>
		</li>
	{:else}
		<li class="empty">No subjects yet — add them on the watch.</li>
	{/each}
</ul>

<style>
	ul {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
	}

	li {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 10px 0;
		border-bottom: 1px solid var(--line);
	}

	li.archived .name {
		color: var(--faint);
	}

	.swatches {
		display: grid;
		margin-left: auto;
		grid-template-columns: repeat(10, 1fr);
		gap: 3px;
		flex: 0 0 auto;
	}

	.swatch {
		width: 10px;
		height: 10px;
		border: none;
		border-radius: 50%;
		padding: 0;
		opacity: 0.32;
		transition: opacity 0.15s ease, transform 0.15s ease;
	}

	.swatch:hover {
		opacity: 0.7;
	}

	.swatch.selected {
		opacity: 1;
		transform: scale(1.35);
	}

	.name,
	input {
		flex: 1;
		background: none;
		border: none;
		text-align: left;
		padding: 4px 0;
		font-size: 15px;
	}

	input {
		border-bottom: 1px solid var(--accent);
		outline: none;
	}

	.archive {
		background: none;
		border: 1px solid var(--line);
		border-radius: 999px;
		padding: 3px 10px;
		font-size: 12px;
		color: var(--muted);
	}

	.archive:hover {
		color: var(--text);
	}

	.empty {
		color: var(--muted);
		border-bottom: none;
	}
</style>
