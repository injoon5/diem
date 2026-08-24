import adapter from '@sveltejs/adapter-vercel';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
export default {
	preprocess: vitePreprocess(),
	kit: {
		// Fluid compute keeps instances alive across invocations, which is what
		// makes a module-level connection pool worth having.
		adapter: adapter({ runtime: 'nodejs22.x' })
	}
};
