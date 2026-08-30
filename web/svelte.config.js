import adapter from '@sveltejs/adapter-cloudflare';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
export default {
	preprocess: vitePreprocess(),
	// The adapter reads wrangler.jsonc to emulate the D1 binding during
	// `vite dev`, so `platform.env.DB` is the same shape locally as deployed.
	kit: { adapter: adapter() }
};
