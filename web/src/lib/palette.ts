/** The same ten swatches the watch uses, in sRGB. */
export const SUBJECT_COLORS = [
	'#9ccc33',
	'#4ec761',
	'#21bf8c',
	'#1ab8b3',
	'#33bade',
	'#4099f0',
	'#4f70f2',
	'#7561ed',
	'#a65cea',
	'#d961c7'
];

export function subjectColor(index: number | null | undefined): string {
	if (index == null) return 'currentColor';
	const count = SUBJECT_COLORS.length;
	return SUBJECT_COLORS[((index % count) + count) % count];
}

export const ACCENT = '#ff590f';
