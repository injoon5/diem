/**
 * Six characters, Crockford-ish: no I, L, O, U, 0 or 1, so nothing is ambiguous
 * on a watch screen or when read aloud.
 */
const ALPHABET = '23456789ABCDEFGHJKMNPQRSTVWXYZ';

export function pairingCode(): string {
	const bytes = crypto.getRandomValues(new Uint8Array(6));
	return Array.from(bytes, (byte) => ALPHABET[byte % ALPHABET.length]).join('');
}

export const CODE_TTL_MS = 10 * 60 * 1000;
